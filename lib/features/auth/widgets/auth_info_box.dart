import 'package:flutter/material.dart';

import '../../../theme/colour_tokens.dart';
import '../../../theme/dimensions.dart';

enum AuthInfoBoxVariant { amber, green, neutral }

/// Tinted info box used on auth screens to show contextual messages.
///
/// Variants (§7.3):
///   [amber]   — warning, e.g. temporary-password notice.
///   [green]   — success, e.g. reset code sent confirmation.
///   [neutral] — contextual note, e.g. MFA sign-in context.
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
    final (bg, border, fg, icon) = switch (variant) {
      AuthInfoBoxVariant.amber => (
          LnColors.lnAmberBg,
          LnColors.lnAmberBorder,
          LnColors.lnAmber,
          const Icon(Icons.warning_amber_rounded, size: 16,
              color: LnColors.lnAmber),
        ),
      AuthInfoBoxVariant.green => (
          LnColors.lnSuccessBg,
          LnColors.lnSuccessBorder,
          LnColors.lnSuccess,
          const Icon(Icons.check_circle_outline, size: 16,
              color: LnColors.lnSuccess),
        ),
      AuthInfoBoxVariant.neutral => (
          LnColors.lnSurface2,
          LnColors.lnBorder,
          LnColors.lnText2,
          null as Widget?,
        ),
    };

    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(LnDims.r6),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 1, right: 8),
              child: icon,
            ),
          ],
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: fg, fontSize: 13, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
