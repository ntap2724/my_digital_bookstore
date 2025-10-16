import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:my_flutter_app/config.dart';
import 'package:my_flutter_app/services/auth_service.dart';

class ApiException implements Exception {
  final int? statusCode;
  final String message;
  final Map<String, dynamic>? body;

  ApiException(this.message, {this.statusCode, this.body});

  @override
  String toString() {
    final code = statusCode != null ? ' (status: $statusCode)' : '';
    return 'ApiException$code: $message';
  }
}

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  final http.Client _client = http.Client();

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
    bool auth = true,
  }) async {
    final response = await _request('GET', path, query: query, auth: auth);
    if (response is Map<String, dynamic>) return response;
    throw ApiException('Unexpected response shape', body: {'data': response});
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? query,
    Object? body,
    bool auth = true,
  }) async {
    final response = await _request(
      'POST',
      path,
      query: query,
      body: body,
      auth: auth,
    );
    if (response is Map<String, dynamic>) return response;
    throw ApiException('Unexpected response shape', body: {'data': response});
  }

  Future<Map<String, dynamic>> putJson(
    String path, {
    Map<String, dynamic>? query,
    Object? body,
    bool auth = true,
  }) async {
    final response = await _request(
      'PUT',
      path,
      query: query,
      body: body,
      auth: auth,
    );
    if (response is Map<String, dynamic>) return response;
    throw ApiException('Unexpected response shape', body: {'data': response});
  }

  Future<Map<String, dynamic>> deleteJson(
    String path, {
    Map<String, dynamic>? query,
    Object? body,
    bool auth = true,
  }) async {
    final response = await _request(
      'DELETE',
      path,
      query: query,
      body: body,
      auth: auth,
    );
    if (response is Map<String, dynamic>) return response;
    if (response == null) return <String, dynamic>{};
    throw ApiException('Unexpected response shape', body: {'data': response});
  }

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
    bool auth = true,
  }) async {
    final uri = _buildUri(path, query);
    final headers = <String, String>{'Accept': 'application/json'};

    String? token;
    if (auth) {
      token = await AuthService.instance.getToken();
      if (token == null || token.isEmpty) {
        throw ApiException('Authentication required to call $path');
      }
      headers['Authorization'] = 'Bearer $token';
    }

    Object? payload = body;
    if (body != null) {
      if (body is Map<String, dynamic>) {
        headers['Content-Type'] = 'application/json';
        payload = jsonEncode(body);
      } else if (body is List || body is Iterable) {
        headers['Content-Type'] = 'application/json';
        payload = jsonEncode(body);
      }
    }

    http.Response response;
    try {
      switch (method) {
        case 'GET':
          response = await _client.get(uri, headers: headers);
          break;
        case 'POST':
          response = await _client.post(uri, headers: headers, body: payload);
          break;
        case 'PUT':
          response = await _client.put(uri, headers: headers, body: payload);
          break;
        case 'DELETE':
          response = await _client.delete(uri, headers: headers, body: payload);
          break;
        default:
          throw ApiException('Unsupported HTTP method $method');
      }
    } catch (e) {
      throw ApiException('Failed to connect: $e');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) {
        return null;
      }
      return _decodeJson(response.body);
    }

    Map<String, dynamic>? bodyJson;
    try {
      if (response.body.isNotEmpty) {
        bodyJson = _decodeJson(response.body);
      }
    } catch (_) {}

    throw ApiException(
      bodyJson?['message']?.toString() ??
          'Request failed with status ${response.statusCode}',
      statusCode: response.statusCode,
      body: bodyJson,
    );
  }

  Uri _buildUri(String path, Map<String, dynamic>? query) {
    final base = AppConfig.apiBaseUrl;
    final uri = Uri.parse(path.startsWith('http') ? path : '$base$path');
    if (query == null || query.isEmpty) {
      return uri;
    }
    final filtered = <String, String>{};
    query.forEach((key, value) {
      if (value == null) return;
      if (value is String && value.isEmpty) return;
      filtered[key] = value.toString();
    });
    return uri.replace(queryParameters: {...uri.queryParameters, ...filtered});
  }

  Map<String, dynamic> _decodeJson(String body) {
    var text = body.trimLeft();
    if (text.isNotEmpty && text.codeUnitAt(0) == 0xFEFF) {
      text = text.substring(1);
    }
    if (text.isEmpty) return <String, dynamic>{};
    final dynamic result = jsonDecode(text);
    if (result is Map<String, dynamic>) {
      return result;
    }
    if (result is Map) {
      return result.cast<String, dynamic>();
    }
    return <String, dynamic>{'data': result};
  }
}
