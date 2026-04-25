import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import '../config/app_config.dart';
import '../models/models.dart';

class ApiService {
  static const Duration _productReviewCacheTtl = Duration(minutes: 3);
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  late final Dio _dio;
  String? _token;
  bool _isTokenLoaded = false;
  final Map<String, _CachedReviewCollection> _rankedReviewCache =
      <String, _CachedReviewCollection>{};
  final Map<String, _InFlightReviewRequest> _rankedReviewInFlight =
      <String, _InFlightReviewRequest>{};
  final Map<String, _CachedReviewPreviewCollection> _reviewPreviewCache =
      <String, _CachedReviewPreviewCollection>{};
  final Map<String, _InFlightReviewPreviewRequest> _reviewPreviewInFlight =
      <String, _InFlightReviewPreviewRequest>{};

  bool _shouldSuppressErrorLog(DioException error) {
    final statusCode = error.response?.statusCode;
    if (statusCode == null) {
      return false;
    }
    final suppressedStatuses =
        error.requestOptions.extra['suppressErrorLogStatuses'];
    if (suppressedStatuses is! Iterable) {
      return false;
    }
    for (final value in suppressedStatuses) {
      if (value is int && value == statusCode) {
        return true;
      }
      if (int.tryParse('$value') == statusCode) {
        return true;
      }
    }
    return false;
  }

