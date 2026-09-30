/// The shop's chrome, built to `docs/wireframe.pen` — this is the app those components were drawn
/// for.
///
/// `Mobile / Bottom Tabs` (S1yZLO) names the five destinations exactly: **Home · Categories · Post ad
/// · Orders · Account**, as 74×36 tabs with a 20px icon over a 10px label. `Mobile / Top Bar` (YRL15)
/// is a 52px bar — menu, logo, bell, cart — over a 52px search row. The measurements live in
/// `uko_core`; what is here is the shop's own arrangement of them.
///
/// The one departure from the wireframe: the top bar's hamburger is dropped. It opens a desktop-style
/// menu duplicating the tabs below it, and on a phone that is a button that leads nowhere new.
library;

import 'package:flutter/material.dart';
import 'package:uko_core/uko_core.dart';

enum ShopTab { home, categories, postAd, orders, account }

extension ShopTabChrome on ShopTab {
  String get label => switch (this) {
        ShopTab.home => 'Home',
        ShopTab.categories => 'Categories',
        ShopTab.postAd => 'Post ad',
        ShopTab.orders => 'Orders',
        ShopTab.account => 'Account',
      };

  IconData get icon => switch (this) {
        ShopTab.home => Icons.home_outlined,
        ShopTab.categories => Icons.grid_view_outlined,
        ShopTab.postAd => Icons.add_box_outlined,
        ShopTab.orders => Icons.receipt_long_outlined,
        ShopTab.account => Icons.person_outline,
      };
}

class ShopBottomTabs extends StatelessWidget {
  const ShopBottomTabs({
    super.key,
    required this.current,
    required this.onSelect,
    this.badges = const {},
  });

  final ShopTab current;
  final ValueChanged<ShopTab> onSelect;
  final Map<ShopTab, int> badges;

  @override
  Widget build(BuildContext context) => UkoBottomTabs(
        current: ShopTab.values.indexOf(current),
        onSelect: (i) => onSelect(ShopTab.values[i]),
        tabs: [
          for (final tab in ShopTab.values)
            UkoTab(label: tab.label, icon: tab.icon, badge: badges[tab] ?? 0),
        ],
      );
}

/// `Mobile / Top Bar`: the mark and wordmark, the bell, the cart with its count, and the search row
/// under them.
class ShopTopBar extends StatelessWidget implements PreferredSizeWidget {
  const ShopTopBar({
    super.key,
    required this.cartCount,
    required this.onCart,
    this.onSearch,
    this.searchHint = 'Search items, shelves, wards',
    this.showSearch = true,
  });

  final int cartCount;
  final VoidCallback onCart;
  final VoidCallback? onSearch;
  final String searchHint;
  final bool showSearch;

  @override
  Size get preferredSize => Size.fromHeight(showSearch ? 108 : 56);

  @override
  Widget build(BuildContext context) => AppBar(
        backgroundColor: UkoColors.bg,
        foregroundColor: UkoColors.ink,
        elevation: 0,
        titleSpacing: 16,
        toolbarHeight: 56,
        shape: showSearch ? null : const Border(bottom: BorderSide(color: UkoColors.border)),
        title: Row(
          children: [
            Container(
              height: 26,
              width: 26,
              decoration: BoxDecoration(
                color: UkoColors.primary,
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Icon(Icons.storefront, size: 15, color: Colors.white),
            ),
            const SizedBox(width: 10),
            const Text('UKO',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: UkoColors.ink)),
          ],
        ),
        actions: [
          const IconButton(
            icon: Icon(Icons.notifications_none, size: 21),
            onPressed: null,
            tooltip: 'Notifications',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: const Icon(Icons.shopping_cart_outlined, size: 21),
                  onPressed: onCart,
                  tooltip: 'Basket',
                ),
                if (cartCount > 0)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: UkoColors.secondary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text('$cartCount',
                          style: const TextStyle(
                              fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
                  ),
              ],
            ),
          ),
        ],
        bottom: showSearch
            ? PreferredSize(
                preferredSize: const Size.fromHeight(52),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  decoration: const BoxDecoration(
                    color: UkoColors.bg,
                    border: Border(bottom: BorderSide(color: UkoColors.border)),
                  ),
                  child: InkWell(
                    onTap: onSearch,
                    borderRadius: BorderRadius.circular(UkoRadius.md),
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: UkoColors.surface,
                        borderRadius: BorderRadius.circular(UkoRadius.md),
                        border: Border.all(color: UkoColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search, size: 18, color: UkoColors.muted),
                          const SizedBox(width: 8),
                          Text(searchHint,
                              style: const TextStyle(fontSize: 13, color: UkoColors.muted)),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            : null,
      );
}

/// The `Checkout Stepper` from the wireframe (TRmYy), which M4–M6 all carry: Cart → Shelf → Pay →
/// Done. Worth keeping on a phone precisely because the steps are not obvious — a buyer who does not
/// know a shelf choice is coming will abandon at it.
class CheckoutStepper extends StatelessWidget {
  const CheckoutStepper({super.key, required this.step});

  /// 0 Cart · 1 Shelf · 2 Pay · 3 Done
  final int step;

  static const _labels = ['Cart', 'Shelf', 'Pay', 'Done'];

  @override
  Widget build(BuildContext context) => Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: const BoxDecoration(
          color: UkoColors.bg,
          border: Border(bottom: BorderSide(color: UkoColors.border)),
        ),
        child: Row(
          children: [
            for (var i = 0; i < _labels.length; i++) ...[
              if (i > 0)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    color: i <= step ? UkoColors.primary : UkoColors.border,
                  ),
                ),
              _dot(i),
            ],
          ],
        ),
      );

  Widget _dot(int i) {
    final done = i < step;
    final here = i == step;
    final colour = done || here ? UkoColors.primary : UkoColors.muted;
    return Row(
      children: [
        Container(
          height: 18,
          width: 18,
          decoration: BoxDecoration(
            color: done ? UkoColors.primary : Colors.transparent,
            border: Border.all(color: colour, width: 1.6),
            shape: BoxShape.circle,
          ),
          child: done
              ? const Icon(Icons.check, size: 11, color: Colors.white)
              : Center(
                  child: Text('${i + 1}',
                      style: TextStyle(
                          fontSize: 9.5, fontWeight: FontWeight.w800, color: colour)),
                ),
        ),
        const SizedBox(width: 5),
        Text(_labels[i],
            style: TextStyle(
                fontSize: 11,
                fontWeight: here ? FontWeight.w800 : FontWeight.w600,
                color: colour)),
      ],
    );
  }
}
