import 'package:http/http.dart' as http;
import 'package:sistem_pos/core/services/storage_service.dart';
import 'package:flutter/foundation.dart';

class UnauthorizedException implements Exception {
  final String message;
  UnauthorizedException([this.message = 'Session expired. Please login again.']);
}

class ApiClient {
  static const String baseUrl = String.fromEnvironment('BASE_URL', defaultValue: 'http://103.197.190.23:9010/api/v1');

  static Future<Map<String, String>> getHeaders() async {
    final token = await StorageService.getToken();
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<void> _handleResponse(http.Response response, Uri url) async {
    if (response.statusCode == 401) {
      // Allow login endpoints to handle their own 401 responses
      if (url.path.contains('login-pin') || url.path.contains('login')) {
        return;
      }
      if (kDebugMode) {
        print('Token expired or unauthorized: 401');
      }
      await StorageService.removeToken();
      throw UnauthorizedException();
    }
  }

  static Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    final requestHeaders = await getHeaders();
    if (headers != null) requestHeaders.addAll(headers);
    final response = await http.get(url, headers: requestHeaders);
    await _handleResponse(response, url);
    return response;
  }

  static Future<http.Response> post(Uri url, {Map<String, String>? headers, Object? body}) async {
    final requestHeaders = await getHeaders();
    if (headers != null) requestHeaders.addAll(headers);
    final response = await http.post(url, headers: requestHeaders, body: body);
    await _handleResponse(response, url);
    return response;
  }

  static Future<http.Response> put(Uri url, {Map<String, String>? headers, Object? body}) async {
    final requestHeaders = await getHeaders();
    if (headers != null) requestHeaders.addAll(headers);
    final response = await http.put(url, headers: requestHeaders, body: body);
    await _handleResponse(response, url);
    return response;
  }

  static Future<http.Response> delete(Uri url, {Map<String, String>? headers}) async {
    final requestHeaders = await getHeaders();
    if (headers != null) requestHeaders.addAll(headers);
    final response = await http.delete(url, headers: requestHeaders);
    await _handleResponse(response, url);
    return response;
  }

  static Future<http.Response> patch(Uri url, {Map<String, String>? headers, Object? body}) async {
    final requestHeaders = await getHeaders();
    if (headers != null) requestHeaders.addAll(headers);
    final response = await http.patch(url, headers: requestHeaders, body: body);
    await _handleResponse(response, url);
    return response;
  }
}
