import 'dart:convert';
import 'package:http/http.dart' as http;
import 'storage_service.dart';

class ApiService {
  // URL Utama API Anda
  static const String baseUrl = 'https://api.etres.my.id/api/v1'; 

 static Future<Map<String, dynamic>> loginPin(String pin, int outletId) async {
  try {
    print("Mencoba Login... PIN: $pin, Outlet: $outletId"); // DEBUG
    
    final response = await http.post(
      Uri.parse('$baseUrl/login-pin'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({'pin': pin, 'outlet_id': outletId}),
    );

    print("Status Code: ${response.statusCode}"); // DEBUG
    print("Response Body: ${response.body}"); // DEBUG (LIHAT DI SINI ERRORNYA)

    if (response.statusCode == 200) {
      return {'success': true, 'data': jsonDecode(response.body)};
    } else {
      final errorData = jsonDecode(response.body);
      return {'success': false, 'message': errorData['message'] ?? 'PIN Salah!'};
    }
  } catch (e) {
    print("Error Catch: $e"); // DEBUG
    return {'success': false, 'message': 'Koneksi error: $e'};
  }
}
  // --- 2. FUNGSI FETCH HISTORY ---
  static Future<List<dynamic>> fetchHistory() async {
    try {
      final int? outletId = await StorageService.getOutletId();
      
      final response = await http.get(
        Uri.parse('$baseUrl/history?outlet_id=$outletId'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result['data'] ?? [];
      } else {
        throw Exception('Gagal memuat riwayat');
      }
    } catch (e) {
      throw Exception('Koneksi Error: $e');
    }
  }
}