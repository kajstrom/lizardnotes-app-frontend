import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/colour_tokens.dart';
import '../../../theme/text_styles.dart';
import '../../folders/providers/folder_provider.dart';
import '../providers/search_provider.dart';

class SearchFilterChips extends ConsumerWidget {
  const SearchFilterChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeFilter = ref.watch(searchProvider.select((s) => s.activeFilter));
    final selectedFolderId = ref.watch(selectedFolderIdProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _chip(
              ref,
              label: 'All',
              filter: SearchFilter.all,
              active: activeFilter == SearchFilter.all,
            ),
            const SizedBox(width: 6),
            _chip(
              ref,
              label: 'Notes',
              filter: SearchFilter.notes,
              active: activeFilter == SearchFilter.notes,
            ),
            const SizedBox(width: 6),
            _chip(
              ref,
              label: 'Attachments',
              filter: SearchFilter.attachments,
              active: activeFilter == SearchFilter.attachments,
            ),
            const SizedBox(width: 6),
            _chip(
              ref,
              label: 'This folder',
              filter: SearchFilter.thisFolder,
              active: activeFilter == SearchFilter.thisFolder,
              disabled: selectedFolderId == null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(
    WidgetRef ref, {
    required String label,
    required SearchFilter filter,
    required bool active,
    bool disabled = false,
  }) {
    final effectiveActive = active && !disabled;
    final bg = effectiveActive
        ? LnColors.lnAccentBg
        : disabled
            ? LnColors.lnSurface2
            : LnColors.lnSurface3;
    final textColor = effectiveActive
        ? LnColors.lnAccent2
        : disabled
            ? LnColors.lnText3
            : LnColors.lnText2;
    final borderColor = effectiveActive ? LnColors.lnAccent : LnColors.lnBorder2;

    return GestureDetector(
      onTap: disabled
          ? null
          : () => ref.read(searchProvider.notifier).setFilter(filter),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label, style: LnTextStyles.primaryButton(color: textColor)),
      ),
    );
  }
}
