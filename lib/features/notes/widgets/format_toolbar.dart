import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../api/api_client.dart';
import '../../../theme/colour_tokens.dart';
import '../../../theme/dimensions.dart';
import '../../attachments/providers/attachment_provider.dart';
import 'image_picker_dialog.dart';

/// Format toolbar for the WYSIWYG editor.
///
/// Two rendering modes:
/// - [scrollable] = false (default): horizontal fixed-size row for the
///   desktop floating overlay.
/// - [scrollable] = true: horizontally scrollable row for the mobile docked
///   bar.
class FormatToolbar extends StatefulWidget {
  const FormatToolbar({
    super.key,
    required this.controller,
    required this.noteId,
    this.scrollable = false,
    this.editorFocusNode,
    this.showClipboardActions = false,
  });

  final QuillController controller;
  final String noteId;
  final bool scrollable;
  /// When provided, focus is restored to the editor after every format action.
  /// This prevents the toolbar from permanently stealing focus on web.
  final FocusNode? editorFocusNode;

  /// When true, Copy / Cut / Paste / Select All buttons are prepended to the
  /// toolbar. Used on mobile web, where flutter_quill's selection toolbar is
  /// unavailable (it defers to the browser's native menu, which the app
  /// disables) and there are no keyboard shortcuts.
  final bool showClipboardActions;

  @override
  State<FormatToolbar> createState() => _FormatToolbarState();
}

class _FormatToolbarState extends State<FormatToolbar> {
  // Cached selection (any kind, including collapsed). A toolbar tap can shift
  // focus and move the live selection before onTap fires, so we restore from
  // this cache when applying formats.
  TextSelection? _savedSelection;

  // Last-rendered visual signature. The controller fires on every keystroke;
  // we only rebuild when something the toolbar actually shows would change
  // (active button states, link enable/disable). This keeps the always-on
  // desktop toolbar from rebuilding — and re-running ExcludeFocus / Focus —
  // on every cursor movement, which on web can race with the editor's own
  // focus handling and swallow keystrokes.
  _ToolbarVisualState _lastVisual = const _ToolbarVisualState.empty();

  @override
  void initState() {
    super.initState();
    _savedSelection = widget.controller.selection;
    _lastVisual = _computeVisual();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    _savedSelection = widget.controller.selection;
    final next = _computeVisual();
    if (next == _lastVisual) return;
    _lastVisual = next;
    setState(() {});
  }

  _ToolbarVisualState _computeVisual() {
    final style = widget.controller.getSelectionStyle();
    final attrs = style.attributes;
    bool has(Attribute a) {
      final existing = attrs[a.key];
      if (existing == null) return false;
      if (a.value == null) return true;
      return existing.value == a.value;
    }

    final linkActive = attrs[Attribute.link.key] != null;
    return _ToolbarVisualState(
      bold: has(Attribute.bold),
      italic: has(Attribute.italic),
      h1: has(Attribute.h1),
      h2: has(Attribute.h2),
      h3: has(Attribute.h3),
      ul: has(Attribute.ul),
      ol: has(Attribute.ol),
      codeBlock: has(Attribute.codeBlock),
      linkActive: linkActive,
      linkDisabled: widget.controller.selection.isCollapsed && !linkActive,
      hasSelection: !widget.controller.selection.isCollapsed,
    );
  }

  bool _isActive(Attribute attr) {
    final style = widget.controller.getSelectionStyle();
    final existing = style.attributes[attr.key];
    if (existing == null) return false;
    if (attr.value == null) return true;
    return existing.value == attr.value;
  }

  void _toggle(Attribute attr) {
    final sel = _savedSelection ?? widget.controller.selection;
    final active = _isActive(attr);
    // One call covers all cases:
    // - non-collapsed inline mark: applies to the range
    // - collapsed inline mark: arms toggledStyle for the next typed text
    // - block scope at any cursor/selection: applies to the line(s)
    widget.controller.formatText(
      sel.start,
      sel.end - sel.start,
      active ? Attribute.clone(attr, null) : attr,
    );
  }

