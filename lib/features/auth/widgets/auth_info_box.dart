import 'package:flutter/material.dart';

import '../../../theme/colour_tokens.dart';

enum AuthInfoBoxVariant { amber, green }

/// Tinted info box used on auth screens to show contextual messages.
///
/// [AuthInfoBoxVariant.amber] — warning (e.g. temporary-password notice).
/// [AuthInfoBoxVariant.green] — success (e.g. reset code sent confirmation).
class AuthInfoBox extends StatelessWidget {
  const AuthInfoBox({
    super.key,
    required this.message,
    required this.variant,
  });

  final String message;
  final AuthInfoBoxVariant variant;

  @override
  Widget build(BuildContext context) {
    final (bg, border, fg) = switch (variant) {
      AuthInfoBoxVariant.amber => (
          const Color(0x1Eb87c2a),
          LnColors.lnAmber,
          LnColors.lnAmber,
        ),
      AuthInfoBoxVariant.green => (
          const Color(0x1E4a9e6a),
          LnColors.lnSuccess,
          LnColors.lnSuccess,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Text(
        message,
        style: TextStyle(color: fg, fontSize: 13, height: 1.5),
      ),
    );
  }
}
