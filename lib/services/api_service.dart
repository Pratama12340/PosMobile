import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'https://api.etres.my.id/api/v1';

  // ==========================================
  // FUNGSI HELPER: MENGAMBIL TOKEN DARI MEMORI
  // ==========================================
  static Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') ?? '';
  }

  // ==========================================
  // FUNGSI 1: LOGIN & SIMPAN TOKEN
  // ==========================================
  static Future<bool> loginWithPin(String pin) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'pin': pin}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String token = data['token'] ?? data['data']?['token'] ?? '';
        
        // Simpan token ke brankas HP
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', token);
        return true; 
      }
      return false;
    } catch (e) {
      print("Error Login: $e");
      return false;
    }
  }

  // ==========================================
  // FUNGSI 2: AMBIL KATEGORI
  // ==========================================
  static Future<List<dynamic>> fetchCategories() async {
    try {
      String token = await _getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/categories'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data is List ? data : (data['data'] ?? []);
      } else {
        throw Exception('Kode: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error Kategori: $e');
    }
  }

  // ==========================================
  // FUNGSI 3: AMBIL PRODUK
  // ==========================================
  static Future<List<dynamic>> fetchProducts() async {
    try {
      String token = await _getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/products'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data is List ? data : (data['data'] ?? []);
      } else {
        throw Exception('Kode: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error Produk: $e');
    }
  }

  // ==========================================
  // FUNGSI 4: AMBIL HISTORY
  // ==========================================
  static Future<List<dynamic>> fetchHistory() async {
    try {
      String token = await _getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/orders'), 
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data is List ? data : (data['data'] ?? []);
      } else {
        throw Exception('Kode: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error History: $e');
    }
  }
}