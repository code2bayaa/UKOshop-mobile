/// What the shop is made of.
///
/// These mirror `shop/back-end/app/serialize.py` — `item_card`, `item_full`, `cart_payload`,
/// `order_dict`, `shelve_dict` — and nothing more.
///
/// **Unlike the partner apps, a buyer IS shown his own codes.** `claim_code`, `shelve_code` and
/// `rider_code` come down on his order because he is the one who reads them out: to a shelf host when
/// he collects, to a rider at his gate. The direction is the same rule as everywhere in UKO — the
/// person letting go of the goods types in what the person taking them says — he is just on the other
/// side of it here.
library;

import 'package:uko_core/uko_core.dart';

/// An item as it appears in a grid, from `item_card`.
class ItemCard {
  ItemCard.fromJson(Map<String, dynamic> j)
      : id = asInt(j['id']),
        code = asText(j['code']),
        title = asText(j['title'], 'Item'),
        image = asText(j['image']),
        images = (j['images'] as List?)?.map((x) => '$x').toList() ?? const [],
        isVerified = j['is_verified'] == true,
        shelveName = asText(j['shelve_name']),
        shelveId = asInt(j['shelve_id']),
        ward = asText(j['ward']),
        rating = asDouble(j['rating']),
        ratingCount = asInt(j['rating_count']),
        minAmount = asDouble(j['min_amount']),
        maxAmount = asDouble(j['max_amount']),
        oldAmount = j['old_amount'] == null ? null : asDouble(j['old_amount']),
        soldCount = asInt(j['sold_count']),
        stock = asInt(j['stock']),
        status = asText(j['status'], 'live'),
        condition = asText(j['condition']),
        boosted = j['boosted'] == true,
        barterEnabled = j['barter_enabled'] == true,
        sellerId = asInt(j['seller_id']);

  final int id;
  final String code;
  final String title;
  final String image;
  final List<String> images;
  final bool isVerified;
  final String shelveName;
  final int shelveId;
  final String ward;
  final double rating;
  final int ratingCount;
  final double minAmount;
  final double maxAmount;
  final double? oldAmount;
  final int soldCount;
  final int stock;
  final String status;
  final String condition;
  final bool boosted;
  final bool barterEnabled;
  final int sellerId;

  bool get soldOut => status == 'sold_out' || stock <= 0;

  /// A range when variants differ in price, one figure when they do not.
  ///
  /// The currency is printed once, as the wireframe's product card does it — "KSh 1,850 – 2,400".
  /// Repeating it makes the range long enough to truncate in a two-column grid, which turns a price
  /// into "KSh 5,600 – KSh 6,…".
  String get price => maxAmount > minAmount
      ? '${ksh(minAmount)} – ${ksh(maxAmount).replaceFirst(RegExp(r'^\D+'), '')}'
      : ksh(minAmount);

  /// What a buyer saves, when the seller set a was-price.
  int? get discountPct {
    final was = oldAmount;
    if (was == null || was <= minAmount || was == 0) return null;
    return (100 - minAmount / was * 100).round();
  }

  /// **The whole promise of UKO in one line.** Verified means a named shelf host looked at the thing
  /// and said it matched the advert; an unverified item is bought direct from the seller with no
  /// escrow behind it. The grid says which, every time.
  String get trust => isVerified
      ? 'Verified at ${shelveName.isEmpty ? 'a shelf' : shelveName}'
      : 'Direct from the seller';
}

/// One selectable variant of an item.
class Variant {
  Variant.fromJson(Map<String, dynamic> j)
      : id = asInt(j['id']),
        // The API sends the parts — type, colour, size — and no composed label. "Dual SIM · Blue ·
        // 128GB" is what a buyer is choosing between; "Option 1" is not.
        label = asText(j['label']).isNotEmpty
            ? asText(j['label'])
            : [asText(j['type']), asText(j['color']), asText(j['size'])]
                .where((p) => p.isNotEmpty)
                .join(' · '),
        amount = asDouble(j['amount']),
        stock = asInt(j['stock']),
        type = asText(j['type']),
        color = asText(j['color']),
        size = asText(j['size']);

  final int id;
  final String label;
  final double amount;
  final int stock;
  final String type;
  final String color;
  final String size;

  bool get soldOut => stock <= 0;
}

