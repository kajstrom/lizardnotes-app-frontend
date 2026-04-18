import 'package:flutter/material.dart';

import '../../../theme/colour_tokens.dart';
import '../../../theme/text_styles.dart';
import '../models/note.dart';

class NoteTile extends StatefulWidget {
  const NoteTile({
    super.key,
    required this.note,
    required this.isActive,
    required this.onTap,
    this.onContextMenu,
    this.onLongPress,
  });

  final Note note;
  final bool isActive;
  final VoidCallback onTap;
  /// Called with the global position when the user right-clicks or taps ···.
  final void Function(Offset globalPosition)? onContextMenu;
  final VoidCallback? onLongPress;

  @override
  State<NoteTile> createState() => _NoteTileState();
}

class _NoteTileState extends State<NoteTile> {
  bool _hovered = false;

  Color get _bgColor {
    if (widget.isActive) return LnColors.lnAccentBg;
    if (_hovered) return LnColors.lnSurface3;
    return Colors.transparent;
  }

  Color get _borderColor {
    if (widget.isActive) return const Color(0x47_7c6fcd); // rgba(124,111,205,0.28)
    return Colors.transparent;
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        onSecondaryTapDown: widget.onContextMenu != null
            ? (details) => widget.onContextMenu!(details.globalPosition)
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          padding: const EdgeInsets.only(
              left: 12, top: 10, bottom: 10, right: 4),
          decoration: BoxDecoration(
            color: _bgColor,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _borderColor),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Text content ──────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.note.title.isEmpty
                          ? 'Untitled'
                          : widget.note.title,
                      style: LnTextStyles.noteCardTitle(
                        color: widget.isActive
                            ? LnColors.lnAccent2
                            : LnColors.lnText,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    if (widget.note.content.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        widget.note.content,
                        style: LnTextStyles.noteCardPreview(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 5),
                    Text(
                      _relativeTime(widget.note.updatedAt),
                      style: LnTextStyles.timestamp(),
                    ),
                  ],
                ),
              ),
              // ── ··· button ────────────────────────────────────────────────
              if (widget.onContextMenu != null)
                AnimatedOpacity(
                  opacity: _hovered || widget.isActive ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 120),
                  child: _MoreButton(onTap: widget.onContextMenu!),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ··· button
// ---------------------------------------------------------------------------

class _MoreButton extends StatefulWidget {
  const _MoreButton({required this.onTap});

  final void Function(Offset globalPosition) onTap;

  @override
  State<_MoreButton> createState() => _MoreButtonState();
}

class _MoreButtonState extends State<_MoreButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (d) => widget.onTap(d.globalPosition),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            color: _hovered ? LnColors.lnSurface3 : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Icon(
            Icons.more_horiz,
            size: 14,
            color: LnColors.lnText3,
          ),
        ),
      ),
    );
  }
}

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
