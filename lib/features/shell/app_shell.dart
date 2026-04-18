import 'package:flutter/widgets.dart';

import '../notes/screens/editor_screen.dart';
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

  /// On desktop, the Sidebar + NoteListPanel are always embedded in
  /// DesktopShell. Folder-browse routes (/app/folders, /app/folders/:id)
  /// are only meaningful for mobile navigation; on desktop the right panel
  /// should always show EditorScreen.
  bool get _isFolderRoute =>
      location == '/app/folders' || location.startsWith('/app/folders/');

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= kBreakpoint) {
          // On desktop, substitute folder routes with EditorScreen so the
          // right panel never shows the mobile-only note/folder list screens.
          return DesktopShell(
            child: _isFolderRoute ? const EditorScreen() : child,
          );
        }
        return MobileShell(location: location, child: child);
      },
    );
  }
}
