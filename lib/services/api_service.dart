import 'dart:convert';
import 'package:http/http.dart' as http;
import 'storage_service.dart';
import '../models/product_models.dart'; 
import '../models/order_model.dart';   

class ApiService {
  static const String baseUrl = 'https://api.etres.my.id/api/v1';

  // --- 1. LOGIN PIN (DENGAN FETCH PROFIL) ---
  static Future<Map<String, dynamic>> loginPin(String pin, int outletId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login-pin'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        body: jsonEncode({'pin': pin, 'outlet_id': outletId}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Ambil objek user agar lebih rapi
        final user = data['user']; 
        
        // --- SIMPAN KE STORAGE ---
        await StorageService.saveToken(data['token']);
        await StorageService.saveCashierName(user['name']);
        await StorageService.saveOutletId(outletId);
        
        // Simpan Foto Profil (Jika ada di database Laravel-mu)
        // Gunakan .toString() atau ?? "" untuk menghindari error null
        if (user['image'] != null) {
          await StorageService.saveProfilePhoto(user['image'].toString());
        } else {
          await StorageService.saveProfilePhoto(""); // Kosongkan jika tidak ada
        }

        // Simpan Role (Misal: Kasir, Admin, atau Manager)
        final role = user['role'] ?? "Cashier";
        await StorageService.saveUserRole(role.toString());

        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['message'] ?? 'PIN Salah!'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Koneksi error: $e'};
    }
  }

  // --- 2. GET CATEGORIES (FIXED PER PAGE 100) ---
  static Future<List<dynamic>> getCategories() async {
    try {
      final token = await StorageService.getToken();
      final int? outletId = await StorageService.getOutletId(); 

      // TAMBAHKAN &per_page=100 agar Laravel mengirim semua kategori sekaligus
      final response = await http.get(
        Uri.parse('$baseUrl/categories?outlet_id=$outletId&per_page=100'), 
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final result = jsonDecode(response.body);

      if (result['data'] != null) {
        // Logika fleksibel: Bisa baca list langsung (->get()) atau terbungkus (->paginate())
        if (result['data'] is List) {
          return result['data'];
        } else if (result['data']['data'] is List) {
          return result['data']['data'];
        }
      }
      return [];
    } catch (e) {
      print("Error Categories: $e");
      return [];
    }
  }

  // --- 3. GET PRODUCTS (FIXED PER PAGE 100) ---
  static Future<List<Product>> getProducts() async {
    try {
      final token = await StorageService.getToken();
      final int? outletId = await StorageService.getOutletId();

      // Tambahkan per_page=100 untuk mengambil semua menu outlet sekaligus
      final response = await http.get(
        Uri.parse('$baseUrl/products?outlet_id=$outletId&per_page=100'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      // 👇 TAMBAHKAN BARIS INI UNTUK MENGETES
      print("HASIL MENTAH DARI SERVER: ${response.body}");

      final result = jsonDecode(response.body);

      if (result['data'] != null) {
        List<dynamic> productList = [];
        
        if (result['data'] is List) {
          productList = result['data'];
        } else if (result['data']['data'] is List) {
          productList = result['data']['data'];
        }

        return productList.map((json) => Product.fromJson(json)).toList();
      } else {
        return [];
      }
    } catch (e) {
      print("Error Produk: $e");
      return [];
    }
  }

  // --- 4. FETCH HISTORY (FIXED PER PAGE 100) ---
  static Future<List<Order>> fetchHistory() async {
    try {
      final token = await StorageService.getToken();
      final int? outletId = await StorageService.getOutletId();
      
      // History juga ditambahkan per_page agar rekap transaksi yang muncul lebih lengkap
      final response = await http.get(
        Uri.parse('$baseUrl/history?outlet_id=$outletId&per_page=100'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        
        List<dynamic> data = [];
        if (result['data'] != null) {
          if (result['data'] is List) {
            data = result['data'];
          } else if (result['data']['data'] is List) {
            data = result['data']['data'];
          }
        }
        
        return data.map((json) => Order.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print("Error History: $e");
      return [];
    }
  }

  // --- 5. POST ORDER (CHECKOUT) ---
  static Future<Map<String, dynamic>> postOrder({
    required List<Map<String, dynamic>> items,
    required double total,
    required String tableNo,
  }) async {
    try {
      final token = await StorageService.getToken();
      final int? outletId = await StorageService.getOutletId();

      final response = await http.post(
        Uri.parse('$baseUrl/orders'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'outlet_id': outletId,
          'table_number': tableNo,
          'total_price': total,
          'details': items,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return {'success': true};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'message': error['message'] ?? 'Gagal simpan transaksi'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Koneksi error: $e'};
    }
  }

  // --- GET ALL OUTLETS (UNTUK LAYAR AWAL) ---
  static Future<List<dynamic>> getOutlets() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/outlets'), 
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['data'] != null) {
          if (result['data'] is List) return result['data'];
          if (result['data']['data'] is List) return result['data']['data'];
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}