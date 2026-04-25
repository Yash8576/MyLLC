// Data models matching the backend API

class UserModel {
  final String id;
  final String email;
  final String name;
  final String? avatar;
  final String? bio;
  final int followersCount;
  final int followingCount;
  final String accountType; // 'SELLER' or 'CONSUMER'
  final String role; // 'consumer', 'seller', or 'admin'
  final String status; // 'active', 'inactive', or 'suspended'
  final bool isVerified;
  final String? phoneNumber;
  final String privacyProfile; // 'PUBLIC' or 'PRIVATE'
  final String visibilityMode; // 'public', 'private', or 'custom'
  final Map<String, bool> visibilityPreferences;
  final bool isFollowing;
  final bool isFollowedBy;
  final bool isConnection;
  final bool canViewConnections;
  final String createdAt;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.avatar,
    this.bio,
    this.followersCount = 0,
    this.followingCount = 0,
    this.accountType = 'CONSUMER',
    this.role = 'consumer',
    this.status = 'active',
    this.isVerified = false,
    this.phoneNumber,
    this.privacyProfile = 'PUBLIC',
    this.visibilityMode = 'public',
    this.visibilityPreferences = const {
      'photos': true,
      'videos': true,
      'reels': true,
      'purchases': true,
    },
    this.isFollowing = false,
    this.isFollowedBy = false,
    this.isConnection = false,
    this.canViewConnections = true,
    required this.createdAt,
  });

  bool get isSeller => accountType == 'SELLER' || role == 'seller';
  bool get isPrivate => privacyProfile.toUpperCase() == 'PRIVATE';
  bool get isCustomVisibility => visibilityMode.toLowerCase() == 'custom';
  bool get isActive => status == 'active';
  bool get isAdmin => role == 'admin';
  bool canViewBucket(String bucket) {
    if (isPrivate) return false;
    if (!isCustomVisibility) return true;
    return visibilityPreferences[bucket.toLowerCase()] ?? true;
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final visibilityPreferencesJson = json['visibility_preferences'];
    final preferences = <String, bool>{
      'photos': true,
      'videos': true,
      'reels': true,
      'purchases': true,
    };
    if (visibilityPreferencesJson is Map) {
      for (final entry in visibilityPreferencesJson.entries) {
        final key = entry.key.toString().toLowerCase();
        final value = entry.value == true;
        preferences[key] = value;
      }
    }

    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      avatar: json['avatar'] as String?,
      bio: json['bio'] as String?,
      followersCount: json['followers_count'] as int? ?? 0,
      followingCount: json['following_count'] as int? ?? 0,
      accountType: json['account_type'] as String? ?? 'CONSUMER',
      role: json['role'] as String? ?? 'consumer',
      status: json['status'] as String? ?? 'active',
      isVerified: json['is_verified'] as bool? ?? false,
      phoneNumber: json['phone_number'] as String?,
      privacyProfile:
          (json['privacy_profile'] as String? ?? 'PUBLIC').toUpperCase(),
      visibilityMode:
          (json['visibility_mode'] as String? ?? 'public').toLowerCase(),
      visibilityPreferences: preferences,
      isFollowing: json['is_following'] as bool? ?? false,
      isFollowedBy: json['is_followed_by'] as bool? ?? false,
      isConnection: json['is_connection'] as bool? ?? false,
      canViewConnections: json['can_view_connections'] as bool? ?? true,
      createdAt: json['created_at'] as String,
    );
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? avatar,
    bool clearAvatar = false,
    String? bio,
    int? followersCount,
    int? followingCount,
    String? accountType,
    String? role,
    String? status,
    bool? isVerified,
    String? phoneNumber,
    String? privacyProfile,
    String? visibilityMode,
    Map<String, bool>? visibilityPreferences,
    bool? isFollowing,
    bool? isFollowedBy,
    bool? isConnection,
    bool? canViewConnections,
    String? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      avatar: clearAvatar ? null : (avatar ?? this.avatar),
      bio: bio ?? this.bio,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      accountType: accountType ?? this.accountType,
      role: role ?? this.role,
      status: status ?? this.status,
      isVerified: isVerified ?? this.isVerified,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      privacyProfile: privacyProfile ?? this.privacyProfile,
      visibilityMode: visibilityMode ?? this.visibilityMode,
      visibilityPreferences:
          visibilityPreferences ?? this.visibilityPreferences,
      isFollowing: isFollowing ?? this.isFollowing,
      isFollowedBy: isFollowedBy ?? this.isFollowedBy,
      isConnection: isConnection ?? this.isConnection,
      canViewConnections: canViewConnections ?? this.canViewConnections,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'avatar': avatar,
      'bio': bio,
      'followers_count': followersCount,
      'following_count': followingCount,
      'account_type': accountType,
      'role': role,
      'status': status,
      'is_verified': isVerified,
      'phone_number': phoneNumber,
      'privacy_profile': privacyProfile,
      'visibility_mode': visibilityMode,
      'visibility_preferences': visibilityPreferences,
      'is_following': isFollowing,
      'is_followed_by': isFollowedBy,
      'is_connection': isConnection,
      'can_view_connections': canViewConnections,
      'created_at': createdAt,
    };
  }
}

