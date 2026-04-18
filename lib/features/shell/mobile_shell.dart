import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/colour_tokens.dart';

/// Linear-navigation shell for narrow (< 600 px) viewports.
///
/// Renders the [child] screen inside a [Scaffold] with a bottom navigation
/// bar that is visible only on root-level routes (folders, search, settings).
class MobileShell extends StatelessWidget {
  const MobileShell({
    super.key,
    required this.child,
    required this.location,
  });

  final Widget child;

  /// Current route path, used to show/hide the bottom nav and set the
  /// active tab index. Provided by the ShellRoute builder.
  final String location;

  static const _rootFolders = '/app/folders';
  static const _rootSearch = '/app/search';
  static const _rootSettings = '/app/settings';

  bool get _isRootRoute =>
      location == _rootFolders ||
      location == _rootSearch ||
      location == _rootSettings;

  int get _selectedIndex {
    if (location.startsWith(_rootSearch)) return 1;
    if (location.startsWith(_rootSettings)) return 2;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LnColors.lnBg,
      body: child,
      bottomNavigationBar: _isRootRoute
          ? BottomNavigationBar(
              currentIndex: _selectedIndex,
              backgroundColor: LnColors.lnSurface,
              selectedItemColor: LnColors.lnAccent2,
              unselectedItemColor: LnColors.lnText3,
              onTap: (index) {
                switch (index) {
                  case 0:
                    context.go(_rootFolders);
                  case 1:
                    context.go(_rootSearch);
                  case 2:
                    context.go(_rootSettings);
                }
              },
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.folder_outlined),
                  activeIcon: Icon(Icons.folder),
                  label: 'Folders',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.search),
                  label: 'Search',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings_outlined),
                  activeIcon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
            )
          : null,
    );
  }
}
