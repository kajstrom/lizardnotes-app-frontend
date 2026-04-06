import 'package:flutter/material.dart';

import 'app.dart';
import 'config/app_config.dart';

void main() {
  AppConfig.assertValid();
  runApp(const App());
}
