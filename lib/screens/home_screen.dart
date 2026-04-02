import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'https://api.etres.my.id/api/v1';

  // --- FUNGSI HELPER: MENGAMBIL TOKEN ---
  static Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') ?? '';
  }

  // --- FUNGSI 1: AMBIL KATEGORI ---
  static Future<List<dynamic>> fetchCategories() async {
    try {
      String token = await _getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/categories'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token', // WAJIB ADA INI
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Sesuaikan jika Laravel membungkusnya dalam 'data'
        return data is List ? data : (data['data'] ?? []);
      } else {
        throw Exception('Gagal mengambil kategori. Kode: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error Koneksi Kategori: $e');
    }
  }

  // --- FUNGSI 2: AMBIL PRODUK ---
  static Future<List<dynamic>> fetchProducts() async {
    try {
      String token = await _getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/products'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token', // WAJIB ADA INI
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data is List ? data : (data['data'] ?? []);
      } else {
        throw Exception('Gagal memuat produk. Kode: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error Koneksi Produk: $e');
    }
  }

  // --- FUNGSI 3: AMBIL HISTORY ---
  static Future<List<dynamic>> fetchHistory() async {
    try {
      String token = await _getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/orders'), // Sesuaikan endpoint history di Swagger
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data is List ? data : (data['data'] ?? []);
      } else {
        throw Exception('Gagal memuat history. Kode: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error Koneksi History: $e');
    }
  }
}