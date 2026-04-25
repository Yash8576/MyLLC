import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class AuthException implements Exception {
  final String code;
  final String message;

  const AuthException(this.code, this.message);

  @override
  String toString() => message;
}

class AuthProvider extends ChangeNotifier {
  final ApiService _api;
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );
  static const String _lastActivityKey = 'last_activity';
  static const String _rememberMeKey = 'remember_me';
  static const String _sessionStartedAtKey = 'session_started_at';
  static const String _pendingAvatarPreviewPathKey =
      'pending_avatar_preview_path';
  static const int _maxInactiveDays = 7;
  static const int _rememberMeDays = 30;

  UserModel? _user;
  bool _isLoading = true;
  bool _isAuthenticated = false;
  String? _pendingAvatarPreviewPath;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;
  bool get isSeller => _user?.isSeller ?? false;
  String? get pendingAvatarPreviewPath => _pendingAvatarPreviewPath;

  AuthProvider({required ApiService apiService}) : _api = apiService {
    _init();
  }

  Future<void> _init() async {
    _isLoading = true;
    notifyListeners();

    try {
      final hasToken = await _api.hasToken();
      if (!hasToken) {
        debugPrint('No token found - user needs to login');
        _isAuthenticated = false;
        _user = null;
        _pendingAvatarPreviewPath = null;
        _isLoading = false;
        notifyListeners();
        return;
      }

      final bootstrapValues = await Future.wait<String?>([
        _storage.read(key: _pendingAvatarPreviewPathKey),
        _storage.read(key: _rememberMeKey),
        _storage.read(key: _sessionStartedAtKey),
        _storage.read(key: _lastActivityKey),
      ]);
      _pendingAvatarPreviewPath = bootstrapValues[0];
      final rememberMeEnabled = bootstrapValues[1] == 'true';
      final sessionStartedAtRaw = bootstrapValues[2];
      final lastActivityRaw = bootstrapValues[3];

      if (rememberMeEnabled) {
        DateTime sessionStartedAt;

        if (sessionStartedAtRaw == null) {
          // Backfill missing key for older sessions so they remain valid.
          sessionStartedAt =
              DateTime.tryParse(lastActivityRaw ?? '') ?? DateTime.now();
          unawaited(_storage.write(
            key: _sessionStartedAtKey,
            value: sessionStartedAt.toIso8601String(),
          ));
        } else {
          sessionStartedAt =
              DateTime.tryParse(sessionStartedAtRaw) ?? DateTime.now();
        }

        final daysSinceSessionStart =
            DateTime.now().difference(sessionStartedAt).inDays;
        if (daysSinceSessionStart > _rememberMeDays) {
          debugPrint(
              'Auto-logout: remember-me session expired ($daysSinceSessionStart days)');
          await _api.logout();
          await _storage.delete(key: _lastActivityKey);
          await _storage.delete(key: _rememberMeKey);
          await _storage.delete(key: _sessionStartedAtKey);
          await _storage.delete(key: _pendingAvatarPreviewPathKey);
          _isAuthenticated = false;
          _user = null;
          _pendingAvatarPreviewPath = null;
          _isLoading = false;
          notifyListeners();
          return;
        }
      }

      // Check if user has been inactive for more than 7 days
      if (!rememberMeEnabled) {
        final lastActivity = await _storage.read(key: _lastActivityKey);
        if (lastActivity != null) {
          final lastDate = DateTime.parse(lastActivity);
          final daysSinceActivity = DateTime.now().difference(lastDate).inDays;

          if (daysSinceActivity > _maxInactiveDays) {
            // Auto-logout due to inactivity
            debugPrint(
                'Auto-logout due to inactivity ($daysSinceActivity days)');
            await _api.logout();
            await _storage.delete(key: _lastActivityKey);
            await _storage.delete(key: _rememberMeKey);
            await _storage.delete(key: _sessionStartedAtKey);
            await _storage.delete(key: _pendingAvatarPreviewPathKey);
            _isAuthenticated = false;
            _user = null;
            _pendingAvatarPreviewPath = null;
            _isLoading = false;
            notifyListeners();
            return;
          }
        }
      }

      // Try to get user profile with existing token
      debugPrint('Attempting to fetch user profile with stored token');
      _user = await _api.getMe().timeout(
            const Duration(seconds: 5),
            onTimeout: () => throw Exception('Request timeout'),
          );
      if ((_user?.avatar ?? '').trim().isNotEmpty) {
        _pendingAvatarPreviewPath = null;
        unawaited(_storage.delete(key: _pendingAvatarPreviewPathKey));
      }
      _isAuthenticated = true;
      _scheduleLastActivityUpdate();
      debugPrint('User authenticated successfully: ${_user?.email}');
    } catch (e) {
      debugPrint('Auth init error: $e');
      // Clear invalid token
      await _api.logout();
      _isAuthenticated = false;
      _user = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _scheduleLastActivityUpdate() {
    unawaited(_updateLastActivity());
  }

  Future<void> _updateLastActivity() async {
    await _storage.write(
      key: _lastActivityKey,
      value: DateTime.now().toIso8601String(),
    );
  }

  Future<void> _persistSessionPreference(bool rememberMe) async {
    await _storage.write(
      key: _rememberMeKey,
      value: rememberMe ? 'true' : 'false',
    );
    await _storage.write(
      key: _sessionStartedAtKey,
      value: DateTime.now().toIso8601String(),
    );
  }

  void _persistLoginSessionInBackground(bool rememberMe) {
    final nowIso = DateTime.now().toIso8601String();
    unawaited(_writeLoginSessionState(nowIso, rememberMe));
  }

  Future<void> _writeLoginSessionState(String nowIso, bool rememberMe) async {
    try {
      await Future.wait<void>([
        _storage.write(
          key: _rememberMeKey,
          value: rememberMe ? 'true' : 'false',
        ),
        _storage.write(
          key: _sessionStartedAtKey,
          value: nowIso,
        ),
        _storage.write(
          key: _lastActivityKey,
          value: nowIso,
        ),
      ]);
    } catch (e) {
      debugPrint('Failed to persist login session state: $e');
    }
  }

  Future<void> login(String email, String password,
      {bool rememberMe = false}) async {
    try {
      final response = await _api.login(email, password);
      _user = UserModel.fromJson(response['user'] as Map<String, dynamic>);
      _isAuthenticated = true;
      _persistLoginSessionInBackground(rememberMe);
      notifyListeners();
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw const AuthException(
          'network_connection_error',
          'Network connection error',
        );
      }
      if (e.response?.statusCode == 429) {
        throw const AuthException(
          'too_many_attempts',
          'Too many attempts-try again in 1 minute.',
        );
      }
      if (e.response?.statusCode == 401) {
        throw const AuthException(
          'authentication_error',
          'Invalid email or password',
        );
      }
      throw const AuthException(
        'internal_server_error',
        'Internal server error',
      );
    } catch (e) {
      if (e is AuthException) {
        rethrow;
      }
      throw const AuthException(
        'login_failed',
        'Login failed. Please try again.',
      );
    }
  }

  Future<void> register(
    String email,
    String password,
    String name, {
    bool rememberMe = false,
    String accountType = 'CONSUMER',
    String privacyProfile = 'PUBLIC',
    String? phoneNumber,
  }) async {
    try {
      final response = await _api.register(
        email,
        password,
        name,
        accountType: accountType,
        privacyProfile: privacyProfile,
        phoneNumber: phoneNumber,
      );
      _user = UserModel.fromJson(response['user'] as Map<String, dynamic>);
      _isAuthenticated = true;
      await _persistSessionPreference(rememberMe);
      await _updateLastActivity();
      notifyListeners();
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw const AuthException(
          'network_connection_error',
          'Network connection error',
        );
      }

      final statusCode = e.response?.statusCode;
      final responseData = e.response?.data;
      final serverError = responseData is Map<String, dynamic>
          ? '${responseData['error'] ?? responseData['message'] ?? ''}'
              .toLowerCase()
          : '';

      if ((statusCode == 400 || statusCode == 409) &&
          (serverError.contains('email already') ||
              serverError.contains('already registered') ||
              serverError.contains('already in use') ||
              serverError.contains('already exists'))) {
        throw const AuthException(
          'email_already_in_use',
          'Email already in use',
        );
      }

      throw const AuthException(
        'signup_failed',
        'Signup failed. Please try again.',
      );
    } catch (e) {
      if (e is AuthException) {
        rethrow;
      }
      throw const AuthException(
        'signup_failed',
        'Signup failed. Please try again.',
      );
    }
  }

  Future<void> logout() async {
    await _api.logout();
    await _storage.delete(key: _lastActivityKey);
    await _storage.delete(key: _rememberMeKey);
    await _storage.delete(key: _sessionStartedAtKey);
    await _storage.delete(key: _pendingAvatarPreviewPathKey);
    _user = null;
    _isAuthenticated = false;
    _pendingAvatarPreviewPath = null;
    notifyListeners();
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    try {
      _user = await _api.updateProfile(data);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> refreshUser({bool preserveAvatarIfMissing = false}) async {
    try {
      final previousUser = _user;
      final fetchedUser = await _api.getMe();

      final shouldPreserveAvatar = preserveAvatarIfMissing &&
          previousUser != null &&
          (previousUser.avatar ?? '').trim().isNotEmpty &&
          (fetchedUser.avatar ?? '').trim().isEmpty;

      _user = shouldPreserveAvatar
          ? fetchedUser.copyWith(avatar: previousUser.avatar)
          : fetchedUser;
      if ((_user?.avatar ?? '').trim().isNotEmpty) {
        _pendingAvatarPreviewPath = null;
        await _storage.delete(key: _pendingAvatarPreviewPathKey);
      }
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  void updateAvatarUrl(String? avatarUrl) {
    if (_user == null) return;
    _user = _user!.copyWith(
      avatar: avatarUrl,
      clearAvatar: avatarUrl == null || avatarUrl.trim().isEmpty,
    );
    if (avatarUrl == null || avatarUrl.trim().isEmpty) {
      _pendingAvatarPreviewPath = null;
      _storage.delete(key: _pendingAvatarPreviewPathKey);
    }
    notifyListeners();
  }

  Future<void> setPendingAvatarPreviewPath(String? path) async {
    _pendingAvatarPreviewPath = path;
    if (path == null || path.trim().isEmpty) {
      await _storage.delete(key: _pendingAvatarPreviewPathKey);
    } else {
      await _storage.write(key: _pendingAvatarPreviewPathKey, value: path);
    }
    notifyListeners();
  }
}
