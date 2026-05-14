import 'dart:async';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../api/api_client.dart';
import '../../../router/app_router.dart';
import '../../attachments/providers/attachment_provider.dart';
import '../../attachments/widgets/attachment_bar.dart';
import '../../../theme/colour_tokens.dart';
import '../../../theme/dimensions.dart';
import '../../../theme/text_styles.dart';
import '../../folders/models/folder.dart';
import '../../folders/providers/folder_provider.dart';
import '../../shell/desktop_shell.dart';
import '../../shell/providers/density_provider.dart';
import '../models/note.dart';
import '../providers/note_provider.dart';
import '../services/content_pipeline.dart';
import '../widgets/format_toolbar.dart';
import '../widgets/note_actions_sheet.dart';
import '../widgets/note_context_menu.dart';

// ---------------------------------------------------------------------------
// Save state
// ---------------------------------------------------------------------------

enum _SaveState { idle, saving, saved, error }

// ---------------------------------------------------------------------------
// Load state
// ---------------------------------------------------------------------------

enum _LoadState { idle, loading, loaded, error }

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({super.key});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  late QuillController _quillController;
  late FocusNode _editorFocus;
  late TextEditingController _titleController;
  late ScrollController _scrollController;

  Timer? _saveDebounce;
  Timer? _savedClearTimer;
  Timer? _titleDebounce;

  _SaveState _saveState = _SaveState.idle;
  _LoadState _loadState = _LoadState.idle;
  String? _loadError;

  String? _loadedNoteId;
  DateTime? _noteUpdatedAt;
  int _paragraphCount = 0;

  @override
  void initState() {
    super.initState();
    _quillController = QuillController.basic();
    _editorFocus = FocusNode();
    _titleController = TextEditingController();
    _scrollController = ScrollController();

    _quillController.addListener(_onDocumentChanged);
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _savedClearTimer?.cancel();
    _titleDebounce?.cancel();
    _quillController.removeListener(_onDocumentChanged);
    _quillController.dispose();
    _editorFocus.dispose();
    _titleController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Document change handlers ─────────────────────────────────────────────

  void _onDocumentChanged() {
    final doc = _quillController.document;
    final count = _countParagraphs(doc);
    if (count != _paragraphCount) {
      setState(() => _paragraphCount = count);
    }
    _scheduleAutoSave();
  }

  // ── Paragraph count ──────────────────────────────────────────────────────

  int _countParagraphs(Document doc) {
    var count = 0;
    for (final child in doc.root.children) {
      final text = child.toPlainText().trim();
      if (text.isNotEmpty) count++;
    }
    return count;
  }

  // ── Auto-save ────────────────────────────────────────────────────────────

  void _scheduleAutoSave() {
    final noteId = _loadedNoteId;
    if (noteId == null) return;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(seconds: 2), () => _save(noteId));
  }

  Future<void> _save(String noteId) async {
    if (!mounted) return;
    setState(() => _saveState = _SaveState.saving);
    final markdown = ContentPipeline.toMarkdown(_quillController.document);
    try {
      await ref.read(noteProvider.notifier).updateContent(noteId, markdown);
      if (!mounted) return;
      setState(() => _saveState = _SaveState.saved);
      _savedClearTimer?.cancel();
      _savedClearTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _saveState = _SaveState.idle);
      });
    } catch (_) {
      if (mounted) setState(() => _saveState = _SaveState.error);
    }
  }

  Future<void> _flushPendingSave() async {
    final hasPending = _saveDebounce?.isActive ?? false;
    _saveDebounce?.cancel();
    _saveDebounce = null;
    final noteId = _loadedNoteId;
    if (hasPending && noteId != null) await _save(noteId);
  }

  // ── Note loading ─────────────────────────────────────────────────────────

  Future<void> _loadNote(String noteId) async {
    if (_loadedNoteId == noteId && _loadState == _LoadState.loaded) return;

    // Flush any pending save for the previous note before switching.
    await _flushPendingSave();

    setState(() {
      _loadState = _LoadState.loading;
      _loadError = null;
      _loadedNoteId = noteId;
      _saveState = _SaveState.idle;
    });

    // Stop listening while we repopulate the controller to avoid triggering
    // auto-save on programmatic changes.
    _quillController.removeListener(_onDocumentChanged);

    try {
      final note = await ref.read(apiClientProvider).getNote(noteId);
      // Load attachments alongside the note (fire-and-forget).
      unawaited(
        ref.read(attachmentProvider(noteId).notifier).loadAttachments(),
      );
      final doc = ContentPipeline.fromMarkdown(note.content);
      _quillController.document = doc;
      _titleController.text = note.title;
      final count = _countParagraphs(doc);
      if (!mounted) return;
      setState(() {
        _loadState = _LoadState.loaded;
        _noteUpdatedAt = note.updatedAt;
        _paragraphCount = count;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadState = _LoadState.error;
        _loadError = e.toString();
        _loadedNoteId = null;
      });
    } finally {
      _quillController.addListener(_onDocumentChanged);
    }
  }

  // ── Title change ─────────────────────────────────────────────────────────

  void _onTitleChanged() {
    final noteId = _loadedNoteId;
    if (noteId == null) return;
    _titleDebounce?.cancel();
    _titleDebounce = Timer(const Duration(milliseconds: 500), () {
      ref.read(noteProvider.notifier).renameNote(noteId, _titleController.text);
    });
  }

  // ── Breadcrumb ───────────────────────────────────────────────────────────

  List<String> _buildBreadcrumbSegments(Note note) {
    final folders = ref.read(folderProvider).folders;
    final segments = <String>[];
    String? currentId = note.folderId;
    while (currentId != null) {
      Folder? folder;
      for (final f in folders) {
        if (f.folderId == currentId) {
          folder = f;
          break;
        }
      }
      if (folder == null) break;
      segments.insert(0, folder.name);
      currentId = folder.parentFolderId;
    }
    segments.add(note.title.isEmpty ? 'Untitled' : note.title);
    return segments;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(densityTokensProvider);
    final selectedNoteId = ref.watch(selectedNoteIdProvider);
    final noteState = ref.watch(noteProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 600;

    // Load note when selection changes.
    ref.listen<String?>(selectedNoteIdProvider, (previous, next) {
      if (next != null && next != _loadedNoteId) {
        _loadNote(next);
      }
    });

    // Trigger initial load if a note is already selected when first built.
    if (selectedNoteId != null && _loadState == _LoadState.idle) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && selectedNoteId != _loadedNoteId) {
          _loadNote(selectedNoteId);
        }
      });
    }

    // Find loaded note metadata from the provider list for context menus.
    final loadedNote = selectedNoteId != null
        ? noteState.notes.cast<Note?>().firstWhere(
              (n) => n?.noteId == selectedNoteId,
              orElse: () => null,
            )
        : null;

    if (selectedNoteId == null) {
      if (!isDesktop) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.go(RouteNames.appFolders);
        });
        return const SizedBox.shrink();
      }
      return const _EmptyState();
    }

    return Scaffold(
      backgroundColor: LnColors.lnBg,
      resizeToAvoidBottomInset: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Topbar ───────────────────────────────────────────────────────
          _Topbar(
            isDesktop: isDesktop,
            loadedNote: loadedNote,
            saveState: _saveState,
            breadcrumbSegments: loadedNote != null
                ? _buildBreadcrumbSegments(loadedNote)
                : const [],
            onToggleNoteList: isDesktop
                ? () => ref.read(noteListVisibleProvider.notifier).toggle()
                : () {
                    final folderId = loadedNote?.folderId ??
                        ref.read(noteProvider).currentFolderId;
                    if (folderId != null) {
                      context.go(
                          '${RouteNames.appFolders}/$folderId');
                    } else {
                      context.go(RouteNames.appFolders);
                    }
                  },
            onActionsMenu: (pos) async {
              if (loadedNote == null) return;
              if (isDesktop) {
                await showNoteContextMenu(
                  context: context,
                  globalPosition: pos,
                );
              } else {
                await showNoteActionsSheet(
                  context: context,
                  note: loadedNote,
                  ref: ref,
                );
              }
            },
          ),
          // ── Desktop docked format toolbar ─────────────────────────────
          if (isDesktop && _loadState == _LoadState.loaded)
            _DockedFormatBar(
              controller: _quillController,
              editorFocusNode: _editorFocus,
            ),
          // ── Editor body ──────────────────────────────────────────────────
          Expanded(
            child: switch (_loadState) {
              _LoadState.loading => const _LoadingSkeleton(),
              _LoadState.error => _ErrorState(
                  message: _loadError ?? 'Failed to load note',
                  onRetry: () => _loadNote(selectedNoteId),
                ),
              _ => _EditorBody(
                  quillController: _quillController,
                  editorFocus: _editorFocus,
                  scrollController: _scrollController,
                  titleController: _titleController,
                  onTitleChanged: _onTitleChanged,
                  noteUpdatedAt: _noteUpdatedAt,
                  paragraphCount: _paragraphCount,
                  editorPad: tokens.editorPad,
                  isDesktop: isDesktop,
                ),
            },
          ),
          // ── Attachment bar ──────────────────────────────────────────
          if (_loadState == _LoadState.loaded && _loadedNoteId != null)
            AttachmentBar(noteId: _loadedNoteId!),
          // ── Mobile docked format toolbar ──────────────────────────────
          if (!isDesktop && _loadState == _LoadState.loaded)
            _DockedFormatBar(
              controller: _quillController,
              editorFocusNode: _editorFocus,
              scrollable: true,
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Topbar
// ---------------------------------------------------------------------------

class _Topbar extends StatelessWidget {
  const _Topbar({
    required this.isDesktop,
    required this.loadedNote,
    required this.saveState,
    required this.breadcrumbSegments,
    required this.onToggleNoteList,
    required this.onActionsMenu,
  });

  final bool isDesktop;
  final Note? loadedNote;
  final _SaveState saveState;
  final List<String> breadcrumbSegments;
  final VoidCallback onToggleNoteList;
  final void Function(Offset globalPosition) onActionsMenu;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: const BoxDecoration(
        color: LnColors.lnSurface,
        border: Border(
          bottom: BorderSide(color: LnColors.lnBorder, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Left: toggle / back button
          if (isDesktop)
            _TopbarIconButton(
              icon: Icons.view_sidebar_outlined,
              onTap: onToggleNoteList,
            )
          else
            _TopbarIconButton(
              icon: Icons.chevron_left,
              onTap: onToggleNoteList,
            ),

          // Centre: breadcrumb or note title
          Expanded(
            child: isDesktop
                ? _Breadcrumb(segments: breadcrumbSegments)
                : _MobileTitle(note: loadedNote),
          ),

          // Save indicator
          _SaveIndicator(state: saveState),

          // Right: ··· actions button
          Builder(
            builder: (ctx) => _TopbarIconButton(
              icon: Icons.more_horiz,
              onTap: () {
                final box = ctx.findRenderObject() as RenderBox?;
                final pos = box?.localToGlobal(
                      Offset(box.size.width, box.size.height),
                    ) ??
                    Offset.zero;
                onActionsMenu(pos);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TopbarIconButton extends StatelessWidget {
  const _TopbarIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 44,
      child: IconButton(
        icon: Icon(icon, size: 18, color: LnColors.lnText3),
        onPressed: onTap,
        splashRadius: 16,
      ),
    );
  }
}

class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({required this.segments});

  final List<String> segments;

  @override
  Widget build(BuildContext context) {
    if (segments.isEmpty) return const SizedBox.shrink();

    final widgets = <Widget>[];
    for (var i = 0; i < segments.length; i++) {
      final isLast = i == segments.length - 1;
      final isSecondToLast = i == segments.length - 2;
      final color =
          (isLast || isSecondToLast) ? LnColors.lnText2 : LnColors.lnText3;

      widgets.add(
        Text(
          segments[i],
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11,
            fontWeight: FontWeight.w400,
            color: color,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      );

      if (!isLast) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '/',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                color: LnColors.lnText3,
              ),
            ),
          ),
        );
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(mainAxisSize: MainAxisSize.min, children: widgets),
    );
  }
}

class _MobileTitle extends StatelessWidget {
  const _MobileTitle({required this.note});

  final Note? note;

  @override
  Widget build(BuildContext context) {
    final title =
        (note?.title.isEmpty ?? true) ? 'Untitled' : note!.title;
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: LnColors.lnText2,
      ),
      textAlign: TextAlign.center,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _SaveIndicator extends StatelessWidget {
  const _SaveIndicator({required this.state});

  final _SaveState state;

  @override
  Widget build(BuildContext context) {
    if (state == _SaveState.idle) return const SizedBox.shrink();

    final (text, color) = switch (state) {
      _SaveState.saving => ('Saving\u2026', LnColors.lnText3),
      _SaveState.saved => ('Saved', LnColors.lnText3),
      _SaveState.error => ('Save failed', LnColors.lnDanger),
      _SaveState.idle => ('', LnColors.lnText3),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        text,
        style: GoogleFonts.jetBrainsMono(fontSize: 10, color: color),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mobile-web clipboard menu
// ---------------------------------------------------------------------------

// On mobile web, QuillRawEditorState.showToolbar() returns false unconditionally
// (it expects the browser's native context menu). But Flutter's pointer event
// handling prevents the browser from generating a contextmenu event via
// long-press. This helper is invoked from onSingleLongTapEnd to show a
// Flutter-native popup instead.
bool get _isMobileWeb =>
    kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

Future<void> _showEditorClipboardMenu(
  BuildContext context,
  Offset globalPosition,
  QuillController controller,
) async {
  final sel = controller.selection;
  final hasSelection = !sel.isCollapsed;

  final result = await showMenu<String>(
    context: context,
    position: RelativeRect.fromLTRB(
      globalPosition.dx,
      globalPosition.dy,
      globalPosition.dx + 1,
      globalPosition.dy + 1,
    ),
    items: [
      if (hasSelection) ...[
        const PopupMenuItem<String>(value: 'copy', child: Text('Copy')),
        const PopupMenuItem<String>(value: 'cut', child: Text('Cut')),
      ],
      const PopupMenuItem<String>(value: 'paste', child: Text('Paste')),
      const PopupMenuItem<String>(value: 'selectAll', child: Text('Select All')),
    ],
  );

  if (!context.mounted) return;

  switch (result) {
    case 'copy':
      await Clipboard.setData(ClipboardData(text: controller.getPlainText()));
    case 'cut':
      await Clipboard.setData(ClipboardData(text: controller.getPlainText()));
      controller.replaceText(sel.start, sel.end - sel.start, '', null);
    case 'paste':
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text case final txt?) {
        final index = sel.isCollapsed ? sel.baseOffset : sel.start;
        final length = sel.isCollapsed ? 0 : sel.end - sel.start;
        controller.replaceText(index, length, txt, null);
      }
    case 'selectAll':
      controller.updateSelection(
        TextSelection(
          baseOffset: 0,
          extentOffset: controller.document.length - 1,
        ),
        ChangeSource.local,
      );
    default:
      break;
  }
}

// ---------------------------------------------------------------------------
// Editor body
// ---------------------------------------------------------------------------

class _EditorBody extends StatelessWidget {
  const _EditorBody({
    required this.quillController,
    required this.editorFocus,
    required this.scrollController,
    required this.titleController,
    required this.onTitleChanged,
    required this.noteUpdatedAt,
    required this.paragraphCount,
    required this.editorPad,
    required this.isDesktop,
  });

  final QuillController quillController;
  final FocusNode editorFocus;
  final ScrollController scrollController;
  final TextEditingController titleController;
  final VoidCallback onTitleChanged;
  final DateTime? noteUpdatedAt;
  final int paragraphCount;
  final double editorPad;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: LnColors.lnBg,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.fromLTRB(editorPad, 40, editorPad, 140),
            children: [
              // Title
              _TitleField(
                controller: titleController,
                isDesktop: isDesktop,
                onChanged: (_) => onTitleChanged(),
              ),
              const SizedBox(height: 8),
              // Meta row
              if (noteUpdatedAt != null)
                _MetaRow(
                  updatedAt: noteUpdatedAt!,
                  paragraphCount: paragraphCount,
                ),
              const SizedBox(height: 24),
              // Quill editor
              QuillEditor(
                controller: quillController,
                focusNode: editorFocus,
                scrollController: ScrollController(),
                config: QuillEditorConfig(
                  scrollable: false,
                  expands: false,
                  padding: EdgeInsets.zero,
                  autoFocus: false,
                  placeholder: 'Start writing\u2026',
                  customStyles: _buildStyles(),
                  onSingleLongTapEnd: _isMobileWeb
                      ? (details, _) {
                          _showEditorClipboardMenu(
                            context,
                            details.globalPosition,
                            quillController,
                          );
                          return false;
                        }
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  DefaultStyles _buildStyles() {
    const hz = HorizontalSpacing(0, 0);
    return DefaultStyles(
      h1: DefaultTextBlockStyle(
        GoogleFonts.inter(
          fontSize: 26,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.42,
          color: LnColors.lnText,
        ),
        hz,
        const VerticalSpacing(40, 14),
        VerticalSpacing.zero,
        null,
      ),
      h2: DefaultTextBlockStyle(
        LnTextStyles.sectionHeader(),
        hz,
        const VerticalSpacing(32, 12),
        VerticalSpacing.zero,
        null,
      ),
      h3: DefaultTextBlockStyle(
        LnTextStyles.subHeader(),
        hz,
        const VerticalSpacing(24, 8),
        VerticalSpacing.zero,
        null,
      ),
      paragraph: DefaultTextBlockStyle(
        GoogleFonts.inter(
          fontSize: 15.5,
          fontWeight: FontWeight.w400,
          height: 1.65,
          color: LnColors.lnText,
        ),
        hz,
        const VerticalSpacing(0, 14),
        VerticalSpacing.zero,
        null,
      ),
      lists: DefaultListBlockStyle(
        GoogleFonts.inter(
          fontSize: 15.5,
          fontWeight: FontWeight.w400,
          height: 1.65,
          color: LnColors.lnText,
        ),
        const HorizontalSpacing(22, 0),
        const VerticalSpacing(0, 5),
        VerticalSpacing.zero,
        null,
        null,
      ),
      quote: DefaultTextBlockStyle(
        GoogleFonts.inter(
          fontSize: 15.5,
          fontStyle: FontStyle.italic,
          color: LnColors.lnText2,
          height: 1.65,
        ),
        const HorizontalSpacing(16, 0),
        const VerticalSpacing(0, 14),
        VerticalSpacing.zero,
        const BoxDecoration(
          border: Border(
            left: BorderSide(color: LnColors.lnBorder3, width: 2),
          ),
        ),
      ),
      code: DefaultTextBlockStyle(
        GoogleFonts.jetBrainsMono(
          fontSize: 13,
          color: LnColors.lnText,
          height: 1.6,
        ),
        const HorizontalSpacing(14, 14),
        const VerticalSpacing(16, 16),
        VerticalSpacing.zero,
        BoxDecoration(
          color: LnColors.lnSurface3,
          borderRadius: BorderRadius.circular(LnDims.r6),
          border: Border.all(color: LnColors.lnBorder2),
        ),
      ),
      inlineCode: InlineCodeStyle(
        style: GoogleFonts.jetBrainsMono(fontSize: 13.5),
        backgroundColor: LnColors.lnSurface2,
        radius: const Radius.circular(LnDims.r4),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Title field
// ---------------------------------------------------------------------------

class _TitleField extends StatelessWidget {
  const _TitleField({
    required this.controller,
    required this.isDesktop,
    required this.onChanged,
  });

  final TextEditingController controller;
  final bool isDesktop;
  final void Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: isDesktop
          ? LnTextStyles.noteTitle()
          : LnTextStyles.noteTitle().copyWith(
              fontSize: 22,
              letterSpacing: -0.33,
            ),
      decoration: InputDecoration(
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        hintText: 'Untitled',
        hintStyle: isDesktop
            ? LnTextStyles.noteTitle(color: LnColors.lnText3)
            : LnTextStyles.noteTitle(color: LnColors.lnText3).copyWith(
                fontSize: 22,
                letterSpacing: -0.33,
              ),
        isDense: true,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Meta row
// ---------------------------------------------------------------------------

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.updatedAt, required this.paragraphCount});

  final DateTime updatedAt;
  final int paragraphCount;

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
    return '${(diff.inDays / 365).floor()}y ago';
  }

  @override
  Widget build(BuildContext context) {
    final para =
        paragraphCount == 1 ? '1 paragraph' : '$paragraphCount paragraphs';
    return Text(
      'Modified ${_relativeTime(updatedAt)} · $para',
      style: LnTextStyles.timestamp(),
    );
  }
}

// ---------------------------------------------------------------------------
// Loading skeleton
// ---------------------------------------------------------------------------

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(48, 40, 48, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SkeletonLine(width: 300, height: 36),
          const SizedBox(height: 12),
          _SkeletonLine(width: 180, height: 12),
          const SizedBox(height: 32),
          _SkeletonLine(width: double.infinity, height: 14),
          const SizedBox(height: 10),
          _SkeletonLine(width: double.infinity, height: 14),
          const SizedBox(height: 10),
          _SkeletonLine(width: 420, height: 14),
        ],
      ),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: LnColors.lnSurface2,
        borderRadius: BorderRadius.circular(LnDims.r4),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error state
// ---------------------------------------------------------------------------

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Failed to load note',
            style: LnTextStyles.bodyComfortable(color: LnColors.lnText2),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onRetry,
            child: Text(
              'Retry',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: LnColors.lnAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state (no note selected)
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Select a note',
        style: LnTextStyles.timestamp(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Docked format bar (used for both desktop and mobile layouts)
// ---------------------------------------------------------------------------

class _DockedFormatBar extends StatelessWidget {
  const _DockedFormatBar({
    required this.controller,
    required this.editorFocusNode,
    this.scrollable = false,
  });

  final QuillController controller;
  final FocusNode editorFocusNode;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: const BoxDecoration(
        color: LnColors.lnSurface2,
        border: Border(
          top: BorderSide(color: LnColors.lnBorder, width: 1),
          bottom: BorderSide(color: LnColors.lnBorder, width: 1),
        ),
      ),
      child: FormatToolbar(
        controller: controller,
        scrollable: scrollable,
        editorFocusNode: editorFocusNode,
      ),
    );
  }
}