class SocialUserModel {
  final String id;
  final String name;
  final String? avatar;
  final String bio;
  final bool isFollowing;
  final bool isFollowedBy;
  final bool isConnection;

  SocialUserModel({
    required this.id,
    required this.name,
    this.avatar,
    this.bio = '',
    this.isFollowing = false,
    this.isFollowedBy = false,
    this.isConnection = false,
  });

  factory SocialUserModel.fromJson(Map<String, dynamic> json) {
    return SocialUserModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Unknown',
      avatar: json['avatar'] as String?,
      bio: json['bio'] as String? ?? '',
      isFollowing: json['is_following'] as bool? ?? false,
      isFollowedBy: json['is_followed_by'] as bool? ?? false,
      isConnection: json['is_connection'] as bool? ?? false,
    );
  }
}

class ProductModel {
  final String id;
  final String title;
  final String description;
  final double price;
  final double? compareAtPrice;
  final String currency;
  final String? sku;
  final int stockQuantity;
  final String condition;
  final List<String> images;
  final String category;
  final List<String> tags;
  final String sellerId;
  final String sellerName;
  final double rating;
  final int reviewsCount;
  final int views;
  final int buys;
  final Map<String, dynamic> metadata;
  final String createdAt;

  ProductModel({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    this.compareAtPrice,
    this.currency = 'USD',
    this.sku,
    this.stockQuantity = 0,
    this.condition = 'new',
    required this.images,
    required this.category,
    required this.tags,
    required this.sellerId,
    required this.sellerName,
    this.rating = 0.0,
    this.reviewsCount = 0,
    this.views = 0,
    this.buys = 0,
    this.metadata = const {},
    required this.createdAt,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final metadata = json['metadata'] is Map
        ? Map<String, dynamic>.from(json['metadata'] as Map)
        : <String, dynamic>{};

    return ProductModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      price: (json['price'] as num).toDouble(),
      compareAtPrice: (json['compare_at_price'] as num?)?.toDouble(),
      currency: json['currency'] as String? ?? 'USD',
      sku: json['sku'] as String?,
      stockQuantity: json['stock_quantity'] as int? ?? 0,
      condition: json['condition'] as String? ?? 'new',
      images: List<String>.from(json['images'] as List? ?? []),
      category: json['category'] as String? ?? '',
      tags: List<String>.from(json['tags'] as List? ?? []),
      sellerId: json['seller_id'] as String,
      sellerName: json['seller_name'] as String? ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      reviewsCount: json['reviews_count'] as int? ?? 0,
      views: json['views'] as int? ?? 0,
      buys: json['buys'] as int? ?? 0,
      metadata: metadata,
      createdAt: json['created_at'] as String,
    );
  }

  String? get brandName => _metadataString('brand_name');
  String? get manufacturer => _metadataString('manufacturer');
  String? get productIdentifier => _metadataString('product_identifier');
  String? get gtin => _metadataString('gtin');
  String? get productType => _metadataString('product_type');
  String? get fulfillmentMethod => _metadataString('fulfillment_method');
  String? get shippingDetails => _metadataString('shipping_details');
  String? get variationSummary => _metadataString('variation_summary');
  String? get material => _metadataString('material');
  String? get weight => _metadataString('weight');
  String? get color => _metadataString('color');
  String? get itemModelNumber => _metadataString('item_model_number');
  String? get countryOfOrigin => _metadataString('country_of_origin');
  String? get specificationPdfUrl => _metadataString('specification_pdf_url');
  List<String> get mediaVideos => _metadataStringList('media_videos');
  List<Map<String, dynamic>> get mediaQueue =>
      _metadataMediaQueue('media_queue');
  List<String> get bulletPoints => _metadataStringList('bullet_points');
  List<String> get searchTerms => _metadataStringList('search_terms');

