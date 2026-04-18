class Folder {
  const Folder({
    required this.folderId,
    required this.name,
    this.parentFolderId,
    required this.path,
    required this.createdAt,
    required this.updatedAt,
  });

  final String folderId;
  final String name;

  /// null means this is a root-level folder.
  final String? parentFolderId;
  final String path;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Folder.fromJson(Map<String, dynamic> json) => Folder(
        folderId: json['folderId'] as String,
        name: json['name'] as String,
        parentFolderId: json['parentFolderId'] as String?,
        path: json['path'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'folderId': folderId,
        'name': name,
        if (parentFolderId != null) 'parentFolderId': parentFolderId,
        'path': path,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  Folder copyWith({
    String? name,
    Object? parentFolderId = _sentinel,
  }) =>
      Folder(
        folderId: folderId,
        name: name ?? this.name,
        parentFolderId: identical(parentFolderId, _sentinel)
            ? this.parentFolderId
            : parentFolderId as String?,
        path: path,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}

const _sentinel = Object();
