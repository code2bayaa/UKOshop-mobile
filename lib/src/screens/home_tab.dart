/// M1 · Home.
///
/// The wireframe's running order, kept: category strip → hero → trust strip → trending → shelves near
/// you → the earn-with-UKO banner. What is dropped is the desktop footer, which on a phone is four
/// screens of links below the fold that nobody scrolls to.
///
/// The hero and the trust strip are doing the real work here. A first-time visitor has no idea what
/// UKO is, and "drop your item at a shelf in your ward, we verify it, the buyer's money is held until
/// he has it" is the entire product in one sentence. It stays above the fold.
library;

import 'package:flutter/material.dart';
import 'package:uko_core/uko_core.dart';

import '../api.dart';
import '../auth.dart';
import '../models.dart';
import 'widgets/item_card.dart';
import 'widgets/shelf_card.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({
    super.key,
    required this.api,
    required this.auth,
    required this.onOpenItem,
    required this.onBrowse,
  });

  final ShopApi api;
  final ShopAuth auth;
  final void Function(ItemCard) onOpenItem;
  final void Function({String category, String query}) onBrowse;

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  Home? _home;
  List<Category> _categories = const [];
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final ward = widget.auth.me?.ward ?? '';
      final results = await Future.wait([
        widget.api.home(ward: ward),
        widget.api.categories(),
      ]);
      if (!mounted) return;
      setState(() {
        _home = results[0] as Home;
        _categories = results[1] as List<Category>;
        _error = '';
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final home = _home;
    if (home == null) {
      return Center(
        child: _error.isEmpty
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.all(24),
                child: UkoEmpty(
                  icon: Icons.wifi_off,
                  title: 'Could not reach UKO',
                  subtitle: _error,
                  action: AsyncButton(label: 'Try again', onPressed: _load),
                ),
              ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          if (_categories.isNotEmpty) _categoryStrip(),
          _hero(home),
          const _TrustStrip(),
          const SizedBox(height: 18),
          if (home.trending.isNotEmpty)
            _section(
              title: 'Trending near you',
              onMore: () => widget.onBrowse(),
              child: ProductGrid(items: home.trending.take(6).toList(), onOpen: widget.onOpenItem),
            ),
          if (home.deals.isNotEmpty)
            _section(
              title: 'Deals in ${home.dealsWard}',
              onMore: () => widget.onBrowse(),
              child: ProductGrid(items: home.deals.take(4).toList(), onOpen: widget.onOpenItem),
            ),
          if (home.shelves.isNotEmpty)
            _section(
              title: 'Shelves near you',
              onMore: null,
              child: Column(
                children: [
                  for (final s in home.shelves)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ShelfCard(
                        shelf: s,
                        onBrowse: () => widget.onBrowse(),
                      ),
                    ),
                ],
              ),
            ),
          _earnBanner(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- pieces
  Widget _categoryStrip() => SizedBox(
        height: 92,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          itemCount: _categories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, i) {
            final c = _categories[i];
            return InkWell(
              onTap: () => widget.onBrowse(category: c.slug),
              borderRadius: BorderRadius.circular(UkoRadius.md),
              child: SizedBox(
                width: 62,
                child: Column(
                  children: [
                    Container(
                      height: 42,
                      width: 42,
                      decoration: BoxDecoration(
                        color: UkoColors.primary050,
                        borderRadius: BorderRadius.circular(UkoRadius.md),
                      ),
                      child: Icon(_categoryIcon(c.name), size: 20, color: UkoColors.primary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      c.name,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 10, height: 1.25, color: UkoColors.ink2),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );

  /// The wireframe draws a placeholder box per category; a recognisable glyph is more use than a grey
  /// square, and an unknown category still gets a sensible default.
  static IconData _categoryIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('electron') || n.contains('phone')) return Icons.devices_other;
    if (n.contains('fashion') || n.contains('cloth')) return Icons.checkroom;
    if (n.contains('home') || n.contains('furni')) return Icons.chair_outlined;
    if (n.contains('baby') || n.contains('kid')) return Icons.child_friendly_outlined;
    if (n.contains('sport') || n.contains('fit')) return Icons.sports_soccer_outlined;
    if (n.contains('beauty') || n.contains('health')) return Icons.spa_outlined;
    if (n.contains('car') || n.contains('auto')) return Icons.directions_car_outlined;
    if (n.contains('book')) return Icons.menu_book_outlined;
    return Icons.category_outlined;
  }

  Widget _hero(Home home) => Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: UkoColors.primary,
          borderRadius: BorderRadius.circular(UkoRadius.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${home.wardsLive} wards live',
                style: const TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Sell without a shop.\nBuy without the risk.',
              style: TextStyle(
                  fontSize: 22, height: 1.25, fontWeight: FontWeight.w800, color: Colors.white),
            ),
            const SizedBox(height: 8),
            const Text(
              'Drop your item at the shelf in your ward. We verify it, hold the buyer\'s money until '
              'he has it, and bring it to his door.',
              style: TextStyle(fontSize: 12.5, height: 1.5, color: Colors.white70),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () => widget.onBrowse(),
                    style: FilledButton.styleFrom(
                      backgroundColor: UkoColors.secondary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Start shopping'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => widget.onBrowse(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                    ),
                    child: const Text('Find a shelf'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              '${home.itemsOnShelves} items verified on shelves right now',
              style: const TextStyle(fontSize: 11, color: Colors.white60),
            ),
          ],
        ),
      );

  Widget _section({required String title, required Widget child, VoidCallback? onMore}) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800, color: UkoColors.ink)),
                ),
                if (onMore != null)
                  TextButton(
                    onPressed: onMore,
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    child: const Text('More items →', style: TextStyle(fontSize: 12.5)),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      );

  Widget _earnBanner() => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: UkoColors.surface,
          borderRadius: BorderRadius.circular(UkoRadius.lg),
          border: Border.all(color: UkoColors.border),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Own a shop or a bike? Earn with UKO.',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800, color: UkoColors.ink, height: 1.3)),
            SizedBox(height: 6),
            Text(
              'Host a shelf in your ward, or join the delivery team. UKO partners have their own apps.',
              style: TextStyle(fontSize: 12, height: 1.5, color: UkoColors.ink2),
            ),
          ],
        ),
      );
}

/// The wireframe's trust strip: the three promises, in three words each.
class _TrustStrip extends StatelessWidget {
  const _TrustStrip();

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: UkoColors.surface,
          borderRadius: BorderRadius.circular(UkoRadius.md),
        ),
        child: const Row(
          children: [
            _Promise(icon: Icons.verified_outlined, label: 'Verified items'),
            _Promise(icon: Icons.pedal_bike_outlined, label: 'Ward delivery'),
            _Promise(icon: Icons.lock_outline, label: 'Escrow pay'),
          ],
        ),
      );
}

class _Promise extends StatelessWidget {
  const _Promise({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Icon(icon, size: 17, color: UkoColors.primary),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(
                    fontSize: 10.5, fontWeight: FontWeight.w600, color: UkoColors.ink2)),
          ],
        ),
      );
}
