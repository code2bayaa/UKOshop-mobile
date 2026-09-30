/// The Account tab: who he is, what he is selling, and the way out.
///
/// It doubles as the seller's front door. UKO has no separate "seller mode" — anyone with an account
/// can post an ad — so a shopper who has never sold sees an invitation, and one who has sees his items
/// and his orders. That is one tab doing two jobs, which beats a sixth tab that is empty for most
/// people.
library;

import 'package:flutter/material.dart';
import 'package:uko_core/uko_core.dart';

import '../api.dart';
import '../auth.dart';
import '../config.dart';
import '../models.dart';
import 'seller_items.dart';

class AccountTab extends StatefulWidget {
  const AccountTab({
    super.key,
    required this.auth,
    required this.api,
    required this.onRequireSignIn,
  });

  final ShopAuth auth;
  final ShopApi api;
  final Future<bool> Function() onRequireSignIn;

  @override
  State<AccountTab> createState() => _AccountTabState();
}

class _AccountTabState extends State<AccountTab> {
  List<ItemCard>? _items;

  @override
  void initState() {
    super.initState();
    if (widget.auth.signedIn) _loadItems();
  }

  Future<void> _loadItems() async {
    try {
      final items = await widget.api.sellerItems();
      if (mounted) setState(() => _items = items);
    } on ApiException {
      // Not being a seller is not an error — the panel below simply invites him to become one.
      if (mounted) setState(() => _items = const []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.auth.me;
    if (me == null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: UkoEmpty(
          icon: Icons.person_outline,
          title: 'Your UKO account',
          subtitle: 'Sign in to check out, follow your orders, and sell what you no longer need.',
          action: AsyncButton(
            label: 'Sign in or join',
            onPressed: () async {
              if (await widget.onRequireSignIn()) await _loadItems();
            },
          ),
        ),
      );
    }

    final items = _items;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        UkoPanel(
          child: Row(
            children: [
              Container(
                height: 46,
                width: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: UkoColors.primary050,
                  borderRadius: BorderRadius.circular(UkoRadius.md),
                ),
                child: Text(me.initials,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800, color: UkoColors.primary)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(me.displayName,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800, color: UkoColors.ink)),
                    const SizedBox(height: 2),
                    Text(me.email,
                        style: const TextStyle(fontSize: 12, color: UkoColors.ink2)),
                  ],
                ),
              ),
              if (me.emailVerified)
                const UkoChip('Verified', tone: UkoTone.success),
            ],
          ),
        ),
        const SizedBox(height: 14),
        UkoPanel(
          title: 'Your details',
          subtitle: Config.shopWebLabel.isEmpty
              ? 'Change these on the UKO website.'
              : 'Change these at ${Config.shopWebLabel}.',
          child: Column(
            children: [
              UkoKeyValue('Phone', me.phone.isEmpty ? '—' : me.phone),
              const Divider(height: 16),
              UkoKeyValue('Ward',
                  [me.ward, me.county].where((s) => s.isNotEmpty).join(', ')),
              if (me.itemsSold > 0) ...[
                const Divider(height: 16),
                UkoKeyValue('Items sold', '${me.itemsSold}'),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        // The seller front door.
        if (items == null)
          const UkoPanel(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
          )
        else if (items.isEmpty)
          UkoPanel(
            title: 'Sell on UKO',
            subtitle: 'You do not need a shop. Drop the item at a shelf in your ward and UKO does '
                'the rest.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'A host checks it against your advert, a buyer\'s money is held until he has it, '
                  'and UKO keeps ${Config.sellerCommissionPct}% of the sale.',
                  style: TextStyle(fontSize: 12, height: 1.55, color: UkoColors.ink2),
                ),
                const SizedBox(height: 14),
                AsyncButton(
                  label: 'Post your first ad',
                  icon: Icons.add_box_outlined,
                  onPressed: () async =>
                      showUkoMessage(context, 'Use the Post ad tab below'),
                ),
              ],
            ),
          )
        else
          UkoPanel(
            title: 'What you are selling',
            subtitle: '${items.length} ${plural(items.length, 'ad')}',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final i in items.take(3))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(i.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12.5, color: UkoColors.ink)),
                        ),
                        const SizedBox(width: 8),
                        UkoChip(i.isVerified ? 'On a shelf' : 'Not on a shelf',
                            tone: i.isVerified ? UkoTone.success : UkoTone.warning),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                AsyncButton(
                  label: 'See all my ads',
                  outlined: true,
                  onPressed: () async {
                    await Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => SellerItemsScreen(api: widget.api),
                    ));
                    await _loadItems();
                  },
                ),
              ],
            ),
          ),

        const SizedBox(height: 22),
        AsyncButton(
          label: 'Sign out',
          icon: Icons.logout,
          outlined: true,
          onPressed: () => _confirmSignOut(context),
        ),
      ],
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'Your basket stays on this phone. Your orders and ads are safe on your account.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Stay')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sign out')),
        ],
      ),
    );
    if (yes != true) return;
    await widget.auth.signOut();
    if (mounted) setState(() => _items = null);
  }
}