/// A shelf, wherever one appears.
class Shelf {
  Shelf.fromJson(Map<String, dynamic> j)
      : id = asInt(j['id']),
        name = asText(j['name'], 'Shelf'),
        county = asText(j['county']),
        ward = asText(j['ward']),
        address = asText(j['address']),
        landmark = asText(j['landmark']),
        phone = asText(j['contact_phone']),
        image = asText(j['image']),
        openingTime = asText(j['opening_time']),
        closingTime = asText(j['closing_time']),
        openSunday = j['open_sunday'] == true,
        deliveryFee = asDouble(j['delivery_fee']),
        itemsCount = asInt(j['items_count']),
        isOpen = j['is_open'] == true,
        distanceKm = j['distance_km'] == null ? null : asDouble(j['distance_km']),
        cartItems = asInt(j['cart_items']),
        lat = j['lat'] == null ? null : asDouble(j['lat']),
        lng = j['lng'] == null ? null : asDouble(j['lng']);

  final int id;
  final String name;
  final String county;
  final String ward;
  final String address;
  final String landmark;
  final String phone;
  final String image;
  final String openingTime;
  final String closingTime;
  final bool openSunday;
  final double deliveryFee;
  final int itemsCount;
  final bool isOpen;
  final double? distanceKm;
  final int cartItems;
  final double? lat;
  final double? lng;

  String get where => [
        if (address.isNotEmpty) address,
        if (ward.isNotEmpty) ward,
        if (landmark.isNotEmpty) 'near $landmark',
      ].join(' · ');

  String get hours =>
      openingTime.isEmpty || closingTime.isEmpty ? '' : '$openingTime – $closingTime';
}

/// The seller behind an item, as `seller_public` sends him.
class SellerPublic {
  SellerPublic.fromJson(Map<String, dynamic> j)
      : id = asInt(j['id']),
        name = asText(j['name']),
        storeName = asText(j['store_name']),
        avatar = asText(j['avatar']),
        positiveRate = asDouble(j['positive_rate']),
        itemsSold = asInt(j['items_sold']),
        joinedYear = asText(j['joined_year']),
        ward = asText(j['ward']);

  final int id;
  final String name;
  final String storeName;
  final String avatar;
  final double positiveRate;
  final int itemsSold;
  final String joinedYear;
  final String ward;

  String get displayName => storeName.isNotEmpty ? storeName : name;
}

/// One review.
class Review {
  Review.fromJson(Map<String, dynamic> j)
      : name = asText(j['name'], 'A buyer'),
        rating = asInt(j['rating']),
        message = asText(j['message']),
        verifiedPurchase = j['verified_purchase'] == true,
        reply = asText(j['reply']),
        at = asDate(j['created_at']);

  final String name;
  final int rating;
  final String message;
  final bool verifiedPurchase;
  final String reply;
  final DateTime? at;
}

/// A full item page, from `item_full` plus what the detail route adds.
class ItemDetail {
  ItemDetail.fromJson(Map<String, dynamic> j)
      : card = ItemCard.fromJson(j),
        description = asText(j['description']),
        brand = asText(j['brand']),
        weightKg = asDouble(j['weight_kg']),
        county = asText(j['county']),
        specification = asText(j['specification']),
        features = _bullets(j['features']),
        variants = asList(j['variants']).map(Variant.fromJson).toList(),
        shelve = j['shelve'] == null ? null : Shelf.fromJson(asMap(j['shelve'])),
        shelveStatus = asText(j['shelve_status']),
        seller = j['seller'] == null ? null : SellerPublic.fromJson(asMap(j['seller'])),
        barterTypes = asList(j['barter_types']).map((b) => asText(b['label'])).toList(),
        reviewCount = asInt(asMap(j['feedback'])['count']),
        reviewAverage = asDouble(asMap(j['feedback'])['average']),
        reviews = asList(asMap(j['feedback'])['reviews']).map(Review.fromJson).toList(),
        moreFromSeller = asList(j['more_from_seller']).map(ItemCard.fromJson).toList();

  final ItemCard card;
  final String description;
  final String brand;
  final double weightKg;
  final String county;
  final String specification;
  final List<String> features;
  final List<Variant> variants;
  final Shelf? shelve;
  final String shelveStatus;
  final SellerPublic? seller;
  final List<String> barterTypes;
  final int reviewCount;
  final double reviewAverage;
  final List<Review> reviews;
  final List<ItemCard> moreFromSeller;

  int get id => card.id;
  String get title => card.title;

  /// Choosing is compulsory when an item has variants — the API refuses `add to cart` without one,
  /// with "Choose a type, colour and size first".
  bool get mustChoose => variants.isNotEmpty;