  Map<String, String> get manualSpecifications {
    final raw = metadata['manual_specifications'];
    if (raw is! Map) {
      return const {};
    }

    final specs = <String, String>{};
    for (final entry in raw.entries) {
      final key = entry.key.toString().trim();
      final value = entry.value?.toString().trim() ?? '';
      if (key.isNotEmpty && value.isNotEmpty) {
        specs[key] = value;
      }
    }
    return specs;
  }

  String? get dimensionsLabel {
    final raw = metadata['dimensions'];
    if (raw is! Map) {
      return null;
    }

    final length = raw['length']?.toString().trim();
    final width = raw['width']?.toString().trim();
    final height = raw['height']?.toString().trim();
    final unit = raw['unit']?.toString().trim();
    final parts = [length, width, height]
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return null;
    }
    final size = parts.join(' x ');
    return unit != null && unit.isNotEmpty ? '$size $unit' : size;
  }

  Map<String, String> get highlightedSpecifications {
    final specs = <String, String>{};
    specs.addAll(manualSpecifications);

    void addSpec(String label, String? value) {
      if (value != null &&
          value.trim().isNotEmpty &&
          !specs.containsKey(label)) {
        specs[label] = value.trim();
      }
    }

    addSpec('Material', material);
    addSpec('Dimensions', dimensionsLabel);
    addSpec('Weight', weight);
    addSpec('Color', color);
    addSpec('Item Model Number', itemModelNumber);
    addSpec('Country of Origin', countryOfOrigin);
    addSpec('Condition', condition);
    addSpec('Category', category);

    return specs;
  }

  String? _metadataString(String key) {
    final value = metadata[key];
    if (value == null) {
      return null;
    }
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  List<String> _metadataStringList(String key) {
    final value = metadata[key];
    if (value is! List) {
      return const [];
    }
    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList();
  }

  List<Map<String, dynamic>> _metadataMediaQueue(String key) {
    final value = metadata[key];
    if (value is! List) {
      return const [];
    }

    return value
        .whereType<Map>()
        .map((entry) => <String, dynamic>{
              'type': entry['type']?.toString().trim().toLowerCase() ?? 'image',
              'url': entry['url']?.toString().trim() ?? '',
              'name': entry['name']?.toString().trim() ?? '',
            })
        .where((entry) => (entry['url'] as String).isNotEmpty)
        .toList();
  }
}

class NetworkPurchaseModel {
  final String productId;
  final String productTitle;
  final String productImage;
  final double productPrice;
  final String buyerId;
  final String buyerName;
  final String? buyerAvatar;
  final String purchaseDate;

  NetworkPurchaseModel({
    required this.productId,
    required this.productTitle,
    required this.productImage,
    required this.productPrice,
    required this.buyerId,
    required this.buyerName,
    this.buyerAvatar,
    required this.purchaseDate,
  });

  factory NetworkPurchaseModel.fromJson(Map<String, dynamic> json) {
    return NetworkPurchaseModel(
      productId: json['product_id'] as String,
      productTitle: json['product_title'] as String,
      productImage: json['product_image'] as String? ?? '',
      productPrice: (json['product_price'] as num).toDouble(),
      buyerId: json['buyer_id'] as String,
      buyerName: json['buyer_name'] as String,
      buyerAvatar: json['buyer_avatar'] as String?,
      purchaseDate: json['purchase_date'] as String,
    );
  }
}

class ProductBuyerModel {
  final String buyerId;
  final String buyerName;
  final String? buyerAvatar;
  final String purchaseDate;
  final int totalQuantity;
  final bool isConnection;

  ProductBuyerModel({
    required this.buyerId,
    required this.buyerName,
    this.buyerAvatar,
    required this.purchaseDate,
    this.totalQuantity = 0,
    this.isConnection = false,
  });

  factory ProductBuyerModel.fromJson(Map<String, dynamic> json) {
    return ProductBuyerModel(
      buyerId: json['buyer_id'] as String,
      buyerName: json['buyer_name'] as String? ?? 'Unknown',
      buyerAvatar: json['buyer_avatar'] as String?,
      purchaseDate: json['purchase_date'] as String,
      totalQuantity: json['total_quantity'] as int? ?? 0,
      isConnection: json['is_connection'] as bool? ?? false,
    );
  }
}

class ReviewPreviewModel {
  final String userId;
  final String username;
  final String? userAvatar;
  final bool isFollowing;

  ReviewPreviewModel({
    required this.userId,
    required this.username,
    this.userAvatar,
    this.isFollowing = false,
  });

  factory ReviewPreviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewPreviewModel(
      userId: json['user_id'] as String,
      username: json['username'] as String? ?? 'Unknown',
      userAvatar: json['user_avatar'] as String?,
      isFollowing: json['is_following'] as bool? ?? false,
    );
  }
}

