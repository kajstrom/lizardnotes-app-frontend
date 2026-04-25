import 'package:flutter/material.dart';

import '../../../theme/colour_tokens.dart';

/// Full-screen overlay shown while the app attempts to restore a persisted
/// Cognito session at startup. Avoids flashing the login page when we're
/// about to silently refresh and land the user back in the app.
class RestoringSessionSplash extends StatelessWidget {
  const RestoringSessionSplash({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: LnColors.lnBg,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(LnColors.lnAccent),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Restoring session…',
              style: TextStyle(
                color: LnColors.lnText2,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
