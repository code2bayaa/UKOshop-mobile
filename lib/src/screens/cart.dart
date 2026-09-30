/// M4 · Cart.
///
/// The stepper, the stock-check notice, the lines, the summary, and a sticky total-and-continue.
///
/// **The notices are the point of this screen.** A UKO basket holds real stock on real shelves for a
/// couple of hours, and in that time an item can sell out or drop to fewer units than the buyer asked
/// for. The server adjusts the basket and writes a sentence saying what it did — "Ankara maxi dress
/// dropped to 2 units at Kilimani Shelf 01, your quantity was adjusted from 3 to 2". Those go at the
/// top, unedited. Silently changing somebody's basket is how a shop loses them.
///
/// The other thing shown here that a normal cart has no concept of: **how many shelves the basket is
/// spread across**. That number is what decides what receiving it costs, and it is better understood
/// here than discovered as a price on the next screen.
library;

import 'package:flutter/material.dart';
import 'package:uko_core/uko_core.dart';

import '../api.dart';
import '../auth.dart';
import '../cart_controller.dart';
import '../config.dart';
import '../models.dart';
import 'checkout.dart';
import 'sign_in.dart';
import 'widgets/chrome.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({
    super.key,
    required this.api,
    required this.cart,
    required this.auth,
    required this.onOpenItem,
    required this.onBrowse,
  });

  final ShopApi api;
  final CartController cart;
  final ShopAuth auth;
  final void Function(ItemCard) onOpenItem;
  final VoidCallback onBrowse;

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _promo = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.cart.addListener(_onCart);
    // Re-price on open: a basket held for hours can have gone stale under the buyer.
    widget.cart.recheck();
  }

  @override
  void dispose() {
    widget.cart.removeListener(_onCart);
    _promo.dispose();
    super.dispose();
  }

  void _onCart() {
    if (mounted) setState(() {});
  }

  Future<void> _continue() async {
    if (!widget.auth.signedIn) {
      final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => SignInScreen(auth: widget.auth, reason: 'Sign in to check out'),
      ));
      if (ok != true || !mounted) return;
      await widget.cart.load();
      if (!mounted) return;
    }
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CheckoutScreen(
        api: widget.api,
        cart: widget.cart,
        auth: widget.auth,
      ),
    ));
    if (mounted) await widget.cart.load();
  }

  @override
  Widget build(BuildContext context) {
    final cart = widget.cart.cart;
    return Scaffold(
      appBar: AppBar(title: const Text('Your basket')),
      body: Column(
        children: [
          const CheckoutStepper(step: 0),
          Expanded(
            child: cart == null
                ? const Center(child: CircularProgressIndicator())
                : cart.isEmpty && cart.saved.isEmpty
                    ? _empty()
                    : _body(cart),
          ),
        ],
      ),
      bottomNavigationBar: cart == null || cart.isEmpty ? null : _stickyCta(cart),
    );
  }

  Widget _empty() => Padding(
        padding: const EdgeInsets.all(24),
        child: UkoEmpty(
          icon: Icons.shopping_cart_outlined,
          title: 'Your basket is empty',
          subtitle: 'Items you add are held on their shelves for '
              '${widget.cart.cart?.holdHours ?? Config.cartHoldHours} hours while you decide.',
          action: AsyncButton(
            label: 'Start shopping',
            onPressed: () async {
              Navigator.pop(context);
              widget.onBrowse();
            },
          ),
        ),
      );

  Widget _body(Cart cart) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          // What the server changed under him, in the server's own words.
          if (cart.notices.isNotEmpty) ...[
            for (final n in cart.notices) ...[
              UkoNotice(n, tone: UkoTone.warning, icon: Icons.inventory_2_outlined),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 4),
          ],

          if (widget.cart.error.isNotEmpty) ...[
            UkoNotice(widget.cart.error, tone: UkoTone.danger),
            const SizedBox(height: 14),
          ],

          Row(
            children: [
              Text('${cart.count} ${plural(cart.count, 'item')}',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800, color: UkoColors.ink)),
              const Spacer(),
              if (cart.shelves > 0)
                Text(
                  cart.multiShelf
                      ? 'across ${cart.shelves} shelves'
                      : 'at ${cart.shelves} shelf',
                  style: const TextStyle(fontSize: 11.5, color: UkoColors.muted),
                ),
            ],
          ),
          if (cart.multiShelf) ...[
            const SizedBox(height: 10),
            UkoNotice(
              'Your items are on ${cart.shelves} different shelves. On the next screen you can have '
              'one rider collect the lot in a single run, rather than visiting each shelf yourself.',
              tone: UkoTone.primary,
              icon: Icons.route_outlined,
            ),
          ],
          const SizedBox(height: 12),

          for (final line in cart.active) _line(line, saved: false),

          const SizedBox(height: 6),
          _promoRow(cart),
          const SizedBox(height: 14),
          _summary(cart),

          if (cart.saved.isNotEmpty) ...[
            const SizedBox(height: 22),
            const Text('Saved for later',
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800, color: UkoColors.ink)),
            const SizedBox(height: 10),
            for (final line in cart.saved) _line(line, saved: true),
          ],
        ],
      );

  Widget _line(CartLine line, {required bool saved}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: UkoPanel(
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () => widget.onOpenItem(line.item),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(UkoRadius.sm),
                      child: Container(
                        height: 66,
                        width: 66,
                        color: UkoColors.surface2,
                        child: line.item.image.isEmpty
                            ? const Icon(Icons.image_outlined, color: UkoColors.muted, size: 20)
                            : Image.network(line.item.image,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(Icons.image_outlined,
                                    color: UkoColors.muted, size: 20)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(line.item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13, height: 1.35, fontWeight: FontWeight.w600,
                                color: UkoColors.ink)),
                        if (line.variantLabel.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(line.variantLabel,
                              style: const TextStyle(fontSize: 11, color: UkoColors.ink2)),
                        ],
                        const SizedBox(height: 3),
                        Text(
                          line.item.shelveName.isEmpty
                              ? line.item.ward
                              : line.item.shelveName,
                          style: const TextStyle(fontSize: 10.5, color: UkoColors.muted),
                        ),
                        const SizedBox(height: 6),
                        Text(ksh(line.lineTotal),
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w800,
                                color: UkoColors.ink)),
                      ],
                    ),
                  ),
                ],
              ),
              if (line.lowStock && !saved) ...[
                const SizedBox(height: 8),
                UkoNotice('Only ${line.available} left at this shelf',
                    tone: UkoTone.warning, icon: Icons.warning_amber_rounded),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  if (!saved) ...[
                    _qty(line),
                    const Spacer(),
                    TextButton(
                      onPressed: () => widget.cart.saveForLater(line.id, true),
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                      child: const Text('Save for later',
                          style: TextStyle(fontSize: 11.5)),
                    ),
                  ] else ...[
                    TextButton(
                      onPressed: () => widget.cart.saveForLater(line.id, false),
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                      child: const Text('Move to basket',
                          style: TextStyle(fontSize: 11.5)),
                    ),
                    const Spacer(),
                  ],
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    tooltip: 'Remove',
                    onPressed: () => widget.cart.remove(line.id),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _qty(CartLine line) => Container(
        height: 34,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(UkoRadius.sm),
          border: Border.all(color: UkoColors.border),
        ),
        child: Row(
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32),
              icon: const Icon(Icons.remove, size: 15),
              // Down to zero removes the line — the API's own convention.
              onPressed: () => widget.cart.setQuantity(line.id, line.quantity - 1),
            ),
            Text('${line.quantity}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32),
              icon: const Icon(Icons.add, size: 15),
              onPressed: line.quantity < line.available
                  ? () => widget.cart.setQuantity(line.id, line.quantity + 1)
                  : null,
            ),
          ],
        ),
      );

  Widget _promoRow(Cart cart) => Row(
        children: [
          Expanded(
            child: TextField(
              controller: _promo,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: cart.promoCode.isEmpty ? 'Promo code' : cart.promoCode,
                isDense: true,
                prefixIcon: const Icon(Icons.local_offer_outlined, size: 18),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 96,
            child: AsyncButton(
              label: cart.promoCode.isEmpty ? 'Apply' : 'Change',
              outlined: true,
              onPressed: () async {
                final code = _promo.text.trim();
                if (code.isEmpty) return;
                await widget.cart.applyPromo(code);
                if (mounted && widget.cart.error.isNotEmpty) {
                  showUkoMessage(context, widget.cart.error, error: true);
                }
              },
            ),
          ),
        ],
      );

  Widget _summary(Cart cart) => UkoPanel(
        title: 'Summary',
        child: Column(
          children: [
            UkoKeyValue('Items (${cart.count})', ksh(cart.subtotal)),
            if (cart.discount > 0) ...[
              const Divider(height: 16),
              UkoKeyValue('Promo ${cart.promoCode}', '−${ksh(cart.discount)}'),
            ],
            if (cart.protectFee > 0) ...[
              const Divider(height: 16),
              UkoKeyValue('UKO protection', ksh(cart.protectFee)),
            ],
            const Divider(height: 16),
            // Deliberately not a total: what it costs to receive is chosen on the next screen, and
            // showing a "total" here that then grows is the classic checkout betrayal.
            UkoKeyValue('Before delivery', ksh(cart.total), strong: true),
            const SizedBox(height: 8),
            const Text(
              'What it costs to receive depends on how you want it — chosen next.',
              style: TextStyle(fontSize: 11, color: UkoColors.muted, height: 1.45),
            ),
          ],
        ),
      );

  Widget _stickyCta(Cart cart) => SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: const BoxDecoration(
            color: UkoColors.bg,
            border: Border(top: BorderSide(color: UkoColors.border)),
          ),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Before delivery',
                      style: TextStyle(fontSize: 10.5, color: UkoColors.muted)),
                  Text(ksh(cart.total),
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800, color: UkoColors.ink)),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: AsyncButton(
                  label: 'Continue',
                  icon: Icons.arrow_forward,
                  onPressed: _continue,
                ),
              ),
            ],
          ),
        ),
      );
}
