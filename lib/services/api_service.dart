import 'dart:convert';
import 'package:http/http.dart' as http;
import 'storage_service.dart';
import '../models/product_models.dart'; // Import Model Product
import '../models/order_model.dart';   // Import Model Order

class ApiService {
  static const String baseUrl = 'https://api.etres.my.id/api/v1';

  // --- 1. LOGIN PIN ---
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
        // Simpan data penting ke Storage
        final token = data['token'];
        final name = data['user']['name'];
        await StorageService.saveToken(token);
        await StorageService.saveCashierName(name);
        await StorageService.saveOutletId(outletId);

        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['message'] ?? 'PIN Salah!'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Koneksi error: $e'};
    }
  }

  // --- 2. GET CATEGORIES (PER OUTLET) ---
  static Future<List<dynamic>> getCategories() async {
    try {
      final token = await StorageService.getToken();
      // 👇 1. Ambil ID Outlet dari penyimpanan HP kasir
      final int? outletId = await StorageService.getOutletId(); 

      // 👇 2. Tambahkan ?outlet_id= ke link API
      final response = await http.get(
        Uri.parse('$baseUrl/categories?outlet_id=$outletId'), 
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final result = jsonDecode(response.body);

      if (result['data'] != null) {
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

  // --- 3. GET PRODUCTS (PER OUTLET) ---
  static Future<List<Product>> getProducts() async {
    try {
      final token = await StorageService.getToken();
      // 👇 1. Ambil ID Outlet dari penyimpanan HP kasir
      final int? outletId = await StorageService.getOutletId();

      // 👇 2. Tambahkan ?outlet_id= ke link API
      final response = await http.get(
        Uri.parse('$baseUrl/products?outlet_id=$outletId'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

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
        print("Struktur API tidak sesuai atau data kosong");
        return [];
      }
    } catch (e) {
      print("Error Produk: $e");
      return [];
    }
  }

  // --- GET ALL OUTLETS ---
  static Future<List<dynamic>> getOutlets() async {
    try {
      final response = await http.get(
        // Pastikan endpoint '/outlets' ini sudah kamu buat di backend Laravel-mu
        Uri.parse('$baseUrl/outlets'), 
        headers: {
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        
        // Menangani format "data" dari Laravel dengan aman
        if (result['data'] != null) {
          if (result['data'] is List) {
            return result['data'];
          } else if (result['data']['data'] is List) {
            return result['data']['data'];
          }
        }
        return [];
      } else {
        print("Error Ambil Outlet: ${response.statusCode}");
        return [];
      }
    } catch (e) {
      print("Exception Ambil Outlet: $e");
      return [];
    }
  }

  // --- 4. FETCH HISTORY (MENGGUNAKAN MODEL ORDER) ---
  static Future<List<Order>> fetchHistory() async {
    try {
      final token = await StorageService.getToken();
      final int? outletId = await StorageService.getOutletId();
      
      final response = await http.get(
        Uri.parse('$baseUrl/history?outlet_id=$outletId'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        
        // PERBAIKAN: Menangani pagination juga di history jika ada
        List<dynamic> data = [];
        if (result['data'] != null) {
          if (result['data'] is List) {
            data = result['data'];
          } else if (result['data']['data'] is List) {
            data = result['data']['data'];
          }
        }
        
        // MENGUBAH LIST JSON MENJADI LIST OBJEK ORDER
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
}