/// Orders, and M8 · Delivery Tracking.
///
/// **The code is the hero of this screen.** Everything else a buyer can look up again; the four digits
/// he reads out at a shelf counter or to a rider at his gate are the one thing he needs in his hand at
/// the moment he needs it. So an order that is ready shows its code large, with a sentence saying who
/// to say it to — and which code that is depends on how he is receiving it.
///
/// This is the same rule as everywhere in UKO, seen from the other side: whoever is letting go of the
/// goods types in what the person taking them says. Here the buyer is the one taking them, so for once
/// the code is his to give.
library;

import 'package:flutter/material.dart';
import 'package:uko_core/uko_core.dart';

import '../api.dart';
import '../auth.dart';
import '../models.dart';

class OrdersTab extends StatefulWidget {
  const OrdersTab({
    super.key,
    required this.api,
    required this.auth,
    required this.onRequireSignIn,
  });

  final ShopApi api;
  final ShopAuth auth;
  final Future<bool> Function() onRequireSignIn;

  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab> {
  List<Order>? _orders;
  String _error = '';

  @override
  void initState() {
    super.initState();
    if (widget.auth.signedIn) _load();
  }

  @override
  void didUpdateWidget(OrdersTab old) {
    super.didUpdateWidget(old);
    if (widget.auth.signedIn && _orders == null) _load();
  }

  Future<void> _load() async {
    try {
      final orders = await widget.api.orders();
      if (mounted) {
        setState(() {
          _orders = orders;
          _error = '';
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.auth.signedIn) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: UkoEmpty(
          icon: Icons.receipt_long_outlined,
          title: 'Your orders live here',
          subtitle: 'Sign in to see what you have bought, follow a rider, and find your collection '
              'codes.',
          action: AsyncButton(
            label: 'Sign in',
            onPressed: () async {
              if (await widget.onRequireSignIn()) await _load();
            },
          ),
        ),
      );
    }
    final orders = _orders;
    if (orders == null) {
      return Center(
        child: _error.isEmpty
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.all(24),
                child: UkoEmpty(
                  icon: Icons.wifi_off,
                  title: 'Could not load your orders',
                  subtitle: _error,
                  action: AsyncButton(label: 'Try again', onPressed: _load),
                ),
              ),
      );
    }
    if (orders.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: UkoEmpty(
          icon: Icons.receipt_long_outlined,
          title: 'No orders yet',
          subtitle: 'When you buy something it appears here, with the code you read out to collect '
              'it.',
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          for (final o in orders) _card(o),
        ],
      ),
    );
  }

  Widget _card(Order o) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: UkoPanel(
          borderColor: o.readyToCollect || o.onTheWay ? UkoColors.primary300 : UkoColors.border,
          child: InkWell(
            onTap: () async {
              await Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => TrackingScreen(api: widget.api, orderId: o.id),
              ));
              await _load();
            },
            borderRadius: BorderRadius.circular(UkoRadius.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    StatusPill(o.status),
                    const SizedBox(width: 6),
                    if (o.unpaid) const UkoChip('Not paid', tone: UkoTone.danger),
                    const Spacer(),
                    Text(ksh(o.total),
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w800, color: UkoColors.ink)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(o.orderNo,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800, color: UkoColors.ink)),
                const SizedBox(height: 3),
                Text(
                  [
                    '${o.itemCount} ${plural(o.itemCount, 'item')}',
                    o.where,
                    if (o.createdAt != null) fmtDate(o.createdAt),
                  ].join(' · '),
                  style: const TextStyle(fontSize: 11.5, height: 1.4, color: UkoColors.ink2),
                ),
                // The one thing he actually needs, when he needs it.
                if ((o.readyToCollect || o.onTheWay) && o.codeToGive.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _code(o),
                ],
              ],
            ),
          ),
        ),
      );

  Widget _code(Order o) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: UkoColors.secondary050,
          borderRadius: BorderRadius.circular(UkoRadius.md),
          border: Border.all(color: UkoColors.secondary),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              o.codeToGive.split('').join('  '),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
                color: UkoColors.secondary600,
              ),
            ),
            const SizedBox(height: 4),
            Text(o.codeLabel,
                style: const TextStyle(
                    fontSize: 11.5, height: 1.4, color: UkoColors.ink2)),
          ],
        ),
      );
}

