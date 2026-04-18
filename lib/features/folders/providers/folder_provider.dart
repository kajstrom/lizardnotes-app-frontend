import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/api_client.dart';
import '../models/folder.dart';

// ---------------------------------------------------------------------------
// Selected folder
// ---------------------------------------------------------------------------

/// The currently selected folder ID. Updated when the user taps a folder tile.
final selectedFolderIdProvider =
    NotifierProvider<SelectedFolderNotifier, String?>(
  SelectedFolderNotifier.new,
);

class SelectedFolderNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) => state = id;
}

// ---------------------------------------------------------------------------
// Folder state
// ---------------------------------------------------------------------------

enum FolderStatus { idle, loading, error }

class FolderState {
  const FolderState({
    this.folders = const [],
    this.status = FolderStatus.idle,
    this.errorMessage,
  });

  final List<Folder> folders;
  final FolderStatus status;
  final String? errorMessage;

  FolderState copyWith({
    List<Folder>? folders,
    FolderStatus? status,
    String? errorMessage,
    bool clearError = false,
  }) =>
      FolderState(
        folders: folders ?? this.folders,
        status: status ?? this.status,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      );
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final folderProvider =
    NotifierProvider<FolderNotifier, FolderState>(FolderNotifier.new);

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class FolderNotifier extends Notifier<FolderState> {
  ApiClient get _api => ref.read(apiClientProvider);

  @override
  FolderState build() => const FolderState();

  Future<void> loadFolders() async {
    state = state.copyWith(status: FolderStatus.loading, clearError: true);
    try {
      final folders = await _api.getFolders();
      state = state.copyWith(folders: folders, status: FolderStatus.idle);
    } catch (e) {
      state = state.copyWith(
        status: FolderStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> createFolder(String name, {String? parentFolderId}) async {
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final temp = Folder(
      folderId: tempId,
      name: name,
      parentFolderId: parentFolderId,
      path: name,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final previous = List<Folder>.unmodifiable(state.folders);
    state = state.copyWith(folders: [...state.folders, temp]);

    try {
      final created = await _api.createFolder(
        name: name,
        parentFolderId: parentFolderId,
      );
      state = state.copyWith(
        folders: state.folders
            .map((f) => f.folderId == tempId ? created : f)
            .toList(),
      );
    } catch (e) {
      state = state.copyWith(
        folders: List<Folder>.from(previous),
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> renameFolder(String folderId, String newName) async {
    final previous = List<Folder>.unmodifiable(state.folders);
    state = state.copyWith(
      folders: state.folders
          .map((f) => f.folderId == folderId ? f.copyWith(name: newName) : f)
          .toList(),
    );
    try {
      final folder = previous.firstWhere((f) => f.folderId == folderId);
      await _api.updateFolder(
        folderId,
        name: newName,
        parentFolderId: folder.parentFolderId,
      );
    } catch (e) {
      state = state.copyWith(
        folders: List<Folder>.from(previous),
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> moveFolder(String folderId, String? newParentFolderId) async {
    final previous = List<Folder>.unmodifiable(state.folders);
    final folder = previous.firstWhere((f) => f.folderId == folderId);
    state = state.copyWith(
      folders: state.folders
          .map(
            (f) => f.folderId == folderId
                ? f.copyWith(parentFolderId: newParentFolderId)
                : f,
          )
          .toList(),
    );
    try {
      await _api.updateFolder(
        folderId,
        name: folder.name,
        parentFolderId: newParentFolderId,
      );
    } catch (e) {
      state = state.copyWith(
        folders: List<Folder>.from(previous),
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> deleteFolder(String folderId) async {
    final previous = List<Folder>.unmodifiable(state.folders);
    final toRemove = _allDescendantIds(folderId)..add(folderId);
    state = state.copyWith(
      folders:
          state.folders.where((f) => !toRemove.contains(f.folderId)).toList(),
    );
    try {
      await _api.deleteFolder(folderId);
    } catch (e) {
      state = state.copyWith(
        folders: List<Folder>.from(previous),
        errorMessage: e.toString(),
      );
    }
  }

  /// Returns direct children of [parentFolderId] (null = root level).
  List<Folder> childrenOf(String? parentFolderId) => state.folders
      .where((f) => f.parentFolderId == parentFolderId)
      .toList();

  /// Returns all descendant folder IDs for [folderId] (not including itself).
  Set<String> allDescendantIds(String folderId) {
    final result = <String>{};
    final queue = childrenOf(folderId).map((f) => f.folderId).toList();
    while (queue.isNotEmpty) {
      final id = queue.removeAt(0);
      result.add(id);
      queue.addAll(childrenOf(id).map((f) => f.folderId));
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Set<String> _allDescendantIds(String folderId) => allDescendantIds(folderId);
}
