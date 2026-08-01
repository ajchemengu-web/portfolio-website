import 'dart:convert';

import 'package:http/http.dart' as http;

import 'constants.dart';

/// Thrown for any non-2xx API response. [statusCode] lets callers branch on
/// e.g. 401 (session expired) vs 422 (validation) vs 5xx (server error).
class ApiException implements Exception {
  ApiException(this.statusCode, this.message, {this.details});

  final int statusCode;
  final String message;
  final Map<String, dynamic>? details;

  bool get isAuthError => statusCode == 401;
  bool get isValidationError => statusCode == 422;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Thrown when the request never reached the server (offline, DNS failure,
/// CORS misconfiguration, backend not deployed yet). Repositories catch
/// this specifically to decide whether to fall back to placeholder content.
class ApiUnreachableException implements Exception {
  ApiUnreachableException(this.cause);
  final Object cause;
}

/// Thin wrapper over `package:http` that centralises base-URL handling, JSON
/// (de)serialisation, bearer-token auth, and error mapping so feature code
/// never touches raw [http.Client] calls.
class ApiClient {
  ApiClient({http.Client? httpClient, this.tokenProvider})
      : _client = httpClient ?? http.Client();

  final http.Client _client;

  /// Supplies the current admin access token, if any. Kept as a callback
  /// (rather than a stored field) so the client always uses the latest
  /// token even after a refresh, without callers having to recreate it.
  final String? Function()? tokenProvider;

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final normalizedBase = AppConfig.apiBaseUrl.endsWith('/')
        ? AppConfig.apiBaseUrl.substring(0, AppConfig.apiBaseUrl.length - 1)
        : AppConfig.apiBaseUrl;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$normalizedBase$normalizedPath');
    if (query == null || query.isEmpty) return uri;
    final stringQuery = query.map((key, value) => MapEntry(key, '$value'));
    return uri.replace(queryParameters: {...uri.queryParameters, ...stringQuery});
  }

  Map<String, String> _headers({bool json = true}) {
    final headers = <String, String>{};
    if (json) headers['Content-Type'] = 'application/json';
    final token = tokenProvider?.call();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    return _send(() => _client.get(_uri(path, query), headers: _headers(json: false)));
  }

  Future<dynamic> post(String path, {Object? body}) async {
    return _send(() => _client.post(
          _uri(path),
          headers: _headers(),
          body: body == null ? null : jsonEncode(body),
        ));
  }

  Future<dynamic> put(String path, {Object? body}) async {
    return _send(() => _client.put(
          _uri(path),
          headers: _headers(),
          body: body == null ? null : jsonEncode(body),
        ));
  }

  Future<dynamic> delete(String path) async {
    return _send(() => _client.delete(_uri(path), headers: _headers(json: false)));
  }

  /// Uploads a file as `multipart/form-data` — used by the admin Media
  /// Manager against `POST /api/uploads`. [bytes] rather than a `dart:io`
  /// `File` so this works unmodified on Flutter Web (where there is no
  /// filesystem to read from) as well as desktop/mobile.
  Future<dynamic> uploadMultipart(
    String path, {
    required List<int> bytes,
    required String filename,
    Map<String, String> fields = const {},
  }) async {
    return _send(() async {
      final request = http.MultipartRequest('POST', _uri(path))
        ..headers.addAll(_headers(json: false))
        ..fields.addAll(fields)
        ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
      final streamed = await request.send();
      return http.Response.fromStream(streamed);
    });
  }

  Future<dynamic> _send(Future<http.Response> Function() request) async {
    http.Response response;
    try {
      response = await request().timeout(const Duration(seconds: 15));
    } catch (e) {
      throw ApiUnreachableException(e);
    }

    if (response.statusCode == 204 || response.body.isEmpty) {
      if (response.statusCode >= 200 && response.statusCode < 300) return null;
      throw ApiException(response.statusCode, 'Request failed (${response.statusCode}).');
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      decoded = null;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    final message = (decoded is Map && decoded['error'] is String)
        ? decoded['error'] as String
        : 'Request failed (${response.statusCode}).';
    final details = (decoded is Map && decoded['details'] is Map)
        ? Map<String, dynamic>.from(decoded['details'] as Map)
        : null;
    throw ApiException(response.statusCode, message, details: details);
  }
}
