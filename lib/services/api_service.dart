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

        // --- VALIDASI SHIFT ---
        final String? shiftId = data['shift_id']?.toString();
        if (shiftId == null || shiftId == 'null' || shiftId.isEmpty) {
          print("❌ [API REJECTED] Karyawan tidak memiliki jadwal shift aktif saat ini.");
          return {
            'success': false,
            'message': 'Akses Ditolak: Anda tidak memiliki jadwal shift aktif saat ini.',
          };
        }
        print("✅ [API VALIDASI] Shift ID Aktif: $shiftId");

        // --- SIMPAN KE STORAGE ---
        print("💾 [API ACTION] Login Valid. Menyimpan data ke Storage...");

        await StorageService.saveToken(data['token']);
        await StorageService.saveCashierName(user['name'] ?? "Kasir");
        final role = user['role'] ?? "Cashier";
        await StorageService.saveUserRole(role.toString());
        await StorageService.saveOutletId(outletId);
        
        final outletName = await fetchOutletNameLive();
        await StorageService.saveOutletName(outletName);

        if (user['image'] != null) {
          await StorageService.saveProfilePhoto(user['image'].toString());
        } else {
          await StorageService.saveProfilePhoto("");
        }

        // Simpan Shift ID (Status kasir dibiarkan utuh diurus oleh LoginScreen)
        await StorageService.saveCurrentShiftId(shiftId);

        // Jika kebetulan backend mengirimkan data opening balance, kita simpan.
        if (data['opening_balance'] != null) {
          int balance = int.tryParse(data['opening_balance'].toString()) ?? 0;
          await StorageService.saveOpeningBalance(balance);
          await StorageService.saveShiftStatus(true);
          print("💾 [API ACTION] Kas Awal dari server disimpan: $balance");
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
      
      // Ambil Shift ID saat ini agar Menu Terlaris difilter per shift
      final String? shiftId = await StorageService.getCurrentShiftId(); 

      final response = await http.get(
        Uri.parse(
          '$baseUrl/history-transactions?outlet_id=$outletId&shift_id=$shiftId&per_page=100',
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

  // --- 7. UPDATE ORDER (LOGIKA VOID ITEMS) ---
  static Future<bool> updateOrder({
    required int orderId,
    required List<OrderItem> items,
    required String reason,
    required double taxAmount,  // 👈 Tambahkan parameter ini
    required double totalPrice, // 👈 Tambahkan parameter ini
  }) async {
    try {
      final headers = await _getHeaders();

      // Memasukkan tax_amount dan total_price ke dalam body data
      final Map<String, dynamic> bodyData = {
        'reason': reason,
        'items': items.map((item) => item.toJson()).toList(),
        'tax_amount': taxAmount,   // 👈 Kirim nilai pajak terbaru
        'total_price': totalPrice, // 👈 Kirim nilai total terbaru
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
        print("✅ [API SUCCESS] Update Berhasil ke Database.");
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

  // --- 8. VOID / EDIT ITEM ---
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

  // --- 9. UPDATE ITEM STATUS ---
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

  // --- 10. GET STATIONS & OUTLETS ---
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

  // --- 11. GET DISCOUNTS ---
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

  // --- 12. GET TAXES ---
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

  // --- 13. CEK STATUS SHIFT (Source of Truth) ---
  static Future<Map<String, dynamic>> checkShiftStatus(int outletId) async {
    print("\n[API REQUEST] --> CEK STATUS SHIFT");
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/shift-karyawans/check-status?outlet_id=$outletId'),
        headers: headers,
      );

      print("[API RESPONSE] <-- STATUS: ${response.statusCode}");
      print("Body: ${response.body}");

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {
          'success': data['success'] ?? true, 
          'message': data['message'], 
          'data': data['data']
        };
      } else {
        return {
          'success': false, 
          'message': data['message'] ?? 'Gagal cek status shift'
        };
      }
    } catch (e) {
      print("💥 [API ERROR] checkShiftStatus: $e");
      return {'success': false, 'message': 'Koneksi error: $e'};
    }
  }

  // --- 14. MULAI SHIFT (BUKA KASIR) ---
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
        final int openingBalanceFromServer = 
            int.tryParse(data['data']['opening_balance'].toString()) ?? nominal;

        await StorageService.saveOpeningBalance(openingBalanceFromServer);
        // Set flag bahwa kasir sudah dibuka
        await StorageService.saveShiftStatus(true);
        
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

  // --- 15. AKHIRI SHIFT (TUTUP KASIR) ---
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

      // 1. JIKA NORMAL DAN SUKSES TUTUP SHIFT
      if (response.statusCode == 200 || response.statusCode == 201) {
        await StorageService.clearOpeningBalance();
        await StorageService.saveShiftStatus(false);
        return {'success': true, 'data': data};
      } 
      // 2. JIKA SERVER BILANG SHIFT SUDAH TIDAK ADA (SYNC)
      else if (response.statusCode == 404) {
        print("⚠️ [API SYNC] Server mengatakan tidak ada shift aktif. Memaksa reset data lokal...");
        
        await StorageService.clearOpeningBalance();
        await StorageService.saveShiftStatus(false);
        
        return {
          'success': true, 
          'message': 'Shift berhasil disinkronkan (Sudah tertutup di server).',
          'is_forced_sync': true 
        };
      } 
      else {
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

 // --- 16. MIDTRANS GET SNAP TOKEN ---
  // 🔥 PERBAIKAN: Menambahkan parameter paymentMethod dan amount
  static Future<Map<String, dynamic>> getMidtransToken(String orderId, String paymentMethod, int amount) async {
    print("\n[API REQUEST] --> GET MIDTRANS TOKEN");
    print("Order ID: $orderId | Method: $paymentMethod | Amount: $amount");
    try {
      final headers = await _getHeaders();
      
      // 🔥 PERBAIKAN: Menambahkan payload body 'payments'
      // Catatan: Saya mengasumsikan backend Anda menerima array of payments. 
      // Jika error berubah menjadi field tidak dikenali, ubah "payments": [...] menjadi "payments": {...} (tanpa kurung siku).
      final requestBody = jsonEncode({
        "payments": [
          {
           "method": paymentMethod,      // 👈 Diubah dari "payment_method"
            "amount_paid": amount
          }
        ]
      });

      final response = await http.post(
        Uri.parse('$baseUrl/orders/$orderId/payments'),
        headers: headers,
        body: requestBody, // 👈 Masukkan payload ke request
      );

      print("[API RESPONSE] <-- STATUS: ${response.statusCode}");
      print("Body: ${response.body}");

      final result = jsonDecode(response.body);
      
      if (response.statusCode == 200 || response.statusCode == 201) { // 👈 Terima 201 juga untuk antisipasi created
        return {
          'success': true, 
          'data': result['data'] ?? result 
        };
      } else {
        return {
          'success': false,
          'message': result['message'] ?? 'Gagal mendapatkan token Midtrans',
        };
      }
    } catch (e) {
      print("💥 [API ERROR] getMidtransToken: $e");
      return {'success': false, 'message': 'Koneksi error: $e'};
    }
  }

  // --- 17. GET REPORTS ---
  static Future<List<dynamic>> getReports() async {
    print("\n[API REQUEST] --> GET REPORTS");
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/reports'),
        headers: headers,
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
      print("💥 [API ERROR] getReports: $e");
      return [];
    }
  }

  // --- 18. GET TABLES ---
  static Future<List<dynamic>> getTables() async {
    print("\n[API REQUEST] --> GET TABLES");
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/tables'),
        headers: headers,
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
      print("💥 [API ERROR] getTables: $e");
      return [];
    }
  }
}