import 'dart:convert';
// Removed http import
import 'package:sistem_pos/core/network/api_client.dart';
import 'package:flutter/foundation.dart';

class PaymentApiService {
  static Future<Map<String, dynamic>> getMidtransToken(
    String orderId,
    String paymentMethod,
    int amount,
  ) async {
    try {
      final requestBody = jsonEncode({
        "payments": [
          {"method": paymentMethod, "amount_paid": amount},
        ],
      });
      final response = await ApiClient.post(
        Uri.parse('${ApiClient.baseUrl}/orders/$orderId/payments'),
        body: requestBody,
      );
      final result = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': result['data'] ?? result};
      }
      return {'success': false, 'message': result['message'] ?? 'Gagal mendapatkan token'};
    } catch (e) {
      if (kDebugMode) print("💥 [API ERROR] getMidtransToken: $e");
      return {'success': false, 'message': 'Koneksi error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getMidtransConfig() async {
    try {
      final response = await ApiClient.get(Uri.parse('${ApiClient.baseUrl}/midtrans-config'));
      final result = jsonDecode(response.body);
      return response.statusCode == 200
          ? {
              'success': true,
              'client_key': result['client_key'],
              'merchant_base_url': result['merchant_base_url'],
            }
          : {'success': false, 'message': 'Gagal memuat konfigurasi'};
    } catch (e) {
      if (kDebugMode) print("💥 [API ERROR] getMidtransConfig: $e");
      return {'success': false, 'message': e.toString()};
    }
  }
}