class ProductReviewPreviewModel {
  final int reviewCount;
  final List<ReviewPreviewModel> reviews;

  ProductReviewPreviewModel({
    required this.reviewCount,
    this.reviews = const <ReviewPreviewModel>[],
  });

  factory ProductReviewPreviewModel.fromJson(Map<String, dynamic> json) {
    return ProductReviewPreviewModel(
      reviewCount: json['review_count'] as int? ?? 0,
      reviews: (json['reviews'] as List? ?? [])
          .map((item) =>
              ReviewPreviewModel.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class VideoModel {
  final String id;
  final String title;
  final String description;
  final String url;
  final String thumbnail;
  final int duration;
  final int views;
  final int likes;
  final int commentCount;
  final String creatorId;
  final String creatorName;
  final String? creatorAvatar;
  final List<ProductModel> products;
  final String createdAt;

  VideoModel({
    required this.id,
    required this.title,
    required this.description,
    required this.url,
    required this.thumbnail,
    required this.duration,
    this.views = 0,
    this.likes = 0,
    this.commentCount = 0,
    required this.creatorId,
    required this.creatorName,
    this.creatorAvatar,
    this.products = const [],
    required this.createdAt,
  });

  factory VideoModel.fromJson(Map<String, dynamic> json) {
    return VideoModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      url: json['url'] as String,
      thumbnail: json['thumbnail'] as String,
      duration: json['duration'] as int,
      views: json['views'] as int? ?? 0,
      likes: json['likes'] as int? ?? 0,
      commentCount: json['comment_count'] as int? ?? 0,
      creatorId: json['creator_id'] as String,
      creatorName: json['creator_name'] as String,
      creatorAvatar: json['creator_avatar'] as String?,
      products: (json['products'] as List?)
              ?.map((p) => ProductModel.fromJson(_videoTaggedProductJson(
                    p as Map<String, dynamic>,
                  )))
              .toList() ??
          [],
      createdAt: json['created_at'] as String,
    );
  }

  static Map<String, dynamic> _videoTaggedProductJson(
      Map<String, dynamic> json) {
    final image = (json['image'] as String?)?.trim();
    return <String, dynamic>{
      'id': json['id'] as String,
      'title': json['title'] as String? ?? '',
      'description': '',
      'price': (json['price'] as num?)?.toDouble() ?? 0,
      'images': [
        if (image != null && image.isNotEmpty) image,
      ],
      'category': '',
      'tags': const <String>[],
      'seller_id': '',
      'seller_name': '',
      'rating': 0,
      'reviews_count': 0,
      'views': 0,
      'buys': 0,
      'metadata': const <String, dynamic>{},
      'created_at': DateTime.fromMillisecondsSinceEpoch(0).toIso8601String(),
    };
  }
}

class ReelModel {
  final String id;
  final String url;
  final String thumbnail;
  final String caption;
  final int views;
  final int likes;
  final int commentCount;
  final int width;
  final int height;
  final String creatorId;
  final String creatorName;
  final String? creatorAvatar;
  final List<ProductModel> products;
  final String createdAt;

  ReelModel({
    required this.id,
    required this.url,
    required this.thumbnail,
    required this.caption,
    this.views = 0,
    this.likes = 0,
    this.commentCount = 0,
    this.width = 0,
    this.height = 0,
    required this.creatorId,
    required this.creatorName,
    this.creatorAvatar,
    this.products = const [],
    required this.createdAt,
  });

  factory ReelModel.fromJson(Map<String, dynamic> json) {
    return ReelModel(
      id: json['id'] as String,
      url: json['url'] as String,
      thumbnail: json['thumbnail'] as String,
      caption: json['caption'] as String? ?? '',
      views: json['views'] as int? ?? 0,
      likes: json['likes'] as int? ?? 0,
      commentCount: json['comment_count'] as int? ?? 0,
      width: json['width'] as int? ?? 0,
      height: json['height'] as int? ?? 0,
      creatorId: json['creator_id'] as String,
      creatorName: json['creator_name'] as String,
      creatorAvatar: json['creator_avatar'] as String?,
      products: (json['products'] as List?)
              ?.map((p) => ProductModel.fromJson(_reelTaggedProductJson(
                    p as Map<String, dynamic>,
                  )))
              .toList() ??
          [],
      createdAt: json['created_at'] as String,
    );
  }

  static Map<String, dynamic> _reelTaggedProductJson(
      Map<String, dynamic> json) {
    final image = (json['image'] as String?)?.trim();
    return <String, dynamic>{
      'id': json['id'] as String,
      'title': json['title'] as String? ?? '',
      'description': '',
      'price': (json['price'] as num?)?.toDouble() ?? 0,
      'images': [
        if (image != null && image.isNotEmpty) image,
      ],
      'category': '',
      'tags': const <String>[],
      'seller_id': '',
      'seller_name': '',
      'rating': 0,
      'reviews_count': 0,
      'views': 0,
      'buys': 0,
      'metadata': const <String, dynamic>{},
      'created_at': DateTime.fromMillisecondsSinceEpoch(0).toIso8601String(),
    };
  }
}

class ReelCommentModel {
  final String id;
  final String reelId;
  final String userId;
  final String commentText;
  final String createdAt;
  final String updatedAt;
  final String username;
  final String? userAvatar;
  final bool isFollowing;
  final bool isCurrentUser;

  ReelCommentModel({
    required this.id,
    required this.reelId,
    required this.userId,
    required this.commentText,
    required this.createdAt,
    required this.updatedAt,
    required this.username,
    this.userAvatar,
    this.isFollowing = false,
    this.isCurrentUser = false,
  });

  factory ReelCommentModel.fromJson(Map<String, dynamic> json) {
    return ReelCommentModel(
      id: json['id'] as String,
      reelId: json['reel_id'] as String,
      userId: json['user_id'] as String,
      commentText: json['comment_text'] as String? ?? '',
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String? ?? json['created_at'] as String,
      username: json['username'] as String? ?? 'Unknown',
      userAvatar: json['user_avatar'] as String?,
      isFollowing: json['is_following'] as bool? ?? false,
      isCurrentUser: json['is_current_user'] as bool? ?? false,
    );
  }
}

class ContentCommentModel {
  final String id;
  final String contentId;
  final String userId;
  final String commentText;
  final String createdAt;
  final String updatedAt;
  final String username;
  final String? userAvatar;
  final bool isFollowing;
  final bool isCurrentUser;

  ContentCommentModel({
    required this.id,
    required this.contentId,
    required this.userId,
    required this.commentText,
    required this.createdAt,
    required this.updatedAt,
    required this.username,
    this.userAvatar,
    this.isFollowing = false,
    this.isCurrentUser = false,
  });

  factory ContentCommentModel.fromJson(Map<String, dynamic> json) {
    return ContentCommentModel(
      id: json['id'] as String,
      contentId: (json['content_id'] ?? json['reel_id']) as String,
      userId: json['user_id'] as String,
      commentText: json['comment_text'] as String? ?? '',
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String? ?? json['created_at'] as String,
      username: json['username'] as String? ?? 'Unknown',
      userAvatar: json['user_avatar'] as String?,
      isFollowing: json['is_following'] as bool? ?? false,
      isCurrentUser: json['is_current_user'] as bool? ?? false,
    );
  }
}

class CartItemModel {
  final ProductModel product;
  final int quantity;

  CartItemModel({
    required this.product,
    required this.quantity,
  });

  factory CartItemModel.fromJson(Map<String, dynamic> json) {
    final hasNestedProduct = json['product'] is Map<String, dynamic>;
    final productJson = hasNestedProduct
        ? Map<String, dynamic>.from(json['product'] as Map<String, dynamic>)
        : <String, dynamic>{
            'id': json['product_id'] as String,
            'title': json['title'] as String? ?? '',
            'description': '',
            'price': (json['price'] as num?)?.toDouble() ?? 0,
            if (json['compare_at_price'] != null)
              'compare_at_price': (json['compare_at_price'] as num).toDouble(),
            'stock_quantity': json['stock_quantity'] as int? ?? 0,
            'images': [
              if ((json['image'] as String?) != null &&
                  (json['image'] as String).isNotEmpty)
                json['image'] as String,
            ],
            'category': '',
            'tags': const <String>[],
            'seller_id': '',
            'seller_name': json['seller_name'] as String? ?? '',
            'rating': 0,
            'reviews_count': 0,
            'views': 0,
            'buys': 0,
            'metadata': const <String, dynamic>{},
            'created_at':
                DateTime.fromMillisecondsSinceEpoch(0).toIso8601String(),
          };

    return CartItemModel(
      product: ProductModel.fromJson(productJson),
      quantity: json['quantity'] as int,
    );
  }
}

class CartModel {
  final List<CartItemModel> items;
  final double subtotal;
  final double discount;
  final double total;
  final int itemCount;

  CartModel({
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.itemCount,
  });

  factory CartModel.fromJson(Map<String, dynamic> json) {
    return CartModel(
      items: (json['items'] as List)
          .map((item) => CartItemModel.fromJson(item as Map<String, dynamic>))
          .toList(),
      subtotal: (json['subtotal'] as num).toDouble(),
      discount: (json['discount'] as num?)?.toDouble() ?? 0,
      total: (json['total'] as num).toDouble(),
      itemCount: json['item_count'] as int,
    );
  }

  factory CartModel.empty() {
    return CartModel(
      items: [],
      subtotal: 0,
      discount: 0,
      total: 0,
      itemCount: 0,
    );
  }
}

class FeedItem {
  final String type; // 'product', 'video', 'reel', or 'post'
  final dynamic data; // ProductModel, VideoModel, ReelModel, or PostModel

  FeedItem({
    required this.type,
    required this.data,
  });

  factory FeedItem.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    final data = json['data'] as Map<String, dynamic>;

    dynamic parsedData;
    switch (type) {
      case 'product':
        parsedData = ProductModel.fromJson(data);
        break;
      case 'video':
        parsedData = VideoModel.fromJson(data);
        break;
      case 'reel':
        parsedData = ReelModel.fromJson(data);
        break;
      case 'post':
        parsedData = PostModel.fromJson(data);
        break;
      default:
        throw Exception('Unknown feed item type: $type');
    }

    return FeedItem(
      type: type,
      data: parsedData,
    );
  }
}

// ============================================================================
// INSTAGRAM-STYLE POST MODELS
// ============================================================================

class PostModel {
  final String id;
  final String userId;
  final String mediaId;
  final String caption;
  final String mediaType; // 'photo', 'video', 'reel'
  final String mediaUrl;
  final String? thumbnailUrl;
  final bool isPrivate;
  final String visibility; // 'followers', 'public', 'close_friends'
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final int viewCount;
  final String createdAt;
  final String updatedAt;

  // Author info (populated from join)
  final String authorName;
  final String? authorAvatar;
  final bool authorVerified;

  // User interaction state
  final bool isLiked;
  final bool isFollowing;

  PostModel({
    required this.id,
    required this.userId,
    required this.mediaId,
    required this.caption,
    required this.mediaType,
    required this.mediaUrl,
    this.thumbnailUrl,
    required this.isPrivate,
    required this.visibility,
    this.likeCount = 0,
    this.commentCount = 0,
    this.shareCount = 0,
    this.viewCount = 0,
    required this.createdAt,
    required this.updatedAt,
    required this.authorName,
    this.authorAvatar,
    this.authorVerified = false,
    this.isLiked = false,
    this.isFollowing = false,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) {
    return PostModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      mediaId: json['media_id'] as String,
      caption: json['caption'] as String? ?? '',
      mediaType: json['media_type'] as String,
      mediaUrl: json['media_url'] as String,
      thumbnailUrl: json['thumbnail_url'] as String?,
      isPrivate: json['is_private'] as bool? ?? false,
      visibility: json['visibility'] as String? ?? 'followers',
      likeCount: json['like_count'] as int? ?? 0,
      commentCount: json['comment_count'] as int? ?? 0,
      shareCount: json['share_count'] as int? ?? 0,
      viewCount: json['view_count'] as int? ?? 0,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
      authorName: json['author_name'] as String,
      authorAvatar: json['author_avatar'] as String?,
      authorVerified: json['author_verified'] as bool? ?? false,
      isLiked: json['is_liked'] as bool? ?? false,
      isFollowing: json['is_following'] as bool? ?? false,
    );
  }

  bool get isPhoto => mediaType == 'photo';
  bool get isVideo => mediaType == 'video' || mediaType == 'reel';

  PostModel copyWith({
    bool? isLiked,
    int? likeCount,
    int? commentCount,
    bool? isFollowing,
  }) {
    return PostModel(
      id: id,
      userId: userId,
      mediaId: mediaId,
      caption: caption,
      mediaType: mediaType,
      mediaUrl: mediaUrl,
      thumbnailUrl: thumbnailUrl,
      isPrivate: isPrivate,
      visibility: visibility,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      shareCount: shareCount,
      viewCount: viewCount,
      createdAt: createdAt,
      updatedAt: updatedAt,
      authorName: authorName,
      authorAvatar: authorAvatar,
      authorVerified: authorVerified,
      isLiked: isLiked ?? this.isLiked,
      isFollowing: isFollowing ?? this.isFollowing,
    );
  }
}

class FeedResponse {
  final List<PostModel> posts;
  final String? nextCursor;
  final bool hasMore;

  FeedResponse({
    required this.posts,
    this.nextCursor,
    this.hasMore = false,
  });

  factory FeedResponse.fromJson(Map<String, dynamic> json) {
    return FeedResponse(
      posts: (json['posts'] as List?)
              ?.map((p) => PostModel.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
      nextCursor: json['next_cursor'] as String?,
      hasMore: json['has_more'] as bool? ?? false,
    );
  }
}

class MediaItem {
  final String id;
  final String? contentId;
  final String mediaType;
  final String mediaUrl;
  final String? thumbnailUrl;
  final String? caption;
  final int viewCount;
  final int likeCount;
  final int commentCount;
  final String createdAt;

  MediaItem({
    required this.id,
    this.contentId,
    required this.mediaType,
    required this.mediaUrl,
    this.thumbnailUrl,
    this.caption,
    this.viewCount = 0,
    this.likeCount = 0,
    this.commentCount = 0,
    required this.createdAt,
  });

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    return MediaItem(
      id: json['id'] as String,
      contentId: json['content_id'] as String?,
      mediaType: json['media_type'] as String,
      mediaUrl: json['media_url'] as String,
      thumbnailUrl: json['thumbnail_url'] as String?,
      caption: json['caption'] as String?,
      viewCount: json['view_count'] as int? ?? 0,
      likeCount: json['like_count'] as int? ?? 0,
      commentCount: json['comment_count'] as int? ?? 0,
      createdAt: json['created_at'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content_id': contentId,
      'media_type': mediaType,
      'media_url': mediaUrl,
      'thumbnail_url': thumbnailUrl,
      'caption': caption,
      'view_count': viewCount,
      'like_count': likeCount,
      'comment_count': commentCount,
      'created_at': createdAt,
    };
  }
}

class ReviewModel {
  final String id;
  final String productId;
  final String userId;
  final int rating;
  final String? reviewTitle;
  final String? reviewText;
  final bool isVerifiedPurchase;
  final bool isPrivate;
  final String moderationStatus;
  final int helpfulCount;
  final String createdAt;
  final String updatedAt;
  final String? username;
  final String? userAvatar;
  final bool hasVoted;
  final bool isFollowing;
  final List<String> images;

  ReviewModel({
    required this.id,
    required this.productId,
    required this.userId,
    required this.rating,
    this.reviewTitle,
    this.reviewText,
    this.isVerifiedPurchase = false,
    this.isPrivate = false,
    this.moderationStatus = 'pending',
    this.helpfulCount = 0,
    required this.createdAt,
    required this.updatedAt,
    this.username,
    this.userAvatar,
    this.hasVoted = false,
    this.isFollowing = false,
    this.images = const [],
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      userId: json['user_id'] as String,
      rating: json['rating'] as int,
      reviewTitle: json['review_title'] as String?,
      reviewText: json['review_text'] as String?,
      isVerifiedPurchase: json['is_verified_purchase'] as bool? ?? false,
      isPrivate: json['is_private'] as bool? ?? false,
      moderationStatus: json['moderation_status'] as String? ?? 'pending',
      helpfulCount: json['helpful_count'] as int? ?? 0,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
      username: json['username'] as String?,
      userAvatar: json['user_avatar'] as String?,
      hasVoted: json['has_voted'] as bool? ?? false,
      isFollowing: json['is_following'] as bool? ?? false,
      images: List<String>.from(json['images'] as List? ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'user_id': userId,
      'rating': rating,
      'review_title': reviewTitle,
      'review_text': reviewText,
      'is_verified_purchase': isVerifiedPurchase,
      'is_private': isPrivate,
      'moderation_status': moderationStatus,
      'helpful_count': helpfulCount,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'username': username,
      'user_avatar': userAvatar,
      'has_voted': hasVoted,
      'is_following': isFollowing,
      'images': images,
    };
  }
}

class MessageParticipantModel {
  final String id;
  final String name;
  final String? avatar;

  MessageParticipantModel({
    required this.id,
    required this.name,
    this.avatar,
  });

  factory MessageParticipantModel.fromJson(Map<String, dynamic> json) {
    return MessageParticipantModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Unknown',
      avatar: json['avatar'] as String?,
    );
  }
}

class MessageConnectionModel {
  final String id;
  final String name;
  final String? avatar;
  final String? conversationId;
  final bool hasExistingConversation;

  MessageConnectionModel({
    required this.id,
    required this.name,
    this.avatar,
    this.conversationId,
    this.hasExistingConversation = false,
  });

  factory MessageConnectionModel.fromJson(Map<String, dynamic> json) {
    return MessageConnectionModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Unknown',
      avatar: json['avatar'] as String?,
      conversationId: json['conversation_id'] as String?,
      hasExistingConversation:
          json['has_existing_conversation'] as bool? ?? false,
    );
  }
}

class ChatMessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String receiverId;
  final String content;
  final String messageType;
  final String? productId;
  final ProductModel? product;
  final Map<String, dynamic>? metadata;
  final String createdAt;
  final bool read;

  ChatMessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.receiverId,
    required this.content,
    this.messageType = 'text',
    this.productId,
    this.product,
    this.metadata,
    required this.createdAt,
    this.read = false,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String,
      receiverId: json['receiver_id'] as String? ?? '',
      content: json['content'] as String? ?? '',
      messageType: json['message_type'] as String? ?? 'text',
      productId: json['product_id'] as String?,
      product: json['product'] is Map<String, dynamic>
          ? ProductModel(
              id: (json['product'] as Map<String, dynamic>)['id'] as String,
              title:
                  (json['product'] as Map<String, dynamic>)['title'] as String,
              description: '',
              price:
                  ((json['product'] as Map<String, dynamic>)['price'] as num?)
                          ?.toDouble() ??
                      0,
              images: [
                if (((json['product'] as Map<String, dynamic>)['image']
                            as String?)
                        ?.isNotEmpty ??
                    false)
                  (json['product'] as Map<String, dynamic>)['image'] as String,
              ],
              category: '',
              tags: const [],
              sellerId: '',
              sellerName: '',
              createdAt: '',
            )
          : null,
      metadata: json['metadata'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['metadata'] as Map<String, dynamic>)
          : null,
      createdAt: json['created_at'] as String,
      read: json['read'] as bool? ?? false,
    );
  }

  bool get isProductShare => messageType == 'product_link' && product != null;
}

