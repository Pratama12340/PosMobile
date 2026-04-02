import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Base URL server Anda
  static const String baseUrl = 'https://api.etres.my.id/api/v1';

  // --- SESSION TOKEN (Variabel Sementara) ---
  // Ini akan menyimpan "Kunci Akses" selama aplikasi terbuka.
  // Begitu aplikasi ditutup total, token ini akan kembali jadi null (aman).
  static String? sessionToken;

  // Helper untuk Header (Otomatis menyisipkan Token jika sudah Login)
  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        // Jika sessionToken ada isinya, masukkan ke Header Authorization
        if (sessionToken != null) 'Authorization': 'Bearer $sessionToken',
      };

  // ==========================================
  // 1. FUNGSI LOGIN (MENGGUNAKAN PIN)
  // ==========================================
  static Future<bool> loginWithPin(String pin) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'pin': pin, // Mengirim PIN ke Laravel
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Ambil token dari response Laravel
        // (Biasanya data['token'] atau data['data']['token'])
        sessionToken = data['token'] ?? data['data']?['token'];
        
        print("Login Berhasil! Token disimpan sementara.");
        return true;
      } else {
        print("Login Gagal: ${response.statusCode}");
        return false;
      }
    } catch (e) {
      print("Error Login: $e");
      return false;
    }
  }

  // Fungsi Logout
  static void logout() {
    sessionToken = null;
  }

  // ==========================================
  // 2. FUNGSI AMBIL DATA (KATEGORI, PRODUK, HISTORY)
  // ==========================================

  // Ambil Kategori
  static Future<List<dynamic>> fetchCategories() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/categories'),
        headers: _headers, // Menggunakan header yang sudah ada tokennya
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] ?? data;
      } else {
        throw Exception('Gagal mengambil kategori. Kode: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error Koneksi Kategori: $e');
    }
  }

  // Ambil Produk
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

  // Ambil History Pesanan
  static Future<List<dynamic>> fetchHistory() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/orders'),
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