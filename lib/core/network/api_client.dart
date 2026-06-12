import 'package:sistem_pos/core/services/storage_service.dart';

class ApiClient {
  static const String baseUrl = 'https://api.etres.my.id/api/v1';

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
}
