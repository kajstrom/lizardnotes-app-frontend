import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../router/app_router.dart';
import '../../../theme/colour_tokens.dart';
import '../../../theme/text_styles.dart';
import '../models/folder.dart';
import '../providers/folder_provider.dart';

class FolderListScreen extends ConsumerStatefulWidget {
  const FolderListScreen({super.key});

  @override
  ConsumerState<FolderListScreen> createState() => _FolderListScreenState();
}

class _FolderListScreenState extends ConsumerState<FolderListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(folderProvider.notifier).loadFolders());
  }

  @override
  Widget build(BuildContext context) {
    final folderState = ref.watch(folderProvider);
    final notifier = ref.read(folderProvider.notifier);
    final rootFolders = notifier.childrenOf(null);

    return Scaffold(
      backgroundColor: LnColors.lnBg,
      appBar: AppBar(
        backgroundColor: LnColors.lnSurface,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'LizardNotes',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: LnColors.lnText,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, size: 20, color: LnColors.lnText2),
            tooltip: 'Search',
            onPressed: () => context.go(RouteNames.appSearch),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: LnColors.lnBorder),
        ),
      ),
      body: folderState.status == FolderStatus.loading && rootFolders.isEmpty
          ? const Center(
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: LnColors.lnAccent,
              ),
            )
          : rootFolders.isEmpty
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(24, 40, 24, 0),
                  child: Text(
                    'No folders yet. Tap + to create your first folder.',
                    style: LnTextStyles.authSubtitle(color: LnColors.lnText3),
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  itemCount: rootFolders.length,
                  itemBuilder: (context, i) {
                    final folder = rootFolders[i];
                    final subfolderCount =
                        notifier.childrenOf(folder.folderId).length;
                    return _FolderRow(
                      folder: folder,
                      subfolderCount: subfolderCount,
                      onTap: () {
                        ref
                            .read(selectedFolderIdProvider.notifier)
                            .select(folder.folderId);
                        context.go(
                          '${RouteNames.appFolders}/${folder.folderId}',
                        );
                      },
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: LnColors.lnAccent,
        foregroundColor: LnColors.lnText,
        tooltip: 'New folder',
        onPressed: () => ref
            .read(folderProvider.notifier)
            .createFolder('New Folder'),
        child: const Icon(Icons.create_new_folder_outlined, size: 22),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Folder row
// ---------------------------------------------------------------------------

class _FolderRow extends StatefulWidget {
  const _FolderRow({
    required this.folder,
    required this.subfolderCount,
    required this.onTap,
  });

  final Folder folder;
  final int subfolderCount;
  final VoidCallback onTap;

  @override
  State<_FolderRow> createState() => _FolderRowState();
}

class _FolderRowState extends State<_FolderRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        color: _pressed ? LnColors.lnSurface3 : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const Icon(
              Icons.folder_outlined,
              size: 18,
              color: LnColors.lnText3,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.folder.name,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: LnColors.lnText,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.subfolderCount > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${widget.subfolderCount} '
                      '${widget.subfolderCount == 1 ? 'subfolder' : 'subfolders'}',
                      style: LnTextStyles.sectionLabel(color: LnColors.lnText3),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: LnColors.lnText3,
            ),
          ],
        ),
      ),
    );
  }
}
