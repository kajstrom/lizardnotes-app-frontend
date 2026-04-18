import 'package:flutter/material.dart';

import '../../../theme/text_styles.dart';

/// A form field wrapper that renders an uppercase mono label above the input,
/// matching the auth-screen field style from §7.2 of the design spec.
///
/// Usage:
/// ```dart
/// AuthField(
///   label: 'Email',
///   child: TextFormField(...),
/// )
/// ```
class AuthField extends StatelessWidget {
  const AuthField({
    super.key,
    required this.label,
    required this.child,
    this.hint,
  });

  /// Field name shown as an uppercase mono label above the input.
  final String label;

  /// The actual input widget (typically [TextFormField]).
  final Widget child;

  /// Optional hint text shown in small type below the input.
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: LnTextStyles.authFieldLabel(),
        ),
        const SizedBox(height: 6),
        child,
        if (hint != null) ...[
          const SizedBox(height: 4),
          Text(hint!, style: LnTextStyles.timestamp()),
        ],
      ],
    );
  }
}
