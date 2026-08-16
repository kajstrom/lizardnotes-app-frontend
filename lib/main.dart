import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'config/app_config.dart';

void configurePlatform() {
  if (kIsWeb) {
    BrowserContextMenu.disableContextMenu();
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  configurePlatform();
  AppConfig.assertValid();
  runApp(const ProviderScope(child: App()));
}
