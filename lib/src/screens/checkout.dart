/// M5 · Shelf & Delivery, then M6 · Payment.
///
/// Two wireframe screens, one screen here with two steps, because on a phone they are one decision
/// followed by its consequence and a back-and-forth between them is worse than a scroll.
///
/// **What makes UKO checkout unlike any other is that a basket is not in one place.** The items sit on
/// real shelves in real wards, possibly several, possibly in another county. So the buyer is not
/// choosing "standard or express"; he is choosing whether to walk round the shelves himself, have one
/// rider collect the lot in a single run to a shelf near him, or have that run come to his door. Every
/// one of those is priced per basket by the server (`app/consolidate.py`) — the app never computes a
/// delivery price, it asks.
///
/// **The courier line is shown separately and is not optional.** An item on a shelf in Mombasa cannot
/// reach a Nairobi buyer at all until a van brings it across, so that cost is already inside every
/// option's fee. Presenting it as a line rather than letting it inflate the options is the difference
/// between an explained price and an unexplained one.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uko_core/uko_core.dart';

import '../api.dart';
import '../auth.dart';
import '../cart_controller.dart';
import '../models.dart';
import 'order_done.dart';
import 'widgets/chrome.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({
    super.key,
    required this.api,
    required this.cart,
    required this.auth,
  });

  final ShopApi api;
  final CartController cart;
  final ShopAuth auth;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  int _step = 1; // 1 = shelf & delivery (M5), 2 = payment (M6)

  CheckoutOptions? _options;
  String _error = '';
  bool _loading = true;

  DeliveryOption? _chosen;
  Shelf? _collectAt;

  final _recipient = TextEditingController();
  final _phone = TextEditingController();
  final _estate = TextEditingController();
  final _house = TextEditingController();
  final _notes = TextEditingController();
  final _mpesaPhone = TextEditingController();

  String _method = 'mpesa';
  Order? _placed;
  bool _placing = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    final me = widget.auth.me;
    _recipient.text = me?.name ?? '';
    _phone.text = me?.phone ?? '';
    _mpesaPhone.text = me?.phone ?? '';
    _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    for (final c in [_recipient, _phone, _estate, _house, _notes, _mpesaPhone]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final o = await widget.api.checkoutOptions(
        ward: widget.auth.me?.ward ?? '',
        destShelveId: _collectAt?.id,
      );
      if (!mounted) return;
      setState(() {
        _options = o;
        _collectAt ??= o.collectAt;
        // Pre-select the first option he can actually have, rather than making him find it.
        _chosen ??= o.options.where((x) => x.available).firstOrNull;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    }
  }

  bool get _canContinue {
    final chosen = _chosen;
    if (chosen == null) return false;
    if (!chosen.toDoor) return true;
    // A run to his door needs somewhere to go — the API refuses without these three.
    return _recipient.text.trim().isNotEmpty &&
        _phone.text.trim().isNotEmpty &&
        _estate.text.trim().isNotEmpty;
  }

  double get _deliveryFee => _chosen?.fee ?? 0;
  double get _total => (widget.cart.cart?.total ?? 0) + _deliveryFee;

  Future<void> _place() async {
    final chosen = _chosen;
    if (chosen == null) return;
    setState(() {
      _placing = true;
      _error = '';
    });
    try {
      final order = await widget.api.placeOrder(
        deliveryOption: chosen.key,
        destShelveId: _collectAt?.id,
        recipientName: _recipient.text.trim(),
        phone: _phone.text.trim(),
        estate: _estate.text.trim(),
        house: _house.text.trim(),
        ward: widget.auth.me?.ward ?? '',
        county: widget.auth.me?.county ?? '',
        notes: _notes.text.trim(),
        promoCode: widget.cart.promo,
      );
      if (!mounted) return;
      setState(() {
        _placed = order;
        _step = 2;
        _placing = false;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _placing = false;
        });
      }
    }
  }

  Future<void> _pay() async {
    final order = _placed;
    if (order == null) return;
    setState(() {
      _placing = true;
      _error = '';
    });
    try {
      await widget.api.pay(order.id, method: _method, phone: _mpesaPhone.text.trim());
      if (!mounted) return;
      setState(() => _placing = false);
      // M-PESA is a push to his phone: the API answers at once and the money arrives later, so the
      // screen watches rather than claiming success.
      _watchPayment(order.id);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _placing = false;
        });
      }
    }
  }

  void _watchPayment(int orderId) {
    _poll?.cancel();
    var ticks = 0;
    _poll = Timer.periodic(const Duration(seconds: 4), (t) async {
      ticks++;
      try {
        final body = await widget.api.paymentStatus(orderId);
        final status = asText(body['payment_status'] ?? asMap(body['order'])['payment_status']);
        if (status == 'paid' || status == 'released') {
          t.cancel();
          if (!mounted) return;
          await widget.cart.load();
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) => OrderDoneScreen(api: widget.api, orderId: orderId)),
          );
        }
      } on ApiException {
        // Keep watching; a dropped poll is not a failed payment.
      }
      // Two minutes is longer than a Daraja push survives. After that it is his to retry.
      if (ticks > 30) {
        t.cancel();
        if (mounted) {
          setState(() => _error =
              'M-PESA has not confirmed yet. If you completed the prompt it may still land — '
              'check your orders in a minute, or try again.');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(_step == 1 ? 'How do you want it?' : 'Pay')),
        body: Column(
          children: [
            CheckoutStepper(step: _step),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _step == 1
                      ? _shelfStep()
                      : _payStep(),
            ),
          ],
        ),
        bottomNavigationBar: _loading ? null : _cta(),
      );

  // ---------------------------------------------------------------- M5
  Widget _shelfStep() {
    final o = _options;
    if (o == null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: UkoEmpty(
          icon: Icons.error_outline,
          title: 'Could not price your delivery',
          subtitle: _error,
          action: AsyncButton(label: 'Try again', onPressed: _load),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        if (o.shelves.isNotEmpty) ...[
          UkoPanel(
            title: o.shelves.length == 1
                ? 'Your items are at one shelf'
                : 'Your items are on ${o.shelves.length} shelves',
            subtitle: 'This is what decides your options below.',
            child: Column(
              children: [
                for (final s in o.shelves) ...[
                  Row(
                    children: [
                      const Icon(Icons.storefront_outlined, size: 15, color: UkoColors.muted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(s.name,
                            style: const TextStyle(fontSize: 12.5, color: UkoColors.ink)),
                      ),
                      Text('${s.cartItems} ${plural(s.cartItems, 'item')}',
                          style: const TextStyle(fontSize: 11, color: UkoColors.muted)),
                      if (s.distanceKm != null) ...[
                        const SizedBox(width: 8),
                        Text(km(s.distanceKm),
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w700,
                                color: UkoColors.primary)),
                      ],
                    ],
                  ),
                  if (s != o.shelves.last) const Divider(height: 16),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // The inter-city legs the basket could not avoid.
        if (o.hasCourier) ...[
          UkoNotice(
            'Part of your basket is in another county, so a van has to bring it across first — '
            '${ksh(o.courierFee)} for ${plural(o.courierLegs, 'leg')}. It is already included in '
            'every price below.',
            tone: UkoTone.primary,
            title: 'Inter-city leg',
            icon: Icons.local_shipping_outlined,
          ),
          const SizedBox(height: 14),
        ],

        const Text('How do you want to receive it?',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: UkoColors.ink)),
        const SizedBox(height: 10),
        for (final option in o.options) _optionTile(option),

        if (_chosen?.toDoor == true) ...[
          const SizedBox(height: 14),
          UkoPanel(
            title: 'Where to bring it',
            subtitle: 'The rider needs a gate he can find and a number he can ring.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _recipient,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Who is receiving it'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _estate,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                      labelText: 'Estate or building', hintText: 'Riverside Court'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _house,
                  decoration: const InputDecoration(
                      labelText: 'House or door (optional)', hintText: 'Block B, B12'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notes,
                  minLines: 2,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Directions for the rider (optional)',
                    hintText: 'Gate 3, call on arrival',
                  ),
                ),
              ],
            ),
          ),
        ],

        if (_chosen?.key == 'shelf_run' && o.collectAt != null) ...[
          const SizedBox(height: 14),
          UkoPanel(
            title: 'Collect at',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(o.collectAt!.name,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700, color: UkoColors.ink)),
                if (o.collectAt!.where.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(o.collectAt!.where,
                      style: const TextStyle(
                          fontSize: 11.5, height: 1.4, color: UkoColors.ink2)),
                ],
                if (o.collectAt!.hours.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('Open ${o.collectAt!.hours}',
                      style: const TextStyle(fontSize: 11, color: UkoColors.muted)),
                ],
              ],
            ),
          ),
        ],

        if (_error.isNotEmpty) ...[
          const SizedBox(height: 14),
          UkoNotice(_error, tone: UkoTone.danger),
        ],
      ],
    );
  }

  Widget _optionTile(DeliveryOption option) {
    final selected = _chosen?.key == option.key;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: option.available ? () => setState(() => _chosen = option) : null,
        borderRadius: BorderRadius.circular(UkoRadius.md),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? UkoColors.primary050 : UkoColors.bg,
            borderRadius: BorderRadius.circular(UkoRadius.md),
            border: Border.all(
              color: selected ? UkoColors.primary : UkoColors.border,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                size: 18,
                color: option.available
                    ? (selected ? UkoColors.primary : UkoColors.borderStrong)
                    : UkoColors.border,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(option.title,
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: option.available ? UkoColors.ink : UkoColors.muted)),
                    const SizedBox(height: 3),
                    Text(option.sub,
                        style: const TextStyle(
                            fontSize: 11.5, height: 1.45, color: UkoColors.ink2)),
                    if (!option.available && option.reason.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(option.reason,
                          style: const TextStyle(
                              fontSize: 11, height: 1.4, color: UkoColors.danger)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                option.fee <= 0 ? 'Free' : ksh(option.fee),
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: option.fee <= 0 ? UkoColors.success : UkoColors.ink),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- M6
  Widget _payStep() {
    final order = _placed;
    if (order == null) return const SizedBox.shrink();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        UkoNotice(
          'Order ${order.orderNo} is placed and your items are held. It is not paid yet.',
          tone: UkoTone.primary,
          title: 'Almost there',
          icon: Icons.lock_clock_outlined,
        ),
        const SizedBox(height: 14),
        UkoPanel(
          title: 'How to pay',
          child: Column(
            children: [
              RadioGroup<String>(
                groupValue: _method,
                onChanged: (v) => setState(() => _method = v ?? 'mpesa'),
                child: const Column(
                  children: [
                    RadioListTile<String>(
                      value: 'mpesa',
                      contentPadding: EdgeInsets.zero,
                      title: Text('M-PESA',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        'A prompt comes to your phone. Approve it with your PIN.',
                        style: TextStyle(fontSize: 11.5, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              if (_method == 'mpesa') ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _mpesaPhone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'M-PESA number',
                    hintText: '07xx xxx xxx',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        UkoPanel(
          title: 'What you are paying for',
          child: Column(
            children: [
              UkoKeyValue('Items (${order.itemCount})', ksh(order.subtotal)),
              if (order.discount > 0) ...[
                const Divider(height: 16),
                UkoKeyValue('Promo', '−${ksh(order.discount)}'),
              ],
              if (order.shelveFee > 0) ...[
                const Divider(height: 16),
                UkoKeyValue('Shelf fee', ksh(order.shelveFee)),
              ],
              if (order.deliveryFee > 0) ...[
                const Divider(height: 16),
                UkoKeyValue('Delivery', ksh(order.deliveryFee)),
              ],
              if (order.protectFee > 0) ...[
                const Divider(height: 16),
                UkoKeyValue('UKO protection', ksh(order.protectFee)),
              ],
              const Divider(height: 16),
              UkoKeyValue('Total', ksh(order.total), strong: true),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const UkoNotice(
          'UKO holds your money until the item is in your hands. If it never arrives, or is not what '
          'was advertised, you get it back.',
          tone: UkoTone.success,
          icon: Icons.shield_outlined,
        ),
        if (_error.isNotEmpty) ...[
          const SizedBox(height: 14),
          UkoNotice(_error, tone: UkoTone.danger),
        ],
        if (_poll?.isActive == true) ...[
          const SizedBox(height: 14),
          const UkoNotice(
            'Waiting for M-PESA to confirm. Approve the prompt on your phone — this screen will move '
            'on by itself.',
            tone: UkoTone.warning,
            title: 'Check your phone',
            icon: Icons.hourglass_top,
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------- the bar
  Widget _cta() => SafeArea(
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
                  const Text('Total',
                      style: TextStyle(fontSize: 10.5, color: UkoColors.muted)),
                  Text(ksh(_step == 1 ? _total : (_placed?.total ?? _total)),
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800, color: UkoColors.ink)),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _step == 1
                    ? AsyncButton(
                        label: 'Place order',
                        icon: Icons.arrow_forward,
                        enabled: _canContinue && !_placing,
                        onPressed: _canContinue && !_placing ? _place : null,
                      )
                    : AsyncButton(
                        label: _poll?.isActive == true ? 'Waiting…' : 'Pay now',
                        icon: Icons.smartphone,
                        tone: UkoTone.secondary,
                        enabled: !_placing && _poll?.isActive != true,
                        onPressed:
                            !_placing && _poll?.isActive != true ? _pay : null,
                      ),
              ),
            ],
          ),
        ),
      );
}
