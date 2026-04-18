import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/colour_tokens.dart';
import '../folders/widgets/sidebar.dart';
import '../notes/widgets/note_list_panel.dart';
import 'providers/density_provider.dart';

/// Whether the note-list column is currently visible.
/// Toggled from the editor topbar; consumed by [DesktopShell].
final noteListVisibleProvider =
    NotifierProvider<NoteListVisibleNotifier, bool>(
  NoteListVisibleNotifier.new,
);

class NoteListVisibleNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() => state = !state;
  void setValue(bool value) => state = value;
}

class _OpenSearchIntent extends Intent {
  const _OpenSearchIntent();
}

/// Three-column persistent shell for desktop / wide-screen layouts.
///
/// ┌─────────────┬──────────────────┬──────────────────────┐
/// │ Sidebar     │  Note list       │  Editor (child)      │
/// │ 240 px      │  280 px (anim)   │  flex: 1             │
/// └─────────────┴──────────────────┴──────────────────────┘
class DesktopShell extends ConsumerStatefulWidget {
  const DesktopShell({super.key, required this.child});

  final Widget child;

  /// Key placed on the note-list [AnimatedContainer] for widget tests.
  static const Key noteListColumnKey = Key('desktopShell.noteListColumn');

  @override
  ConsumerState<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends ConsumerState<DesktopShell> {
  late final FocusNode _shellFocus;

  @override
  void initState() {
    super.initState();
    _shellFocus = FocusNode(debugLabel: 'DesktopShellFocus');
  }

  @override
  void dispose() {
    _shellFocus.dispose();
    super.dispose();
  }

  void _openSearch(BuildContext context) {
    // TODO: show SearchModal when implemented.
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(densityTokensProvider);
    final noteListVisible = ref.watch(noteListVisibleProvider);

    return Shortcuts(
      shortcuts: {
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
            const _OpenSearchIntent(),
        const SingleActivator(LogicalKeyboardKey.keyK, control: true):
            const _OpenSearchIntent(),
      },
      child: Actions(
        actions: {
          _OpenSearchIntent: CallbackAction<_OpenSearchIntent>(
            onInvoke: (_) {
              _openSearch(context);
              return null;
            },
          ),
        },
        child: Focus(
          focusNode: _shellFocus,
          autofocus: true,
          child: Scaffold(
            backgroundColor: LnColors.lnBg,
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Sidebar ───────────────────────────────────────────────
                Container(
                  width: tokens.sidebarWidth,
                  decoration: const BoxDecoration(
                    color: LnColors.lnSurface,
                    border: Border(
                      right: BorderSide(color: LnColors.lnBorder, width: 1),
                    ),
                  ),
                  child: const Sidebar(),
                ),
                // ── Note list (animated) ───────────────────────────────────
                AnimatedContainer(
                  key: DesktopShell.noteListColumnKey,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeInOut,
                  width: noteListVisible ? tokens.noteListWidth : 0.0,
                  clipBehavior: Clip.hardEdge,
                  decoration: BoxDecoration(
                    color: LnColors.lnSurface,
                    border: noteListVisible
                        ? const Border(
                            right: BorderSide(
                              color: LnColors.lnBorder,
                              width: 1,
                            ),
                          )
                        : null,
                  ),
                  child: const NoteListPanel(),
                ),
                // ── Editor column (flex: 1) ────────────────────────────────
                Expanded(
                  child: ColoredBox(
                    color: LnColors.lnBg,
                    child: widget.child,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
