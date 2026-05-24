import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/colour_tokens.dart';
import '../../../theme/dimensions.dart';
import '../../../theme/text_styles.dart';
import '../../attachments/providers/attachment_provider.dart';
import '../../attachments/widgets/upload_overlay.dart';

/// Opens the image picker as a dialog (desktop) or bottom sheet (mobile).
///
/// Returns the selected [AttachmentItem], or null if dismissed.
Future<AttachmentItem?> showImagePickerDialog({
  required BuildContext context,
  required String noteId,
}) {
  final isDesktop = MediaQuery.of(context).size.width >= 600;
  if (isDesktop) {
    return showDialog<AttachmentItem>(
      context: context,
      builder: (_) => _ImagePickerAlertDialog(noteId: noteId),
    );
  }
  return showModalBottomSheet<AttachmentItem>(
    context: context,
    backgroundColor: LnColors.lnSurface2,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
    ),
    builder: (_) => ImagePickerDialog(noteId: noteId),
  );
}

/// The picker content — use directly inside showModalBottomSheet or wrap in
/// an AlertDialog via [_ImagePickerAlertDialog].
class ImagePickerDialog extends ConsumerWidget {
  const ImagePickerDialog({super.key, required this.noteId});

  final String noteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(attachmentProvider(noteId));
    final imageItems = state.items
        .where((i) => i.attachment.mimeType.startsWith('image/'))
        .toList();

    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Insert image', style: LnTextStyles.modalTitle()),
              const Spacer(),
              TextButton.icon(
                onPressed: () =>
                    showUploadOverlay(context: context, noteId: noteId),
                icon: const Icon(Icons.upload_outlined,
                    size: 15, color: LnColors.lnAccent2),
                label: Text(
                  'Upload image',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: LnColors.lnAccent2),
                ),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (imageItems.isEmpty)
            const _EmptyState()
          else
            _ImageList(
              items: imageItems,
              onSelected: (item) => Navigator.of(context).pop(item),
            ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                    fontSize: 13, color: LnColors.lnText2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImagePickerAlertDialog extends StatelessWidget {
  const _ImagePickerAlertDialog({required this.noteId});

  final String noteId;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: LnColors.lnSurface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LnDims.r10),
        side: const BorderSide(color: LnColors.lnBorder3),
      ),
      contentPadding: EdgeInsets.zero,
      content: SizedBox(
        width: 440,
        child: ImagePickerDialog(noteId: noteId),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          const Icon(Icons.image_outlined,
              size: 32, color: LnColors.lnText3),
          const SizedBox(height: 8),
          Text('No images yet',
              style: LnTextStyles.bodyComfortable(color: LnColors.lnText2)),
          const SizedBox(height: 4),
          Text('Upload one using the button above.',
              style: LnTextStyles.timestamp()),
        ],
      ),
    );
  }
}

class _ImageList extends StatelessWidget {
  const _ImageList({required this.items, required this.onSelected});

  final List<AttachmentItem> items;
  final void Function(AttachmentItem) onSelected;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 300),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: items.length,
        separatorBuilder: (_, _) =>
            const Divider(height: 1, color: LnColors.lnBorder),
        itemBuilder: (_, i) {
          final item = items[i];
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onSelected(item),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.image_outlined,
                        size: 18, color: LnColors.lnText2),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item.attachment.filename,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: LnColors.lnText,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
