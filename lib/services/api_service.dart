import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'storage_service.dart';
import '../models/product_models.dart';
import '../models/order_model.dart';
import '../models/discount_model.dart';
import '../models/rekap_model.dart'; // Import model rekap & shift master

class ApiService {
  static const String baseUrl = 'https://api.etres.my.id/api/v1';

  // Helper untuk mendapatkan header secara otomatis (DIPERBAIKI: Null Safety)
  static Future<Map<String, String>> _getHeaders() async {
    final token = await StorageService.getToken();
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    
    return headers;
  }

  // --- 1. LOGIN PIN ---
  static Future<Map<String, dynamic>> loginPin(String pin, int outletId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login-pin'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'pin': pin, 'outlet_id': outletId}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final user = data['user'];

        await StorageService.saveToken(data['token']);
        await StorageService.saveCashierName(user['name'] ?? "Kasir");
        await StorageService.saveOutletId(outletId);

        final outletName = await fetchOutletNameLive();
        await StorageService.saveOutletName(outletName);

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

  // --- 2. FETCH OUTLET NAME LIVE ---
  static Future<String> fetchOutletNameLive() async {
    try {
      final token = await StorageService.getToken();
      final outletId = await StorageService.getOutletId();

      if (outletId == null) return "Outlet Belum Dipilih";

      final response = await http.get(
        Uri.parse('$baseUrl/outlets'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        List<dynamic> outlets = [];

        if (result['data'] is List) {
          outlets = result['data'];
        } else if (result['data'] != null && result['data']['data'] is List) {
          outlets = result['data']['data'];
        }

        for (var outlet in outlets) {
          if (outlet['id'].toString() == outletId.toString()) {
            return outlet['name'].toString();
          }
        }
        return "Outlet Tidak Ditemukan";
      } else {
        return "Gagal Memuat Server";
      }
    } catch (e) {
      debugPrint("Error fetchOutletNameLive: $e");
      return "Error Jaringan";
    }
  }

  // --- 3. GET CATEGORIES ---
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

  // --- 4. GET PRODUCTS ---
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

  // --- 5. SUBMIT ORDER ---
  static Future<Map<String, dynamic>> submitOrder(Map<String, dynamic> orderData) async {
    try {
      final headers = await _getHeaders();
      if (!orderData.containsKey('outlet_id')) {
        final int? outletId = await StorageService.getOutletId();
        orderData['outlet_id'] = outletId;
      }
      final response = await http.post(
        Uri.parse('$baseUrl/orders/checkout'),
        headers: headers,
        body: jsonEncode(orderData),
      );
      final result = jsonDecode(response.body);
      if (response.statusCode == 201 || response.statusCode == 200) {
        return {'success': true, 'data': result['data'] ?? result};
      } else {
        return {'success': false, 'message': result['message'] ?? 'Gagal Simpan',};
      }
    } catch (e) {
      return {'success': false, 'message': 'Kesalahan Sistem: $e'};
    }
  }

  // --- 5. API HISTORY TRANSACTIONS (DIPERBAIKI) ---
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
        // Langsung map ke List<Order>
        return data.map((json) => Order.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<Order?> fetchHistoryDetail(int id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse('$baseUrl/history-transactions/$id'), headers: headers);
      if (response.statusCode == 200) {
        return Order.fromJson(jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint("Error API Detail: $e");
    }
    return null;
  }

  // --- 6. VOID / EDIT ITEM ---
  static Future<Map<String, dynamic>> voidOrEditItem({
    required int itemId, required int orderId, required int newQty, required String reason
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/order-items/$itemId/void-items'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'order_id': orderId,
          'qty': newQty,
          'notes': reason,
        }),
      );
      return (response.statusCode == 200 || response.statusCode == 201) 
          ? {'success': true} 
          : {'success': false, 'message': json.decode(response.body)['message'] ?? 'Gagal simpan'};
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan: $e'};
    }
  }

