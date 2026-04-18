import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'config/app_config.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  BrowserContextMenu.disableContextMenu();
  AppConfig.assertValid();
  runApp(const ProviderScope(child: App()));
}
