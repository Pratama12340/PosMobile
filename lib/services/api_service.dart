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

  // Helper untuk mendapatkan header secara otomatis
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
    print("\n=========================================");
    print("[API REQUEST] --> LOGIN PIN");
    print("Payload: {'pin': '***', 'outlet_id': $outletId}");

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login-pin'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'pin': pin, 'outlet_id': outletId}),
      );

      print("[API RESPONSE] <-- STATUS: ${response.statusCode}");

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final user = data['user'];
        if (user == null) {
          print("❌ [API ERROR] Data user dari server bernilai null.");
          return {
            'success': false,
            'message': 'Format data server tidak valid.',
          };
        }

        // --- VALIDASI OUTLET ---
        final int userOutletId =
            int.tryParse(user['outlet_id'].toString()) ?? 0;
        print(
          "🔍 [API VALIDASI] Cek Cabang Karyawan: DB ($userOutletId) vs App ($outletId)",
        );

        if (userOutletId != outletId) {
          print(
            "❌ [API REJECTED] Karyawan terdaftar di cabang lain! Data TIDAK disimpan.",
          );
          return {
            'success': false,
            'message': 'Akses Ditolak: Anda terdaftar di Cabang lain.',
          };
        }
        print("✅ [API VALIDASI] Cabang cocok.");

        // Jika semua validasi lulus, baru simpan ke StorageService
        print("💾 [API ACTION] Login Valid. Menyimpan data ke Storage...");

        // 1. Simpan Token
        await StorageService.saveToken(data['token']);

        // 2. Simpan Nama & Role
        await StorageService.saveCashierName(user['name'] ?? "Kasir");
        final role = user['role'] ?? "Cashier";
        await StorageService.saveUserRole(role.toString());

        // 3. Simpan Outlet ID & Fetch Live Outlet Name
        await StorageService.saveOutletId(outletId);
        final outletName = await fetchOutletNameLive();
        await StorageService.saveOutletName(outletName);

        // 4. Simpan Image
        if (user['image'] != null) {
          await StorageService.saveProfilePhoto(user['image'].toString());
        } else {
          await StorageService.saveProfilePhoto("");
        }

        // 5. Simpan Shift Data & Kas Awal
        if (data['shift_id'] != null) {
          print("✅ [API VALIDASI] Shift ID Aktif: ${data['shift_id']}");
          await StorageService.saveCurrentShiftId(data['shift_id'].toString());
          await StorageService.saveShiftStatus(true);

          // --- TAMBAHAN: Simpan Kas Awal jika sedang dalam shift aktif ---
          if (data['opening_balance'] != null) {
            int balance = int.tryParse(data['opening_balance'].toString()) ?? 0;
            await StorageService.saveOpeningBalance(balance);
            print("💾 [API ACTION] Kas Awal ditemukan & disimpan: $balance");
          }
        } else {
          print(
            "⚠️ [API WARNING] Karyawan login namun belum memiliki shift aktif.",
          );
          await StorageService.saveShiftStatus(false);
          // Jika tidak ada shift aktif, pastikan storage kas awal bersih
          await StorageService.clearOpeningBalance();
        }

        print("=========================================\n");
        return {'success': true, 'data': data};
      } else {
        print("❌ [API FAILED] Login ditolak oleh server: ${data['message']}");
        print("=========================================\n");
        return {'success': false, 'message': data['message'] ?? 'PIN Salah!'};
      }
    } catch (e) {
      print("💥 [API CRITICAL ERROR] loginPin: $e");
      print("=========================================\n");
      return {'success': false, 'message': 'Koneksi error: $e'};
    }
  }

  // --- 2. FETCH OUTLET NAME LIVE ---
  static Future<String> fetchOutletNameLive() async {
    print("[API REQUEST] --> FETCH OUTLET NAME LIVE");
    try {
      final token = await StorageService.getToken();
      final outletId = await StorageService.getOutletId();

      if (outletId == null) return "Outlet Belum Dipilih";

      final response = await http.get(
        Uri.parse('$baseUrl/outlets'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
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
      debugPrint("💥 [API ERROR] fetchOutletNameLive: $e");
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
  static Future<Map<String, dynamic>> submitOrder(
    Map<String, dynamic> orderData,
  ) async {
    print("\n[API REQUEST] --> CHECKOUT ORDER");
    try {
      final headers = await _getHeaders();
      if (!orderData.containsKey('outlet_id')) {
        final int? outletId = await StorageService.getOutletId();
        orderData['outlet_id'] = outletId;
      }
      print("Payload: ${jsonEncode(orderData)}");

      final response = await http.post(
        Uri.parse('$baseUrl/orders/checkout'),
        headers: headers,
        body: jsonEncode(orderData),
      );

      print("[API RESPONSE] <-- STATUS: ${response.statusCode}");
      print("Body: ${response.body}");

      final result = jsonDecode(response.body);
      if (response.statusCode == 201 || response.statusCode == 200) {
        print("✅ [API SUCCESS] Checkout Berhasil.");
        return {'success': true, 'data': result['data'] ?? result};
      } else {
        print("❌ [API FAILED] Checkout Gagal: ${result['message']}");
        return {
          'success': false,
          'message': result['message'] ?? 'Gagal Simpan',
        };
      }
    } catch (e) {
      print("💥 [API ERROR] submitOrder: $e");
      return {'success': false, 'message': 'Kesalahan Sistem: $e'};
    }
  }

  // --- 6. API HISTORY TRANSACTIONS ---
  static Future<List<Order>> fetchHistory() async {
    try {
      final headers = await _getHeaders();
      final int? outletId = await StorageService.getOutletId();
      final response = await http.get(
        Uri.parse(
          '$baseUrl/history-transactions?outlet_id=$outletId&per_page=100',
        ),
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
      return [];
    }
  }

  static Future<Order?> fetchHistoryDetail(int id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/history-transactions/$id'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        return Order.fromJson(jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint("💥 [API ERROR] fetchHistoryDetail: $e");
    }
    return null;
  }

  // --- TAMBAHKAN: UPDATE ORDER (LOGIKA VOID ITEMS) ---
  static Future<bool> updateOrder({
    required int orderId,
    required List<OrderItem> items,
    required String reason,
  }) async {
    try {
      final headers = await _getHeaders();

      final Map<String, dynamic> bodyData = {
        'reason': reason,
        'items': items.map((item) => item.toJson()).toList(),
      };

      print("\n--- [API REQUEST] PROSES UPDATE ORDER (VOID) ---");
      print("URL: $baseUrl/orders/$orderId/void-items");
      print("Payload: ${jsonEncode(bodyData)}");

      final response = await http.post(
        Uri.parse('$baseUrl/orders/$orderId/void-items'),
        headers: headers,
        body: jsonEncode(bodyData),
      );

      print("[API RESPONSE] <-- STATUS: ${response.statusCode}");
      print("Body: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        print("✅ [API SUCCESS] Update Berhasil.");
        return true;
      } else {
        print("❌ [API FAILED] Server menolak update.");
        return false;
      }
    } catch (e) {
      print("💥 [API ERROR] updateOrder: $e");
      return false;
    }
  }

  // --- 7. VOID / EDIT ITEM ---
  static Future<Map<String, dynamic>> voidOrEditItem({
    required int itemId,
    required int orderId,
    required int newQty,
    required String reason,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/order-items/$itemId/void-items'),
        headers: await _getHeaders(),
        body: jsonEncode({'order_id': orderId, 'qty': newQty, 'notes': reason}),
      );
      return (response.statusCode == 200 || response.statusCode == 201)
          ? {'success': true}
          : {
              'success': false,
              'message':
                  json.decode(response.body)['message'] ?? 'Gagal simpan',
            };
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan: $e'};
    }
  }

  // --- 8. UPDATE ITEM STATUS ---
  static Future<Map<String, dynamic>> updateItemStatus(
    int itemId,
    String status,
  ) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/order-items/$itemId/status'),
        headers: await _getHeaders(),
        body: jsonEncode({'status': status}),
      );
      return response.statusCode == 200
          ? {'success': true}
          : {'success': false};
    } catch (e) {
      return {'success': false};
    }
  }

  // --- 9. GET STATIONS & OUTLETS ---
  static Future<List<dynamic>> getStations() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/stations'),
        headers: await _getHeaders(),
      );
      final result = jsonDecode(response.body);
      return response.statusCode == 200
          ? (result['data'] is List
              ? result['data']
              : result['data']['data'] ?? [])
          : [];
    } catch (e) {
      return [];
    }
  }

  static Future<List<dynamic>> getOutlets() async {
    print("\n[API REQUEST] --> GET OUTLETS");
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/outlets'),
        headers: await _getHeaders(),
      );

      print("[API RESPONSE] <-- STATUS: ${response.statusCode}");
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['data'] != null) {
          return result['data'] is List
              ? result['data']
              : result['data']['data'] ?? [];
        }
      }
      return [];
    } catch (e) {
      print("💥 [API ERROR] getOutlets: $e");
      return [];
    }
  }

  // --- 10. GET DISCOUNTS ---
  static Future<List<Discount>> getDiscounts() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/discounts'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        final dynamic res = jsonDecode(response.body);
        List<dynamic> data = [];
        if (res is List)
          data = res;
        else if (res is Map) {
          if (res['data'] is List)
            data = res['data'];
          else if (res['data'] is Map && res['data']['data'] is List)
            data = res['data']['data'];
          else if (res['discounts'] is List)
            data = res['discounts'];
        }
        return data.map((json) => Discount.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint("💥 [API ERROR] getDiscounts: $e");
    }
    return [];
  }

  // --- 11. GET TAXES ---
  static Future<List<dynamic>> getTaxes() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/taxes'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        final dynamic result = jsonDecode(response.body);
        if (result is List) return result;
        if (result is Map) {
          if (result['data'] is List) return result['data'];
          if (result['data'] != null && result['data']['data'] is List)
            return result['data']['data'];
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // --- SHIFT KARYAWAN ---

  static Future<Map<String, dynamic>> startShift(int nominal, int outletId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/shift-karyawans/start'),
        headers: headers,
        body: jsonEncode({'outlet_id': outletId, 'opening_balance': nominal}),
      );

      print("[API RESPONSE] <-- STATUS: ${response.statusCode}");
      print("Body: ${response.body}");

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        // --- PERBAIKAN: Ambil nilai dari server untuk sinkronisasi ---
        final int openingBalanceFromServer = 
            int.tryParse(data['data']['opening_balance'].toString()) ?? nominal;

        // --- SIMPAN KE STORAGE LOKAL ---
        await StorageService.saveOpeningBalance(openingBalanceFromServer);
        
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Gagal memulai shift',
        };
      }
    } catch (e) {
      print("💥 [API ERROR] startShift: $e");
      return {'success': false, 'message': 'Koneksi error: $e'};
    }
  }

  static Future<Map<String, dynamic>> endShift(
    int totalFisik,
    String notes,
  ) async {
    print("\n[API REQUEST] --> END SHIFT (TUTUP KASIR)");
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/shift-karyawans/end'),
        headers: headers,
        body: jsonEncode({
          'actual_closing_balance': totalFisik,
          'notes': notes,
        }),
      );

      print("[API RESPONSE] <-- STATUS: ${response.statusCode}");
      print("Body: ${response.body}");

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        // --- HAPUS DATA KAS AWAL DARI STORAGE SETELAH SHIFT BERAKHIR ---
        await StorageService.clearOpeningBalance();
        
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Gagal mengakhiri shift',
        };
      }
    } catch (e) {
      print("💥 [API ERROR] endShift: $e");
      return {'success': false, 'message': 'Koneksi error: $e'};
    }
  }

  static Future<List<RekapShift>> getShiftHistory() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/shift-karyawans'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        List data = result['data'] is List
            ? result['data']
            : result['data']['data'] ?? [];
        return data.map((json) => RekapShift.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print("💥 [API ERROR] getShiftHistory: $e");
      return [];
    }
  }

  static Future<List<ShiftMaster>> getMasterShifts() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/shifts'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        List data = result['data'] is List
            ? result['data']
            : result['data']['data'] ?? [];
        return data.map((json) => ShiftMaster.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print("💥 [API ERROR] getMasterShifts: $e");
      return [];
    }
  }
}