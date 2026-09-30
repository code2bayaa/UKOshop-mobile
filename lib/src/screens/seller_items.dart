/// A seller's own ads, and what is happening to them.
///
/// The one thing this list has to make obvious is **which ads are actually earning**. An ad that is
/// not on a shelf cannot be bought through UKO at all — it is only a listing — so it is flagged rather
/// than left looking the same as a live one.
library;

import 'package:flutter/material.dart';
import 'package:uko_core/uko_core.dart';

import '../api.dart';
import '../models.dart';

class SellerItemsScreen extends StatefulWidget {
  const SellerItemsScreen({super.key, required this.api});

  final ShopApi api;

  @override
  State<SellerItemsScreen> createState() => _SellerItemsScreenState();
}

class _SellerItemsScreenState extends State<SellerItemsScreen> {
  List<ItemCard>? _items;
  List<Order>? _orders;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await widget.api.sellerItems();
      if (mounted) setState(() => _items = items);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
    try {
      final orders = await widget.api.sellerOrders();
      if (mounted) setState(() => _orders = orders);
    } on ApiException {
      if (mounted) setState(() => _orders = const []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      appBar: AppBar(title: const Text('My ads')),
      body: items == null
          ? Center(
              child: _error.isEmpty
                  ? const CircularProgressIndicator()
                  : Padding(
                      padding: const EdgeInsets.all(24),
                      child: UkoEmpty(
                        icon: Icons.error_outline,
                        title: 'Could not load your ads',
                        subtitle: _error,
                        action: AsyncButton(label: 'Try again', onPressed: _load),
                      ),
                    ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                children: [
                  if (_orders != null && _orders!.isNotEmpty) ...[
                    UkoPanel(
                      title: 'Sold',
                      subtitle: '${_orders!.length} ${plural(_orders!.length, 'order')} through UKO',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final o in _orders!.take(5))
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(o.orderNo,
                                        style: const TextStyle(
                                            fontSize: 12.5, color: UkoColors.ink)),
                                  ),
                                  StatusPill(o.status),
                                  const SizedBox(width: 8),
                                  Text(ksh(o.subtotal),
                                      style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: UkoColors.ink)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (items.isEmpty)
                    const UkoPanel(
                      padded: false,
                      child: UkoEmpty(
                        icon: Icons.sell_outlined,
                        title: 'No ads yet',
                        subtitle: 'Post one from the Post ad tab.',
                      ),
                    )
                  else
                    for (final i in items) _row(i),
                ],
              ),
            ),
    );
  }

  Widget _row(ItemCard i) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: UkoPanel(
          borderColor: i.isVerified ? UkoColors.border : UkoColors.warning,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(UkoRadius.sm),
                child: Container(
                  height: 54,
                  width: 54,
                  color: UkoColors.surface2,
                  child: i.image.isEmpty
                      ? const Icon(Icons.image_outlined, size: 18, color: UkoColors.muted)
                      : Image.network(i.image,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.image_outlined,
                              size: 18, color: UkoColors.muted)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(i.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700, color: UkoColors.ink)),
                    const SizedBox(height: 4),
                    Text(
                      [
                        i.price,
                        '${i.stock} left',
                        if (i.soldCount > 0) '${i.soldCount} sold',
                      ].where((s) => s.isNotEmpty).join(' · '),
                      style: const TextStyle(fontSize: 11, color: UkoColors.ink2),
                    ),
                    const SizedBox(height: 6),
                    if (i.isVerified)
                      UkoChip('On ${i.shelveName.isEmpty ? 'a shelf' : i.shelveName}',
                          tone: UkoTone.success)
                    else
                      const UkoChip('Not on a shelf — cannot be bought',
                          tone: UkoTone.warning),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
