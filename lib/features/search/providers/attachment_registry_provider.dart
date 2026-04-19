import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../attachments/models/attachment.dart';

// Accumulates every Attachment list that has been loaded into memory, keyed by
// noteId. Written by AttachmentNotifier.loadAttachments(); read by SearchNotifier
// for attachment filename search.
final attachmentRegistryProvider = NotifierProvider<AttachmentRegistryNotifier,
    Map<String, List<Attachment>>>(
  AttachmentRegistryNotifier.new,
);

class AttachmentRegistryNotifier
    extends Notifier<Map<String, List<Attachment>>> {
  @override
  Map<String, List<Attachment>> build() => const {};

  void register(String noteId, List<Attachment> attachments) {
    state = {...state, noteId: attachments};
  }
}
