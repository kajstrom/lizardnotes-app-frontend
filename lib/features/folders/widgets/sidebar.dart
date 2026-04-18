import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../theme/colour_tokens.dart';
import '../../../theme/text_styles.dart';
import '../providers/folder_provider.dart';
import 'folder_tree_tile.dart';

// ---------------------------------------------------------------------------
// User email provider
// ---------------------------------------------------------------------------

/// Reads the stored username (email) from SharedPreferences.
final userEmailProvider = FutureProvider<String?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('auth_username');
});

// ---------------------------------------------------------------------------
// Sidebar
// ---------------------------------------------------------------------------

class Sidebar extends ConsumerStatefulWidget {
  const Sidebar({super.key});

  @override
  ConsumerState<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends ConsumerState<Sidebar> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(folderProvider.notifier).loadFolders());
  }

  @override
  Widget build(BuildContext context) {
    final emailAsync = ref.watch(userEmailProvider);
    final folderState = ref.watch(folderProvider);
    final notifier = ref.read(folderProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Header ──────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
          child: Row(
            children: [
              // Brand mark
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: LnColors.lnSurface2,
                  borderRadius: BorderRadius.circular(7),
                  border:
                      Border.all(color: LnColors.lnAccent, width: 1),
                ),
                child: const Center(
                  child: Text(
                    '\u{1F98E}', // lizard emoji
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LizardNotes',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: LnColors.lnText,
                      ),
                    ),
                    emailAsync.when(
                      data: (email) => Text(
                        email ?? '',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          color: LnColors.lnText3,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      loading: () => const SizedBox.shrink(),
                      error: (err, st) => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // ── Search pill ─────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: _SearchPill(),
        ),
        const SizedBox(height: 14),
        // ── Folders section label ────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
          child: Text(
            'FOLDERS',
            style: LnTextStyles.sectionLabel(),
          ),
        ),
        // ── Folder tree ──────────────────────────────────────────────────────
        Expanded(
          child: _FolderTree(folderState: folderState, notifier: notifier),
        ),
        // ── Footer ───────────────────────────────────────────────────────────
        _SidebarFooter(notifier: notifier),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Search pill
// ---------------------------------------------------------------------------

class _SearchPill extends StatefulWidget {
  @override
  State<_SearchPill> createState() => _SearchPillState();
}

class _SearchPillState extends State<_SearchPill> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () {
          // TODO: wire to DesktopShell ⌘K handler.
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: _hovered ? LnColors.lnSurface3 : LnColors.lnSurface2,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: LnColors.lnBorder2),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.search,
                size: 14,
                color: LnColors.lnText3,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Search notes\u2026',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: LnColors.lnText3,
                  ),
                ),
              ),
              Text(
                '\u2318K',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  color: LnColors.lnText3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Folder tree
// ---------------------------------------------------------------------------

class _FolderTree extends StatelessWidget {
  const _FolderTree({
    required this.folderState,
    required this.notifier,
  });

  final dynamic folderState;
  final FolderNotifier notifier;

  @override
  Widget build(BuildContext context) {
    if (folderState.status == FolderStatus.loading &&
        (folderState.folders as List).isEmpty) {
      return const Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: LnColors.lnText3,
          ),
        ),
      );
    }

    if (folderState.status == FolderStatus.error) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          folderState.errorMessage ?? 'Failed to load folders.',
          style: LnTextStyles.sectionLabel(color: LnColors.lnDanger),
        ),
      );
    }

    final rootFolders = notifier.childrenOf(null);
    if (rootFolders.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          'No folders yet.',
          style: LnTextStyles.sectionLabel(),
        ),
      );
    }

    return ListView.builder(
      itemCount: rootFolders.length,
      itemBuilder: (ctx, i) => FolderTreeTile(
        key: ValueKey(rootFolders[i].folderId),
        folder: rootFolders[i],
        depth: 0,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Footer
// ---------------------------------------------------------------------------

class _SidebarFooter extends StatelessWidget {
  const _SidebarFooter({required this.notifier});

  final FolderNotifier notifier;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: LnColors.lnBorder, width: 1),
        ),
      ),
      child: Row(
        children: [
          // New note button (primary)
          Expanded(
            child: _NewNoteButton(),
          ),
          const SizedBox(width: 6),
          // + folder button (ghost icon)
          _NewFolderButton(notifier: notifier),
        ],
      ),
    );
  }
}

class _NewNoteButton extends StatefulWidget {
  @override
  State<_NewNoteButton> createState() => _NewNoteButtonState();
}

class _NewNoteButtonState extends State<_NewNoteButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () {
          // TODO: wire to note creation in step 2-9.
          debugPrint('new note');
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          height: 30,
          decoration: BoxDecoration(
            color:
                _hovered ? LnColors.lnAccent2 : LnColors.lnAccent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text(
              'New note',
              style: LnTextStyles.primaryButton(),
            ),
          ),
        ),
      ),
    );
  }
}

class _NewFolderButton extends StatefulWidget {
  const _NewFolderButton({required this.notifier});

  final FolderNotifier notifier;

  @override
  State<_NewFolderButton> createState() => _NewFolderButtonState();
}

class _NewFolderButtonState extends State<_NewFolderButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () =>
            widget.notifier.createFolder('New Folder'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: _hovered ? LnColors.lnSurface3 : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: LnColors.lnBorder2),
          ),
          child: const Center(
            child: Icon(
              Icons.create_new_folder_outlined,
              size: 14,
              color: LnColors.lnText2,
            ),
          ),
        ),
      ),
    );
  }
}
