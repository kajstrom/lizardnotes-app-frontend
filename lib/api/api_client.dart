import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../features/attachments/models/attachment.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/auth/services/auth_service.dart';
import '../features/folders/models/folder.dart';
import '../features/notes/models/note.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    authService: ref.read(authServiceProvider),
    onSessionExpired: () =>
        ref.read(authProvider.notifier).handleSessionExpired(),
  );
});

class ApiClient {
  ApiClient({
    required AuthService authService,
    required Future<void> Function() onSessionExpired,
  })  : _authService = authService,
        _onSessionExpired = onSessionExpired;

  final AuthService _authService;
  final Future<void> Function() _onSessionExpired;
  bool _expiredHandled = false;

  Future<Map<String, String>> _headers() async {
    final token = await _authService.getValidAccessToken();
    if (token == null) {
      await _notifyExpired();
      throw const AuthExpiredException();
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Uri _uri(String path) => Uri.parse('${AppConfig.apiUrl}$path');

  void _assertSuccess(http.Response response, String context) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    if (response.statusCode == 401) {
      // Fire-and-forget: surface as AuthExpiredException for the caller.
      _notifyExpired();
      throw const AuthExpiredException();
    }
    throw ApiException(response.statusCode, response.body, context);
  }

  Future<void> _notifyExpired() async {
    if (_expiredHandled) return;
    _expiredHandled = true;
    await _onSessionExpired();
  }

  // ── Folders ──────────────────────────────────────────────────────────────

  Future<List<Folder>> getFolders() async {
    final response =
        await http.get(_uri('/folders'), headers: await _headers());
    _assertSuccess(response, 'getFolders');
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => Folder.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Folder> createFolder({
    required String name,
    String? parentFolderId,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'parentFolderId': parentFolderId,
    };
    final response = await http.post(
      _uri('/folders'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    _assertSuccess(response, 'createFolder');
    return Folder.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<Folder> updateFolder(
    String folderId, {
    required String name,
    String? parentFolderId,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'parentFolderId': parentFolderId,
    };
    final response = await http.put(
      _uri('/folders/$folderId'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    _assertSuccess(response, 'updateFolder');
    return Folder.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteFolder(String folderId) async {
    final response = await http.delete(
      _uri('/folders/$folderId'),
      headers: await _headers(),
    );
    _assertSuccess(response, 'deleteFolder');
  }

  // ── Notes ─────────────────────────────────────────────────────────────────

  Future<List<Note>> getNotes({String? folderId}) async {
    final uri = folderId != null
        ? _uri('/notes').replace(queryParameters: {'folderId': folderId})
        : _uri('/notes');
    final response = await http.get(uri, headers: await _headers());
    _assertSuccess(response, 'getNotes');
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => Note.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Note> createNote({
    required String folderId,
    required String title,
  }) async {
    final body = <String, dynamic>{
      'folderId': folderId,
      'title': title,
      'content': '',
    };
    final response = await http.post(
      _uri('/notes'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    _assertSuccess(response, 'createNote');
    return Note.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<Note> getNote(String noteId) async {
    final response =
        await http.get(_uri('/notes/$noteId'), headers: await _headers());
    _assertSuccess(response, 'getNote');
    return Note.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<Note> updateNote(
    String noteId, {
    String? title,
    String? content,
    String? folderId,
  }) async {
    final body = <String, dynamic>{
      'title': ?title,
      'content': ?content,
      'folderId': ?folderId,
    };
    final response = await http.put(
      _uri('/notes/$noteId'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    _assertSuccess(response, 'updateNote');
    return Note.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteNote(String noteId) async {
    final response = await http.delete(
      _uri('/notes/$noteId'),
      headers: await _headers(),
    );
    _assertSuccess(response, 'deleteNote');
  }

  // ── Attachments ───────────────────────────────────────────────────────────

  Future<List<Attachment>> getAttachments(String noteId) async {
    final response = await http.get(
      _uri('/notes/$noteId/attachments'),
      headers: await _headers(),
    );
    _assertSuccess(response, 'getAttachments');
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => Attachment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CreateAttachmentResult> createAttachment({
    required String noteId,
    required String filename,
    required String mimeType,
    required int size,
  }) async {
    final body = <String, dynamic>{
      'filename': filename,
      'mimeType': mimeType,
      'size': size,
    };
    final response = await http.post(
      _uri('/notes/$noteId/attachments'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    _assertSuccess(response, 'createAttachment');
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return CreateAttachmentResult(
      attachment: Attachment.fromJson(json['attachment'] as Map<String, dynamic>),
      uploadUrl: json['uploadUrl'] as String,
    );
  }

  Future<String> getAttachmentDownloadUrl({
    required String noteId,
    required String attachmentId,
  }) async {
    final response = await http.get(
      _uri('/notes/$noteId/attachments/$attachmentId'),
      headers: await _headers(),
    );
    _assertSuccess(response, 'getAttachmentDownloadUrl');
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return json['downloadUrl'] as String;
  }

  Future<void> deleteAttachment({
    required String noteId,
    required String attachmentId,
  }) async {
    final response = await http.delete(
      _uri('/notes/$noteId/attachments/$attachmentId'),
      headers: await _headers(),
    );
    _assertSuccess(response, 'deleteAttachment');
  }
}

class ApiException implements Exception {
  const ApiException(this.statusCode, this.body, this.context);

  final int statusCode;
  final String body;
  final String context;

  @override
  String toString() => 'ApiException($context $statusCode): $body';
}

/// Thrown when the access token is missing/expired and could not be refreshed,
/// or when the API responds with 401. Callers can usually ignore it — the
/// router will redirect to the login flow via [AuthNotifier.handleSessionExpired].
class AuthExpiredException implements Exception {
  const AuthExpiredException();

  @override
  String toString() => 'AuthExpiredException';
}
