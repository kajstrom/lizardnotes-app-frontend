import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/colour_tokens.dart';
import '../../../theme/dimensions.dart';

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
    this.scrollable = false,
    this.editorFocusNode,
  });

  final QuillController controller;
  final bool scrollable;
  /// When provided, focus is restored to the editor after every format action.
  /// This prevents the toolbar from permanently stealing focus on web.
  final FocusNode? editorFocusNode;

  @override
  State<FormatToolbar> createState() => _FormatToolbarState();
}

class _FormatToolbarState extends State<FormatToolbar> {
  // Last known non-collapsed selection. Saved on every controller change so
  // we can restore it before formatting — tapping a toolbar button shifts
  // focus away from the editor and collapses the selection before onTap fires.
  TextSelection? _savedSelection;

  @override
  void initState() {
    super.initState();
    // Snapshot the current selection immediately — the listener won't fire
    // until the next controller change, so without this the very first tap
    // after the toolbar appears would have _savedSelection == null.
    final sel = widget.controller.selection;
    if (!sel.isCollapsed) _savedSelection = sel;
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    final sel = widget.controller.selection;
    if (!sel.isCollapsed) _savedSelection = sel;
    setState(() {});
  }

  bool _isActiveForSel(Attribute attr, TextSelection sel) {
    final style = widget.controller.getSelectionStyle();
    final existing = style.attributes[attr.key];
    if (existing == null) return false;
    if (attr.value == null) return true;
    return existing.value == attr.value;
  }

  bool _isActive(Attribute attr) => _isActiveForSel(attr, widget.controller.selection);

  void _toggle(Attribute attr) {
    final sel = _savedSelection ?? widget.controller.selection;
    if (sel.isCollapsed) return;
    // Use formatText with explicit offsets so we never need to call
    // updateSelection (which would trigger another overlay rebuild cycle).
    final active = _isActiveForSel(attr, sel);
    widget.controller.formatText(
      sel.start,
      sel.end - sel.start,
      active ? Attribute.clone(attr, null) : attr,
    );
    // ExcludeFocus prevents the toolbar from stealing focus, so the editor
    // retains focus throughout. No need to re-request it here; doing so
    // triggers _onEditorFocusChanged → setState → rebuild cascade that causes
    // content loss on web.
  }

  Future<void> _applyLink() async {
    // Snapshot selection now — the dialog will collapse it.
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

  @override
  Widget build(BuildContext context) {
    final buttons = [
      _ToolbarButton(
        label: 'B',
        bold: true,
        isActive: _isActive(Attribute.bold),
        onTap: () => _toggle(Attribute.bold),
      ),
      _ToolbarButton(
        label: 'I',
        italic: true,
        isActive: _isActive(Attribute.italic),
        onTap: () => _toggle(Attribute.italic),
      ),
      const _ToolbarDivider(),
      _ToolbarButton(
        label: 'H1',
        isActive: _isActive(Attribute.h1),
        onTap: () => _toggle(Attribute.h1),
      ),
      _ToolbarButton(
        label: 'H2',
        isActive: _isActive(Attribute.h2),
        onTap: () => _toggle(Attribute.h2),
      ),
      _ToolbarButton(
        label: 'H3',
        isActive: _isActive(Attribute.h3),
        onTap: () => _toggle(Attribute.h3),
      ),
      const _ToolbarDivider(),
      _ToolbarButton(
        label: '• list',
        isActive: _isActive(Attribute.ul),
        onTap: () => _toggle(Attribute.ul),
      ),
      _ToolbarButton(
        label: '1. list',
        isActive: _isActive(Attribute.ol),
        onTap: () => _toggle(Attribute.ol),
      ),
      const _ToolbarDivider(),
      _ToolbarButton(
        label: 'code',
        mono: true,
        isActive: _isActive(Attribute.codeBlock),
        onTap: () => _toggle(Attribute.codeBlock),
      ),
      _ToolbarButton(
        label: 'link',
        isActive: _isActive(Attribute.link),
        onTap: _applyLink,
      ),
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
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final bool bold;
  final bool italic;
  final bool mono;

  @override
  State<_ToolbarButton> createState() => _ToolbarButtonState();
}

class _ToolbarButtonState extends State<_ToolbarButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bg = widget.isActive
        ? LnColors.lnAccentBg
        : (_hovered ? LnColors.lnSurface3 : Colors.transparent);
    final fg = widget.isActive ? LnColors.lnAccent2 : LnColors.lnText2;

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
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
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
