/// The basket, held once for the whole app.
///
/// It lives above the screens rather than inside the cart tab because three other places need it: the
/// top bar's badge, the item screen's "add to basket", and checkout. Every mutation returns the whole
/// basket from the server, so this never patches a local copy — it replaces it, which is what keeps
/// the badge honest when an item sells out under the buyer.
library;

import 'package:flutter/foundation.dart';
import 'package:uko_core/uko_core.dart';

import 'api.dart';
import 'models.dart';

class CartController extends ChangeNotifier {
  CartController({required this.api});

  final ShopApi api;

  Cart? _cart;
  String _promo = '';
  bool _busy = false;
  String _error = '';

  Cart? get cart => _cart;
  bool get busy => _busy;
  String get error => _error;
  String get promo => _promo;

  int get count => _cart?.count ?? 0;

  /// Sentences the server wrote about changes it made to the basket. Read once and cleared, so a
  /// buyer is told "that sold out" exactly the same number of times it happened: once.
  List<String> takeNotices() {
    final notices = _cart?.notices ?? const <String>[];
    if (notices.isEmpty) return const [];
    return notices;
  }

  Future<void> load() => _run(() => api.cart(promo: _promo));

  /// Called when checkout opens: re-prices against current stock, because a basket held for two hours
  /// can go stale under the buyer.
  Future<void> recheck() => _run(() => api.recheck(promo: _promo));

  Future<void> add(int itemId, {int? variantId, int quantity = 1}) =>
      _run(() => api.addToCart(itemId, variantId: variantId, quantity: quantity));

  Future<void> setQuantity(int rowId, int quantity) =>
      _run(() => api.setQuantity(rowId, quantity));

  Future<void> remove(int rowId) => _run(() => api.removeLine(rowId));

  Future<void> saveForLater(int rowId, bool saved) =>
      _run(() => api.saveForLater(rowId, saved));

  Future<void> applyPromo(String code) async {
    await _run(() => api.applyPromo(code));
    // Only keep the code if the server accepted it — it refuses an unknown one with a 400, which
    // `_run` surfaces as `error` without changing the basket.
    if (_error.isEmpty) _promo = code.toUpperCase();
  }

  void clearPromo() {
    _promo = '';
    load();
  }

  Future<void> _run(Future<Cart> Function() call) async {
    _busy = true;
    _error = '';
    notifyListeners();
    try {
      _cart = await call();
    } on ApiException catch (e) {
      // A 401 just means the guest basket is the one in play; anything else is worth showing.
      if (!e.unauthorised) _error = e.message;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