  /// Only a verified item on a shelf can go in a basket. Anything else is a direct deal with the
  /// seller, outside escrow — which the screen has to say plainly rather than just disabling a button.
  bool get canAddToCart => card.isVerified && !card.soldOut;
}

/// A category, for the strip and the browse tab.
class Category {
  Category.fromJson(Map<String, dynamic> j)
      : id = asInt(j['id']),
        name = asText(j['name']),
        slug = asText(j['slug']),
        children = asList(j['children']).map(Category.fromJson).toList();

  final int id;
  final String name;
  final String slug;
  final List<Category> children;
}

/// One line in the basket.
class CartLine {
  CartLine.fromJson(Map<String, dynamic> j)
      : id = asInt(j['id']),
        item = ItemCard.fromJson(asMap(j['item'])),
        variantLabel = asText(j['variant_label']),
        variantId = j['variant'] == null ? null : asInt(asMap(j['variant'])['id']),
        quantity = asInt(j['quantity'], 1),
        amount = asDouble(j['amount']),
        available = asInt(j['available']),
        lowStock = j['low_stock'] == true,
        savedForLater = j['saved_for_later'] == true;

  final int id;
  final ItemCard item;
  final String variantLabel;
  final int? variantId;
  final int quantity;
  final double amount;
  final int available;
  final bool lowStock;
  final bool savedForLater;

  double get lineTotal => amount * quantity;
}

/// The basket, from `cart_payload`.
class Cart {
  Cart.fromJson(Map<String, dynamic> j)
      : lines = asList(j['items']).map(CartLine.fromJson).toList(),
        /// Sentences the server wrote when it had to change the basket under the buyer — an item that
        /// sold out, a quantity it had to drop. Shown verbatim, because silently altering someone's
        /// basket is how a shop loses trust.
        notices = (j['notices'] as List?)?.map((x) => '$x').toList() ?? const [],
        count = asInt(asMap(j['summary'])['count']),
        subtotal = asDouble(asMap(j['summary'])['subtotal']),
        shelves = asInt(asMap(j['summary'])['shelves']),
        discount = asDouble(asMap(j['summary'])['discount']),
        promoCode = asText(asMap(j['summary'])['promo_code']),
        protectFee = asDouble(asMap(j['summary'])['protect_fee']),
        total = asDouble(asMap(j['summary'])['total']),
        holdHours = asInt(asMap(j['summary'])['hold_hours'], 2);

  final List<CartLine> lines;
  final List<String> notices;
  final int count;
  final double subtotal;
  final int shelves;
  final double discount;
  final String promoCode;
  final double protectFee;
  final double total;
  final int holdHours;

  List<CartLine> get active => lines.where((l) => !l.savedForLater).toList();
  List<CartLine> get saved => lines.where((l) => l.savedForLater).toList();

  bool get isEmpty => active.isEmpty;

  /// A basket spread over several shelves is the thing that makes UKO checkout unusual, and the
  /// reason the delivery options exist at all.
  bool get multiShelf => shelves > 1;
}

/// One way of receiving a cart, from `DELIVERY_OPTIONS` priced per basket.
class DeliveryOption {
  DeliveryOption.fromJson(Map<String, dynamic> j)
      : key = asText(j['key']),
        title = asText(j['title']),
        sub = asText(j['sub']),
        fee = asDouble(j['fee']),
        available = j['available'] != false,
        reason = asText(j['reason']);

  final String key;
  final String title;
  final String sub;
  final double fee;
  final bool available;
  final String reason;

  /// Ends at the buyer's own address, so checkout must ask for one.
  bool get toDoor => key == 'rider' || key == 'taxi';
}

/// What `/cart/checkout-options` returns.
class CheckoutOptions {
  CheckoutOptions.fromJson(Map<String, dynamic> j)
      : shelves = asList(j['shelves']).map(Shelf.fromJson).toList(),
        options = asList(j['delivery_options']).map(DeliveryOption.fromJson).toList(),
        collectAt = j['collect_at'] == null ? null : Shelf.fromJson(asMap(j['collect_at'])),
        /// The inter-city legs this basket could not avoid. Already inside every option's fee — sent
        /// separately so checkout can show the line instead of an unexplained jump in the total.
        ///
        /// `legs` is a **list** of the journeys, not a count, and `required` is the server's own
        /// answer to "does this basket need a van at all" — so that is what decides, rather than
        /// inferring it from a fee that can legitimately be zero.
        courierFee = asDouble(asMap(j['courier'])['fee']),
        courierLegs = _legCount(asMap(j['courier'])['legs']),
        courierRequired = asMap(j['courier'])['required'] == true,
        weightKg = asDouble(j['weight_kg']);

