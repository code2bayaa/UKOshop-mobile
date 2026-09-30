/// M3 · Item Detail.
///
/// Gallery, price, the variant pickers, how it is fulfilled, the seller, reviews — and a sticky action
/// bar with quantity, Add to basket and Buy now, exactly as the wireframe draws it.
///
/// **The fulfilment panel is the important one, and it is not decoration.** An item on a shelf has been
/// looked at by a named host and is paid for through escrow; an item that is not is a direct deal with
/// a stranger and UKO holds nothing. The API enforces this — `add to cart` refuses an unverified item
/// with "order from the seller directly instead" — so this screen explains it *before* the buyer taps,
/// rather than letting a button fail and leaving him to guess why.
///
/// The variant pickers are compulsory for the same reason: the API refuses with "Choose a type, colour
/// and size first", so the button stays disabled and says what is missing.
library;

import 'package:flutter/material.dart';
import 'package:uko_core/uko_core.dart';

import '../api.dart';
import '../cart_controller.dart';
import '../models.dart';

class ItemScreen extends StatefulWidget {
  const ItemScreen({
    super.key,
    required this.api,
    required this.cart,
    required this.itemId,
    this.preview,
  });

  final ShopApi api;
  final CartController cart;
  final int itemId;

  /// The card tapped to get here, so the screen has a title and a price to draw immediately rather
  /// than a spinner over a blank page.
  final ItemCard? preview;

  @override
  State<ItemScreen> createState() => _ItemScreenState();
}

class _ItemScreenState extends State<ItemScreen> {
  ItemDetail? _item;
  String _error = '';
  int _quantity = 1;
  int _image = 0;
  Variant? _variant;

  @override
  void initState() {
    super.initState();
    _load();
    widget.api.recordView(widget.itemId);
  }

