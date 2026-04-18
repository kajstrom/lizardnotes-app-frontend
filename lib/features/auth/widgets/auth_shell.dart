import 'package:flutter/material.dart';

import '../../../theme/colour_tokens.dart';

/// Shared scaffold wrapper used by every auth screen.
///
/// Renders the icon mark (lizard or lock emoji in a rounded rectangle),
/// a screen [title], an optional [subtitle], and a [child] form slot —
/// all centred in a column with a max width of 400 px.
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

  /// When true, shows a lock emoji instead of the lizard mark (used for MFA
  /// screens).
  final bool useLockMark;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _IconMark(useLock: useLockMark),
                  const SizedBox(height: 24),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: LnColors.lnText,
                          fontWeight: FontWeight.w600,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: LnColors.lnText2,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 32),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IconMark extends StatelessWidget {
  const _IconMark({required this.useLock});

  final bool useLock;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: LnColors.lnSurface2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: LnColors.lnAccent, width: 1.5),
        ),
        child: Center(
          child: Text(
            useLock ? '🔒' : '🦎',
            style: const TextStyle(fontSize: 32),
          ),
        ),
      ),
    );
  }
}
