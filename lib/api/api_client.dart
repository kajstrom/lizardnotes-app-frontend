import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../features/folders/models/folder.dart';
import '../features/notes/models/note.dart';

final apiClientProvider = Provider<ApiClient>((_) => ApiClient());

class ApiClient {
  static const _kAccessToken = 'auth_access_token';

  Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_kAccessToken);
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Uri _uri(String path) => Uri.parse('${AppConfig.apiUrl}$path');

  void _assertSuccess(http.Response response, String context) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw ApiException(response.statusCode, response.body, context);
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
}

class ApiException implements Exception {
  const ApiException(this.statusCode, this.body, this.context);

  final int statusCode;
  final String body;
  final String context;

  @override
  String toString() => 'ApiException($context $statusCode): $body';
}
