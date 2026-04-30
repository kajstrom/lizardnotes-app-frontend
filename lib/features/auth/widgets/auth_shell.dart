import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/colour_tokens.dart';
import '../../../theme/dimensions.dart';
import 'web_semantics_scope.dart';

/// Shared scaffold wrapper used by every auth screen.
///
/// Renders the brand mark (lizard emoji or lock icon in a 52 px rounded
/// square), title, optional subtitle, and a [child] form slot — all centred
/// inside a card with max-width 400 px.
class AuthShell extends StatelessWidget {
  const AuthShell({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.useLockMark = false,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  /// When true, shows a lock SVG icon instead of the lizard emoji (MFA screens).
  final bool useLockMark;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LnColors.lnBg,
      body: WebSemanticsScope(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 36,
                  ),
                  decoration: BoxDecoration(
                    color: LnColors.lnSurface,
                    borderRadius: BorderRadius.circular(LnDims.r12),
                    border: Border.all(color: LnColors.lnBorder, width: 1),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _IconMark(useLock: useLockMark),
                      const SizedBox(height: 20),
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.33,
                          color: LnColors.lnText,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 8),
                        Center(
                          child: ConstrainedBox(
                            constraints:
                                const BoxConstraints(maxWidth: 320),
                            child: Text(
                              subtitle!,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: LnColors.lnText2,
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),
                      child,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Brand mark shown at the top of every auth card.
///
/// Lizard screens: lnSurface2 bg, 1 px lnAccent border, 🦎 at 26 px.
/// MFA screens (useLock=true): lnSurface2 bg, 1 px lnBorder3 border,
/// lock icon in lnAccent2 at 22 px.
class _IconMark extends StatelessWidget {
  const _IconMark({required this.useLock});

  final bool useLock;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: LnColors.lnSurface2,
          borderRadius: BorderRadius.circular(LnDims.r12),
          border: Border.all(
            color: useLock ? LnColors.lnBorder3 : LnColors.lnAccent,
            width: 1,
          ),
        ),
        child: Center(
          child: useLock
              ? const Icon(
                  Icons.lock_outline,
                  size: 22,
                  color: LnColors.lnAccent2,
                )
              : const Text(
                  '🦎',
                  style: TextStyle(fontSize: 26),
                ),
        ),
      ),
    );
  }
}
