import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'storage_service.dart';
import '../models/product_model.dart';
import '../models/order_model.dart';
import '../models/discount_model.dart';
import '../models/rekap_model.dart';
import 'printer_service.dart';
import '../models/print_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class ApiService {
  static const String baseUrl = 'https://api.etres.my.id/api/v1';

  static List<Order>? _pendingCache;
  static DateTime? _pendingCacheTime;
  static const _cacheDuration = Duration(seconds: 30);


  // -------------------------------------------------------------------------
  // HELPER
  // -------------------------------------------------------------------------

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

  // -------------------------------------------------------------------------
  // 1. LOGIN PIN
  // -------------------------------------------------------------------------

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
          return {'success': false, 'message': 'Format data server tidak valid.'};
        }

        final int userOutletId = int.tryParse(user['outlet_id'].toString()) ?? 0;
        debugPrint("🔍 [API VALIDASI] Cek Cabang Karyawan: DB ($userOutletId) vs App ($outletId)");

        if (userOutletId != outletId) {
          debugPrint("❌ [API REJECTED] Karyawan terdaftar di cabang lain!");
          return {'success': false, 'message': 'Akses Ditolak: Anda terdaftar di Cabang lain.'};
        }

        final String? shiftId = data['shift_id']?.toString();
        if (shiftId == null || shiftId == 'null' || shiftId.isEmpty) {
          debugPrint("❌ [API REJECTED] Karyawan tidak memiliki jadwal shift aktif saat ini.");
          return {
            'success': false,
            'message': 'Akses Ditolak: Anda tidak memiliki jadwal shift aktif saat ini.',
          };
        }

        await StorageService.saveToken(data['token']);
        await StorageService.saveCashierName(user['name'] ?? "Kasir");
        await StorageService.saveUserRole(user['role']?.toString() ?? "Cashier");
        await StorageService.saveOutletId(outletId);
        await StorageService.saveProfilePhoto(
          user['image'] != null ? user['image'].toString() : "",
        );
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

  // -------------------------------------------------------------------------
  // 2. FETCH OUTLET INFO LIVE
  // -------------------------------------------------------------------------

  static Future<Map<String, dynamic>> fetchOutletInfoLive() async {
    debugPrint("[API REQUEST] --> FETCH OUTLET INFO LIVE");
    try {
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

      final headers = await _getHeaders();
      final response = await http.get(Uri.parse('$baseUrl/outlets'), headers: headers);

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        List<dynamic> outlets = (result['data'] is List)
            ? result['data']
            : (result['data']?['data'] ?? []);

        for (var outlet in outlets) {
          if (outlet['id'].toString() == outletId.toString()) {
            String ownerName = "Belum diatur";
            String ownerEmail = "Belum diatur";

            if (role == 'owner' && outlet['owner_id'] != null) {
              try {
                debugPrint("==================================================");
                debugPrint("🚨 [DEBUG Laporan Backend] MULAI CEK AKSES /users");
                debugPrint("🚨 [DEBUG Laporan Backend] Mencari owner_id : ${outlet['owner_id']}");

                final userResponse = await http.get(Uri.parse('$baseUrl/users'), headers: headers);

                debugPrint("🚨 [DEBUG Laporan Backend] Status HTTP   : ${userResponse.statusCode}");
                debugPrint("🚨 [DEBUG Laporan Backend] Body Response : ${userResponse.body}");
                debugPrint("==================================================");

                if (userResponse.statusCode == 200) {
                  final userResult = jsonDecode(userResponse.body);
                  List<dynamic> users = [];
                  if (userResult is List) {
                    users = userResult;
                  } else if (userResult['data'] is List) {
                    users = userResult['data'];
                  }

                  for (var user in users) {
                    if (user['id'].toString() == outlet['owner_id'].toString()) {
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
              'address_outlet': outlet['address_outlet']?.toString() ?? "Alamat tidak tersedia",
              'phone_number_outlet': outlet['phone_number_outlet']?.toString() ?? "-",
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

  // -------------------------------------------------------------------------
  // 3. GET CATEGORIES
  // -------------------------------------------------------------------------

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

  // -------------------------------------------------------------------------
  // 4. GET PRODUCTS
  // -------------------------------------------------------------------------

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

  // -------------------------------------------------------------------------
  // 5. SUBMIT ORDER
  // -------------------------------------------------------------------------

  static Future<Map<String, dynamic>> submitOrder(Map<String, dynamic> orderData) async {
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
      debugPrint("[API RESPONSE BODY] >>>>> ${response.body} <<<<<");
      debugPrint("[API RESPONSE BODY LENGTH] ${response.body.length}");

      final result = jsonDecode(response.body);

      if (response.statusCode == 201 || response.statusCode == 200) {
        final resData = result['data'] ?? result;
        
        return {'success': true, 'data': resData};
      } else {
        return {'success': false, 'message': result['message'] ?? 'Gagal Simpan'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Kesalahan Sistem: $e'};
    }
  }

  // -------------------------------------------------------------------------
  // 5B. UPDATE PENDING ORDER
  // -------------------------------------------------------------------------

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

      // STEP 1A: Update item lama
      debugPrint("Step 1A - Update Existing Items: ${jsonEncode({'items': existingItems})}");

      final itemsResponse = await http.put(
        Uri.parse('$baseUrl/orders/$orderId/items'),
        headers: headers,
        body: jsonEncode({'items': existingItems}),
      );

      debugPrint("[Step 1A RESPONSE] <-- STATUS: ${itemsResponse.statusCode}");
      debugPrint("[Step 1A BODY]: ${itemsResponse.body}");

      if (itemsResponse.statusCode != 200 && itemsResponse.statusCode != 201) {
        final err = jsonDecode(itemsResponse.body);
        return {'success': false, 'message': err['message'] ?? 'Gagal update items'};
      }

      // STEP 1B: Tambah item baru — kirim satu per satu
      if (newItems.isNotEmpty) {
        for (final item in newItems) {
          final singlePayload = {
            'product_id': item['product_id'],
            'qty': item['qty'] ?? item['quantity'] ?? 1,
          };

          debugPrint("Step 1B - Add New Item: ${jsonEncode(singlePayload)}");

          final resp = await http.post(
            Uri.parse('$baseUrl/orders/$orderId/items'),
            headers: headers,
            body: jsonEncode(singlePayload),
          );

          debugPrint("[Step 1B RESPONSE] <-- STATUS: ${resp.statusCode}");
          debugPrint("[Step 1B BODY]: ${resp.body}");

          if (resp.statusCode != 200 && resp.statusCode != 201) {
            final err = jsonDecode(resp.body);
            return {'success': false, 'message': err['message'] ?? 'Gagal tambah item baru'};
          }
        }
      }

      // STEP 2: Proses pembayaran
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

      if (paymentResponse.statusCode >= 200 && paymentResponse.statusCode < 300) {
        debugPrint("✅ [API SUCCESS] Pembayaran Pending Order Berhasil.");
        return {'success': true, 'data': result['data'] ?? result};
      } else {
        debugPrint("❌ [API FAILED] Pembayaran Gagal: ${result['message']}");
        return {'success': false, 'message': result['message'] ?? 'Gagal proses pembayaran'};
      }
    } catch (e) {
      debugPrint("💥 [API ERROR] updatePendingOrder: $e");
      return {'success': false, 'message': 'Kesalahan Sistem: $e'};
    }
  }

// SEHARUSNYA — tambah outlet_id + per_page kecil
static Future<List<Order>> getPendingOrders({
  bool forceRefresh = false,
}) async {
  // 1. Kembalikan cache jika masih fresh
  if (!forceRefresh &&
      _pendingCache != null &&
      _pendingCacheTime != null &&
      DateTime.now().difference(_pendingCacheTime!) < _cacheDuration) {
    debugPrint('✅ [PENDING] Pakai cache (${_pendingCache!.length} orders)');
    return List.from(_pendingCache!);
  }

  try {
    final headers = await _getHeaders();
    final int? outletId = await StorageService.getOutletId();

    // 2. Fetch halaman pertama — tampil ke user secepat mungkin
    final firstPage = await _fetchPendingPage(
      headers: headers,
      outletId: outletId,
      page: 1,
    );

    final List<Order> result = List.from(firstPage.orders);
    final int totalPages = firstPage.lastPage;

    debugPrint('📦 [PENDING] Page 1: ${result.length} orders, total $totalPages hal.');

    // 3. Jika hanya 1 halaman, langsung simpan cache dan return
    if (totalPages <= 1) {
      _pendingCache = result;
      _pendingCacheTime = DateTime.now();
      return result;
    }

    // 4. Fetch sisa halaman PARALEL, batch 3 request bersamaan
    final remainingPages = List.generate(totalPages - 1, (i) => i + 2);
    const batchSize = 3;

    for (int i = 0; i < remainingPages.length; i += batchSize) {
      final batch = remainingPages.skip(i).take(batchSize).toList();

      final batchResults = await Future.wait(
        batch.map((page) => _fetchPendingPage(
              headers: headers,
              outletId: outletId,
              page: page,
            ).catchError((_) => _PendingPageResult(orders: [], lastPage: 1))),
      );

      for (final pageResult in batchResults) {
        result.addAll(pageResult.orders);
      }
    }

    _pendingCache = result;
    _pendingCacheTime = DateTime.now();
    debugPrint('✅ [PENDING] Total ${result.length} orders dari $totalPages halaman');
    return result;
  } catch (e) {
    debugPrint('💥 getPendingOrders error: $e');
    return _pendingCache ?? []; // fallback ke cache lama jika ada
  }
}

// Helper: fetch satu halaman
static Future<_PendingPageResult> _fetchPendingPage({
  required Map<String, String> headers,
  required int? outletId,
  required int page,
}) async {
  final response = await http.get(
    Uri.parse(
      '$baseUrl/orders?status=pending&outlet_id=$outletId&per_page=20&page=$page',
    ),
    headers: headers,
  ).timeout(const Duration(seconds: 10));

  if (response.statusCode != 200) {
    return _PendingPageResult(orders: [], lastPage: 1);
  }

  final result = jsonDecode(response.body);
  List<dynamic> rawData = [];
  int lastPage = 1;

  if (result['data'] is List) {
    rawData = result['data'];
    lastPage = result['last_page'] ?? 1;
  } else if (result['data'] is Map && result['data']['data'] is List) {
    rawData = result['data']['data'];
    lastPage = result['data']['last_page'] ?? 1;
  }

  return _PendingPageResult(
    orders: rawData.map((json) => Order.fromJson(json)).toList(),
    lastPage: lastPage,
  );
}

// Invalidasi cache — panggil setelah checkout / accept / reverb event
static void invalidatePendingCache() {
  _pendingCache = null;
  _pendingCacheTime = null;
  debugPrint('🗑️ [PENDING] Cache diinvalidasi');
}

  // -------------------------------------------------------------------------
  // 5D. ACCEPT ORDER
  // -------------------------------------------------------------------------

  static Future<bool> acceptOrder(int orderId) async {
    try {
      final headers = await _getHeaders();
      final body = jsonEncode({'scope': 'cashier'});

      debugPrint('=== ACCEPT ORDER ===');
      debugPrint('URL: $baseUrl/orders/$orderId/accept');
      debugPrint('Body: $body');

      final response = await http.post(
        Uri.parse('$baseUrl/orders/$orderId/accept'),
        headers: headers,
        body: body,
      );

      debugPrint('Status: ${response.statusCode}');
      debugPrint('Response: ${response.body}');

      if (response.statusCode == 200) return true;

      debugPrint('acceptOrder failed: ${response.statusCode} - ${response.body}');
      return false;
    } catch (e) {
      debugPrint('acceptOrder error: $e');
      return false;
    }
  }

  // -------------------------------------------------------------------------
  // 5E. GET PAID ORDERS (belum di-accept)
  // -------------------------------------------------------------------------

  static Future<List<Order>> getPaidOrders() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/orders?status=paid'),
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
        return rawData
            .map((json) => Order.fromJson(json))
            .where((order) => !order.isAccepted)
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // -------------------------------------------------------------------------
  // 6. FETCH HISTORY TRANSACTIONS
  // -------------------------------------------------------------------------

  static Future<List<Order>> fetchHistory() async {
  try {
    final headers = await _getHeaders();
    final int? outletId = await StorageService.getOutletId();
    final String? shiftId = await StorageService.getCurrentShiftId();

    List<Order> allOrders = [];
    int currentPage = 1;
    int lastPage = 1;
    const int maxRetry = 3;

    do {
      int attempt = 0;
      http.Response? response;

      while (attempt < maxRetry) {
        try {
          // PERUBAHAN: Ubah per_page menjadi lebih besar (misal 100 atau 200) agar mengurangi jumlah HTTP Request
          response = await http.get(
            Uri.parse(
              '$baseUrl/history-transactions?outlet_id=$outletId&shift_id=$shiftId&per_page=100&page=$currentPage',
            ),
            headers: headers,
          ).timeout(const Duration(seconds: 15));
          break;
        } catch (e) {
          attempt++;
          if (attempt >= maxRetry) rethrow;
        }
      }

      if (response == null || response.statusCode != 200) break;

      final result = jsonDecode(response.body);
      final dynamic paginatedData = (result['data'] is Map) ? result['data'] : result;
      final List<dynamic> pageData = (paginatedData['data'] is List) ? paginatedData['data'] : [];

      lastPage = paginatedData['last_page'] ?? 1;
      allOrders.addAll(pageData.map((json) => Order.fromJson(json)).toList());

      currentPage++;

      // PERUBAHAN: HAPUS await Future.delayed(const Duration(milliseconds: 200));

    } while (currentPage <= lastPage);

    return allOrders;
  } catch (e) {
    debugPrint("💥 fetchHistory: $e");
    return [];
  }
}

// Tarik data history HANYA untuk satu halaman spesifik
static Future<List<Order>> fetchHistoryPage({required int page, int perPage = 20}) async {
  try {
    final headers = await _getHeaders();
    final int? outletId = await StorageService.getOutletId();
    final String? shiftId = await StorageService.getCurrentShiftId();

    final response = await http.get(
      Uri.parse('$baseUrl/history-transactions?outlet_id=$outletId&shift_id=$shiftId&per_page=$perPage&page=$page'),
      headers: headers,
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final result = jsonDecode(response.body);
      final dynamic paginatedData = (result['data'] is Map) ? result['data'] : result;
      final List<dynamic> pageData = (paginatedData['data'] is List) ? paginatedData['data'] : [];
      
      return pageData.map((json) => Order.fromJson(json)).toList();
    }
    return [];
  } catch (e) {
    debugPrint("💥 fetchHistoryPage error: $e");
    return [];
  }
}

  // Dipakai oleh edit_dialog.dart — jangan hapus
  static Future<Order?> fetchHistoryDetail(int id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/history-transactions/$id'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        final data = result['data'] ?? result;
        return Order.fromJson(data);
      }
    } catch (e) {
      debugPrint("💥 fetchHistoryDetail: $e");
    }
    return null;
  }

  // -------------------------------------------------------------------------
  // 7. UPDATE ORDER (VOID ITEMS)
  // -------------------------------------------------------------------------

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

  // -------------------------------------------------------------------------
  // 8. VOID / EDIT ITEM
  // -------------------------------------------------------------------------

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
          : {'success': false, 'message': json.decode(response.body)['message'] ?? 'Gagal'};
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan: $e'};
    }
  }

  // -------------------------------------------------------------------------
  // 9. UPDATE ITEM STATUS
  // -------------------------------------------------------------------------

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

  // -------------------------------------------------------------------------
  // 10. GET STATIONS & OUTLETS
  // -------------------------------------------------------------------------

  static Future<List<dynamic>> getStations() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/stations'),
        headers: await _getHeaders(),
      );
      final result = jsonDecode(response.body);
      return response.statusCode == 200
          ? (result['data'] is List ? result['data'] : result['data']['data'] ?? [])
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
        return result['data'] is List ? result['data'] : result['data']['data'] ?? [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // -------------------------------------------------------------------------
  // 11. GET DISCOUNTS
  // -------------------------------------------------------------------------

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

  // -------------------------------------------------------------------------
  // 12. GET TAXES
  // -------------------------------------------------------------------------

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
          if (result['data'] != null && result['data']['data'] is List) {
            return result['data']['data'];
          }
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // -------------------------------------------------------------------------
  // 13. CEK STATUS SHIFT
  // -------------------------------------------------------------------------

  static Future<Map<String, dynamic>> checkShiftStatus(int outletId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/shift-karyawans/check-status?outlet_id=$outletId'),
        headers: headers,
      );
      final data = jsonDecode(response.body);
      return response.statusCode == 200
          ? {'success': data['success'] ?? true, 'message': data['message'], 'data': data['data']}
          : {'success': false, 'message': data['message'] ?? 'Gagal'};
    } catch (e) {
      return {'success': false, 'message': 'Koneksi error: $e'};
    }
  }

  // -------------------------------------------------------------------------
  // 14. MULAI SHIFT
  // -------------------------------------------------------------------------

  static Future<Map<String, dynamic>> startShift(int nominal, int outletId) async {
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
      return {'success': false, 'message': data['message'] ?? 'Gagal memulai shift'};
    } catch (e) {
      return {'success': false, 'message': 'Koneksi error: $e'};
    }
  }

  // -------------------------------------------------------------------------
  // 15. AKHIRI SHIFT
  // -------------------------------------------------------------------------

  static Future<Map<String, dynamic>> endShift(int totalFisik, String notes) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/shift-karyawans/end'),
        headers: headers,
        body: jsonEncode({'actual_closing_balance': totalFisik, 'notes': notes}),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        await StorageService.clearOpeningBalance();
        await StorageService.saveShiftStatus(false);
        return {'success': true, 'data': data};
      } else if (response.statusCode == 404) {
        await StorageService.clearOpeningBalance();
        await StorageService.saveShiftStatus(false);
        return {'success': true, 'message': 'Shift sinkron.', 'is_forced_sync': true};
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
        List data = result['data'] is List ? result['data'] : result['data']['data'] ?? [];
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
        List data = result['data'] is List ? result['data'] : result['data']['data'] ?? [];
        return data.map((json) => ShiftMaster.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // -------------------------------------------------------------------------
  // 16. MIDTRANS PAYMENTS
  // -------------------------------------------------------------------------

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
      return {'success': false, 'message': result['message'] ?? 'Gagal mendapatkan token'};
    } catch (e) {
      return {'success': false, 'message': 'Koneksi error: $e'};
    }
  }

  // -------------------------------------------------------------------------
  // 17. MIDTRANS CONFIG
  // -------------------------------------------------------------------------

  static Future<Map<String, dynamic>> getMidtransConfig() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse('$baseUrl/midtrans-config'), headers: headers);
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

  // -------------------------------------------------------------------------
  // 18. REPORTS
  // -------------------------------------------------------------------------

  static Future<List<dynamic>> getReports() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/reports'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result['data'] is List ? result['data'] : result['data']['data'] ?? [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // -------------------------------------------------------------------------
  // 19. GET TOP PRODUCTS (BESTSELLER)
  // -------------------------------------------------------------------------

  static Future<List<String>> getTopProducts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final int outletId = prefs.getInt('outlet_id') ?? 1;

      final response = await http.get(
        Uri.parse('$baseUrl/public/top-products?outlet_id=$outletId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        debugPrint("🏆 [CEK API BESTSELLER - OUTLET $outletId]: $result");

        List<dynamic> rawData = [];
        if (result['top_products'] != null) {
          rawData = result['top_products'];
        } else if (result['data'] != null) {
          rawData = result['data'] is List ? result['data'] : (result['data']['data'] ?? []);
        } else if (result is List) {
          rawData = result;
        }

        return rawData
            .map((item) => item['name']?.toString().toLowerCase().trim() ?? '')
            .where((name) => name.isNotEmpty)
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint("💥 [API ERROR] getTopProducts: $e");
      return [];
    }
  }

  // -------------------------------------------------------------------------
  // 20. TABLES
  // -------------------------------------------------------------------------

  static Future<List<dynamic>> getTables() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/tables'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result['data'] is List ? result['data'] : result['data']['data'] ?? [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}

class _PendingPageResult {
  final List<Order> orders;
  final int lastPage;
  _PendingPageResult({required this.orders, required this.lastPage});
}