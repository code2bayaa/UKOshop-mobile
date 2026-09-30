# UKO — shop app (Flutter)

The buyer's and seller's app, built to the mobile wireframes **M1–M8** in `docs/wireframe.pen`. Same
API as the web app (`shop/back-end`, port 8008).

```
shop/front-end/
├─ web-app/     React 19 + TanStack Router  →  http://localhost:3000
└─ mobile/      Flutter 3.47 (this)         →  Android + iOS
```

## What is different about this one

The three partner apps each belong to one person doing one job. This one has to work for somebody who
has never heard of UKO, so two things drive every screen.

**There is no sign-in gate.** Browsing, searching and filling a basket all work signed out — a shop you
cannot look at until you have an account is a shop nobody joins. The guest basket lives on an
`X-Session-Key` the app generates once and keeps; signing in merges it into the account server-side.
The app only asks who you are at checkout, Orders, and Post ad, and it always says why.

**A UKO basket is not in one place.** The items sit on real shelves in real wards, possibly several,
possibly in another county. So checkout is not "standard or express" — it is *how do you want to
collect a basket that is spread across three counters*, and every option is priced per basket by the
server (`app/consolidate.py`). The app never computes a delivery price; it asks.

## The distinction the whole app rests on

An item **on a shelf** has been looked at by a named host, and the buyer's money is held by UKO until
he has it. An item **not on a shelf** is an ordinary stranger-to-stranger sale with no escrow behind
it. Both appear in the same grid, so every card says which, and the item screen explains it before the
buyer taps rather than letting a button fail:

> `add to cart` on an unverified item returns
> *"This item is not on a shelf yet — order from the seller directly instead"*

## Which codes a buyer sees

Everywhere else in UKO, the person letting go of the goods types in what the person taking them says.
The buyer is on the other side of that, so for once **the code is his to give** — and which one depends
on how he is receiving the order:

| receiving | code shown | who he reads it to |
|---|---|---|
| `pickup` / `shelf_run` | `shelve_code` | the shelf host at the counter |
| `rider` / `taxi` | `rider_code` | the rider at his gate |

Orders shows it large on any order that is ready or on the way, because it is the one thing he needs in
his hand at the moment he needs it.

## Screens

| Wireframe | Screen | Notes |
|---|---|---|
| M1 | Home | Category strip, hero, trust strip, trending, shelves near you. The desktop footer is dropped — on a phone it is four screens of links nobody scrolls to |
| M2 | Categories | Search, results, and the filter sheet. Paging is "load more", not infinite scroll, so the filter button stays reachable |
| M3 | Item | Gallery, price, variant pickers, **the fulfilment panel**, seller, reviews, sticky add-to-basket |
| M4 | Cart | The server's stock-check sentences at the top, unedited. Shows how many shelves the basket spans, and deliberately says "before delivery" rather than a total that later grows |
| M5 | Checkout · shelf | The options, priced per basket, with the inter-city courier shown as its own line rather than letting it inflate the prices unexplained |
| M6 | Checkout · pay | M-PESA push, then polling — the API answers immediately and the money arrives later |
| — | Done | The code, large, and what happens next |
| M8 | Tracking | Status, the rider, the timeline |
| M7 | Post ad | Title, description, price, **photos**, ward. What UKO charges and which shelf takes it are the API's to decide, after the ad exists |
| — | Account | The shopper, and the seller's front door — no separate "seller mode" |

## Running it

```powershell
flutter pub get
flutter run --dart-define=UKO_API=http://10.0.2.2:8008
```

`10.0.2.2` is the Android emulator's alias for the host. **On a real handset that is the handset**, so
pass the laptop's LAN address instead:

```powershell
flutter run --dart-define=UKO_API=http://192.168.1.20:8008
flutter build apk --release --dart-define=UKO_API=https://uko-app.co.ke
```

### Checking it in a browser

```powershell
flutter build web --dart-define=UKO_API=http://127.0.0.1:8008
python -m http.server 5013 --directory build/web
```

**`127.0.0.1`, not `localhost`.** `shop/back-end/run.ps1` binds uvicorn to `127.0.0.1` only, and a
browser asking for `localhost` may resolve it to `::1` and get `ERR_CONNECTION_REFUSED` while the API
is up. The camera does not work in a browser; everything else does.

```powershell
flutter analyze
flutter test
```

## What the app does not decide

Prices, stock, what receiving a basket costs, whether an item may be added at all, what an ad costs to
post. Error messages from the API go on screen **unchanged** — they are written for the person reading
them.

## Shared code

`mobile/uko_core`, the same package the delivery, courier and shelves apps use: the HTTP client and its
error handling, uploads and the camera field, the money and date formatting, the design tokens from
`docs/wireframe.pen`, the wireframe chrome (bottom tabs, top bar, stat cards, the M8 timeline) and the
code box.

What the shop does **not** take from it is `AuthController`. A partner signs in with a company e-mail
UKO issued, a password and a 6-digit code, into a two-hour session. A shop account is an ordinary
customer account — self-registered, OTP-verified, long-lived — so `lib/src/auth.dart` is its own.

## Platform bits

* `android/app/src/main/AndroidManifest.xml` — `INTERNET` and `CAMERA`, nothing else. **No location
  permission**: a buyer carries nobody's goods, and his ward is a word he types, not a position we read.
* `ios/Runner/Info.plist` — the two camera strings, and no location strings on purpose.
