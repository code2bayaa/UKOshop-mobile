/// The app itself: one API client, one auth controller, one cart, and a shell.
///
/// Unlike the three partner apps there is **no sign-in gate**. A shop you cannot look at until you
/// have an account is a shop nobody joins, so browsing, searching and filling a basket all work signed
/// out; the app only asks who he is at the point where it genuinely has to — checkout, orders, posting
/// an ad. The guest basket then merges into the account (`merge_session_cart` on the server).
library;

import 'package:flutter/material.dart';
import 'package:uko_core/uko_core.dart';

import 'api.dart';
import 'auth.dart';
import 'cart_controller.dart';
import 'config.dart';
import 'screens/shell.dart';

class UkoShopApp extends StatefulWidget {
  const UkoShopApp({super.key});

  @override
  State<UkoShopApp> createState() => _UkoShopAppState();
}

class _UkoShopAppState extends State<UkoShopApp> {
  late final ApiClient _client;
  late final ShopAuth _auth;
  late final ShopApi _api;
  late final CartController _cart;

  @override
  void initState() {
    super.initState();
    final store = SessionStore(key: Config.sessionKey);
    _client = ApiClient(
      baseUrl: Config.apiBase,
      readToken: () async => _auth.token,
      // The guest-cart key travels on every request, signed in or not.
      readHeaders: () async => _auth.headers,
      onSessionExpired: _onSessionExpired,
    );
    _auth = ShopAuth(api: _client, store: store);
    _api = ShopApi(_client);
    _cart = CartController(api: _api);
    _start();
  }

  Future<void> _start() async {
    await _auth.restore();
    // The basket is fetched after the session is known, so a signed-in shopper gets his own rather
    // than the guest one he would have been shown a moment earlier.
    await _cart.load();
  }

  /// A 401 from anywhere. Drop the token — but not the basket, which survives as a guest one.
  void _onSessionExpired() => _auth.forget();

  @override
  void dispose() {
    _client.close();
    _auth.dispose();
    _cart.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'UKO',
        theme: ukoTheme(),
        debugShowCheckedModeBanner: false,
        home: AnimatedBuilder(
          animation: _auth,
          builder: (context, _) {
            if (_auth.restoring) return const _Splash();
            return ShopShell(auth: _auth, api: _api, cart: _cart);
          },
        ),
      );
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) => const Scaffold(
        backgroundColor: UkoColors.primary,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.storefront, color: Colors.white, size: 44),
              SizedBox(height: 18),
              SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white70),
              ),
            ],
          ),
        ),
      );
}