  final List<Shelf> shelves;
  final List<DeliveryOption> options;
  final Shelf? collectAt;
  final double courierFee;
  final int courierLegs;
  final bool courierRequired;
  final double weightKg;

  bool get hasCourier => courierRequired || courierLegs > 0 || courierFee > 0;
}

/// How many inter-city journeys. The server sends a **list** of them; an older shape sent a count,
/// and a bare `as List` cast on that throws rather than degrading. Both are read.
int _legCount(dynamic legs) => switch (legs) {
      List l => l.length,
      num n => n.toInt(),
      _ => 0,
    };

/// Feature bullets, whichever shape they arrive in.
///
/// `items.features` is a **rich-text HTML string** on the shop API — `<ul><li>…</li></ul>` — because
/// the web app edits it in a rich-text field. A bare `as List` cast on that throws, which left the
/// item screen spinning forever behind a perfectly good 200. The list shape is accepted too, in case
/// it ever changes.
List<String> _bullets(dynamic features) {
  if (features is List) {
    return features.map((x) => '$x').where((s) => s.trim().isNotEmpty).toList();
  }
  final html = asText(features);
  if (html.trim().isEmpty) return const [];
  final items = RegExp(r'<li[^>]*>(.*?)</li>', dotAll: true, caseSensitive: false)
      .allMatches(html)
      .map((m) => _stripTags(m.group(1) ?? ''))
      .where((s) => s.isNotEmpty)
      .toList();
  if (items.isNotEmpty) return items;
  // Not a list at all — a paragraph or two. One bullet is better than losing it.
  final plain = _stripTags(html);
  return plain.isEmpty ? const [] : [plain];
}

String _stripTags(String html) => html
    .replaceAll(RegExp(r'<[^>]*>'), ' ')
    .replaceAll('&amp;', '&')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// One line of a placed order.
class OrderLine {
  OrderLine.fromJson(Map<String, dynamic> j)
      : title = asText(j['title'], 'Item'),
        variantLabel = asText(j['variant_label']),
        image = asText(j['image']),
        quantity = asInt(j['quantity'], 1),
        amount = asDouble(j['amount']),
        sellerStatus = asText(j['seller_status']);

  final String title;
  final String variantLabel;
  final String image;
  final int quantity;
  final double amount;
  final String sellerStatus;

  String get line => '$quantity × $title${variantLabel.isEmpty ? '' : ' · $variantLabel'}';
}

/// A buyer's order.
class Order {
  Order.fromJson(Map<String, dynamic> j)
      : id = asInt(j['id']),
        orderNo = asText(j['order_no']),
        status = asText(j['status']),
        paymentStatus = asText(j['payment_status']),
        deliveryOption = asText(j['delivery_option']),
        subtotal = asDouble(j['subtotal']),
        deliveryFee = asDouble(j['delivery_fee']),
        shelveFee = asDouble(j['shelve_fee']),
        protectFee = asDouble(j['protect_fee']),
        discount = asDouble(j['discount']),
        total = asDouble(j['total']),
        itemCount = asInt(j['item_count']),
        shelve = j['shelve'] == null ? null : Shelf.fromJson(asMap(j['shelve'])),
        collectShelve =
            j['collect_shelve'] == null ? null : Shelf.fromJson(asMap(j['collect_shelve'])),
        // His own, to read out — see the library note at the top of this file.
        claimCode = asText(j['claim_code']),
        shelveCode = asText(j['shelve_code']),
        riderCode = asText(j['rider_code']),
        recipientName = asText(j['recipient_name']),
        phone = asText(j['phone']),
        estate = asText(j['estate']),
        house = asText(j['house']),
        ward = asText(j['ward']),
        notes = asText(j['notes']),
        items = asList(j['items']).map(OrderLine.fromJson).toList(),
        createdAt = asDate(j['created_at']),
        holdUntil = asDate(j['hold_until']);

  final int id;
  final String orderNo;
  final String status;
  final String paymentStatus;
  final String deliveryOption;
  final double subtotal;
  final double deliveryFee;
  final double shelveFee;
  final double protectFee;
  final double discount;
  final double total;
  final int itemCount;
  final Shelf? shelve;
  final Shelf? collectShelve;
  final String claimCode;
  final String shelveCode;
  final String riderCode;
  final String recipientName;
  final String phone;
  final String estate;
  final String house;
  final String ward;
  final String notes;
  final List<OrderLine> items;
  final DateTime? createdAt;
  final DateTime? holdUntil;

