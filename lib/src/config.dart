/// Where this build of the app points.
library;

abstract final class Config {
  /// Origin only — no trailing slash and no `/api`; [ApiClient] adds that.
  static const apiBase = String.fromEnvironment(
    'UKO_API',
    // The Android emulator's alias for the machine running it. A physical phone needs the LAN address
    // passed in; `localhost` there would be the handset itself.
    defaultValue: 'http://10.0.2.2:8008',
  );

  static const shopWebUrl = String.fromEnvironment(
    'UKO_SHOP_WEB',
    defaultValue: 'http://10.0.2.2:3000',
  );

  /// The site's address as a shopper should read it — empty when this build points at a developer's
  /// machine. Opening a dev URL on a dev build is right; *printing* one is not.
  static String get shopWebLabel {
    final dev = RegExp(
        r'^https?://(10\.0\.2\.2|localhost|127\.|0\.0\.0\.0|192\.168\.|10\.|172\.(1[6-9]|2\d|3[01])\.)');
    if (dev.hasMatch(shopWebUrl)) return '';
    return shopWebUrl.replaceFirst(RegExp(r'^https?://'), '').replaceFirst(RegExp(r'/$'), '');
  }

  /// Distinct from the three partner keys so all four can live on one phone.
  static const sessionKey = 'uko_shop_session';

  /// Fallback only — every cart response carries the server's own `hold_hours`, which is what the
  /// screens use. Kept in step with `CART_HOLD_HOURS` so an empty basket still states it correctly.
  static const cartHoldHours = 24;

  /// UKO's cut of a sale, for explaining a seller's payout. The API calculates the real figure.
  static const sellerCommissionPct = 20;
}
