import 'dart:convert';
import 'package:http/http.dart' as http;
import 'storage_service.dart';
import 'package:flutter/foundation.dart'; // Tambahkan ini
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
        final user = data['user']; 
        
        await StorageService.saveToken(data['token']);
        await StorageService.saveCashierName(user['name']);
        await StorageService.saveOutletId(outletId);
        
        if (user['image'] != null) {
          await StorageService.saveProfilePhoto(user['image'].toString());
        } else {
          await StorageService.saveProfilePhoto(""); 
        }

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

  // --- 2. GET CATEGORIES ---
  static Future<List<dynamic>> getCategories() async {
    try {
      final token = await StorageService.getToken();
      final int? outletId = await StorageService.getOutletId(); 

      final response = await http.get(
        Uri.parse('$baseUrl/categories?outlet_id=$outletId&per_page=100'), 
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final result = jsonDecode(response.body);
      if (result['data'] != null) {
        if (result['data'] is List) return result['data'];
        if (result['data']['data'] is List) return result['data']['data'];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // --- 3. GET PRODUCTS ---
  static Future<List<Product>> getProducts() async {
    try {
      final token = await StorageService.getToken();
      final int? outletId = await StorageService.getOutletId();

      final response = await http.get(
        Uri.parse('$baseUrl/products?outlet_id=$outletId&per_page=100'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final result = jsonDecode(response.body);
      if (result['data'] != null) {
        List<dynamic> productList = (result['data'] is List) 
            ? result['data'] 
            : result['data']['data'];
        return productList.map((json) => Product.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // --- 4. SUBMIT ORDER & CHECKOUT ---
 static Future<Map<String, dynamic>> submitOrder(Map<String, dynamic> orderData) async {
    try {
      final token = await StorageService.getToken();
      final int? outletId = await StorageService.getOutletId();

      orderData['outlet_id'] = outletId;

      // UBAH URL DI BAWAH INI:
      // Dari '$baseUrl/orders' menjadi '$baseUrl/orders/checkout'
      final response = await http.post(
        Uri.parse('$baseUrl/orders/checkout'), 
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(orderData),
      );

      print("DEBUG PAYLOAD: ${jsonEncode(orderData)}");
      print("SERVER LOG: ${response.body}");

      final result = jsonDecode(response.body);

      if (response.statusCode == 201 || response.statusCode == 200) {
        return {'success': true};
      } else {
        return {
          'success': false, 
          'message': result['message'] ?? 'Gagal Simpan'
        };
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // --- 5. UPDATE ITEM STATUS (KITCHEN ACTION) ---
  static Future<Map<String, dynamic>> updateItemStatus(int itemId, String status) async {
    try {
      final token = await StorageService.getToken();
      final response = await http.patch(
        Uri.parse('$baseUrl/order-items/$itemId/status'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'status': status}),
      );

      if (response.statusCode == 200) {
        return {'success': true};
      } else {
        final data = jsonDecode(response.body);
        return {'success': false, 'message': data['message'] ?? 'Gagal update status'};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // --- 6. GET STATIONS (STASIUN KERJA) ---
  static Future<List<dynamic>> getStations() async {
    try {
      final token = await StorageService.getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/stations'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final result = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return result['data'] is List ? result['data'] : result['data']['data'] ?? [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // --- 7. GET ALL OUTLETS ---
  static Future<List<dynamic>> getOutlets() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/outlets'), 
        headers: {'Accept': 'application/json'},
      );

      final result = jsonDecode(response.body);
      if (response.statusCode == 200) {
        if (result['data'] != null) {
          return result['data'] is List ? result['data'] : result['data']['data'] ?? [];
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // --- 4. FETCH HISTORY (NON-AKTIF SEMENTARA) ---
  static Future<List<Order>> fetchHistory() async {
    try {
      // Kita kembalikan list kosong secara langsung agar UI tidak error
      // Anda bisa menghapus baris ini nanti jika API sudah siap di backend
      return []; 

      /* // Kode ini disembunyikan sampai backend siap
      final token = await StorageService.getToken();
      final int? outletId = await StorageService.getOutletId();
      
      final response = await http.get(
        Uri.parse('$baseUrl/history?outlet_id=$outletId&per_page=100'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        List<dynamic> data = result['data'] is List ? result['data'] : result['data']['data'] ?? [];
        return data.map((json) => Order.fromJson(json)).toList();
      }
      return [];
      */
    } catch (e) {
      debugPrint("History is currently disabled or unreachable: $e");
      return [];
    }
  }
}