import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../core/config.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);
  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Thin HTTP client for our backend, with optional bearer token.
class ApiClient {
  String? _token;

  void setToken(String? token) => _token = token;
  String? get token => _token;

  Map<String, String> _headers({bool jsonBody = false}) {
    return {
      if (jsonBody) 'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
    };
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final qp = query?.map((k, v) => MapEntry(k, v.toString()));
    return Uri.parse(AppConfig.apiBaseUrl + path).replace(queryParameters: qp);
  }

  dynamic _decode(http.Response r) {
    if (r.statusCode == 204) return null;
    if (r.statusCode >= 200 && r.statusCode < 300) {
      if (r.body.isEmpty) return null;
      return jsonDecode(utf8.decode(r.bodyBytes));
    }
    String detail = r.body;
    try {
      final body = jsonDecode(utf8.decode(r.bodyBytes));
      detail = (body['detail'] ?? body['message'] ?? r.body).toString();
    } catch (_) {}
    throw ApiException(r.statusCode, detail);
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    final r = await http.get(_uri(path, query), headers: _headers());
    return _decode(r);
  }

  Future<dynamic> post(String path, [Map<String, dynamic>? body]) async {
    final r = await http.post(
      _uri(path),
      headers: _headers(jsonBody: true),
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(r);
  }

  Future<dynamic> patch(String path, Map<String, dynamic> body) async {
    final r = await http.patch(
      _uri(path),
      headers: _headers(jsonBody: true),
      body: jsonEncode(body),
    );
    return _decode(r);
  }

  Future<dynamic> delete(String path) async {
    final r = await http.delete(_uri(path), headers: _headers());
    return _decode(r);
  }

  Future<Map<String, dynamic>> uploadImage(File file) async {
    final req = http.MultipartRequest('POST', _uri('/upload/image'));
    if (_token != null) req.headers['Authorization'] = 'Bearer $_token';
    req.files.add(await http.MultipartFile.fromPath('file', file.path));
    final streamed = await req.send();
    final resp = await http.Response.fromStream(streamed);
    return _decode(resp) as Map<String, dynamic>;
  }

  /// Returns a fully-qualified URL from a relative `/uploads/...` path.
  static String absoluteUrl(String? path) {
    if (path == null) return '';
    if (path.startsWith('http')) return path;
    return AppConfig.apiBaseUrl + path;
  }
}
