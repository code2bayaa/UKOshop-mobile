/// Every call the shop app makes, in one place.
///
/// Thin on purpose: the shop API decides prices, stock, what a basket costs to receive and whether an
/// item may be added at all. The rules live in `shop/back-end/app/routers/`.
///
/// One shape worth noticing: **every cart call returns the whole cart**. Add, change a quantity,
/// remove, apply a promo — each answers with the full `cart_payload`, including the sentences the
/// server wrote when it had to adjust something. So the app never patches a local basket; it replaces
/// it with what the server says it is.
library;

import 'package:uko_core/uko_core.dart';

import 'models.dart';

class ShopApi {
  ShopApi(this.client);

  final ApiClient client;

  // ---------------------------------------------------------------- browsing
  Future<Home> home({String ward = ''}) async =>
      Home.fromJson(asMap(await client.get('/home', query: {'ward': ward})));

  Future<List<Category>> categories() async =>
      asList(await client.get('/categories')).map(Category.fromJson).toList();

  /// The search and browse endpoint. Every filter the M2 sheet offers maps to one of these.
  Future<SearchResults> search({
    String q = '',
    String category = '',
    String sub = '',
    List<String> wards = const [],
    List<String> conditions = const [],
    List<String> sizes = const [],
    double? minAmount,
    double? maxAmount,
    bool? verified,
    int? seller,
    int? shelve,
    String sort = 'relevant',
    int page = 1,
    int perPage = 12,
  }) async {
    // Repeated query keys (`ward=A&ward=B`) are how FastAPI reads a list, and Uri handles that only
    // when the value is a List — so these are passed through as-is rather than joined.
    final query = <String, dynamic>{
      'q': q,
      'category': category,
      'sub': sub,
      'min_amount': minAmount,
      'max_amount': maxAmount,
      'verified': verified,
      'seller': seller,
      'shelve': shelve,
      'sort': sort,
      'page': page,
      'per_page': perPage,
    };
    final uri = <String, String>{};
    query.forEach((k, v) {
      if (v == null || v == '' || v == false) return;
      uri[k] = '$v';
    });
    final extra = [
      for (final w in wards) 'ward=${Uri.encodeQueryComponent(w)}',
      for (final c in conditions) 'condition=${Uri.encodeQueryComponent(c)}',
      for (final s in sizes) 'size=${Uri.encodeQueryComponent(s)}',
    ].join('&');
    final path = extra.isEmpty
        ? '/items'
        : '/items?$extra';
    return SearchResults.fromJson(asMap(await client.get(path, query: uri)));
  }

  Future<ItemDetail> item(int id) async =>
      ItemDetail.fromJson(asMap(await client.get('/items/$id')));

  /// Counted server-side; a failure here must never interrupt looking at the thing.
  void recordView(int id, {String ward = ''}) =>
      client.postQuietly('/items/$id/view', body: {'ward': ward});

  Future<List<Shelf>> shelves() async =>
      asList(await client.get('/shelves')).map(Shelf.fromJson).toList();

  // ---------------------------------------------------------------- the basket
  Future<Cart> cart({String promo = ''}) async =>
      Cart.fromJson(asMap(await client.get('/cart', query: {'promo': promo})));

  Future<Cart> addToCart(int itemId, {int? variantId, int quantity = 1}) async =>
      Cart.fromJson(asMap(await client.post('/cart',
          body: {'item_id': itemId, 'variant_id': variantId, 'quantity': quantity})));

  /// Quantity 0 removes the line — the API's own convention, kept rather than wrapped.
  Future<Cart> setQuantity(int rowId, int quantity) async =>
      Cart.fromJson(asMap(await client.put('/cart/$rowId', body: {'quantity': quantity})));

  Future<Cart> saveForLater(int rowId, bool saved) async => Cart.fromJson(
      asMap(await client.put('/cart/$rowId', body: {'quantity': 1, 'saved_for_later': saved})));

  Future<Cart> removeLine(int rowId) async =>
      Cart.fromJson(asMap(await client.delete('/cart/$rowId')));

  Future<Cart> applyPromo(String code) async =>
      Cart.fromJson(asMap(await client.post('/cart/promo', body: {'code': code})));