class ConversationModel {
  final String id;
  final MessageParticipantModel participant;
  final ChatMessageModel? lastMessage;
  final int unreadCount;
  final String updatedAt;

  ConversationModel({
    required this.id,
    required this.participant,
    this.lastMessage,
    this.unreadCount = 0,
    required this.updatedAt,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      id: json['id'] as String,
      participant: MessageParticipantModel.fromJson(
        json['participant'] as Map<String, dynamic>,
      ),
      lastMessage: json['last_message'] is Map<String, dynamic>
          ? ChatMessageModel.fromJson(
              json['last_message'] as Map<String, dynamic>,
            )
          : null,
      unreadCount: json['unread_count'] as int? ?? 0,
      updatedAt: json['updated_at'] as String,
    );
  }

  ConversationModel copyWith({
    ChatMessageModel? lastMessage,
    int? unreadCount,
    String? updatedAt,
  }) {
    return ConversationModel(
      id: id,
      participant: participant,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class ConversationThreadModel {
  final String conversationId;
  final MessageParticipantModel participant;
  final List<ChatMessageModel> messages;

  ConversationThreadModel({
    required this.conversationId,
    required this.participant,
    required this.messages,
  });

  factory ConversationThreadModel.fromJson(Map<String, dynamic> json) {
    return ConversationThreadModel(
      conversationId: json['conversation_id'] as String,
      participant: MessageParticipantModel.fromJson(
        json['participant'] as Map<String, dynamic>,
      ),
      messages: (json['messages'] as List? ?? [])
          .map(
              (item) => ChatMessageModel.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class MessageComposerDraft {
  final String content;
  final String messageType;
  final String? productId;
  final Map<String, dynamic>? metadata;
  final String? previewTitle;
  final String? previewSubtitle;
  final String? previewImage;

  const MessageComposerDraft({
    this.content = '',
    this.messageType = 'text',
    this.productId,
    this.metadata,
    this.previewTitle,
    this.previewSubtitle,
    this.previewImage,
  });

  factory MessageComposerDraft.product(ProductModel product) {
    return MessageComposerDraft(
      content: 'Check this out',
      messageType: 'product_link',
      productId: product.id,
      metadata: {
        'kind': 'product',
        'title': product.title,
        'price': product.price,
        'image': product.images.isNotEmpty ? product.images.first : null,
      },
      previewTitle: product.title,
      previewSubtitle: '\$${product.price.toStringAsFixed(2)}',
      previewImage: product.images.isNotEmpty ? product.images.first : null,
    );
  }

  bool get hasSharePayload => messageType != 'text' || productId != null;
}

class MessagesRouteIntent {
  final String? conversationId;
  final MessageParticipantModel? participant;
  final MessageComposerDraft? draft;

  const MessagesRouteIntent({
    this.conversationId,
    this.participant,
    this.draft,
  });
}
