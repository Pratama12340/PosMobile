import 'dart:convert';
import 'package:http/http.dart' as http;
import 'storage_service.dart';
import 'package:flutter/foundation.dart'; 
import '../models/product_models.dart'; 
import '../models/order_model.dart';    

class ApiService {
  static const String baseUrl = 'https://api.etres.my.id/api/v1';

  // Helper untuk mendapatkan header secara otomatis
  static Future<Map<String, String>> _getHeaders() async {
    final token = await StorageService.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

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
        final user = data['user']; 
        
        await StorageService.saveToken(data['token']);
        await StorageService.saveCashierName(user['name'] ?? "Kasir");
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
      final headers = await _getHeaders();
      final int? outletId = await StorageService.getOutletId(); 

      final response = await http.get(
        Uri.parse('$baseUrl/categories?outlet_id=$outletId&per_page=100'), 
        headers: headers,
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
      final headers = await _getHeaders();
      final int? outletId = await StorageService.getOutletId();

      final response = await http.get(
        Uri.parse('$baseUrl/products?outlet_id=$outletId&per_page=100'),
        headers: headers,
      );

      final result = jsonDecode(response.body);
      if (result['data'] != null) {
        List<dynamic> productList = (result['data'] is List) 
            ? result['data'] 
            : result['data']['data'] ?? [];
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
      final headers = await _getHeaders();
      final int? outletId = await StorageService.getOutletId();

      orderData['outlet_id'] = outletId;

      final response = await http.post(
        Uri.parse('$baseUrl/orders/checkout'), 
        headers: headers,
        body: jsonEncode(orderData),
      );

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

  // --- 5. API HISTORY TRANSACTIONS ---

  // GET LIST RIWAYAT
  static Future<List<Order>> fetchHistory() async {
    try {
      final headers = await _getHeaders();
      final int? outletId = await StorageService.getOutletId();
      
      final response = await http.get(
        Uri.parse('$baseUrl/history-transactions?outlet_id=$outletId&per_page=100'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        List<dynamic> data = [];
        
        if (result['data'] is List) {
          data = result['data'];
        } else if (result['data'] != null && result['data']['data'] is List) {
          data = result['data']['data'];
        }
        
        return data.map((json) => Order.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      debugPrint("Error fetching history: $e");
      return [];
    }
  }

  // GET DETAIL RIWAYAT (Berdasarkan ID)
  static Future<Order?> fetchHistoryDetail(int id) async {
    try {
      final headers = await _getHeaders();
      // Perbaikan URL: Pastikan path sesuai dengan endpoint API detail history Anda
      final response = await http.get(
        Uri.parse('$baseUrl/history-transactions/$id'), 
        headers: headers
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        
        // Cek apakah data dibungkus dalam key 'data' atau tidak
        final dataToParse = decoded['data'] ?? decoded;
        
        if (dataToParse != null && dataToParse is Map<String, dynamic>) {
          return Order.fromJson(dataToParse);
        }
      }
    } catch (e) {
      debugPrint("Error API Detail: $e");
    }
    return null;
  }

  // --- 6. UPDATE ITEM STATUS ---
  static Future<Map<String, dynamic>> updateItemStatus(int itemId, String status) async {
    try {
      final headers = await _getHeaders();
      final response = await http.patch(
        Uri.parse('$baseUrl/order-items/$itemId/status'),
        headers: headers,
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

  // --- 7. GET STATIONS ---
  static Future<List<dynamic>> getStations() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/stations'),
        headers: headers,
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

  // --- 8. GET ALL OUTLETS ---
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
}