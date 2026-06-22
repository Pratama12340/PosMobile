import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:sistem_pos/features/orders/models/order_model.dart';
import 'package:sistem_pos/core/services/storage_service.dart';
import 'package:sistem_pos/core/network/api_client.dart';

class _PendingPageResult {
  final List<Order> orders;
  final int lastPage;
  final bool failed; // true jika halaman gagal dimuat (timeout / non-200 / error)
  _PendingPageResult({
    required this.orders,
    required this.lastPage,
    this.failed = false,
  });
}

class OrderApiService {
  static final Map<int, List<Order>> _pendingCache = {};
  static final Map<int, DateTime> _pendingCacheTime = {};
  static const _cacheDuration = Duration(seconds: 30);

  static Future<Map<String, dynamic>> submitOrder(Map<String, dynamic> orderData) async {
    // debugPrint("\n[API REQUEST] --> CHECKOUT ORDER");
    try {
      if (!orderData.containsKey('outlet_id')) {
        orderData['outlet_id'] = await StorageService.getOutletId();
      }

      // debugPrint("Payload: ${jsonEncode(orderData)}");

      final response = await ApiClient.post(
        Uri.parse('${ApiClient.baseUrl}/orders/checkout'),
        body: jsonEncode(orderData),
      );

      // debugPrint("[API RESPONSE] <-- STATUS: ${response.statusCode}");
      // debugPrint("[API RESPONSE BODY] >>>>> ${response.body} <<<<<");
      // debugPrint("[API RESPONSE BODY LENGTH] ${response.body.length}");

      final result = jsonDecode(response.body);

      if (response.statusCode == 201 || response.statusCode == 200) {
        final resData = result['data'] ?? result;
        return {'success': true, 'data': resData};
      } else {
        return {'success': false, 'message': result['message'] ?? 'Gagal Simpan'};
      }
    } catch (e) {
      if (kDebugMode) print("💥 [API ERROR] submitOrder: $e");
      return {'success': false, 'message': 'Kesalahan Sistem: $e'};
    }
  }

  static Future<Map<String, dynamic>> updatePendingOrder(
    String orderId,
    Map<String, dynamic> orderData,
  ) async {
    // debugPrint("\n[API REQUEST] --> UPDATE PENDING ORDER (ID: $orderId)");
    try {

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

      // debugPrint("Step 1A - Update Existing Items: ${jsonEncode({'items': existingItems})}");

      final itemsResponse = await ApiClient.put(
        Uri.parse('${ApiClient.baseUrl}/orders/$orderId/items'),
        body: jsonEncode({'items': existingItems}),
      );

      // debugPrint("[Step 1A RESPONSE] <-- STATUS: ${itemsResponse.statusCode}");
      // debugPrint("[Step 1A BODY]: ${itemsResponse.body}");

      if (itemsResponse.statusCode != 200 && itemsResponse.statusCode != 201) {
        final err = jsonDecode(itemsResponse.body);
        return {'success': false, 'message': err['message'] ?? 'Gagal update items'};
      }

      if (newItems.isNotEmpty) {
        for (final item in newItems) {
          final singlePayload = {
            'product_id': item['product_id'],
            'qty': item['qty'] ?? item['quantity'] ?? 1,
          };

          // debugPrint("Step 1B - Add New Item: ${jsonEncode(singlePayload)}");

          final resp = await ApiClient.post(
            Uri.parse('${ApiClient.baseUrl}/orders/$orderId/items'),
            body: jsonEncode(singlePayload),
          );

          // debugPrint("[Step 1B RESPONSE] <-- STATUS: ${resp.statusCode}");
          // debugPrint("[Step 1B BODY]: ${resp.body}");

          if (resp.statusCode != 200 && resp.statusCode != 201) {
            final err = jsonDecode(resp.body);
            return {'success': false, 'message': err['message'] ?? 'Gagal tambah item baru'};
          }
        }
      }

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

      // debugPrint("Step 2 - Process Payment: ${jsonEncode(paymentPayload)}");

      final paymentResponse = await ApiClient.post(
        Uri.parse('${ApiClient.baseUrl}/orders/$orderId/payments'),
        body: jsonEncode(paymentPayload),
      );

      // debugPrint("[Step 2 RESPONSE] <-- STATUS: ${paymentResponse.statusCode}");
      // debugPrint("Body: ${paymentResponse.body}");

      final result = jsonDecode(paymentResponse.body);

      if (paymentResponse.statusCode >= 200 && paymentResponse.statusCode < 300) {
        // debugPrint("✅ [API SUCCESS] Pembayaran Pending Order Berhasil.");
        return {'success': true, 'data': result['data'] ?? result};
      } else {
        // debugPrint("❌ [API FAILED] Pembayaran Gagal: ${result['message']}");
        return {'success': false, 'message': result['message'] ?? 'Gagal proses pembayaran'};
      }
    } catch (e) {
      if (kDebugMode) print("💥 [API ERROR] updatePendingOrder: $e");
      return {'success': false, 'message': 'Kesalahan Sistem: $e'};
    }
  }

