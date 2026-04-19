import 'package:flutter/material.dart';

import '../../../theme/colour_tokens.dart';
import '../../../theme/text_styles.dart';
import '../providers/search_provider.dart';
import '../utils/highlight_builder.dart';
import 'note_result_row.dart';

class AttachmentResultRow extends StatelessWidget {
  const AttachmentResultRow({
    super.key,
    required this.result,
    required this.isActive,
    required this.onTap,
  });

  final AttachmentSearchResult result;
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
            Row(
              children: [
                const Icon(
                  Icons.attach_file,
                  size: 14,
                  color: LnColors.lnText3,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: RichText(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      children: buildHighlightSpans(
                        result.attachment.filename,
                        result.filenameMatchRanges,
                        normalStyle: LnTextStyles.noteCardTitle(),
                        highlightStyle: LnTextStyles.noteCardTitle(
                          color: LnColors.lnAccent2,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                result.parentNote.title.isEmpty
                    ? 'Untitled'
                    : result.parentNote.title,
                style: LnTextStyles.noteCardPreview(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
