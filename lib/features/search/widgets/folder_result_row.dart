import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/colour_tokens.dart';
import '../../../theme/text_styles.dart';
import '../providers/search_provider.dart';
import '../utils/highlight_builder.dart';
import 'note_result_row.dart';

class FolderResultRow extends StatelessWidget {
  const FolderResultRow({
    super.key,
    required this.result,
    required this.isActive,
    required this.onTap,
  });

  final FolderSearchResult result;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SearchResultHoverRow(
      forceActive: isActive,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Row(
          children: [
            const Icon(
              Icons.folder_outlined,
              size: 15,
              color: LnColors.lnText3,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: RichText(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  children: buildHighlightSpans(
                    result.folder.name,
                    result.nameMatchRanges,
                    normalStyle: LnTextStyles.noteCardTitle(),
                    highlightStyle: LnTextStyles.noteCardTitle(
                      color: LnColors.lnAccent2,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
            if (result.folder.path.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  result.folder.path,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    color: LnColors.lnText3,
                  ),
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
