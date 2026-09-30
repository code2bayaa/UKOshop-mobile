/// Who is using the shop, and the basket they carry before they are anybody.
///
/// **This is not `uko_core`'s `AuthController`, and deliberately so.** A partner — rider, driver, shelf
/// host — signs in with a company e-mail UKO issued him, a password, and a 6-digit code, into a
/// two-hour session. A shop account is an ordinary customer account: he signs up himself, with an
/// e-mail he already had, verified by OTP, or with Google; the session is long-lived because nobody
/// wants to re-authenticate to look at a watch.
///
/// The other thing this holds is the **guest session key**. A shop is useless if you must have an
/// account to put something in a basket, so the API keys a guest cart on an `X-Session-Key` header
/// that the client generates once and keeps. Signing in merges that cart into the account's
/// (`merge_session_cart` on the server), which is why the key is kept rather than thrown away.
library;

import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:uko_core/uko_core.dart';

/// The signed-in shopper, as `user_dict` sends him.
class Shopper {
  Shopper.fromJson(Map<String, dynamic> j)
      : id = asInt(j['id']),
        name = asText(j['name']),
        email = asText(j['email']),
        phone = asText(j['telephone']),
        ward = asText(asMap(j['profile'])['ward']),
        county = asText(asMap(j['profile'])['county']),
        storeName = asText(asMap(j['profile'])['store_name']),
        avatar = asText(asMap(j['profile'])['avatar']),
        sellerPackage = asText(asMap(j['profile'])['seller_package'], 'free'),
        itemsSold = asInt(asMap(j['profile'])['items_sold']),
        emailVerified = asMap(j['profile'])['email_verified'] == true,
        isSeller = asMap(j['roles'])['seller'] == true,
        isShelveOwner = asMap(j['roles'])['shelve_owner'] == true;

  final int id;
  final String name;
  final String email;
  final String phone;
  final String ward;
  final String county;
  final String storeName;
  final String avatar;
  final String sellerPackage;
  final int itemsSold;
  final bool emailVerified;
  final bool isSeller;
  final bool isShelveOwner;

  /// What to call him on his own screens. A store name is what buyers see, so it wins.
  String get displayName => storeName.isNotEmpty ? storeName : (name.isEmpty ? 'You' : name);

  String get initials {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'U';
    return parts.length == 1
        ? parts.first.characters(1)
        : parts.first.characters(1) + parts.last.characters(1);
  }
}

extension on String {
  String characters(int n) => length <= n ? toUpperCase() : substring(0, n).toUpperCase();
}

class ShopAuth extends ChangeNotifier {
  ShopAuth({required this.api, required this.store});

  final ApiClient api;
  final SessionStore store;

  Shopper? _me;
  String? _token;
  String _sessionKey = '';
  bool _restoring = true;

  Shopper? get me => _me;
  bool get signedIn => _token != null && _me != null;
  bool get restoring => _restoring;
  String? get token => _token;

  /// The guest-cart key, sent on every request as `X-Session-Key`. Present whether or not anybody is
  /// signed in: the server ignores it once a token is attached.
  Map<String, String> get headers =>
      _sessionKey.isEmpty ? const {} : {'X-Session-Key': _sessionKey};

  static const _tokenKey = 'token';
  static const _guestKey = 'guest_session_key';

  /// Read the keystore on launch. A shopper who was signed in yesterday should not see a sign-in
  /// screen flash past today.
  Future<void> restore() async {
    _sessionKey = await store.readRaw(_guestKey) ?? '';
    if (_sessionKey.isEmpty) {
      _sessionKey = _newKey();
      await store.writeRaw(_guestKey, _sessionKey);
    }
    _token = await store.readRaw(_tokenKey);
    if (_token != null && _token!.isNotEmpty) {
      try {
        _me = Shopper.fromJson(asMap(await api.get('/auth/me')));
      } on ApiException {
        // The token is stale or the account is gone. Browsing works signed out, so this is not an
        // error to show anyone — just drop it.
        _token = null;
        await store.deleteRaw(_tokenKey);
      }
    }
    _restoring = false;
    notifyListeners();
  }

  /// A random key with enough entropy that two phones never collide on one guest cart.
  static String _newKey() {
    final r = Random.secure();
    return base64Url
        .encode(List<int>.generate(24, (_) => r.nextInt(256)))
        .replaceAll('=', '');
  }

  // ---------------------------------------------------------------- signing in
  Future<void> signIn({required String identifier, required String password}) async {
    final body = asMap(await api.post('/auth/login', body: {
      'identifier': identifier.trim(),
      'password': password,
      'remember': true,
    }));
    await _adopt(body);
  }

  /// Step 1 of signing up: UKO e-mails a code to prove the address is his.
  Future<void> sendOtp({required String target, String channel = 'email', String purpose = 'register'}) =>
      api.post('/auth/otp/send', body: {'channel': channel, 'target': target.trim(), 'purpose': purpose});

  /// Step 2: the code comes back as a token that `register` then requires. The token is what proves
  /// verification happened, so it is returned rather than stored — `register` needs it in hand.
  Future<String> verifyOtp({
    required String target,
    required String code,
    String channel = 'email',
    String purpose = 'register',
  }) async {
    final body = asMap(await api.post('/auth/otp/verify',
        body: {'channel': channel, 'target': target.trim(), 'code': code.trim(), 'purpose': purpose}));
    return asText(body['token']);
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String country,
    required String county,
    required String ward,
    required String emailToken,
    String phone = '',
  }) async {
    final body = asMap(await api.post('/auth/register', body: {
      'name': name.trim(),
      'email': email.trim(),
      'phone': phone.trim(),
      'password': password,
      'country': country,
      'county': county,
      'ward': ward,
      'email_token': emailToken,
      'accept_terms': true,
    }));
    await _adopt(body);
  }

  Future<void> signOut() async {
    try {
      await api.post('/auth/logout');
    } on ApiException {
      // Already gone server-side; the local drop below is what matters.
    }
    await forget();
  }

  /// Drop the session without calling the API — what a 401 triggers.
  Future<void> forget() async {
    _token = null;
    _me = null;
    await store.deleteRaw(_tokenKey);
    notifyListeners();
  }

  /// Re-read the account after something changed it (a profile edit, a first sale).
  Future<void> refresh() async {
    if (_token == null) return;
    try {
      _me = Shopper.fromJson(asMap(await api.get('/auth/me')));
      notifyListeners();
    } on ApiException {
      // Leave what we have; the next 401 will clear it properly.
    }
  }

  Future<void> _adopt(Map<String, dynamic> body) async {
    _token = asText(body['token']);
    await store.writeRaw(_tokenKey, _token!);
    _me = Shopper.fromJson(asMap(body['user']));
    notifyListeners();
  }
}
