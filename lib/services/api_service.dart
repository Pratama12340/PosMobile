import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'storage_service.dart';
import '../models/product_model.dart';
import '../models/order_model.dart';
import '../models/discount_model.dart';
import '../models/rekap_model.dart';

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
    debugPrint("\n=========================================");
    debugPrint("[API REQUEST] --> LOGIN PIN");
    debugPrint("Payload: {'pin': '***', 'outlet_id': $outletId}");

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login-pin'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'pin': pin, 'outlet_id': outletId}),
      );

      debugPrint("[API RESPONSE] <-- STATUS: ${response.statusCode}");

      // ✅ FIX 2: Token tidak dicetak ke log (keamanan)
      if (kDebugMode) {
        final body = Map<String, dynamic>.from(jsonDecode(response.body));
        body.remove('token');
        debugPrint('[RESPONSE BODY]: $body');
      }

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final user = data['user'];
        if (user == null) {
          debugPrint("❌ [API ERROR] Data user dari server bernilai null.");
          return {
            'success': false,
            'message': 'Format data server tidak valid.',
          };
        }

        final int userOutletId =
            int.tryParse(user['outlet_id'].toString()) ?? 0;
        debugPrint(
          "🔍 [API VALIDASI] Cek Cabang Karyawan: DB ($userOutletId) vs App ($outletId)",
        );

        if (userOutletId != outletId) {
          debugPrint("❌ [API REJECTED] Karyawan terdaftar di cabang lain!");
          return {
            'success': false,
            'message': 'Akses Ditolak: Anda terdaftar di Cabang lain.',
          };
        }

        final String? shiftId = data['shift_id']?.toString();
        if (shiftId == null || shiftId == 'null' || shiftId.isEmpty) {
          debugPrint(
            "❌ [API REJECTED] Karyawan tidak memiliki jadwal shift aktif saat ini.",
          );
          return {
            'success': false,
            'message':
                'Akses Ditolak: Anda tidak memiliki jadwal shift aktif saat ini.',
          };
        }

        await StorageService.saveToken(data['token']);
        await StorageService.saveCashierName(user['name'] ?? "Kasir");
        await StorageService.saveUserRole(
          user['role']?.toString() ?? "Cashier",
        );
        await StorageService.saveOutletId(outletId);

        if (user['image'] != null) {
          await StorageService.saveProfilePhoto(user['image'].toString());
        } else {
          await StorageService.saveProfilePhoto("");
        }

        await StorageService.saveCurrentShiftId(shiftId);

        if (data['opening_balance'] != null) {
          int balance = int.tryParse(data['opening_balance'].toString()) ?? 0;
          await StorageService.saveOpeningBalance(balance);
          await StorageService.saveShiftStatus(true);
        }

        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['message'] ?? 'PIN Salah!'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Koneksi error: $e'};
    }
  }

  // --- 2. FETCH OUTLET INFO LIVE ---
  static Future<Map<String, dynamic>> fetchOutletInfoLive() async {
    debugPrint("[API REQUEST] --> FETCH OUTLET INFO LIVE");
    try {
      // ✅ FIX 1: Deklarasikan role dari storage agar kondisi di bawah bisa berjalan
      final String role = await StorageService.getUserRole();
      final outletId = await StorageService.getOutletId();

      if (outletId == null) {
        return {
          'name': "Outlet Belum Dipilih",
          'address_outlet': "-",
          'phone_number_outlet': "-",
          'image': null,
          'owner_name': "-",
          'owner_email': "-",
        };
      }

      // ✅ FIX 3: Gunakan _getHeaders() agar konsisten, tidak perlu ambil token manual
      final headers = await _getHeaders();

      final response = await http.get(
        Uri.parse('$baseUrl/outlets'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        List<dynamic> outlets = (result['data'] is List)
            ? result['data']
            : (result['data']?['data'] ?? []);

        for (var outlet in outlets) {
          if (outlet['id'].toString() == outletId.toString()) {
            String ownerName = "Belum diatur";
            String ownerEmail = "Belum diatur";

            // ✅ FIX 1: role sudah terdefinisi, kondisi ini kini berjalan dengan benar
            if (role == 'owner' && outlet['owner_id'] != null) {
              try {
                debugPrint(
                  "==================================================",
                );
                debugPrint("🚨 [DEBUG Laporan Backend] MULAI CEK AKSES /users");
                debugPrint(
                  "🚨 [DEBUG Laporan Backend] Mencari owner_id : ${outlet['owner_id']}",
                );

                // ✅ FIX 3: Pakai headers yang sama, tidak perlu tulis ulang
                final userResponse = await http.get(
                  Uri.parse('$baseUrl/users'),
                  headers: headers,
                );

                debugPrint(
                  "🚨 [DEBUG Laporan Backend] Status HTTP   : ${userResponse.statusCode}",
                );
                debugPrint(
                  "🚨 [DEBUG Laporan Backend] Body Response : ${userResponse.body}",
                );
                debugPrint(
                  "==================================================",
                );

                if (userResponse.statusCode == 200) {
                  final userResult = jsonDecode(userResponse.body);
                  List<dynamic> users = [];
                  if (userResult is List) {
                    users = userResult;
                  } else if (userResult['data'] is List) {
                    users = userResult['data'];
                  }

                  for (var user in users) {
                    if (user['id'].toString() ==
                        outlet['owner_id'].toString()) {
                      ownerName = user['name']?.toString() ?? "Belum diatur";
                      ownerEmail = user['email']?.toString() ?? "Belum diatur";
                      break;
                    }
                  }
                }
              } catch (e) {
                debugPrint("💥 [API ERROR] Gagal fetch data user: $e");
              }
            }

            return {
              'name': outlet['name']?.toString() ?? "Outlet",
              'address_outlet':
                  outlet['address_outlet']?.toString() ??
                  "Alamat tidak tersedia",
              'phone_number_outlet':
                  outlet['phone_number_outlet']?.toString() ?? "-",
              'image': outlet['image'],
              'owner_name': ownerName,
              'owner_email': ownerEmail,
            };
          }
        }
      }
      return {
        'name': "Outlet Tidak Ditemukan",
        'address_outlet': "-",
        'phone_number_outlet': "-",
        'image': null,
        'owner_name': "-",
        'owner_email': "-",
      };
    } catch (e) {
      debugPrint("💥 [API ERROR] fetchOutletInfoLive: $e");
      return {
        'name': "Error Jaringan",
        'address_outlet': "-",
        'phone_number_outlet': "-",
        'image': null,
        'owner_name': "-",
        'owner_email': "-",
      };
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
    debugPrint("\n[API REQUEST] --> CHECKOUT ORDER");
    try {
      final headers = await _getHeaders();
      if (!orderData.containsKey('outlet_id')) {
        orderData['outlet_id'] = await StorageService.getOutletId();
      }
      debugPrint("Payload: ${jsonEncode(orderData)}");
      final response = await http.post(
        Uri.parse('$baseUrl/orders/checkout'),
        headers: headers,
        body: jsonEncode(orderData),
      );
      debugPrint("[API RESPONSE] <-- STATUS: ${response.statusCode}");
      final result = jsonDecode(response.body);
      if (response.statusCode == 201 || response.statusCode == 200) {
        return {'success': true, 'data': result['data'] ?? result};
      } else {
        return {
          'success': false,
          'message': result['message'] ?? 'Gagal Simpan',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Kesalahan Sistem: $e'};
    }
  }

  // --- 5B. UPDATE PENDING ORDER ---
  static Future<Map<String, dynamic>> updatePendingOrder(
    String orderId,
    Map<String, dynamic> orderData,
  ) async {
    debugPrint("\n[API REQUEST] --> UPDATE PENDING ORDER (ID: $orderId)");
    try {
      final headers = await _getHeaders();

      if (!orderData.containsKey('outlet_id')) {
        final int? outletId = await StorageService.getOutletId();
        orderData['outlet_id'] = outletId;
      }

      List<dynamic> allItems = orderData['items'] ?? [];
      List<dynamic> existingItems = allItems
          .where((item) => item['id'] != null && item['id'] != 0)
          .toList();
      List<dynamic> newItems = allItems
          .where((item) => item['id'] == null || item['id'] == 0)
          .toList();

      // ✅ STEP 1A: Update item lama
      final itemsPayload = {
        '_method': 'PUT',
        'outlet_id': orderData['outlet_id'],
        'customer_name': orderData['customer_name'],
        'table_id': orderData['table_id'],
        'subtotal_price': orderData['subtotal_price'],
        'discount_amount': orderData['discount_amount'],
        'tax_amount': orderData['tax_amount'],
        'tax_breakdown': orderData['tax_breakdown'],
        'total_price': orderData['total_price'],
        'items': existingItems,
      };

      debugPrint(
        "Step 1A - Update Existing Items: ${jsonEncode(itemsPayload)}",
      );

      final itemsResponse = await http.post(
        Uri.parse('$baseUrl/orders/$orderId/items'),
        headers: headers,
        body: jsonEncode(itemsPayload),
      );

      debugPrint("[Step 1A RESPONSE] <-- STATUS: ${itemsResponse.statusCode}");
      debugPrint("[Step 1A BODY]: ${itemsResponse.body}");

      if (itemsResponse.statusCode != 200 && itemsResponse.statusCode != 201) {
        final err = jsonDecode(itemsResponse.body);
        return {
          'success': false,
          'message': err['message'] ?? 'Gagal update items',
        };
      }

      // ✅ STEP 1B: Tambah item baru
      if (newItems.isNotEmpty) {
        List<dynamic> cleanNewItems = newItems.map((item) {
          final Map<String, dynamic> clean = Map.from(item);
          clean.remove('id');
          return clean;
        }).toList();

        final newItemsPayload = {
          'outlet_id': orderData['outlet_id'],
          'items': cleanNewItems,
        };

        debugPrint("Step 1B - Add New Items: ${jsonEncode(newItemsPayload)}");

        final newItemsResponse = await http.post(
          Uri.parse('$baseUrl/orders/$orderId/add-items'),
          headers: headers,
          body: jsonEncode(newItemsPayload),
        );

        debugPrint(
          "[Step 1B RESPONSE] <-- STATUS: ${newItemsResponse.statusCode}",
        );
        debugPrint("[Step 1B BODY]: ${newItemsResponse.body}");

        if (newItemsResponse.statusCode == 404) {
          // Coba endpoint alternatif
          final altResponse = await http.post(
            Uri.parse('$baseUrl/orders/$orderId/items/add'),
            headers: headers,
            body: jsonEncode(newItemsPayload),
          );
          debugPrint(
            "[Step 1B ALT RESPONSE] <-- STATUS: ${altResponse.statusCode}",
          );
          debugPrint("[Step 1B ALT BODY]: ${altResponse.body}");

          // ✅ FIX 4: Jika endpoint alternatif juga gagal, return error
          if (altResponse.statusCode != 200 && altResponse.statusCode != 201) {
            final err = jsonDecode(altResponse.body);
            return {
              'success': false,
              'message': err['message'] ?? 'Gagal tambah item baru',
            };
          }
        } else if (newItemsResponse.statusCode != 200 &&
            newItemsResponse.statusCode != 201) {
          // ✅ FIX 4: Jika endpoint pertama gagal (bukan 404), return error
          final err = jsonDecode(newItemsResponse.body);
          return {
            'success': false,
            'message': err['message'] ?? 'Gagal tambah item',
          };
        }
      }

      // ✅ STEP 2: Proses pembayaran
      final paymentPayload = {
        'payments': [
          {
            'method': orderData['payment_method'],
            'amount_paid': orderData['paid_amount'],
          },
        ],
        'tax_amount': orderData['tax_amount'],
        'tax_breakdown': orderData['tax_breakdown'],
        'total_price': orderData['total_price'],
        'subtotal_price': orderData['subtotal_price'],
        'discount_amount': orderData['discount_amount'],
      };

      debugPrint("Step 2 - Process Payment: ${jsonEncode(paymentPayload)}");

      final paymentResponse = await http.post(
        Uri.parse('$baseUrl/orders/$orderId/payments'),
        headers: headers,
        body: jsonEncode(paymentPayload),
      );

      debugPrint("[Step 2 RESPONSE] <-- STATUS: ${paymentResponse.statusCode}");
      debugPrint("Body: ${paymentResponse.body}");

      final result = jsonDecode(paymentResponse.body);

      // Ubah pengecekan status menjadi >= 200 dan < 300
      if (paymentResponse.statusCode >= 200 &&
          paymentResponse.statusCode < 300) {
        debugPrint("✅ [API SUCCESS] Pembayaran Pending Order Berhasil.");
        return {'success': true, 'data': result['data'] ?? result};
      } else {
        debugPrint("❌ [API FAILED] Pembayaran Gagal: ${result['message']}");
        return {
          'success': false,
          'message': result['message'] ?? 'Gagal proses pembayaran',
        };
      }
    } catch (e) {
      debugPrint("💥 [API ERROR] updatePendingOrder: $e");
      return {'success': false, 'message': 'Kesalahan Sistem: $e'};
    }
  }

  // --- 5C. GET PENDING ORDERS ---
  static Future<List<Order>> getPendingOrders() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/orders?status=pending'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        List<dynamic> rawData = [];
        if (result['data'] != null) {
          if (result['data'] is Map && result['data'].containsKey('data')) {
            rawData = result['data']['data'];
          } else if (result['data'] is List) {
            rawData = result['data'];
          }
        }
        return rawData.map((json) => Order.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // --- 6. API HISTORY TRANSACTIONS ---
  static Future<List<Order>> fetchHistory() async {
    try {
      final headers = await _getHeaders();
      final int? outletId = await StorageService.getOutletId();
      final String? shiftId = await StorageService.getCurrentShiftId();
      final response = await http.get(
        Uri.parse(
          '$baseUrl/history-transactions?outlet_id=$outletId&shift_id=$shiftId&per_page=100',
        ),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        List<dynamic> data = (result['data'] is List)
            ? result['data']
            : result['data']['data'] ?? [];
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
      // ✅ FIX 5: Ambil bagian 'data' dari response sebelum parsing ke model
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        final data = result['data'] ?? result;
        return Order.fromJson(data);
      }
    } catch (e) {
      debugPrint("💥 [API ERROR] fetchHistoryDetail: $e");
    }
    return null;
  }

  // --- 7. UPDATE ORDER (VOID ITEMS) ---
  static Future<bool> updateOrder({
    required int orderId,
    required List<OrderItem> items,
    required String reason,
    required double taxAmount,
    required double totalPrice,
  }) async {
    try {
      final headers = await _getHeaders();
      final Map<String, dynamic> bodyData = {
        'reason': reason,
        'items': items.map((item) => item.toJson()).toList(),
        'tax_amount': taxAmount,
        'total_price': totalPrice,
      };
      final response = await http.post(
        Uri.parse('$baseUrl/orders/$orderId/void-items'),
        headers: headers,
        body: jsonEncode(bodyData),
      );
      return (response.statusCode == 200 || response.statusCode == 201);
    } catch (e) {
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
              'message': json.decode(response.body)['message'] ?? 'Gagal',
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
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/outlets'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result['data'] is List
            ? result['data']
            : result['data']['data'] ?? [];
      }
      return [];
    } catch (e) {
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
        if (res is List) {
          data = res;
        } else if (res is Map) {
          if (res['data'] is List) {
            data = res['data'];
          } else if (res['data'] is Map && res['data']['data'] is List) {
            data = res['data']['data'];
          } else if (res['discounts'] is List) {
            data = res['discounts'];
          }
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
        if (result is List) {
          return result;
        }
        if (result is Map) {
          if (result['data'] is List) {
            return result['data'];
          }
          if (result['data'] != null && result['data']['data'] is List) {
            return result['data']['data']; // ✅ tambah {}
          }
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // --- 13. CEK STATUS SHIFT ---
  static Future<Map<String, dynamic>> checkShiftStatus(int outletId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/shift-karyawans/check-status?outlet_id=$outletId'),
        headers: headers,
      );
      final data = jsonDecode(response.body);
      return response.statusCode == 200
          ? {
              'success': data['success'] ?? true,
              'message': data['message'],
              'data': data['data'],
            }
          : {'success': false, 'message': data['message'] ?? 'Gagal'};
    } catch (e) {
      return {'success': false, 'message': 'Koneksi error: $e'};
    }
  }

  // --- 14. MULAI SHIFT ---
  static Future<Map<String, dynamic>> startShift(
    int nominal,
    int outletId,
  ) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/shift-karyawans/start'),
        headers: headers,
        body: jsonEncode({'outlet_id': outletId, 'opening_balance': nominal}),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final int balance =
            int.tryParse(data['data']['opening_balance'].toString()) ?? nominal;
        await StorageService.saveOpeningBalance(balance);
        await StorageService.saveShiftStatus(true);
        return {'success': true, 'data': data};
      }
      return {
        'success': false,
        'message': data['message'] ?? 'Gagal memulai shift',
      };
    } catch (e) {
      return {'success': false, 'message': 'Koneksi error: $e'};
    }
  }

  // --- 15. AKHIRI SHIFT ---
  static Future<Map<String, dynamic>> endShift(
    int totalFisik,
    String notes,
  ) async {
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
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        await StorageService.clearOpeningBalance();
        await StorageService.saveShiftStatus(false);
        return {'success': true, 'data': data};
      } else if (response.statusCode == 404) {
        await StorageService.clearOpeningBalance();
        await StorageService.saveShiftStatus(false);
        return {
          'success': true,
          'message': 'Shift sinkron.',
          'is_forced_sync': true,
        };
      }
      return {'success': false, 'message': data['message'] ?? 'Gagal'};
    } catch (e) {
      return {'success': false, 'message': 'Koneksi error: $e'};
    }
  }

  static Future<List<RekapShift>> getShiftHistory() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/shift-karyawans'),
        headers: await _getHeaders(),
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
      return [];
    }
  }

  static Future<List<ShiftMaster>> getMasterShifts() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/shifts'),
        headers: await _getHeaders(),
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
      return [];
    }
  }

  // --- 16. MIDTRANS PAYMENTS ---
  static Future<Map<String, dynamic>> getMidtransToken(
    String orderId,
    String paymentMethod,
    int amount,
  ) async {
    try {
      final headers = await _getHeaders();
      final requestBody = jsonEncode({
        "payments": [
          {"method": paymentMethod, "amount_paid": amount},
        ],
      });
      final response = await http.post(
        Uri.parse('$baseUrl/orders/$orderId/payments'),
        headers: headers,
        body: requestBody,
      );
      final result = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': result['data'] ?? result};
      }
      return {
        'success': false,
        'message': result['message'] ?? 'Gagal mendapatkan token',
      };
    } catch (e) {
      return {'success': false, 'message': 'Koneksi error: $e'};
    }
  }

  // --- 17. MIDTRANS CONFIG ---
  static Future<Map<String, dynamic>> getMidtransConfig() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/midtrans-config'),
        headers: headers,
      );
      final result = jsonDecode(response.body);
      return response.statusCode == 200
          ? {
              'success': true,
              'client_key': result['client_key'],
              'merchant_base_url': result['merchant_base_url'],
            }
          : {'success': false, 'message': 'Gagal memuat konfigurasi'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // --- 18. REPORTS ---
  static Future<List<dynamic>> getReports() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/reports'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result['data'] is List
            ? result['data']
            : result['data']['data'] ?? [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // --- 19. TABLES ---
  static Future<List<dynamic>> getTables() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/tables'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result['data'] is List
            ? result['data']
            : result['data']['data'] ?? [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}
