class Attachment {
  const Attachment({
    required this.attachmentId,
    required this.noteId,
    required this.filename,
    required this.mimeType,
    required this.size,
    required this.createdAt,
  });

  final String attachmentId;
  final String noteId;
  final String filename;
  final String mimeType;
  final int size;
  final DateTime createdAt;

  factory Attachment.fromJson(Map<String, dynamic> json) => Attachment(
        attachmentId: json['attachmentId'] as String,
        noteId: json['noteId'] as String,
        filename: json['filename'] as String,
        mimeType: json['mimeType'] as String,
        size: (json['size'] as num).toInt(),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'attachmentId': attachmentId,
        'noteId': noteId,
        'filename': filename,
        'mimeType': mimeType,
        'size': size,
        'createdAt': createdAt.toIso8601String(),
      };
}

class CreateAttachmentResult {
  const CreateAttachmentResult({
    required this.attachment,
    required this.uploadUrl,
  });

  final Attachment attachment;
  final String uploadUrl;
}
