import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sistem_pos/core/services/storage_service.dart';
import 'package:flutter/foundation.dart';

class UnauthorizedException implements Exception {
  final String message;
  UnauthorizedException([this.message = 'Session expired. Please login again.']);
}

class ApiClient {
  static const String baseUrl = String.fromEnvironment('BASE_URL', defaultValue: 'https://api.etres.my.id/api/v1');

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

  static void _handleResponse(http.Response response) {
    if (response.statusCode == 401) {
      if (kDebugMode) {
        print('Token expired or unauthorized: 401');
      }
      StorageService.removeToken();
      throw UnauthorizedException();
    }
  }

  static Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    final requestHeaders = await getHeaders();
    if (headers != null) requestHeaders.addAll(headers);
    final response = await http.get(url, headers: requestHeaders);
    _handleResponse(response);
    return response;
  }

  static Future<http.Response> post(Uri url, {Map<String, String>? headers, Object? body}) async {
    final requestHeaders = await getHeaders();
    if (headers != null) requestHeaders.addAll(headers);
    final response = await http.post(url, headers: requestHeaders, body: body);
    _handleResponse(response);
    return response;
  }

  static Future<http.Response> put(Uri url, {Map<String, String>? headers, Object? body}) async {
    final requestHeaders = await getHeaders();
    if (headers != null) requestHeaders.addAll(headers);
    final response = await http.put(url, headers: requestHeaders, body: body);
    _handleResponse(response);
    return response;
  }

  static Future<http.Response> delete(Uri url, {Map<String, String>? headers}) async {
    final requestHeaders = await getHeaders();
    if (headers != null) requestHeaders.addAll(headers);
    final response = await http.delete(url, headers: requestHeaders);
    _handleResponse(response);
    return response;
  }

  static Future<http.Response> patch(Uri url, {Map<String, String>? headers, Object? body}) async {
    final requestHeaders = await getHeaders();
    if (headers != null) requestHeaders.addAll(headers);
    final response = await http.patch(url, headers: requestHeaders, body: body);
    _handleResponse(response);
    return response;
  }
}
