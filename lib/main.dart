import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'config/app_config.dart';

void main() {
  AppConfig.assertValid();
  runApp(const ProviderScope(child: App()));
}
