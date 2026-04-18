class Note {
  const Note({
    required this.noteId,
    required this.folderId,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  final String noteId;
  final String folderId;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;

  Note copyWith({
    String? noteId,
    String? folderId,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Note(
        noteId: noteId ?? this.noteId,
        folderId: folderId ?? this.folderId,
        title: title ?? this.title,
        content: content ?? this.content,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  factory Note.fromJson(Map<String, dynamic> json) => Note(
        noteId: json['noteId'] as String,
        folderId: json['folderId'] as String,
        title: json['title'] as String,
        content: json['content'] as String? ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'noteId': noteId,
        'folderId': folderId,
        'title': title,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}