  static Future<List<Order>> getPendingOrders({
    bool forceRefresh = false,
  }) async {
    final int? outletId = await StorageService.getOutletId();
    final currentOutletId = outletId ?? 0;

    if (!forceRefresh &&
        _pendingCache.containsKey(currentOutletId) &&
        _pendingCacheTime.containsKey(currentOutletId) &&
        DateTime.now().difference(_pendingCacheTime[currentOutletId]!) < _cacheDuration) {
      // debugPrint('✅ [PENDING] Pakai cache (${_pendingCache[currentOutletId]!.length} orders)');
      return List.from(_pendingCache[currentOutletId]!);
    }

    try {

      bool anyFailed = false;

      final firstPage = await _fetchPendingPage(
        outletId: outletId,
        page: 1,
      );
      if (firstPage.failed) anyFailed = true;

      final List<Order> result = List.from(firstPage.orders);
      final int totalPages = firstPage.lastPage;

      // debugPrint('📦 [PENDING] Page 1: ${result.length} orders, total $totalPages hal.');

      if (totalPages > 1) {
        final remainingPages = List.generate(totalPages - 1, (i) => i + 2);
        const batchSize = 3;

        for (int i = 0; i < remainingPages.length; i += batchSize) {
          final batch = remainingPages.skip(i).take(batchSize).toList();

          final batchResults = await Future.wait(
            batch.map((page) => _fetchPendingPage(
                  outletId: outletId,
                  page: page,
                ).catchError((_) =>
                    _PendingPageResult(orders: [], lastPage: 1, failed: true))),
          );

          for (final pageResult in batchResults) {
            if (pageResult.failed) {
              anyFailed = true;
            } else {
              result.addAll(pageResult.orders);
            }
          }
        }
      }

      // Hanya simpan ke cache jika SEMUA halaman berhasil dimuat. Jika tidak,
      // daftar tak lengkap akan tersimpan & disajikan selama masa cache,
      // membuat sebagian pesanan "hilang".
      if (!anyFailed) {
        _pendingCache[currentOutletId] = result;
        _pendingCacheTime[currentOutletId] = DateTime.now();
        // debugPrint('✅ [PENDING] Total ${result.length} orders dari $totalPages halaman');
        return result;
      }

      // Ada halaman yang gagal → jangan cache hasil parsial.
      // Pakai cache lama bila masih ada agar tidak ada pesanan yang hilang;
      // jika tidak ada, kembalikan hasil parsial apa adanya (tanpa di-cache).
      if (kDebugMode) {
        print('⚠️ [PENDING] Sebagian halaman gagal dimuat — hasil tidak di-cache.');
      }
      if (_pendingCache.containsKey(currentOutletId)) {
        return List.from(_pendingCache[currentOutletId]!);
      }
      return result;
    } catch (e) {
      if (kDebugMode) print('💥 getPendingOrders error: $e');
      return _pendingCache[currentOutletId] ?? [];
    }
  }