  Future<void> _load() async {
    try {
      final item = await widget.api.item(widget.itemId);
      if (!mounted) return;
      setState(() {
        _item = item;
        _error = '';
        // One variant is not a choice, so make it for him.
        if (item.variants.length == 1) _variant = item.variants.first;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  bool get _ready {
    final item = _item;
    if (item == null) return false;
    if (!item.canAddToCart) return false;
    return !item.mustChoose || _variant != null;
  }

  double get _unitPrice => _variant?.amount ?? _item?.card.minAmount ?? 0;

  Future<void> _add({bool thenCheckout = false}) async {
    final item = _item;
    if (item == null) return;
    await widget.cart.add(item.id, variantId: _variant?.id, quantity: _quantity);
    if (!mounted) return;
    if (widget.cart.error.isNotEmpty) {
      showUkoMessage(context, widget.cart.error, error: true);
      return;
    }
    showUkoMessage(context, thenCheckout
        ? 'In your basket — open it to check out'
        : '${item.title} added to your basket');
    if (thenCheckout) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    final preview = widget.preview;
    return Scaffold(
      appBar: AppBar(title: Text(item?.title ?? preview?.title ?? 'Item')),
      body: item == null
          ? Center(
              child: _error.isEmpty
                  ? const CircularProgressIndicator()
                  : Padding(
                      padding: const EdgeInsets.all(24),
                      child: UkoEmpty(
                        icon: Icons.error_outline,
                        title: 'Could not load this item',
                        subtitle: _error,
                        action: AsyncButton(label: 'Try again', onPressed: _load),
                      ),
                    ),
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 28),
              children: [
                _gallery(item),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title,
                          style: const TextStyle(
                              fontSize: 18, height: 1.3, fontWeight: FontWeight.w800,
                              color: UkoColors.ink)),
                      const SizedBox(height: 8),
                      _meta(item),
                      const SizedBox(height: 14),
                      _priceBox(item),
                      const SizedBox(height: 14),
                      if (item.variants.isNotEmpty) ...[
                        _variantPicker(item),
                        const SizedBox(height: 14),
                      ],
                      _fulfilment(item),
                      const SizedBox(height: 14),
                      if (item.seller != null) _seller(item.seller!),
                      const SizedBox(height: 14),
                      if (item.description.isNotEmpty) ...[
                        UkoPanel(
                          title: 'Details',
                          child: Text(item.description,
                              style: const TextStyle(
                                  fontSize: 13, height: 1.55, color: UkoColors.ink)),
                        ),
                        const SizedBox(height: 14),
                      ],
                      if (item.features.isNotEmpty) ...[
                        UkoPanel(
                          title: 'Features',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final f in item.features)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 3),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Padding(
                                        padding: EdgeInsets.only(top: 4, right: 8),
                                        child: Icon(Icons.check, size: 13,
                                            color: UkoColors.success),
                                      ),
                                      Expanded(
                                        child: Text(f,
                                            style: const TextStyle(
                                                fontSize: 12.5, height: 1.5,
                                                color: UkoColors.ink)),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      _reviews(item),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: item == null ? null : _actionBar(item),
    );
  }

  // ---------------------------------------------------------------- pieces
  Widget _gallery(ItemDetail item) {
    final images = item.card.images.isEmpty
        ? (item.card.image.isEmpty ? <String>[] : [item.card.image])
        : item.card.images;
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1.2,
          child: Container(
            color: UkoColors.surface2,
            child: images.isEmpty
                ? const Icon(Icons.image_outlined, size: 40, color: UkoColors.borderStrong)
                : Image.network(images[_image.clamp(0, images.length - 1)],
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.image_outlined,
                        size: 40, color: UkoColors.borderStrong)),
          ),
        ),
        if (images.length > 1)
          SizedBox(
            height: 68,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              itemCount: images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => InkWell(
                onTap: () => setState(() => _image = i),
                child: Container(
                  width: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(UkoRadius.sm),
                    border: Border.all(
                      color: i == _image ? UkoColors.primary : UkoColors.border,
                      width: i == _image ? 2 : 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.network(images[i],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const ColoredBox(color: UkoColors.surface2)),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _meta(ItemDetail item) => Row(
        children: [
          if (item.card.ratingCount > 0) ...[
            const Icon(Icons.star, size: 13, color: UkoColors.warning),
            const SizedBox(width: 3),
            Text('${item.card.rating} (${item.card.ratingCount})',
                style: const TextStyle(fontSize: 11.5, color: UkoColors.ink2)),
            const SizedBox(width: 10),
          ],
          if (item.card.soldCount > 0) ...[
            Text('${item.card.soldCount} sold',
                style: const TextStyle(fontSize: 11.5, color: UkoColors.ink2)),
            const SizedBox(width: 10),
          ],
          if (item.card.code.isNotEmpty)
            Text(item.card.code,
                style: const TextStyle(fontSize: 11.5, color: UkoColors.muted)),
        ],
      );

  Widget _priceBox(ItemDetail item) => UkoPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(ksh(_unitPrice),
                    style: const TextStyle(
                        fontSize: 26, fontWeight: FontWeight.w800, color: UkoColors.ink)),
                const SizedBox(width: 10),
                if (item.card.oldAmount != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(ksh(item.card.oldAmount!),
                        style: const TextStyle(
                          fontSize: 13,
                          color: UkoColors.muted,
                          decoration: TextDecoration.lineThrough,
                        )),
                  ),
                const Spacer(),
                if (item.card.discountPct != null)
                  UkoChip('−${item.card.discountPct}%', tone: UkoTone.secondary),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.card.soldOut
                  ? 'Sold out'
                  : '${_variant?.stock ?? item.card.stock} in stock'
                      '${item.card.condition.isEmpty ? '' : ' · ${item.card.condition}'}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: item.card.soldOut ? UkoColors.danger : UkoColors.ink2,
              ),
            ),
          ],
        ),
      );

  Widget _variantPicker(ItemDetail item) => UkoPanel(
        title: 'Choose one',
        subtitle: 'UKO cannot add this to a basket until you pick which one you mean.',
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final v in item.variants)
              ChoiceChip(
                label: Text(
                  '${v.label.isEmpty ? 'Option ${v.id}' : v.label}'
                  '${v.amount != item.card.minAmount ? ' · ${ksh(v.amount)}' : ''}',
                  style: const TextStyle(fontSize: 12),
                ),
                selected: _variant?.id == v.id,
                // A sold-out variant stays visible: knowing the blue one exists but is gone is more
                // use than wondering whether it was ever made.
                onSelected: v.soldOut ? null : (_) => setState(() => _variant = v),
                disabledColor: UkoColors.surface2,
              ),
          ],
        ),
      );

