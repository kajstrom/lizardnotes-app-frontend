import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/colour_tokens.dart';

enum NoteMenuAction { rename, moveTo, copyLink, delete }

/// Shows a context menu positioned at [globalPosition], clamped to the
/// viewport. Returns the chosen [NoteMenuAction] or null if dismissed.
Future<NoteMenuAction?> showNoteContextMenu({
  required BuildContext context,
  required Offset globalPosition,
}) async {
  final overlayState = Overlay.of(context);
  final overlayBox =
      overlayState.context.findRenderObject()! as RenderBox;
  final screenSize = overlayBox.size;

  const menuWidth = 192.0;
  const menuHeight = 180.0;

  final dx = (globalPosition.dx + menuWidth > screenSize.width)
      ? screenSize.width - menuWidth - 4
      : globalPosition.dx;
  final dy = (globalPosition.dy + menuHeight > screenSize.height)
      ? screenSize.height - menuHeight - 4
      : globalPosition.dy;

  final completer = Completer<NoteMenuAction?>();
  OverlayEntry? entry;

  void close([NoteMenuAction? action]) {
    if (completer.isCompleted) return;
    entry?.remove();
    entry = null;
    completer.complete(action);
  }

  entry = OverlayEntry(
    builder: (_) => _ContextMenuOverlay(
      position: Offset(dx, dy),
      onClose: close,
    ),
  );

  overlayState.insert(entry!);
  return completer.future;
}

// ---------------------------------------------------------------------------
// Overlay
// ---------------------------------------------------------------------------

class _ContextMenuOverlay extends StatelessWidget {
  const _ContextMenuOverlay({
    required this.position,
    required this.onClose,
  });

  final Offset position;
  final void Function([NoteMenuAction?]) onClose;

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () => onClose(),
      },
      child: Focus(
        autofocus: true,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => onClose(),
                behavior: HitTestBehavior.opaque,
              ),
            ),
            Positioned(
              left: position.dx,
              top: position.dy,
              child: _MenuContent(onClose: onClose),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Menu content
// ---------------------------------------------------------------------------

class _MenuContent extends StatelessWidget {
  const _MenuContent({required this.onClose});

  final void Function([NoteMenuAction?]) onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 192,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: LnColors.lnSurface3,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: LnColors.lnBorder3),
          boxShadow: const [
            BoxShadow(
              color: Color(0x50000000),
              blurRadius: 14,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MenuItem(
              label: 'Rename',
              icon: Icons.edit_outlined,
              onTap: () => onClose(NoteMenuAction.rename),
            ),
            _MenuItem(
              label: 'Move to folder\u2026',
              icon: Icons.drive_file_move_outlined,
              onTap: () => onClose(NoteMenuAction.moveTo),
            ),
            _MenuItem(
              label: 'Copy link',
              icon: Icons.link,
              onTap: () => onClose(NoteMenuAction.copyLink),
            ),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 3),
              height: 1,
              color: LnColors.lnBorder2,
            ),
            _MenuItem(
              label: 'Delete',
              icon: Icons.delete_outline,
              isDanger: true,
              onTap: () => onClose(NoteMenuAction.delete),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Menu item
// ---------------------------------------------------------------------------

class _MenuItem extends StatefulWidget {
  const _MenuItem({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isDanger = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isDanger;

  @override
  State<_MenuItem> createState() => _MenuItemState();
}

class _MenuItemState extends State<_MenuItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bg = _hovered
        ? (widget.isDanger ? LnColors.lnDangerBg : LnColors.lnAccentBg)
        : Colors.transparent;
    final textColor = _hovered
        ? (widget.isDanger ? LnColors.lnDanger : LnColors.lnAccent2)
        : (widget.isDanger ? LnColors.lnDanger : LnColors.lnText);
    final iconColor = _hovered
        ? (widget.isDanger ? LnColors.lnDanger : LnColors.lnAccent2)
        : LnColors.lnText2;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 14, color: iconColor),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w400,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
