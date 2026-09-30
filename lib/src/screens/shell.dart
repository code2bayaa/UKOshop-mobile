/// The shop's home: the wireframe's top bar, a body, and the five bottom tabs.
///
/// Two of the five need an account, and they handle that themselves rather than being hidden. A tab
/// bar that changes shape depending on whether you are signed in is a tab bar people learn twice, so
/// Post ad and Orders are always there and ask for a sign-in when tapped.
library;

import 'package:flutter/material.dart';
import '../api.dart';
import '../auth.dart';
import '../cart_controller.dart';
import '../models.dart';
import 'account_tab.dart';
import 'browse_tab.dart';
import 'cart.dart';
import 'home_tab.dart';
import 'item.dart';
import 'orders_tab.dart';
import 'post_ad.dart';
import 'sign_in.dart';
import 'widgets/chrome.dart';

class ShopShell extends StatefulWidget {
  const ShopShell({
    super.key,
    required this.auth,
    required this.api,
    required this.cart,
  });

  final ShopAuth auth;
  final ShopApi api;
  final CartController cart;

  @override
  State<ShopShell> createState() => _ShopShellState();
}

class _ShopShellState extends State<ShopShell> {
  ShopTab _tab = ShopTab.home;

  /// Set when Categories is opened from a category tile on Home, so the browse tab starts filtered.
  String _browseCategory = '';
  String _browseQuery = '';

  @override
  void initState() {
    super.initState();
    widget.cart.addListener(_onCart);
  }

  @override
  void dispose() {
    widget.cart.removeListener(_onCart);
    super.dispose();
  }

  void _onCart() {
    if (mounted) setState(() {});
  }

  // ---------------------------------------------------------------- navigation
  Future<void> openItem(ItemCard card) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ItemScreen(
        api: widget.api,
        cart: widget.cart,
        itemId: card.id,
        // Handed through so the screen has something to draw before the detail call lands.
        preview: card,
      ),
    ));
  }

  Future<void> openCart() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CartScreen(
        api: widget.api,
        cart: widget.cart,
        auth: widget.auth,
        onOpenItem: openItem,
        onBrowse: () => setState(() => _tab = ShopTab.home),
      ),
    ));
  }

  void browse({String category = '', String query = ''}) {
    setState(() {
      _browseCategory = category;
      _browseQuery = query;
      _tab = ShopTab.categories;
    });
  }

  /// Ask who he is, and come back where he was. Returns true once signed in.
  Future<bool> requireSignIn(String why) async {
    if (widget.auth.signedIn) return true;
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => SignInScreen(auth: widget.auth, reason: why),
    ));
    if (ok == true) {
      // The guest basket has just been merged into his account server-side; re-read it.
      await widget.cart.load();
      return true;
    }
    return false;
  }

  Future<void> _selectTab(ShopTab tab) async {
    if (tab == ShopTab.postAd) {
      if (!await requireSignIn('Sign in to post an ad')) return;
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PostAdScreen(api: widget.api, auth: widget.auth),
      ));
      return;
    }
    setState(() => _tab = tab);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: ShopTopBar(
          cartCount: widget.cart.count,
          onCart: openCart,
          onSearch: () => browse(),
          showSearch: _tab == ShopTab.home || _tab == ShopTab.categories,
        ),
        body: _body(),
        bottomNavigationBar: ShopBottomTabs(
          current: _tab,
          onSelect: _selectTab,
        ),
      );

  Widget _body() => switch (_tab) {
        ShopTab.home => HomeTab(
            api: widget.api,
            auth: widget.auth,
            onOpenItem: openItem,
            onBrowse: browse,
          ),
        ShopTab.categories => BrowseTab(
            api: widget.api,
            initialCategory: _browseCategory,
            initialQuery: _browseQuery,
            onOpenItem: openItem,
          ),
        // Never reached — Post ad pushes a screen instead of becoming a tab body — but `switch` on an
        // enum has to be exhaustive, and a silent `default` would hide a real gap later.
        ShopTab.postAd => const SizedBox.shrink(),
        ShopTab.orders => OrdersTab(
            api: widget.api,
            auth: widget.auth,
            onRequireSignIn: () => requireSignIn('Sign in to see your orders'),
          ),
        ShopTab.account => AccountTab(
            auth: widget.auth,
            api: widget.api,
            onRequireSignIn: () => requireSignIn('Sign in to your UKO account'),
          ),
      };
}