  bool get unpaid => paymentStatus == 'unpaid';
  bool get paid => paymentStatus == 'paid' || paymentStatus == 'released';
  bool get cancelled => status == 'cancelled';
  bool get done => status == 'completed';

  /// Waiting at a shelf for him to walk in.
  bool get readyToCollect => status == 'ready';

  /// On a rider, somewhere between a shelf and his gate.
  bool get onTheWay => status == 'shipped';

  /// The one thing he must not lose. Which code matters depends on how he is receiving it: a shelf
  /// code if he is collecting, a rider code if it is coming to his door.
  String get codeToGive => deliveryOption == 'pickup' || deliveryOption == 'shelf_run'
      ? shelveCode
      : riderCode;

  String get codeLabel => deliveryOption == 'pickup' || deliveryOption == 'shelf_run'
      ? 'Read this to the shelf when you collect'
      : 'Read this to the rider when he hands it over';

  String get where => switch (deliveryOption) {
        'pickup' => 'Collect at each shelf',
        'shelf_run' => 'Collect at ${collectShelve?.name ?? 'your shelf'}',
        'rider' => 'To your door',
        'taxi' => 'Taxi to your door',
        _ => deliveryOption,
      };
}

/// The rider on an order, for tracking.
class OrderTracking {
  OrderTracking.fromJson(Map<String, dynamic> j)
      : trackingNo = asText(j['tracking_no']),
        status = asText(j['status']),
        riderName = asText(asMap(j['rider'])['name']),
        riderPhone = asText(asMap(j['rider'])['phone']),
        numberPlate = asText(asMap(j['rider'])['number_plate']),
        vehicle = asText(j['vehicle']),
        distanceKm = asDouble(j['distance_km']),
        eta = asText(j['eta']),
        windowStart = asText(j['window_start']),
        windowEnd = asText(j['window_end']),
        events = asList(j['events'])
            .map((e) => (
                  title: asText(e['title']),
                  sub: asText(e['sub']),
                  at: asDate(e['time']),
                ))
            .toList();

  final String trackingNo;
  final String status;
  final String riderName;
  final String riderPhone;
  final String numberPlate;
  final String vehicle;
  final double distanceKm;
  final String eta;
  final String windowStart;
  final String windowEnd;
  final List<({String title, String sub, DateTime? at})> events;

  bool get hasRider => riderName.isNotEmpty;
  bool get delivered => status == 'delivered';
}

/// The shop home screen (M1), in one response.
class Home {
  Home.fromJson(Map<String, dynamic> j)
      : trending = asList(j['trending']).map(ItemCard.fromJson).toList(),
        deals = asList(j['deals']).map(ItemCard.fromJson).toList(),
        boosted = asList(j['boosted']).map(ItemCard.fromJson).toList(),
        shelves = asList(j['shelves']).map(Shelf.fromJson).toList(),
        dealsWard = asText(j['deals_ward']),
        itemsOnShelves = asInt(asMap(j['stats'])['items_on_shelves']),
        verifiedSellers = asInt(asMap(j['stats'])['verified_sellers']),
        wardsLive = asInt(asMap(j['stats'])['wards_live']);

  final List<ItemCard> trending;
  final List<ItemCard> deals;
  final List<ItemCard> boosted;
  final List<Shelf> shelves;
  final String dealsWard;
  final int itemsOnShelves;
  final int verifiedSellers;
  final int wardsLive;
}

/// A page of search results.
class SearchResults {
  SearchResults.fromJson(Map<String, dynamic> j)
      : items = asList(j['items']).map(ItemCard.fromJson).toList(),
        total = asInt(j['total']),
        page = asInt(j['page'], 1),
        pages = asInt(j['pages'], 1),
        title = asText(j['title'], 'All items'),
        wards = asList(asMap(j['filters'])['wards'])
            .map((w) => (name: asText(w['name']), count: asInt(w['count'])))
            .toList(),
        sizes = (asMap(j['filters'])['sizes'] as List?)?.map((x) => '$x').toList() ?? const [],
        conditions =
            (asMap(j['filters'])['conditions'] as List?)?.map((x) => '$x').toList() ?? const [];

  final List<ItemCard> items;
  final int total;
  final int page;
  final int pages;
  final String title;
  final List<({String name, int count})> wards;
  final List<String> sizes;
  final List<String> conditions;

  bool get hasMore => page < pages;
}