  /// Re-price the basket against current stock. Called when checkout opens, because a basket held for
  /// two hours can go stale under the buyer.
  Future<Cart> recheck({String promo = ''}) async =>
      Cart.fromJson(asMap(await client.post('/cart/recheck', query: {'promo': promo})));

  // ---------------------------------------------------------------- checkout
  Future<CheckoutOptions> checkoutOptions({
    String ward = '',
    double? lat,
    double? lng,
    int? destShelveId,
  }) async =>
      CheckoutOptions.fromJson(asMap(await client.get('/cart/checkout-options', query: {
        'ward': ward,
        'lat': lat,
        'lng': lng,
        'dest_shelve_id': destShelveId,
      })));

  Future<List<Shelf>> collectShelves({String ward = '', String county = '', double? lat, double? lng}) async =>
      asList(await client.get('/cart/collect-shelves',
              query: {'ward': ward, 'county': county, 'lat': lat, 'lng': lng}))
          .map(Shelf.fromJson)
          .toList();

  /// Place the order. `confirmFunds` and `confirmAccount` are not decoration: the API refuses without
  /// both, because this is the moment a buyer commits money to escrow.
  Future<Order> placeOrder({
    required String deliveryOption,
    int? destShelveId,
    String recipientName = '',
    String phone = '',
    String estate = '',
    String house = '',
    String ward = '',
    String county = '',
    double? destLat,
    double? destLng,
    String notes = '',
    String promoCode = '',
    bool smsReminders = false,
  }) async =>
      Order.fromJson(asMap(await client.post('/orders', body: {
        'delivery_option': deliveryOption,
        'dest_shelve_id': destShelveId,
        'recipient_name': recipientName,
        'phone': phone,
        'estate': estate,
        'house': house,
        'ward': ward,
        'county': county,
        'dest_lat': destLat,
        'dest_lng': destLng,
        'notes': notes,
        'promo_code': promoCode,
        'confirm_funds': true,
        'confirm_account': true,
        'sms_reminders': smsReminders,
      })));

  // ---------------------------------------------------------------- orders
  Future<List<Order>> orders() async {
    final body = await client.get('/orders');
    // The route has returned a bare list and a wrapped one at different times; read both.
    final rows = body is List ? body : asMap(body)['orders'];
    return asList(rows).map(Order.fromJson).toList();
  }

  Future<Order> order(int id) async => Order.fromJson(asMap(await client.get('/orders/$id')));

  Future<void> cancelOrder(int id) => client.post('/orders/$id/cancel');

  Future<({Order order, OrderTracking? tracking})> tracking(int id) async {
    final body = asMap(await client.get('/orders/$id/tracking'));
    return (
      order: Order.fromJson(asMap(body['order'])),
      tracking: body['delivery'] == null
          ? null
          : OrderTracking.fromJson(asMap(body['delivery'])),
    );
  }

  /// Pay for an order. M-PESA is a push to the buyer's phone: the API answers immediately and the
  /// result arrives later, which is why the payment screen polls `paymentStatus` rather than treating
  /// this response as the answer.
  Future<Map<String, dynamic>> pay(int id, {required String method, String phone = ''}) async =>
      asMap(await client.post('/orders/$id/pay', body: {'method': method, 'phone': phone}));

  Future<Map<String, dynamic>> paymentStatus(int id) async =>
      asMap(await client.post('/orders/$id/payment-status'));

  // ---------------------------------------------------------------- selling
  Future<Map<String, dynamic>> sellerDashboard() async =>
      asMap(await client.get('/seller/dashboard'));

  Future<List<ItemCard>> sellerItems() async {
    final body = await client.get('/seller/items');
    final rows = body is List ? body : asMap(body)['items'];
    return asList(rows).map(ItemCard.fromJson).toList();
  }

  Future<List<Order>> sellerOrders() async {
    final body = await client.get('/seller/orders');
    final rows = body is List ? body : asMap(body)['orders'];
    return asList(rows).map(Order.fromJson).toList();
  }

  /// Post an ad. The API charges for it and decides whether it needs a shelf — the app only carries
  /// what the seller typed.
  Future<Map<String, dynamic>> postItem(Map<String, dynamic> body) async =>
      asMap(await client.post('/items', body: body));

  Future<void> requestShelve(int itemId, Map<String, dynamic> body) =>
      client.post('/items/$itemId/shelve-request', body: body);
}
