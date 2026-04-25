import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class CartProvider extends ChangeNotifier {
  final ApiService _api;
  
  CartModel _cart = CartModel.empty();
  bool _isLoading = false;
  final Map<String, int> _resolvedStockByProductId = {};

  CartModel get cart => _cart;
  bool get isLoading => _isLoading;

  CartProvider({required ApiService apiService}) : _api = apiService;

  int? stockLimitFor(String productId, {int? fallbackStock}) {
    if (fallbackStock != null && fallbackStock > 0) {
      return fallbackStock;
    }
    return _resolvedStockByProductId[productId];
  }

  Future<void> _hydrateStockLimits(List<CartItemModel> items) async {
    for (final item in items) {
      final stock = item.product.stockQuantity;
      if (stock > 0) {
        _resolvedStockByProductId[item.product.id] = stock;
        continue;
      }

      try {
        final product = await _api.getProduct(item.product.id);
        if (product.stockQuantity > 0) {
          _resolvedStockByProductId[item.product.id] = product.stockQuantity;
        }
      } catch (_) {
        // Keep previous resolved value if fetch fails.
      }
    }
  }

  Future<int?> _resolveMaxQuantity(String productId, int? maxQuantity) async {
    final cached = stockLimitFor(productId, fallbackStock: maxQuantity);
    if (cached != null && cached > 0) {
      return cached;
    }

    try {
      final product = await _api.getProduct(productId);
      if (product.stockQuantity > 0) {
        _resolvedStockByProductId[productId] = product.stockQuantity;
        return product.stockQuantity;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  int _clampQuantity(int quantity, int? maxQuantity) {
    if (quantity < 1) {
      return 0;
    }

    if (maxQuantity == null || maxQuantity < 1) {
      return quantity;
    }

    return quantity > maxQuantity ? maxQuantity : quantity;
  }

  Future<void> fetchCart() async {
    try {
      _isLoading = true;
      notifyListeners();
      
      _cart = await _api.getCart();
      await _hydrateStockLimits(_cart.items);
    } catch (e) {
      debugPrint('Error fetching cart: $e');
      _cart = CartModel.empty();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addToCart(
    String productId, {
    int quantity = 1,
    int? maxQuantity,
  }) async {
    try {
      final resolvedMaxQuantity = await _resolveMaxQuantity(productId, maxQuantity);
      final safeQuantity = _clampQuantity(quantity, resolvedMaxQuantity);
      if (safeQuantity < 1) {
        return false;
      }

      await _api.addToCart(productId, quantity: safeQuantity);
      await fetchCart();
      return true;
    } catch (e) {
      debugPrint('Error adding to cart: $e');
      return false;
    }
  }

  Future<bool> updateQuantity(
    String productId,
    int quantity, {
    int? maxQuantity,
  }) async {
    try {
      final resolvedMaxQuantity = await _resolveMaxQuantity(productId, maxQuantity);
      final safeQuantity = _clampQuantity(quantity, resolvedMaxQuantity);
      if (safeQuantity < 1) {
        return false;
      }

      await _api.updateCartQuantity(productId, safeQuantity);
      await fetchCart();
      return true;
    } catch (e) {
      debugPrint('Error updating quantity: $e');
      return false;
    }
  }

  Future<bool> removeFromCart(String productId) async {
    try {
      await _api.removeFromCart(productId);
      await fetchCart();
      return true;
    } catch (e) {
      debugPrint('Error removing from cart: $e');
      return false;
    }
  }

  Future<bool> clearCart() async {
    try {
      await _api.clearCart();
      _cart = CartModel.empty();
      _resolvedStockByProductId.clear();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error clearing cart: $e');
      return false;
    }
  }
}