/// M8 · Delivery Tracking — the status header, the rider, and the timeline.
class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key, required this.api, required this.orderId});

  final ShopApi api;
  final int orderId;

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  Order? _order;
  OrderTracking? _tracking;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await widget.api.tracking(widget.orderId);
      if (mounted) {
        setState(() {
          _order = r.order;
          _tracking = r.tracking;
          _error = '';
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = _order;
    final t = _tracking;
    return Scaffold(
      appBar: AppBar(title: Text(o?.orderNo ?? 'Order')),
      body: o == null
          ? Center(
              child: _error.isEmpty
                  ? const CircularProgressIndicator()
                  : Padding(
                      padding: const EdgeInsets.all(24),
                      child: UkoEmpty(
                          icon: Icons.error_outline,
                          title: 'Could not load',
                          subtitle: _error),
                    ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                children: [
                  Row(
                    children: [
                      StatusPill(o.status),
                      const Spacer(),
                      Text(ksh(o.total),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800,
                              color: UkoColors.primary)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(o.where,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800, color: UkoColors.ink)),
                  if (t != null && t.eta.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(t.eta,
                        style: const TextStyle(fontSize: 12.5, color: UkoColors.ink2)),
                  ],
                  const SizedBox(height: 16),

                  if (o.codeToGive.isNotEmpty) ...[
                    UkoPanel(
                      title: 'Your code',
                      subtitle: o.codeLabel,
                      borderColor: UkoColors.secondary,
                      child: Text(
                        o.codeToGive.split('').join('  '),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 3,
                          color: UkoColors.secondary600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  if (t != null && t.hasRider) ...[
                    UkoPanel(
                      title: 'Your rider',
                      child: Column(
                        children: [
                          UkoKeyValue('Name', t.riderName),
                          if (t.numberPlate.isNotEmpty) ...[
                            const Divider(height: 16),
                            UkoKeyValue('Number plate', t.numberPlate),
                          ],
                          if (t.vehicle.isNotEmpty) ...[
                            const Divider(height: 16),
                            UkoKeyValue('Vehicle', vehicleName(t.vehicle)),
                          ],
                          if (t.distanceKm > 0) ...[
                            const Divider(height: 16),
                            UkoKeyValue('Distance', km(t.distanceKm)),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  if (t != null && t.events.isNotEmpty) ...[
                    UkoPanel(
                      title: 'What has happened',
                      child: JobTimeline(events: t.events),
                    ),
                    const SizedBox(height: 14),
                  ],

                  UkoPanel(
                    title: 'What you ordered',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final line in o.items)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Text(line.line,
                                style: const TextStyle(fontSize: 13, color: UkoColors.ink)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  UkoPanel(
                    title: 'What you paid',
                    child: Column(
                      children: [
                        UkoKeyValue('Items', ksh(o.subtotal)),
                        if (o.deliveryFee > 0) ...[
                          const Divider(height: 16),
                          UkoKeyValue('Delivery', ksh(o.deliveryFee)),
                        ],
                        if (o.discount > 0) ...[
                          const Divider(height: 16),
                          UkoKeyValue('Promo', '−${ksh(o.discount)}'),
                        ],
                        const Divider(height: 16),
                        UkoKeyValue('Total', ksh(o.total), strong: true),
                      ],
                    ),
                  ),

                  if (o.unpaid) ...[
                    const SizedBox(height: 14),
                    const UkoNotice(
                      'This order has not been paid. Your items are held for a short time only.',
                      tone: UkoTone.danger,
                      icon: Icons.schedule,
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
