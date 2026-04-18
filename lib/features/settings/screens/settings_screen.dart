import 'package:flutter/material.dart';

import '../../../theme/colour_tokens.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: LnColors.lnBg,
      body: Center(
        child: Text('Settings', style: TextStyle(color: LnColors.lnText2)),
      ),
    );
  }
}