  // --- 7. UPDATE ITEM STATUS ---
  static Future<Map<String, dynamic>> updateItemStatus(int itemId, String status) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/order-items/$itemId/status'),
        headers: await _getHeaders(),
        body: jsonEncode({'status': status}),
      );
      return response.statusCode == 200 ? {'success': true} : {'success': false};
    } catch (e) {
      return {'success': false};
    }
  }

  // --- 8. GET STATIONS ---
  static Future<List<dynamic>> getStations() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/stations'), headers: await _getHeaders());
      final result = jsonDecode(response.body);
      return response.statusCode == 200 ? (result['data'] is List ? result['data'] : result['data']['data'] ?? []) : [];
    } catch (e) {
      return [];
    }
  }

  static Future<List<dynamic>> getOutlets() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/shift-karyawans'), headers: await _getHeaders());
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['data'] != null) {
          return result['data'] is List ? result['data'] : result['data']['data'] ?? [];
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // --- 10. GET DISCOUNTS ---
  static Future<List<Discount>> getDiscounts() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/discounts'), headers: await _getHeaders());
      if (response.statusCode == 200) {
        final dynamic res = jsonDecode(response.body);
        List<dynamic> data = [];
        if (res is List) data = res;
        else if (res is Map) {
          if (res['data'] is List) data = res['data'];
          else if (res['data'] is Map && res['data']['data'] is List) data = res['data']['data'];
          else if (res['discounts'] is List) data = res['discounts'];
        }
        return data.map((json) => Discount.fromJson(json)).toList();
      }
    } catch (e) { debugPrint("Error getDiscounts: $e"); }
    return [];
  }

  // --- 11. GET TAXES ---
  static Future<List<dynamic>> getTaxes() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/taxes'), headers: await _getHeaders());
      if (response.statusCode == 200) {
        final dynamic result = jsonDecode(response.body);
        if (result is List) return result;
        if (result is Map) {
          if (result['data'] is List) return result['data'];
          if (result['data'] != null && result['data']['data'] is List) return result['data']['data'];
        }
      }
      return [];
    } catch (e) { return []; }
  }

  // --- 9. SHIFT KARYAWAN (DIPERBAIKI) ---

  /// Memulai shift (Start Shift) - Sekarang mengirimkan outlet_id dan nominal
  static Future<Map<String, dynamic>> startShift(int nominal, int outletId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/shift-karyawans/start'),
        headers: headers,
        body: jsonEncode({
          'outlet_id': outletId,
          'starting_cash': nominal,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Gagal memulai shift'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Koneksi error: $e'};
    }
  }

  static Future<Map<String, dynamic>> endShift() async {
    try {
      final response = await http.post(Uri.parse('$baseUrl/shift-karyawans/end'), headers: await _getHeaders());
      final data = jsonDecode(response.body);
      return (response.statusCode == 200 || response.statusCode == 201) 
          ? {'success': true, 'data': data} 
          : {'success': false, 'message': data['message'] ?? 'Gagal mengakhiri shift'};
    } catch (e) { return {'success': false, 'message': 'Koneksi error: $e'}; }
  }

  // Ambil Riwayat Shift (DIPERBAIKI: Mengembalikan List<RekapShift>)
  static Future<List<RekapShift>> getShiftHistory() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/shift-karyawans'), headers: await _getHeaders());
      final result = jsonDecode(response.body);
      if (response.statusCode == 200 && result['data'] != null) {
          List data = result['data'] is List ? result['data'] : result['data']['data'] ?? [];
          return data.map((json) => RekapShift.fromJson(json)).toList();
      }
      return [];
    } catch (e) { return []; }
  }

  // TAMBAHKAN INI: Mengambil Master Data Shift (DIPERBAIKI: Mengembalikan List<ShiftMaster>)
  static Future<List<ShiftMaster>> getMasterShifts() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/shifts'), 
        headers: headers
      );
      final result = jsonDecode(response.body);
      if (response.statusCode == 200 && result['data'] != null) {
          List data = result['data'] is List ? result['data'] : result['data']['data'] ?? [];
          return data.map((json) => ShiftMaster.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}