  static Future<_PendingPageResult> _fetchPendingPage({
    required int? outletId,
    required int page,
  }) async {
    final response = await ApiClient.get(
      Uri.parse(
        '${ApiClient.baseUrl}/orders?status=pending&outlet_id=$outletId&per_page=20&page=$page',
      ),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      return _PendingPageResult(orders: [], lastPage: 1, failed: true);
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

    // Filter: Hanya tampilkan pesanan QR POS (tidak punya nama kasir)
    final qrOrdersOnly = rawData.where((json) {
      final hasCashierName = json['cashier_name'] != null && json['cashier_name'].toString().isNotEmpty;
      final hasCashierObj = json['cashier'] != null;
      final hasUserObj = json['user'] != null;
      
      return !(hasCashierName || hasCashierObj || hasUserObj);
    }).toList();

    return _PendingPageResult(
      orders: qrOrdersOnly.map((json) => Order.fromJson(json)).toList(),
      lastPage: lastPage,
    );
  }

  static void invalidatePendingCache() {
    _pendingCache.clear();
    _pendingCacheTime.clear();
    // debugPrint('🗑️ [PENDING] Cache diinvalidasi');
  }

  static Future<bool> acceptOrder(int orderId) async {
    try {
      final body = jsonEncode({'scope': 'cashier'});

      // debugPrint('=== ACCEPT ORDER ===');
      // debugPrint('URL: ${ApiClient.baseUrl}/orders/$orderId/accept');
      // debugPrint('Body: $body');

      final response = await ApiClient.post(
        Uri.parse('${ApiClient.baseUrl}/orders/$orderId/accept'),
        body: body,
      );

      // debugPrint('Status: ${response.statusCode}');
      // debugPrint('Response: ${response.body}');

      if (response.statusCode == 200) return true;

      // debugPrint('acceptOrder failed: ${response.statusCode} - ${response.body}');
      return false;
    } catch (e) {
      if (kDebugMode) print('💥 acceptOrder error: $e');
      return false;
    }
  }

  static Future<List<Order>> getPaidOrders() async {
    try {
      final response = await ApiClient.get(
        Uri.parse('${ApiClient.baseUrl}/orders?status=paid'),
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
      if (kDebugMode) print('💥 getPaidOrders error: $e');
      return [];
    }
  }

  static Future<List<Order>> fetchHistory() async {
    try {
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
            response = await ApiClient.get(
              Uri.parse(
                '${ApiClient.baseUrl}/history-transactions?outlet_id=$outletId&shift_id=$shiftId&per_page=100&page=$currentPage',
              ),
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
      } while (currentPage <= lastPage);

      return allOrders;
    } catch (e) {
      if (kDebugMode) print("💥 fetchHistory: $e");
      return [];
    }
  }

  static Future<List<Order>> fetchHistoryPage({required int page, int perPage = 20}) async {
    try {
      final int? outletId = await StorageService.getOutletId();
      final String? shiftId = await StorageService.getCurrentShiftId();

      final response = await ApiClient.get(
        Uri.parse('${ApiClient.baseUrl}/history-transactions?outlet_id=$outletId&shift_id=$shiftId&per_page=$perPage&page=$page'),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        final dynamic paginatedData = (result['data'] is Map) ? result['data'] : result;
        final List<dynamic> pageData = (paginatedData['data'] is List) ? paginatedData['data'] : [];
        
        return pageData.map((json) => Order.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) print("💥 fetchHistoryPage error: $e");
      return [];
    }
  }

  static Future<Order?> fetchHistoryDetail(int id) async {
    try {
      final response = await ApiClient.get(
        Uri.parse('${ApiClient.baseUrl}/history-transactions/$id'),
      );
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        final data = result['data'] ?? result;
        return Order.fromJson(data);
      }
    } catch (e) {
      if (kDebugMode) print("💥 fetchHistoryDetail: $e");
    }
    return null;
  }

  static Future<bool> updateOrder({
    required int orderId,
    required List<OrderItem> items,
    required String reason,
    required double taxAmount,
    required double totalPrice,
  }) async {
    try {
      final Map<String, dynamic> bodyData = {
        'reason': reason,
        'items': items.map((item) => item.toJson()).toList(),
        'tax_amount': taxAmount,
        'total_price': totalPrice,
      };
      final response = await ApiClient.post(
        Uri.parse('${ApiClient.baseUrl}/orders/$orderId/void-items'),
        body: jsonEncode(bodyData),
      );
      return (response.statusCode == 200 || response.statusCode == 201);
    } catch (e) {
      if (kDebugMode) print("💥 updateOrder error: $e");
      return false;
    }
  }

  static Future<Map<String, dynamic>> voidOrEditItem({
    required int itemId,
    required int orderId,
    required int newQty,
    required String reason,
  }) async {
    try {
      final response = await ApiClient.post(
        Uri.parse('${ApiClient.baseUrl}/order-items/$itemId/void-items'),
        body: jsonEncode({'order_id': orderId, 'qty': newQty, 'notes': reason}),
      );
      return (response.statusCode == 200 || response.statusCode == 201)
          ? {'success': true}
          : {'success': false, 'message': json.decode(response.body)['message'] ?? 'Gagal'};
    } catch (e) {
      if (kDebugMode) print("💥 voidOrEditItem error: $e");
      return {'success': false, 'message': 'Terjadi kesalahan: $e'};
    }
  }

  static Future<Map<String, dynamic>> updateItemStatus(int itemId, String status) async {
    try {
      final response = await ApiClient.patch(
        Uri.parse('${ApiClient.baseUrl}/order-items/$itemId/status'),
        body: jsonEncode({'status': status}),
      );
      return response.statusCode == 200 ? {'success': true} : {'success': false};
    } catch (e) {
      if (kDebugMode) print("💥 updateItemStatus error: $e");
      return {'success': false};
    }
  }
}
