import 'package:flutter/widgets.dart';

import 'desktop_shell.dart';
import 'mobile_shell.dart';

/// Top-level shell switcher used as the [ShellRoute] builder.
///
/// Selects [DesktopShell] (≥ 600 px) or [MobileShell] (< 600 px) based on
/// the available width reported by [LayoutBuilder].
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.child,
    required this.location,
  });

  final Widget child;

  /// Current route path forwarded from the ShellRoute state. Used by
  /// [MobileShell] to control bottom-nav visibility.
  final String location;

  /// Width breakpoint separating mobile from desktop layout.
  static const double kBreakpoint = 600;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= kBreakpoint) {
          return DesktopShell(child: child);
        }
        return MobileShell(location: location, child: child);
      },
    );
  }
}
