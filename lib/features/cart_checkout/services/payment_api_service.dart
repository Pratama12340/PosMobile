import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sistem_pos/core/network/api_client.dart';

class PaymentApiService {
  static Future<Map<String, dynamic>> getMidtransToken(
    String orderId,
    String paymentMethod,
    int amount,
  ) async {
    try {
      final headers = await ApiClient.getHeaders();
      final requestBody = jsonEncode({
        "payments": [
          {"method": paymentMethod, "amount_paid": amount},
        ],
      });
      final response = await http.post(
        Uri.parse('${ApiClient.baseUrl}/orders/$orderId/payments'),
        headers: headers,
        body: requestBody,
      );
      final result = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': result['data'] ?? result};
      }
      return {'success': false, 'message': result['message'] ?? 'Gagal mendapatkan token'};
    } catch (e) {
      return {'success': false, 'message': 'Koneksi error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getMidtransConfig() async {
    try {
      final headers = await ApiClient.getHeaders();
      final response = await http.get(Uri.parse('${ApiClient.baseUrl}/midtrans-config'), headers: headers);
      final result = jsonDecode(response.body);
      return response.statusCode == 200
          ? {
              'success': true,
              'client_key': result['client_key'],
              'merchant_base_url': result['merchant_base_url'],
            }
          : {'success': false, 'message': 'Gagal memuat konfigurasi'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