  /// The panel that decides whether this is a UKO purchase or a private sale.
  Widget _fulfilment(ItemDetail item) {
    if (item.card.isVerified) {
      final shelf = item.shelve;
      return UkoPanel(
        title: 'On a UKO shelf',
        borderColor: UkoColors.success,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.verified, size: 16, color: UkoColors.success),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    shelf == null
                        ? 'Checked by a UKO shelf host'
                        : 'Checked by the host at ${shelf.name}',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700, color: UkoColors.ink),
                  ),
                ),
              ],
            ),
            if (shelf != null && shelf.where.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(shelf.where,
                  style: const TextStyle(fontSize: 11.5, height: 1.4, color: UkoColors.ink2)),
            ],
            const SizedBox(height: 10),
            const Text(
              'Your money is held by UKO until the item is in your hands. Collect it at the shelf '
              'with your code, or have a rider bring it to your door.',
              style: TextStyle(fontSize: 11.5, height: 1.5, color: UkoColors.ink2),
            ),
          ],
        ),
      );
    }
    return const UkoPanel(
      title: 'Not on a shelf',
      borderColor: UkoColors.warning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: UkoColors.warning),
              SizedBox(width: 6),
              Expanded(
                child: Text('Nobody at UKO has seen this item',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700, color: UkoColors.ink)),
              ),
            ],
          ),
          SizedBox(height: 10),
          Text(
            'It cannot go in a basket, and UKO holds no money for it. You would be buying directly '
            'from the seller and arranging the hand-over yourselves — the same as any private sale.',
            style: TextStyle(fontSize: 11.5, height: 1.5, color: UkoColors.ink2),
          ),
        ],
      ),
    );
  }

  Widget _seller(SellerPublic s) => UkoPanel(
        title: 'Seller',
        child: Row(
          children: [
            Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: UkoColors.primary050,
                borderRadius: BorderRadius.circular(UkoRadius.md),
              ),
              child: const Icon(Icons.storefront_outlined, size: 19, color: UkoColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.displayName,
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w700, color: UkoColors.ink)),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (s.itemsSold > 0) '${s.itemsSold} sold',
                      if (s.positiveRate > 0) '${s.positiveRate.round()}% positive',
                      if (s.joinedYear.isNotEmpty) 'since ${s.joinedYear}',
                    ].join(' · '),
                    style: const TextStyle(fontSize: 11, color: UkoColors.ink2),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _reviews(ItemDetail item) {
    if (item.reviewCount == 0) {
      return const UkoPanel(
        title: 'Reviews',
        child: Text('No reviews yet. Buyers can review once they have collected an order.',
            style: TextStyle(fontSize: 12.5, height: 1.5, color: UkoColors.ink2)),
      );
    }
    return UkoPanel(
      title: 'Reviews',
      subtitle: '${item.reviewAverage} out of 5 · ${item.reviewCount} '
          '${plural(item.reviewCount, 'review')}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final r in item.reviews.take(4)) ...[
            Row(
              children: [
                for (var i = 1; i <= 5; i++)
                  Icon(i <= r.rating ? Icons.star : Icons.star_border,
                      size: 12, color: UkoColors.warning),
                const SizedBox(width: 6),
                Text(r.name,
                    style: const TextStyle(
                        fontSize: 11.5, fontWeight: FontWeight.w700, color: UkoColors.ink)),
                if (r.verifiedPurchase) ...[
                  const SizedBox(width: 6),
                  const UkoChip('Bought it', tone: UkoTone.success),
                ],
              ],
            ),
            if (r.message.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(r.message,
                  style: const TextStyle(fontSize: 12, height: 1.5, color: UkoColors.ink2)),
            ],
            if (r != item.reviews.take(4).last) const Divider(height: 20),
          ],
        ],
      ),
    );
  }

  /// The wireframe's sticky action bar: quantity, add, buy.
  Widget _actionBar(ItemDetail item) {
    final max = _variant?.stock ?? item.card.stock;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: const BoxDecoration(
          color: UkoColors.bg,
          border: Border(top: BorderSide(color: UkoColors.border)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_ready && item.canAddToCart && item.mustChoose)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('Pick an option above first',
                    style: TextStyle(fontSize: 11.5, color: UkoColors.muted)),
              ),
            Row(
              children: [
                if (item.canAddToCart) ...[
                  Container(
                    height: 42,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(UkoRadius.md),
                      border: Border.all(color: UkoColors.border),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.remove, size: 17),
                          onPressed:
                              _quantity > 1 ? () => setState(() => _quantity--) : null,
                        ),
                        Text('$_quantity',
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700)),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.add, size: 17),
                          onPressed: _quantity < max
                              ? () => setState(() => _quantity++)
                              : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: item.canAddToCart
                      ? AsyncButton(
                          label: 'Add to basket',
                          icon: Icons.add_shopping_cart,
                          enabled: _ready,
                          onPressed: _ready ? () => _add() : null,
                        )
                      : AsyncButton(
                          label: item.card.soldOut ? 'Sold out' : 'Not available on UKO',
                          enabled: false,
                          onPressed: null,
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
