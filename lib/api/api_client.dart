import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../features/folders/models/folder.dart';

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
}

class ApiException implements Exception {
  const ApiException(this.statusCode, this.body, this.context);

  final int statusCode;
  final String body;
  final String context;

  @override
  String toString() => 'ApiException($context $statusCode): $body';
}