  Future<void> _applyLink() async {
    // Links are the one format that requires a non-collapsed selection — a
    // link must wrap a span of text, and it can sit inside any block (e.g. a
    // list item), so the selection is what disambiguates the target.
    final sel = _savedSelection ?? widget.controller.selection;
    if (sel.isCollapsed) return;

    final style = widget.controller.getSelectionStyle();
    final existing = style.attributes[Attribute.link.key]?.value as String?;
    final ctrl = TextEditingController(text: existing);

    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => _LinkDialog(controller: ctrl),
    );

    if (url == null) return;
    // Do NOT guard with `mounted` here. Opening the dialog collapses the
    // selection, which removes the floating overlay, which disposes this
    // widget — but the QuillController is still valid and must be updated.
    final attr = url.trim().isEmpty
        ? Attribute.clone(Attribute.link, null)
        : LinkAttribute(url.trim());
    widget.controller.formatText(sel.start, sel.end - sel.start, attr);
  }

  // -------------------------------------------------------------------------
  // Clipboard actions (mobile web)
  // -------------------------------------------------------------------------
  // These read from the cached _savedSelection rather than the live selection,
  // matching how formats are applied: a toolbar tap can shift focus before the
  // handler runs, and ExcludeFocus keeps the editor's selection intact.

  String _selectedText(TextSelection sel) =>
      widget.controller.document.getPlainText(sel.start, sel.end - sel.start);

  Future<void> _copy() async {
    final sel = _savedSelection ?? widget.controller.selection;
    if (sel.isCollapsed) return;
    await Clipboard.setData(ClipboardData(text: _selectedText(sel)));
    widget.editorFocusNode?.requestFocus();
  }

  Future<void> _cut() async {
    final sel = _savedSelection ?? widget.controller.selection;
    if (sel.isCollapsed) return;
    await Clipboard.setData(ClipboardData(text: _selectedText(sel)));
    widget.controller.replaceText(sel.start, sel.end - sel.start, '', null);
    widget.editorFocusNode?.requestFocus();
  }

  Future<void> _paste() async {
    final sel = _savedSelection ?? widget.controller.selection;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text case final txt?) {
      final index = sel.isCollapsed ? sel.baseOffset : sel.start;
      final length = sel.isCollapsed ? 0 : sel.end - sel.start;
      widget.controller.replaceText(index, length, txt, null);
    }
    widget.editorFocusNode?.requestFocus();
  }

  void _selectAll() {
    widget.controller.updateSelection(
      TextSelection(
        baseOffset: 0,
        extentOffset: widget.controller.document.length - 1,
      ),
      ChangeSource.local,
    );
  }

  Future<void> _openImagePicker() async {
    final selected = await showImagePickerDialog(
      context: context,
      noteId: widget.noteId,
    );
    if (selected == null || !mounted) return;
    await _insertImage(selected);
  }

  Future<void> _insertImage(AttachmentItem item) async {
    try {
      final api = ProviderScope.containerOf(context).read(apiClientProvider);
      final url = await api.getAttachmentDownloadUrl(
        noteId: widget.noteId,
        attachmentId: item.attachment.attachmentId,
      );
      if (!mounted) return;
      final sel = _savedSelection ?? widget.controller.selection;
      final index = sel.isCollapsed ? sel.baseOffset : sel.start;
      final length = sel.isCollapsed ? 0 : sel.end - sel.start;
      widget.controller.replaceText(
        index,
        length,
        Embeddable('ln-image', {
          'attachmentId': item.attachment.attachmentId,
          'url': url,
          'caption': '',
        }),
        null,
      );
      widget.editorFocusNode?.requestFocus();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to insert image')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = _lastVisual;
    final buttons = [
      if (widget.showClipboardActions) ...[
        _ToolbarButton(
          label: 'Copy',
          isActive: false,
          disabled: !v.hasSelection,
          onTap: _copy,
        ),
        _ToolbarButton(
          label: 'Cut',
          isActive: false,
          disabled: !v.hasSelection,
          onTap: _cut,
        ),
        _ToolbarButton(
          label: 'Paste',
          isActive: false,
          onTap: _paste,
        ),
        _ToolbarButton(
          label: 'All',
          isActive: false,
          onTap: _selectAll,
        ),
        const _ToolbarDivider(),
      ],
      _ToolbarButton(
        label: 'B',
        bold: true,
        isActive: v.bold,
        onTap: () => _toggle(Attribute.bold),
      ),
      _ToolbarButton(
        label: 'I',
        italic: true,
        isActive: v.italic,
        onTap: () => _toggle(Attribute.italic),
      ),
      const _ToolbarDivider(),
      _ToolbarButton(
        label: 'H1',
        isActive: v.h1,
        onTap: () => _toggle(Attribute.h1),
      ),
      _ToolbarButton(
        label: 'H2',
        isActive: v.h2,
        onTap: () => _toggle(Attribute.h2),
      ),
      _ToolbarButton(
        label: 'H3',
        isActive: v.h3,
        onTap: () => _toggle(Attribute.h3),
      ),
      const _ToolbarDivider(),
      _ToolbarButton(
        label: '• list',
        isActive: v.ul,
        onTap: () => _toggle(Attribute.ul),
      ),
      _ToolbarButton(
        label: '1. list',
        isActive: v.ol,
        onTap: () => _toggle(Attribute.ol),
      ),
      const _ToolbarDivider(),
      _ToolbarButton(
        label: 'code',
        mono: true,
        isActive: v.codeBlock,
        onTap: () => _toggle(Attribute.codeBlock),
      ),
      _ToolbarButton(
        label: 'link',
        isActive: v.linkActive,
        disabled: v.linkDisabled,
        onTap: _applyLink,
      ),
      const _ToolbarDivider(),
      _ImageToolbarButton(onTap: _openImagePicker),
    ];

    // ExcludeFocus prevents any tap on the toolbar from stealing focus away
    // from the QuillEditor (critical on web where mousedown defocuses inputs).
    return ExcludeFocus(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: buttons,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Button
// ---------------------------------------------------------------------------

class _ToolbarButton extends StatefulWidget {
  const _ToolbarButton({
    required this.label,
    required this.isActive,
    required this.onTap,
    this.bold = false,
    this.italic = false,
    this.mono = false,
    this.disabled = false,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final bool bold;
  final bool italic;
  final bool mono;
  final bool disabled;

  @override
  State<_ToolbarButton> createState() => _ToolbarButtonState();
}

class _ToolbarButtonState extends State<_ToolbarButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bg = widget.isActive
        ? LnColors.lnAccentBg
        : (!widget.disabled && _hovered
            ? LnColors.lnSurface3
            : Colors.transparent);
    final fg = widget.disabled
        ? LnColors.lnText3
        : (widget.isActive ? LnColors.lnAccent2 : LnColors.lnText2);

    TextStyle style;
    if (widget.mono) {
      style = GoogleFonts.jetBrainsMono(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: fg,
      );
    } else {
      style = GoogleFonts.inter(
        fontSize: 12,
        fontWeight: widget.bold ? FontWeight.w700 : FontWeight.w400,
        fontStyle: widget.italic ? FontStyle.italic : FontStyle.normal,
        color: fg,
      );
    }

    return MouseRegion(
      cursor: widget.disabled
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.disabled ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(LnDims.r4),
          ),
          child: Text(widget.label, style: style),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Visual state — drives whether the toolbar needs to rebuild
// ---------------------------------------------------------------------------

@immutable
class _ToolbarVisualState {
  const _ToolbarVisualState({
    required this.bold,
    required this.italic,
    required this.h1,
    required this.h2,
    required this.h3,
    required this.ul,
    required this.ol,
    required this.codeBlock,
    required this.linkActive,
    required this.linkDisabled,
    required this.hasSelection,
  });

  const _ToolbarVisualState.empty()
      : bold = false,
        italic = false,
        h1 = false,
        h2 = false,
        h3 = false,
        ul = false,
        ol = false,
        codeBlock = false,
        linkActive = false,
        linkDisabled = true,
        hasSelection = false;

  final bool bold;
  final bool italic;
  final bool h1;
  final bool h2;
  final bool h3;
  final bool ul;
  final bool ol;
  final bool codeBlock;
  final bool linkActive;
  final bool linkDisabled;
  final bool hasSelection;

  @override
  bool operator ==(Object other) =>
      other is _ToolbarVisualState &&
      other.bold == bold &&
      other.italic == italic &&
      other.h1 == h1 &&
      other.h2 == h2 &&
      other.h3 == h3 &&
      other.ul == ul &&
      other.ol == ol &&
      other.codeBlock == codeBlock &&
      other.linkActive == linkActive &&
      other.linkDisabled == linkDisabled &&
      other.hasSelection == hasSelection;

  @override
  int get hashCode => Object.hash(
        bold,
        italic,
        h1,
        h2,
        h3,
        ul,
        ol,
        codeBlock,
        linkActive,
        linkDisabled,
        hasSelection,
      );
}

// ---------------------------------------------------------------------------
// Divider
// ---------------------------------------------------------------------------

class _ToolbarDivider extends StatelessWidget {
  const _ToolbarDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 16,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      color: LnColors.lnBorder2,
    );
  }
}

// ---------------------------------------------------------------------------
// Link dialog
// ---------------------------------------------------------------------------

class _LinkDialog extends StatelessWidget {
  const _LinkDialog({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: LnColors.lnSurface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LnDims.r10),
        side: const BorderSide(color: LnColors.lnBorder3),
      ),
      title: Text(
        'Insert link',
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: LnColors.lnText,
        ),
      ),
      content: TextField(
        controller: controller,
        autofocus: true,
        style: GoogleFonts.inter(fontSize: 14, color: LnColors.lnText),
        decoration: InputDecoration(
          hintText: 'https://',
          hintStyle: GoogleFonts.inter(fontSize: 14, color: LnColors.lnText3),
          filled: true,
          fillColor: LnColors.lnSurface3,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(LnDims.r6),
            borderSide: const BorderSide(color: LnColors.lnBorder2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(LnDims.r6),
            borderSide: const BorderSide(color: LnColors.lnBorder2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(LnDims.r6),
            borderSide: const BorderSide(color: LnColors.lnAccent),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: GoogleFonts.inter(fontSize: 13, color: LnColors.lnText2),
          ),
        ),
        if (controller.text.isNotEmpty)
          TextButton(
            onPressed: () => Navigator.of(context).pop(''),
            child: Text(
              'Remove',
              style: GoogleFonts.inter(
                  fontSize: 13, color: LnColors.lnDanger),
            ),
          ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: LnColors.lnAccent,
            foregroundColor: LnColors.lnText,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(LnDims.r6),
            ),
          ),
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: Text(
            'Apply',
            style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Image toolbar button
// ---------------------------------------------------------------------------

class _ImageToolbarButton extends StatefulWidget {
  const _ImageToolbarButton({required this.onTap});

  // VoidCallback (fire-and-forget) is safe here because _openImagePicker
  // catches all async errors internally via try/catch in _insertImage.
  final VoidCallback onTap;

  @override
  State<_ImageToolbarButton> createState() => _ImageToolbarButtonState();
}

class _ImageToolbarButtonState extends State<_ImageToolbarButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: _hovered ? LnColors.lnSurface3 : Colors.transparent,
            borderRadius: BorderRadius.circular(LnDims.r4),
          ),
          child: const Icon(
            Icons.image_outlined,
            size: 16,
            color: LnColors.lnText2,
          ),
        ),
      ),
    );
  }
}
