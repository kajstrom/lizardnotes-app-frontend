import 'package:flutter/material.dart';

import '../../../theme/colour_tokens.dart';
import '../../../theme/text_styles.dart';
import '../providers/search_provider.dart';
import '../utils/highlight_builder.dart';

class NoteResultRow extends StatelessWidget {
  const NoteResultRow({
    super.key,
    required this.result,
    required this.isActive,
    required this.onTap,
  });

  final NoteSearchResult result;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SearchResultHoverRow(
      forceActive: isActive,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                children: buildHighlightSpans(
                  result.note.title.isEmpty ? 'Untitled' : result.note.title,
                  result.titleMatchRanges,
                  normalStyle: LnTextStyles.noteCardTitle(),
                  highlightStyle: LnTextStyles.noteCardTitle(
                    color: LnColors.lnAccent2,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            if (result.matchSnippet != null && result.matchSnippet!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: RichText(
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    children: buildHighlightSpans(
                      result.matchSnippet!,
                      result.snippetMatchRanges,
                      normalStyle: LnTextStyles.noteCardPreview(),
                      highlightStyle: LnTextStyles.noteCardPreview(
                        color: LnColors.lnAccent2,
                      ),
                    ),
                  ),
                ),
              ),
            if (result.folderPath.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  result.folderPath,
                  style: LnTextStyles.sectionLabel(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Hover-aware container shared by all search result row widgets.
class SearchResultHoverRow extends StatefulWidget {
  const SearchResultHoverRow({
    super.key,
    required this.child,
    required this.onTap,
    required this.forceActive,
  });

  final Widget child;
  final VoidCallback onTap;
  final bool forceActive;

  @override
  State<SearchResultHoverRow> createState() => _SearchResultHoverRowState();
}

class _SearchResultHoverRowState extends State<SearchResultHoverRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.forceActive || _hovered;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          color: active ? LnColors.lnAccentBg : Colors.transparent,
          child: widget.child,
        ),
      ),
    );
  }
}
