import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

class LocalOrderRatingStore {
  static const String _storageKey = 'local_order_ratings_v1';
  static const String _legacyUserKey = '__legacy__';
  static bool _isLoaded = false;
  static final ValueNotifier<Map<String, Map<String, int>>> ratingsNotifier =
      ValueNotifier<Map<String, Map<String, int>>>(
          <String, Map<String, int>>{});

  static Future<void> ensureLoaded() async {
    if (_isLoaded) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);

    if (raw == null || raw.isEmpty) {
      _isLoaded = true;
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final parsed = <String, Map<String, int>>{};
        for (final entry in decoded.entries) {
          final value = entry.value;
          if (value is int) {
            // Migrate old shape: { productId: rating }
            parsed[entry.key] = <String, int>{_legacyUserKey: value};
          } else if (value is Map<String, dynamic>) {
            final byUser = <String, int>{};
            for (final userEntry in value.entries) {
              if (userEntry.value is int) {
                byUser[userEntry.key] = userEntry.value as int;
              }
            }
            if (byUser.isNotEmpty) {
              parsed[entry.key] = byUser;
            }
          }
        }
        ratingsNotifier.value = parsed;
      }
    } catch (_) {
      // Ignore malformed local data and continue with empty ratings.
    }

    _isLoaded = true;
  }

  static int? getRatingForUser(String productId, String userId) {
    if (userId.trim().isEmpty) {
      return null;
    }
    return ratingsNotifier.value[productId]?[userId];
  }

  static Future<void> setRatingForUser(
    String productId,
    String userId,
    int rating,
  ) async {
    if (userId.trim().isEmpty) {
      return;
    }

    await ensureLoaded();
    final next = <String, Map<String, int>>{};
    for (final entry in ratingsNotifier.value.entries) {
      next[entry.key] = Map<String, int>.from(entry.value);
    }
    final productRatings = next.putIfAbsent(productId, () => <String, int>{});
    productRatings[userId] = rating;
    ratingsNotifier.value = next;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(next));
  }

  static Iterable<int> _allRatingsForProduct(String productId) {
    final byUser = ratingsNotifier.value[productId];
    if (byUser == null || byUser.isEmpty) {
      return const <int>[];
    }
    return byUser.values;
  }

  static int globalRatingCount(ProductModel product) {
    final localCount = _allRatingsForProduct(product.id).length;
    return product.reviewsCount + localCount;
  }

  static double globalAverageRating(ProductModel product) {
    final localRatings = _allRatingsForProduct(product.id).toList();
    if (localRatings.isEmpty) {
      return product.rating;
    }

    if (product.reviewsCount <= 0 || product.rating <= 0) {
      final localTotal =
          localRatings.fold<double>(0, (sum, rating) => sum + rating);
      return localTotal / localRatings.length;
    }

    final localTotal =
        localRatings.fold<double>(0, (sum, rating) => sum + rating);
    final total = (product.rating * product.reviewsCount) + localTotal;
    final count = product.reviewsCount + localRatings.length;
    return total / count;
  }
}
