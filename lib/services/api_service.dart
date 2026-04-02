import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Gunakan v1 sesuai folder di server Anda
  static const String baseUrl = 'https://api.etres.my.id/api/v1';

  // Helper untuk Header (PENTING untuk menghindari 405)
  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json', // Memberitahu Laravel kita minta JSON, bukan HTML
  };

  // 1. Ambil Kategori
  static Future<List<dynamic>> fetchCategories() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/categories'), // Pastikan tidak ada '/' di akhir
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Sesuaikan dengan struktur JSON Laravel (biasanya dalam key 'data')
        return data['data'] ?? data; 
      } else {
        throw Exception('Gagal mengambil kategori. Kode: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error Koneksi Kategori: $e');
    }
  }

  // 2. Ambil Produk
  static Future<List<dynamic>> fetchProducts() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/products'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] ?? data;
      } else {
        throw Exception('Gagal memuat produk. Kode: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error Koneksi Produk: $e');
    }
  }

  // 3. Ambil History
  static Future<List<dynamic>> fetchHistory() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/orders'), // Sesuaikan jika endpointnya 'history' atau 'orders'
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] ?? data;
      } else {
        throw Exception('Gagal memuat history. Kode: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error Koneksi History: $e');
    }
  }
}