  Map<String, dynamic> _redactedHeaders(Map<String, dynamic> headers) {
    final redacted = Map<String, dynamic>.from(headers);
    if (redacted.containsKey('Authorization')) {
      redacted['Authorization'] = 'Bearer [REDACTED]';
    }
    if (redacted.containsKey('authorization')) {
      redacted['authorization'] = 'Bearer [REDACTED]';
    }
    return redacted;
  }

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      // Do NOT set Content-Type here. Dio sets it automatically:
      // - 'application/json' for Map/JSON data
      // - 'multipart/form-data; boundary=...' for FormData
      // A static value here conflicts with FormData uploads.
    ));

    // Add interceptors
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Ensure token is loaded before making requests
        if (!_isTokenLoaded) {
          await _loadToken();
        }
        if (_token != null) {
          options.headers['Authorization'] = 'Bearer $_token';
        }
        return handler.next(options);
      },
      onError: (error, handler) {
        if (!_shouldSuppressErrorLog(error)) {
          debugPrint(
              'API Error [${error.response?.statusCode}]: ${error.message}');
          if (error.response != null) {
            debugPrint('  Response body: ${error.response!.data}');
            debugPrint('  Request URL: ${error.requestOptions.uri}');
            debugPrint(
                '  Request headers: ${_redactedHeaders(error.requestOptions.headers)}');
          }
        }
        return handler.next(error);
      },
    ));
  }

  Future<void> _loadToken() async {
    if (_isTokenLoaded) return;

    try {
      _token = await _storage.read(key: 'buzz_token');
      if (_token != null) {
        _dio.options.headers['Authorization'] = 'Bearer $_token';
        debugPrint('Token loaded successfully');
      } else {
        debugPrint('No token found in storage');
      }
    } catch (e) {
      debugPrint('Error loading token: $e');
    } finally {
      _isTokenLoaded = true;
    }
  }

  // Public method to ensure token is loaded
  Future<void> ensureTokenLoaded() async {
    await _loadToken();
  }

  Future<String?> getAuthToken() async {
    await _loadToken();
    return _token;
  }

  // Check if user has a token (is potentially logged in)
  Future<bool> hasToken() async {
    await _loadToken();
    return _token != null;
  }

  String? get currentToken => _token;

  Future<void> _saveToken(String token) async {
    _token = token;
    await _storage.write(key: 'buzz_token', value: token);
    _dio.options.headers['Authorization'] = 'Bearer $_token';
  }

  Future<void> _clearToken() async {
    _token = null;
    await _storage.delete(key: 'buzz_token');
    _dio.options.headers.remove('Authorization');
  }

  // Auth APIs
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await _dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });

      final token = response.data['access_token'] as String;
      await _saveToken(token);

      return response.data as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> register(
    String email,
    String password,
    String name, {
    String accountType = 'CONSUMER',
    String privacyProfile = 'PUBLIC',
    String? phoneNumber,
  }) async {
    try {
      // Map account type to role and convert to lowercase for backend
      final accountTypeLower = accountType.toLowerCase();
      String role = accountType == 'SELLER' ? 'seller' : 'consumer';

      final data = {
        'email': email,
        'password': password,
        'name': name,
        'account_type': accountTypeLower,
        'role': role,
        'privacy_profile': privacyProfile.toLowerCase(),
      };

      // Add phone number if provided
      if (phoneNumber != null && phoneNumber.isNotEmpty) {
        data['phone_number'] = phoneNumber;
      }

      final response = await _dio.post('/auth/register', data: data);

      final token = response.data['access_token'] as String;
      await _saveToken(token);

      return response.data as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  Future<UserModel> getMe() async {
    try {
      final response = await _dio.get('/auth/me');
      return UserModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  Future<UserModel> getUser(String userId) async {
    try {
      final response = await _dio.get('/users/$userId');
      return UserModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  // ============================================================================
  // INSTAGRAM-STYLE FEED & POST APIs
  // ============================================================================

  /// Get followers feed (posts from people you follow)
  /// Uses cursor-based pagination for infinite scroll
  Future<FeedResponse> getFollowersFeed({
    String? cursor,
    int limit = 20,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'limit': limit,
      };
      if (cursor != null) {
        queryParams['cursor'] = cursor;
      }

      final response = await _dio.get(
        '/feed/followers',
        queryParameters: queryParams,
      );

      return FeedResponse.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  /// Get discovery feed (ranked public posts)
  /// Uses pull model  with engagement-based ranking
  Future<FeedResponse> getDiscoveryFeed({
    String? cursor,
    int limit = 20,
    bool excludeFollowing = false,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'limit': limit,
      };
      if (cursor != null) {
        queryParams['cursor'] = cursor;
      }
      if (excludeFollowing) {
        queryParams['exclude_following'] = 'true';
      }

      final response = await _dio.get(
        '/feed/discovery',
        queryParameters: queryParams,
      );

      return FeedResponse.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  /// Get posts from a specific user (for profile gallery)
  Future<FeedResponse> getUserPosts({
    required String userId,
    String? cursor,
    int limit = 20,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'limit': limit,
      };
      if (cursor != null) {
        queryParams['cursor'] = cursor;
      }

      final response = await _dio.get(
        '/feed/user/$userId',
        queryParameters: queryParams,
      );

      return FeedResponse.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  /// Create a new post (requires mediaId from uploaded media)
  Future<Map<String, dynamic>> createPost({
    required String mediaId,
    String? caption,
    List<String>? taggedUsers,
    List<String>? hashtags,
  }) async {
    try {
      final data = <String, dynamic>{
        'media_id': mediaId,
      };
      if (caption != null && caption.isNotEmpty) {
        data['caption'] = caption;
      }
      if (taggedUsers != null && taggedUsers.isNotEmpty) {
        data['tagged_users'] = taggedUsers;
      }
      if (hashtags != null && hashtags.isNotEmpty) {
        data['hashtags'] = hashtags;
      }

      final response = await _dio.post('/posts', data: data);
      return response.data as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  /// Like a post
  Future<void> likePost(String postId) async {
    try {
      await _dio.post('/posts/$postId/like');
    } catch (e) {
      rethrow;
    }
  }

  /// Unlike a post
  Future<void> unlikePost(String postId) async {
    try {
      await _dio.delete('/posts/$postId/like');
    } catch (e) {
      rethrow;
    }
  }

  /// Upload photo with option to create post automatically
  Future<Map<String, dynamic>> uploadPhoto({
    required XFile imageFile,
    String? caption,
    bool createPost = false,
  }) async {
    try {
      // Ensure token is loaded
      await ensureTokenLoaded();

      // Use bytes-based upload for cross-platform (web + mobile) support
      final bytes = await imageFile.readAsBytes();
      final fileName = imageFile.name;
      debugPrint(
          '[uploadPhoto] fileName=$fileName, size=${bytes.length}, mime=${_getImageMediaType(fileName)}');

      final formData = FormData.fromMap({
        'image': MultipartFile.fromBytes(
          bytes,
          filename: fileName,
          contentType: _getImageMediaType(fileName),
        ),
        if (caption != null && caption.isNotEmpty) 'caption': caption,
        'create_post': createPost.toString(),
      });

      final response = await _dio.post(
        '/upload/user-photo',
        data: formData,
        options: Options(
          sendTimeout: const Duration(minutes: 5),
          receiveTimeout: const Duration(minutes: 2),
        ),
      );

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      debugPrint(
          '[uploadPhoto] Failed: ${e.response?.statusCode} - ${e.response?.data}');
      rethrow;
    } catch (e) {
      debugPrint('[uploadPhoto] Unexpected error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> uploadAvatar(XFile file) async {
    try {
      await ensureTokenLoaded();

      final bytes = await file.readAsBytes();
      final fileName = _resolveImageFileName(file, fallbackPrefix: 'avatar');
      final multipartFile = MultipartFile.fromBytes(
        bytes,
        filename: fileName,
        contentType: _getImageMediaType(fileName),
      );
      debugPrint(
          '[uploadAvatar] fileName=$fileName, path=${file.path}, length=${multipartFile.length}');

      final formData = FormData.fromMap({
        'avatar': multipartFile,
      });

      final response = await _dio.post(
        '/upload/avatar',
        data: formData,
        options: Options(
          sendTimeout: const Duration(minutes: 5),
          receiveTimeout: const Duration(minutes: 2),
        ),
      );

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      debugPrint(
          '[uploadAvatar] Failed: ${e.response?.statusCode} - ${e.response?.data}');
      rethrow;
    }
  }

  String _resolveImageFileName(XFile file, {String fallbackPrefix = 'image'}) {
    final fileName = file.name.trim();
    if (fileName.isNotEmpty) {
      return fileName;
    }

    final pathName = file.path.trim().split(RegExp(r'[\\/]')).last;
    if (pathName.isNotEmpty && pathName != file.path.trim()) {
      return pathName;
    }

    return '${fallbackPrefix}_${DateTime.now().millisecondsSinceEpoch}.jpg';
  }

  Future<void> deleteAvatar() async {
    try {
      await _dio.delete('/upload/avatar');
    } on DioException catch (e) {
      debugPrint(
          '[deleteAvatar] Failed: ${e.response?.statusCode} - ${e.response?.data}');
      rethrow;
    }
  }

  Future<UserModel> updateProfile(Map<String, dynamic> data) async {
    try {
      final response = await _dio.put('/auth/profile', data: data);
      return UserModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> logout() async {
    await _clearToken();
  }

  List<ReviewModel>? peekCachedProductReviewsRanked(
    String productId, {
    int limit = 50,
    bool allowPartial = false,
  }) {
    final cacheKey = _rankedReviewCacheKey(productId);
    final cached = _rankedReviewCache[cacheKey];
    if (cached == null) {
      return null;
    }
    if (cached.isExpired(_productReviewCacheTtl)) {
      _rankedReviewCache.remove(cacheKey);
      return null;
    }
    if (!allowPartial && !cached.canSatisfy(limit)) {
      return null;
    }
    return List<ReviewModel>.from(cached.slice(limit));
  }

  ProductReviewPreviewModel? peekCachedProductReviewPreview(
    String productId, {
    int limit = 3,
  }) {
    final cacheKey = _reviewPreviewCacheKey(productId);
    final cached = _reviewPreviewCache[cacheKey];
    if (cached == null) {
      return null;
    }
    if (cached.isExpired(_productReviewCacheTtl)) {
      _reviewPreviewCache.remove(cacheKey);
      return null;
    }
    if (!cached.canSatisfy(limit)) {
      return null;
    }
    return ProductReviewPreviewModel(
      reviewCount: cached.reviewCount,
      reviews: List<ReviewPreviewModel>.from(cached.slice(limit)),
    );
  }

  void invalidateProductReviewCache(String productId) {
    final cacheKeySuffix = '::$productId';
    _rankedReviewCache.removeWhere(
      (key, _) => key.endsWith(cacheKeySuffix),
    );
    _rankedReviewInFlight.removeWhere(
      (key, _) => key.endsWith(cacheKeySuffix),
    );
    _reviewPreviewCache.removeWhere(
      (key, _) => key.endsWith(cacheKeySuffix),
    );
    _reviewPreviewInFlight.removeWhere(
      (key, _) => key.endsWith(cacheKeySuffix),
    );
  }

  Future<void> warmProductReviewsRanked(String productId,
      {int limit = 50}) async {
    try {
      await getProductReviewsRanked(productId, limit: limit);
    } catch (_) {
      // A warm-up miss should never block UI flows.
    }
  }

  // Feed API
  Future<List<FeedItem>> getFeed() async {
    try {
      final response = await _dio.get('/feed');
      return (response.data as List)
          .map((item) => FeedItem.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  // Products APIs
  Future<List<ProductModel>> getProducts({String? category}) async {
    try {
      final response = await _dio.get('/products', queryParameters: {
        if (category != null && category.isNotEmpty) 'category': category,
      });
      return (response.data as List)
          .map((item) => ProductModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<ProductModel>> getSellerProducts(String sellerId) async {
    try {
      final response = await _dio.get('/products/seller/$sellerId');
      return (response.data as List)
          .map((item) => ProductModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // Return empty list if no products found
      debugPrint('Error fetching seller products: $e');
      return [];
    }
  }

  Future<ProductModel> getProduct(String id) async {
    try {
      final response = await _dio.get('/products/$id');
      return ProductModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  Future<List<NetworkPurchaseModel>> getNetworkPurchases(
      {int limit = 10}) async {
    try {
      final response =
          await _dio.get('/products/network-purchases', queryParameters: {
        'limit': limit,
      });
      return (response.data as List)
          .map((item) =>
              NetworkPurchaseModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // Return empty list if endpoint not implemented yet
      debugPrint('Network purchases API not available: $e');
      return [];
    }
  }

  Future<List<ProductBuyerModel>> getProductBuyers(String productId,
      {int limit = 100}) async {
    try {
      final response = await _dio.get(
        '/products/$productId/buyers',
        queryParameters: {'limit': limit},
      );
      return (response.data as List? ?? [])
          .map((item) =>
              ProductBuyerModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching product buyers: $e');
      return [];
    }
  }

  Future<ProductReviewPreviewModel> getProductReviewPreview(
    String productId, {
    int limit = 3,
    bool forceRefresh = false,
  }) async {
    await _loadToken();
    final cacheKey = _reviewPreviewCacheKey(productId);

    if (!forceRefresh) {
      final cached = peekCachedProductReviewPreview(productId, limit: limit);
      if (cached != null) {
        return cached;
      }

      final inFlight = _reviewPreviewInFlight[cacheKey];
      if (inFlight != null && inFlight.requestedLimit >= limit) {
        final preview = await inFlight.future;
        return ProductReviewPreviewModel(
          reviewCount: preview.reviewCount,
          reviews: List<ReviewPreviewModel>.from(preview.reviews.take(limit)),
        );
      }
    }

    final request = _fetchProductReviewPreviewNetwork(
      cacheKey,
      productId,
      limit: limit,
    );
    _reviewPreviewInFlight[cacheKey] = _InFlightReviewPreviewRequest(
      future: request,
      requestedLimit: limit,
    );

    try {
      return await request;
    } finally {
      final activeRequest = _reviewPreviewInFlight[cacheKey];
      if (identical(activeRequest?.future, request)) {
        _reviewPreviewInFlight.remove(cacheKey);
      }
    }
  }

  Future<ProductReviewPreviewModel> _fetchProductReviewPreviewNetwork(
    String cacheKey,
    String productId, {
    required int limit,
  }) async {
    final response = await _dio.get(
      '/products/$productId/reviews/preview',
      queryParameters: {'limit': limit},
    );
    final preview = ProductReviewPreviewModel.fromJson(
      response.data as Map<String, dynamic>,
    );
    _storeReviewPreviewCache(cacheKey, preview, requestedLimit: limit);
    final cached = _reviewPreviewCache[cacheKey];
    return ProductReviewPreviewModel(
      reviewCount: cached?.reviewCount ?? preview.reviewCount,
      reviews: List<ReviewPreviewModel>.from(
        cached?.slice(limit) ?? preview.reviews.take(limit),
      ),
    );
  }

  void _storeReviewPreviewCache(
    String cacheKey,
    ProductReviewPreviewModel preview, {
    required int requestedLimit,
  }) {
    final existing = _reviewPreviewCache[cacheKey];
    final isComplete = preview.reviewCount < requestedLimit ||
        preview.reviewCount <= preview.reviews.length;
    final shouldKeepExistingLarger = existing != null &&
        !existing.isExpired(_productReviewCacheTtl) &&
        !isComplete &&
        existing.reviews.length > preview.reviews.length;

    _reviewPreviewCache[cacheKey] = _CachedReviewPreviewCollection(
      reviews: List<ReviewPreviewModel>.unmodifiable(
        shouldKeepExistingLarger ? existing.reviews : preview.reviews,
      ),
      reviewCount:
          shouldKeepExistingLarger ? existing.reviewCount : preview.reviewCount,
      fetchedAt: DateTime.now(),
      isComplete:
          isComplete || (shouldKeepExistingLarger && existing.isComplete),
    );
  }

  // Videos APIs
  Future<List<VideoModel>> getVideos() async {
    try {
      final response = await _dio.get('/videos');
      return (response.data as List)
          .map((item) => VideoModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<VideoModel> getVideo(String id) async {
    try {
      final response = await _dio.get('/videos/$id');
      return VideoModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createVideo({
    required String title,
    required String description,
    required String url,
    required String thumbnail,
    int? duration,
    List<String>? productIds,
  }) async {
    try {
      final response = await _dio.post('/videos', data: {
        'title': title,
        'description': description,
        'url': url,
        'thumbnail': thumbnail,
        if (duration != null) 'duration': duration,
        if (productIds != null && productIds.isNotEmpty)
          'product_ids': productIds,
      });
      return response.data as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteVideo(String id) async {
    try {
      await _dio.delete('/videos/$id');
    } catch (e) {
      rethrow;
    }
  }

  Future<List<ContentCommentModel>> getVideoComments(String videoId) async {
    try {
      final response = await _dio.get('/videos/$videoId/comments');
      return (response.data as List? ?? [])
          .map((item) =>
              ContentCommentModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<ContentCommentModel> createVideoComment({
    required String videoId,
    required String commentText,
  }) async {
    try {
      final response = await _dio.post('/videos/$videoId/comments', data: {
        'comment_text': commentText,
      });
      return ContentCommentModel.fromJson(
        response.data as Map<String, dynamic>,
      );
    } catch (e) {
      rethrow;
    }
  }

  // Reels APIs
  Future<List<ReelModel>> getReels() async {
    try {
      final response = await _dio.get('/reels');
      return (response.data as List)
          .map((item) => ReelModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<ReelModel> getReel(String reelId) async {
    try {
      final response = await _dio.get('/reels/$reelId');
      return ReelModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createReel({
    required String url,
    required String thumbnail,
    required int width,
    required int height,
    String? caption,
    List<String>? productIds,
  }) async {
    try {
      final response = await _dio.post('/reels', data: {
        'url': url,
        'thumbnail': thumbnail,
        'width': width,
        'height': height,
        if (caption != null && caption.isNotEmpty) 'caption': caption,
        if (productIds != null && productIds.isNotEmpty)
          'product_ids': productIds,
      });
      return response.data as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteReel(String id) async {
    try {
      await _dio.delete('/reels/$id');
    } catch (e) {
      rethrow;
    }
  }

  Future<void> likeReel(String reelId) async {
    try {
      await _dio.post('/reels/$reelId/like');
    } catch (e) {
      rethrow;
    }
  }

  Future<List<ReelCommentModel>> getReelComments(String reelId) async {
    try {
      final response = await _dio.get('/reels/$reelId/comments');
      return (response.data as List? ?? [])
          .map(
              (item) => ReelCommentModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<ReelCommentModel> createReelComment({
    required String reelId,
    required String commentText,
  }) async {
    try {
      final response = await _dio.post('/reels/$reelId/comments', data: {
        'comment_text': commentText,
      });
      return ReelCommentModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  // Cart APIs
  Future<CartModel> getCart() async {
    try {
      final response = await _dio.get('/cart');
      return CartModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> addToCart(String productId, {int quantity = 1}) async {
    try {
      await _dio.post('/cart/add', data: {
        'product_id': productId,
        'quantity': quantity,
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateCartQuantity(String productId, int quantity) async {
    try {
      await _dio.post('/cart/update', data: {
        'product_id': productId,
        'quantity': quantity,
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> removeFromCart(String productId) async {
    try {
      await _dio.post('/cart/remove', data: {
        'product_id': productId,
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> clearCart() async {
    try {
      await _dio.delete('/cart/clear');
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> checkoutCart({
    required String shippingAddressLine1,
    required String shippingCity,
    required String shippingState,
    required String shippingPostalCode,
    required String shippingCountry,
    String shippingAddressLine2 = '',
    String phoneNumber = '',
  }) async {
    try {
      final response = await _dio.post('/cart/checkout', data: {
        'shipping_address_line1': shippingAddressLine1,
        'shipping_address_line2': shippingAddressLine2,
        'shipping_city': shippingCity,
        'shipping_state': shippingState,
        'shipping_postal_code': shippingPostalCode,
        'shipping_country': shippingCountry,
        'phone_number': phoneNumber,
      });
      return response.data as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<ProductModel>> getUserPurchases(String userId) async {
    try {
      final response = await _dio.get('/users/$userId/purchases');
      return (response.data as List? ?? [])
          .map((item) => ProductModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching user purchases: $e');
      return [];
    }
  }

  // Search API
  Future<Map<String, dynamic>> search(String query) async {
    try {
      final response = await _dio.get('/search', queryParameters: {'q': query});
      return response.data as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  // Follow APIs
  Future<void> followUser(String userId) async {
    try {
      await _dio.post('/follow/$userId');
    } catch (e) {
      rethrow;
    }
  }

  Future<void> unfollowUser(String userId) async {
    try {
      await _dio.post('/unfollow/$userId');
    } catch (e) {
      rethrow;
    }
  }

  Future<List<SocialUserModel>> getFollowers(String userId) async {
    try {
      final response = await _dio.get('/users/$userId/followers');
      return (response.data as List? ?? [])
          .map((item) => SocialUserModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<SocialUserModel>> getFollowing(String userId) async {
    try {
      final response = await _dio.get('/users/$userId/following');
      return (response.data as List? ?? [])
          .map((item) => SocialUserModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  // Messages APIs
  Future<List<MessageConnectionModel>> getMessageConnections() async {
    try {
      final response = await _dio.get('/messages/connections');
      return (response.data as List? ?? [])
          .map((item) => MessageConnectionModel.fromJson(
                item as Map<String, dynamic>,
              ))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<ConversationModel>> getConversations() async {
    try {
      final response = await _dio.get('/messages/conversations');
      return (response.data as List? ?? [])
          .map((item) =>
              ConversationModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<ConversationThreadModel> getConversationThread(
    String conversationId,
  ) async {
    try {
      final response =
          await _dio.get('/messages/conversations/$conversationId');
      return ConversationThreadModel.fromJson(
        response.data as Map<String, dynamic>,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> sendMessage({
    required String receiverId,
    required String content,
    String? productId,
  }) async {
    try {
      final response = await _dio.post('/messages', data: {
        'receiver_id': receiverId,
        'content': content,
        'message_type': productId != null ? 'product_link' : 'text',
        if (productId != null) 'product_id': productId,
      });
      return response.data as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  Future<ChatMessageModel> createMessage({
    required String receiverId,
    required String content,
    String messageType = 'text',
    String? productId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final response = await _dio.post('/messages', data: {
        'receiver_id': receiverId,
        'content': content,
        'message_type': messageType,
        if (productId != null) 'product_id': productId,
        if (metadata != null) 'metadata': metadata,
      });
      return ChatMessageModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  // Product Creation API
  Future<ProductModel> createProduct({
    String? id,
    required String title,
    required String description,
    required double price,
    required String category,
    required List<String> images,
    double? compareAtPrice,
    List<String>? tags,
    String? sku,
    int? stockQuantity,
    String? condition,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final response = await _dio.post('/products', data: {
        if (id != null && id.isNotEmpty) 'id': id,
        'title': title,
        'description': description,
        'price': price,
        'category': category,
        'images': images,
        if (compareAtPrice != null) 'compare_at_price': compareAtPrice,
        if (tags != null && tags.isNotEmpty) 'tags': tags,
        if (sku != null && sku.isNotEmpty) 'sku': sku,
        if (stockQuantity != null) 'stock_quantity': stockQuantity,
        if (condition != null && condition.isNotEmpty) 'condition': condition,
        if (metadata != null && metadata.isNotEmpty) 'metadata': metadata,
      });
      return ProductModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  Future<ProductModel> updateProduct({
    required String productId,
    required String title,
    required String description,
    required double price,
    required String category,
    required List<String> images,
    double? compareAtPrice,
    List<String>? tags,
    String? sku,
    int? stockQuantity,
    String? condition,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final response = await _dio.put('/products/$productId', data: {
        'title': title,
        'description': description,
        'price': price,
        'category': category,
        'images': images,
        if (compareAtPrice != null) 'compare_at_price': compareAtPrice,
        if (tags != null && tags.isNotEmpty) 'tags': tags,
        if (sku != null && sku.isNotEmpty) 'sku': sku,
        if (stockQuantity != null) 'stock_quantity': stockQuantity,
        if (condition != null && condition.isNotEmpty) 'condition': condition,
        if (metadata != null && metadata.isNotEmpty) 'metadata': metadata,
      });
      return ProductModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteProduct(String id) async {
    try {
      await _dio.delete('/products/$id');
    } catch (e) {
      rethrow;
    }
  }

  // Upload APIs
  Future<Map<String, dynamic>> uploadImage(XFile file, {String? folder}) async {
    try {
      final bytes = await file.readAsBytes();
      debugPrint('[uploadImage] fileName=${file.name}, size=${bytes.length}');
      final fileName = file.name;
      final formData = FormData.fromMap({
        'image': MultipartFile.fromBytes(bytes,
            filename: fileName, contentType: _getImageMediaType(fileName)),
      });

      final response = await _dio.post(
        '/upload/image',
        data: formData,
        queryParameters: {
          if (folder != null && folder.isNotEmpty) 'folder': folder,
        },
        options: Options(
          sendTimeout: const Duration(minutes: 5),
          receiveTimeout: const Duration(minutes: 2),
        ),
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      debugPrint(
          '[uploadImage] Failed: ${e.response?.statusCode} - ${e.response?.data}');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> uploadVideo(
    XFile file, {
    String? folder,
    String? productId,
  }) async {
    try {
      final bytes = await file.readAsBytes();
      final fileName = file.name;
      final formData = FormData.fromMap({
        'video': MultipartFile.fromBytes(bytes, filename: fileName),
      });

      final response = await _dio.post(
        '/upload/video',
        data: formData,
        queryParameters: {
          if (folder != null && folder.isNotEmpty) 'folder': folder,
          if (productId != null && productId.isNotEmpty)
            'product_id': productId,
        },
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> uploadProductImage(
    XFile file, {
    String? productId,
  }) async {
    try {
      final bytes = await file.readAsBytes();
      debugPrint(
          '[uploadProductImage] fileName=${file.name}, size=${bytes.length}');
      final fileName = file.name;
      final formData = FormData.fromMap({
        'image': MultipartFile.fromBytes(bytes,
            filename: fileName, contentType: _getImageMediaType(fileName)),
      });

      final response = await _dio.post(
        '/upload/product-image',
        data: formData,
        queryParameters: {
          if (productId != null && productId.isNotEmpty)
            'product_id': productId,
        },
        options: Options(
          sendTimeout: const Duration(minutes: 5),
          receiveTimeout: const Duration(minutes: 2),
        ),
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      debugPrint(
          '[uploadProductImage] Failed: ${e.response?.statusCode} - ${e.response?.data}');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> uploadProductDocument(
    XFile file, {
    String? productId,
  }) async {
    try {
      final bytes = await file.readAsBytes();
      debugPrint(
          '[uploadProductDocument] fileName=${file.name}, size=${bytes.length}');
      final fileName = file.name;
      final formData = FormData.fromMap({
        'document': MultipartFile.fromBytes(
          bytes,
          filename: fileName,
          contentType: MediaType('application', 'pdf'),
        ),
      });

      final response = await _dio.post(
        '/upload/product-document',
        data: formData,
        queryParameters: {
          if (productId != null && productId.isNotEmpty)
            'product_id': productId,
        },
        options: Options(
          sendTimeout: const Duration(minutes: 5),
          receiveTimeout: const Duration(minutes: 2),
        ),
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      debugPrint(
          '[uploadProductDocument] Failed: ${e.response?.statusCode} - ${e.response?.data}');
      rethrow;
    }
  }

  // Upload user photo with caption (saves to user_media table)
  Future<Map<String, dynamic>> uploadUserPhoto(XFile file,
      {String? caption}) async {
    try {
      final bytes = await file.readAsBytes();
      debugPrint(
          '[uploadUserPhoto] fileName=${file.name}, size=${bytes.length}');
      final fileName = file.name;
      final formData = FormData.fromMap({
        'image': MultipartFile.fromBytes(bytes,
            filename: fileName, contentType: _getImageMediaType(fileName)),
        if (caption != null && caption.isNotEmpty) 'caption': caption,
      });

      final response = await _dio.post(
        '/upload/user-photo',
        data: formData,
        options: Options(
          sendTimeout: const Duration(minutes: 5),
          receiveTimeout: const Duration(minutes: 2),
        ),
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      debugPrint(
          '[uploadUserPhoto] Failed: ${e.response?.statusCode} - ${e.response?.data}');
      rethrow;
    }
  }

  // Get user media for profile gallery
  Future<List<MediaItem>> getUserMedia(String userId,
      {String? type, int limit = 50}) async {
    try {
      final queryParams = <String, dynamic>{
        'limit': limit.toString(),
        if (type != null) 'type': type,
      };

      debugPrint('Fetching user media for user: $userId, type: $type');

      final response = await _dio.get(
        '/users/$userId/media',
        queryParameters: queryParams,
      );

      debugPrint('Response received: ${response.statusCode}');

      if (response.data == null) {
        debugPrint('Response data is null');
        return [];
      }

      if (response.data is! List) {
        debugPrint('Response data is not a List: ${response.data.runtimeType}');
        return [];
      }

      final List<MediaItem> items = (response.data as List)
          .map((item) {
            try {
              return MediaItem.fromJson(item as Map<String, dynamic>);
            } catch (e) {
              debugPrint('Error parsing media item: $e');
              return null;
            }
          })
          .whereType<MediaItem>() // Filter out null values
          .toList();

      debugPrint('Parsed ${items.length} media items');
      return items;
    } catch (e) {
      debugPrint('Error in getUserMedia: $e');
      // Return empty list instead of rethrowing to prevent blocking other data
      return [];
    }
  }

  Future<void> deleteUserMedia(String mediaId) async {
    try {
      await _dio.delete('/users/media/$mediaId');
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deletePost(String postId) async {
    try {
      await _dio.delete('/posts/$postId');
    } catch (e) {
      rethrow;
    }
  }

  // Review APIs
  Future<List<ReviewModel>> getProductReviews(String productId,
      {int limit = 50}) async {
    try {
      final response = await _dio.get(
        '/products/$productId/reviews',
        queryParameters: {'limit': limit},
      );
      return (response.data as List)
          .map((item) => ReviewModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<ReviewModel>> getProductReviewsRanked(String productId,
      {int limit = 50, bool forceRefresh = false}) async {
    await _loadToken();
    final cacheKey = _rankedReviewCacheKey(productId);

    if (!forceRefresh) {
      final cached = peekCachedProductReviewsRanked(productId, limit: limit);
      if (cached != null) {
        return cached;
      }

      final inFlight = _rankedReviewInFlight[cacheKey];
      if (inFlight != null && inFlight.requestedLimit >= limit) {
        final reviews = await inFlight.future;
        return List<ReviewModel>.from(reviews.take(limit));
      }
    }

    final request =
        _fetchProductReviewsRankedNetwork(cacheKey, productId, limit: limit);
    _rankedReviewInFlight[cacheKey] = _InFlightReviewRequest(
      future: request,
      requestedLimit: limit,
    );

    try {
      return await request;
    } finally {
      final activeRequest = _rankedReviewInFlight[cacheKey];
      if (identical(activeRequest?.future, request)) {
        _rankedReviewInFlight.remove(cacheKey);
      }
    }
  }

  Future<List<ReviewModel>> _fetchProductReviewsRankedNetwork(
    String cacheKey,
    String productId, {
    required int limit,
  }) async {
    try {
      final response = await _dio.get(
        '/products/$productId/reviews/ranked',
        queryParameters: {'limit': limit},
      );
      final reviews = (response.data as List)
          .map((item) => ReviewModel.fromJson(item as Map<String, dynamic>))
          .toList();
      _storeRankedReviewCache(cacheKey, reviews, requestedLimit: limit);
      return List<ReviewModel>.from(
        _rankedReviewCache[cacheKey]?.slice(limit) ?? reviews,
      );
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        final fallbackReviews =
            await getProductReviews(productId, limit: limit);
        _storeRankedReviewCache(
          cacheKey,
          fallbackReviews,
          requestedLimit: limit,
        );
        return List<ReviewModel>.from(
          _rankedReviewCache[cacheKey]?.slice(limit) ?? fallbackReviews,
        );
      }
      rethrow;
    }
  }

  void _storeRankedReviewCache(
    String cacheKey,
    List<ReviewModel> reviews, {
    required int requestedLimit,
  }) {
    final existing = _rankedReviewCache[cacheKey];
    final isComplete = reviews.length < requestedLimit;
    final shouldKeepExistingLarger = existing != null &&
        !existing.isExpired(_productReviewCacheTtl) &&
        !isComplete &&
        existing.reviews.length > reviews.length;

    _rankedReviewCache[cacheKey] = _CachedReviewCollection(
      reviews: List<ReviewModel>.unmodifiable(
        shouldKeepExistingLarger ? existing.reviews : reviews,
      ),
      fetchedAt: DateTime.now(),
      isComplete:
          isComplete || (shouldKeepExistingLarger && existing.isComplete),
    );
  }

  String _rankedReviewCacheKey(String productId) =>
      '${_token ?? 'anonymous'}::$productId';

  String _reviewPreviewCacheKey(String productId) =>
      '${_token ?? 'anonymous'}::$productId';

  Future<ReviewModel> getReview(String reviewId) async {
    try {
      final response = await _dio.get('/reviews/$reviewId');
      return ReviewModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  Future<ReviewModel> createReview({
    required String productId,
    required int rating,
    String? reviewTitle,
    String? reviewText,
    bool isPrivate = false,
    List<String>? imageUrls,
    bool suppressAlreadyReviewedConflictLog = false,
  }) async {
    try {
      final response = await _dio.post(
        '/products/$productId/reviews',
        data: {
          'product_id': productId,
          'rating': rating,
          if (reviewTitle != null && reviewTitle.isNotEmpty)
            'review_title': reviewTitle,
          if (reviewText != null && reviewText.isNotEmpty)
            'review_text': reviewText,
          'is_private': isPrivate,
          if (imageUrls != null && imageUrls.isNotEmpty) 'images': imageUrls,
        },
        options: Options(
          extra: {
            if (suppressAlreadyReviewedConflictLog)
              'suppressErrorLogStatuses': [409],
          },
        ),
      );
      return ReviewModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  Future<ReviewModel> updateReview({
    required String reviewId,
    required String productId,
    required int rating,
    String? reviewTitle,
    String? reviewText,
    bool isPrivate = false,
  }) async {
    try {
      final response = await _dio.put('/reviews/$reviewId', data: {
        'product_id': productId,
        'rating': rating,
        if (reviewTitle != null && reviewTitle.isNotEmpty)
          'review_title': reviewTitle,
        if (reviewText != null && reviewText.isNotEmpty)
          'review_text': reviewText,
        'is_private': isPrivate,
      });
      return ReviewModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  Future<String> uploadReviewImage(XFile file) async {
    try {
      final bytes = await file.readAsBytes();
      debugPrint(
          '[uploadReviewImage] fileName=${file.name}, size=${bytes.length}');
      final fileName = file.name;
      final formData = FormData.fromMap({
        'image': MultipartFile.fromBytes(bytes,
            filename: fileName, contentType: _getImageMediaType(fileName)),
      });

      final response = await _dio.post(
        '/upload/review-image',
        data: formData,
        options: Options(
          sendTimeout: const Duration(minutes: 5),
          receiveTimeout: const Duration(minutes: 2),
        ),
      );
      return response.data['url'] as String;
    } on DioException catch (e) {
      debugPrint(
          '[uploadReviewImage] Failed: ${e.response?.statusCode} - ${e.response?.data}');
      rethrow;
    }
  }

  Future<void> markReviewHelpful(String reviewId) async {
    try {
      await _dio.post('/reviews/$reviewId/helpful');
    } catch (e) {
      rethrow;
    }
  }

  Future<void> unmarkReviewHelpful(String reviewId) async {
    try {
      await _dio.delete('/reviews/$reviewId/helpful');
    } catch (e) {
      rethrow;
    }
  }

  Future<ReviewModel> updateReviewPrivacy(
      String reviewId, bool isPrivate) async {
    try {
      final response = await _dio.patch('/reviews/$reviewId/privacy', data: {
        'is_private': isPrivate,
      });
      return ReviewModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  /// Returns the correct [MediaType] for an image file based on its extension.
  /// Defaults to image/jpeg when the extension is unrecognised (e.g. cropped
  /// temp files with no extension), ensuring the backend never receives the
  /// Dio default of application/octet-stream.
  MediaType _getImageMediaType(String filename) {
    final ext = filename.toLowerCase().split('.').last;
    switch (ext) {
      case 'png':
        return MediaType('image', 'png');
      case 'gif':
        return MediaType('image', 'gif');
      case 'webp':
        return MediaType('image', 'webp');
      case 'heic':
        return MediaType('image', 'heic');
      case 'heif':
        return MediaType('image', 'heif');
      case 'jpg':
      case 'jpeg':
      default:
        return MediaType('image', 'jpeg');
    }
  }
}

class _CachedReviewCollection {
  const _CachedReviewCollection({
    required this.reviews,
    required this.fetchedAt,
    required this.isComplete,
  });

  final List<ReviewModel> reviews;
  final DateTime fetchedAt;
  final bool isComplete;

  bool isExpired(Duration ttl) => DateTime.now().difference(fetchedAt) > ttl;

  bool canSatisfy(int limit) => isComplete || reviews.length >= limit;

  List<ReviewModel> slice(int limit) {
    if (reviews.length <= limit) {
      return reviews;
    }
    return reviews.take(limit).toList(growable: false);
  }
}

class _InFlightReviewRequest {
  const _InFlightReviewRequest({
    required this.future,
    required this.requestedLimit,
  });

  final Future<List<ReviewModel>> future;
  final int requestedLimit;
}

class _CachedReviewPreviewCollection {
  const _CachedReviewPreviewCollection({
    required this.reviews,
    required this.reviewCount,
    required this.fetchedAt,
    required this.isComplete,
  });

  final List<ReviewPreviewModel> reviews;
  final int reviewCount;
  final DateTime fetchedAt;
  final bool isComplete;

  bool isExpired(Duration ttl) => DateTime.now().difference(fetchedAt) > ttl;

  bool canSatisfy(int limit) => isComplete || reviews.length >= limit;

  List<ReviewPreviewModel> slice(int limit) {
    if (reviews.length <= limit) {
      return reviews;
    }
    return reviews.take(limit).toList(growable: false);
  }
}

class _InFlightReviewPreviewRequest {
  const _InFlightReviewPreviewRequest({
    required this.future,
    required this.requestedLimit,
  });

  final Future<ProductReviewPreviewModel> future;
  final int requestedLimit;
}
