/// UKO — the shop app, for buyers and sellers.
///
/// Points at the shop API (`shop/back-end`, port 8008). The base URL is a `--dart-define`; see
/// `src/config.dart` for the emulator / handset / production forms.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const UkoShopApp());
}
