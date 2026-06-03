import 'dart:convert';
import 'package:intl/intl.dart';

// ============================================================
// Payment Model — type-safe, tidak lagi raw dynamic
// ============================================================
class OrderPayment {
  final int id;
  final String method;
  final double amountPaid;
  final double changeAmount;
  final String? referenceNo;
  final String? paidAt;

  OrderPayment({
    required this.id,
    required this.method,
    required this.amountPaid,
    required this.changeAmount,
    this.referenceNo,
    this.paidAt,
  });

  factory OrderPayment.fromJson(Map<String, dynamic> json) {
    return OrderPayment(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      method: json['method']?.toString() ?? 'unknown',
      amountPaid: double.tryParse(
        (json['amount_paid'] ?? '0').toString(),
      ) ?? 0.0,
      changeAmount: double.tryParse(
        (json['change_amount'] ?? '0').toString(),
      ) ?? 0.0,
      referenceNo: json['reference_no']?.toString(),
      paidAt: json['paid_at']?.toString(),
    );
  }
}

// ============================================================
// OrderLog
// ============================================================
class OrderLog {
  final String title, reason, date, actor;

  OrderLog({
    required this.title,
    required this.reason,
    required this.date,
    required this.actor,
  });

  factory OrderLog.fromJson(Map<String, dynamic> json) {
    String rawDate = json['date']?.toString() ??
        json['updated_at']?.toString() ??
        json['created_at']?.toString() ??
        "";

    String formattedLogDate = rawDate;
    if (rawDate.isNotEmpty) {
      try {
        // Backend kirim format "dd MMM yyyy HH:mm" langsung → tidak perlu parse ulang
        // Tapi jika ISO 8601, parse dulu
        if (rawDate.contains('T') || rawDate.contains('-')) {
          DateTime parsedDate = DateTime.parse(rawDate).toLocal();
          formattedLogDate = DateFormat('dd MMM yyyy HH:mm', 'id_ID').format(parsedDate);
        } else {
          formattedLogDate = rawDate; // sudah terformat dari backend
        }
      } catch (e) {
        formattedLogDate = rawDate.replaceAll('T', ' ').split('.')[0];
      }
    }

    return OrderLog(
      title: json['action'] ?? json['title'] ?? "Perubahan Pesanan",
      reason: json['reason']?.toString() ?? "-",
      date: formattedLogDate,
      actor: json['by'] ?? json['user']?['name'] ?? json['cashier_name'] ?? "Staff",
    );
  }
}

// ============================================================
// OrderItem
// ============================================================
class OrderItem {
  final int id, productId;
  int originalQty;
  int activeQty;
  final String itemName;
  final double unitPrice;       // harga setelah diskon (untuk display/kalkulasi)
  final double originalPrice;   // harga sebelum diskon (selalu harga asli)
  final int? discountId; 
  final int? categoryId;
  final bool isVoided;
  String notes;
  final String stationId;

  int get quantity => activeQty;
  double get price => unitPrice;
  double get subtotal =>
      (isVoided || activeQty == 0) ? 0 : (activeQty * unitPrice);

  set quantity(int val) {
    activeQty = val;
    if (activeQty > originalQty) originalQty = activeQty;
  }

  OrderItem({
    required this.id,
    required this.productId,
    required this.originalQty,
    required this.activeQty,
    required this.itemName,
    required this.unitPrice,
    double? originalPrice,
    this.discountId,
    this.categoryId,  
    this.isVoided = false,
    this.notes = "",
    required this.stationId,
  }) : originalPrice = originalPrice ?? unitPrice;

   factory OrderItem.fromJson(Map<String, dynamic> json) {
    final product = json['product'] ?? {};
    final int orig = int.tryParse(
      (json['qty'] ?? json['quantity'])?.toString() ?? '1',
    ) ?? 1;
    final int canc = int.tryParse(
      json['cancelled_qty']?.toString() ?? '0',
    ) ?? 0;
    final int active = (orig - canc).clamp(0, orig);
 
    return OrderItem(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      productId: int.tryParse(json['product_id']?.toString() ?? '0') ?? 0,
      originalQty: orig,
      activeQty: active,
      itemName: product['name'] ??
          json['product_name'] ??
          json['item_name'] ??
          'Tanpa Nama',
      unitPrice: double.tryParse(
        (json['price'] ?? json['unit_price'])?.toString() ?? '0',
      ) ?? 0.0,
      // Saat parse dari JSON (pending order, history), originalPrice = unitPrice
      // karena backend sudah menyimpan harga yang benar.
      discountId: json['discount_id'] != null
          ? int.tryParse(json['discount_id'].toString())
          : null,
          categoryId: json['category_id'] != null
    ? int.tryParse(json['category_id'].toString())
    : json['product']?['category_id'] != null
        ? int.tryParse(json['product']['category_id'].toString())
        : null,
      isVoided: json['is_void'] == 1 ||
          json['status'] == 'void' ||
          active <= 0,
      notes: json['notes'] ?? json['note'] ?? "",
      stationId: json['station_id']?.toString() ?? "",
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'cancelled_qty': originalQty - activeQty,
  };
}

// ============================================================
// Order
// ============================================================
class Order {
  final int id;
  final int orderId;
  final String invoiceNo,
      date,
      cashierName,
      customerName,
      tableNo,
      status;

  // ✅ PERBAIKAN 1: Nullable — karena backend bisa kirim null
  final String? paymentMethod;

  final int? tableId;
  final int? discountId;
  final Map<String, dynamic>? latestAcceptance;

  final double subtotalPrice,
      discountAmount,
      taxAmount,
      totalPrice,
      paidAmount,
      changeAmount;

  final List<OrderItem> items;
  final List<OrderLog> logs;
  final List<dynamic>? taxBreakdown;

  // ✅ PERBAIKAN 4: Type-safe payment list
  final List<OrderPayment> payments;

  // ============================================================
  // ✅ PERBAIKAN 5: Getter yang benar untuk logika pending
  // ============================================================

  String get paymentMethodDisplay {
    final m = paymentMethod?.trim() ?? '';
    if (m.isEmpty) return 'Cash';
    switch (m.toLowerCase()) {
      case 'cash':
      case 'tunai':
        return 'Tunai';
      case 'qris':
      case 'midtrans':
      case 'gopay':
      case 'other_qris':
        return 'QRIS';
      case 'card':
      case 'credit_card':
        return 'Kartu';
      default:
        return m.toUpperCase();
    }
  }
  
  /// Payment method yang sudah dinormalisasi ke lowercase
  String get normalizedMethod {
    // Prioritas: dari kolom orders
    final fromOrder = paymentMethod?.toLowerCase().trim() ?? '';
    if (fromOrder.isNotEmpty) return fromOrder;

    // Fallback: dari payment pertama (data lama)
    return payments.isNotEmpty
        ? payments.first.method.toLowerCase().trim()
        : '';
  }

  /// true = cash / belum ada payment method → perlu checkout kasir
  bool get isCashOrder {
    final m = normalizedMethod;
    if (m.isEmpty) return true; // null → anggap cash (data lama)
    return m == 'cash' || m == 'tunai';
  }

  /// true = non-cash (QRIS/Card) → langsung accept
  bool get isNonCashOrder {
    final m = normalizedMethod;
    return ['qris', 'midtrans', 'card', 'credit_card', 'gopay', 'other_qris']
        .contains(m);
  }

  /// Pending non-cash = sudah bayar online, tinggal accept
  bool get needsAcceptance => status == 'paid';

  bool get waitingPayment => status == 'pending' && isNonCashOrder;

  /// Pending cash dari QR = belum bayar, perlu ke kasir
  bool get needsCashierCheckout => status == 'pending' && isCashOrder;

  String? get tableNumber => tableId?.toString();

  Order({
    required this.id,
    required this.orderId,
    required this.invoiceNo,
    required this.date,
    required this.cashierName,
    required this.customerName,
    required this.tableNo,
    this.tableId,
    this.discountId,
    this.latestAcceptance,
    this.paymentMethod, 
    required this.status,
    required this.subtotalPrice,
    required this.discountAmount,
    required this.taxAmount,
    this.taxBreakdown,
    required this.totalPrice,
    required this.paidAmount,
    required this.changeAmount,
    required this.items,
    required this.logs,
    required this.payments,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> d =
        (json['data'] != null && json['data'] is Map)
            ? json['data'] as Map<String, dynamic>
            : json;

    final Map<String, dynamic> orderRelasi =
        d['order'] is Map ? d['order'] as Map<String, dynamic> : {};

    // Items
    final itemsRaw = (orderRelasi['order_items'] ??
        orderRelasi['items'] ??
        d['items'] ??
        []) as List;

    // Logs — handle string JSON dari backend
    final logsRawData = d['logs'] ??
        d['order_logs'] ??
        orderRelasi['logs'] ??
        orderRelasi['order_logs'];

    List logsRaw = [];
    if (logsRawData is String) {
      try {
        logsRaw = jsonDecode(logsRawData) as List;
      } catch (_) {
        logsRaw = [];
      }
    } else if (logsRawData is List) {
      logsRaw = logsRawData;
    }

    // Date
    final rawDate = d['updated_at']?.toString() ??
        d['paid_at']?.toString() ??
        d['created_at']?.toString() ??
        "";

    String formattedDate = "-";
    if (rawDate.isNotEmpty) {
      try {
        formattedDate = DateFormat('dd MMM yyyy, HH:mm', 'id_ID')
            .format(DateTime.parse(rawDate).toLocal());
      } catch (_) {
        formattedDate = rawDate.replaceAll('T', ' ').split('.')[0];
      }
    }

    // Table
    String tNo = "Takeaway";
    int? tId;
    final tableData = orderRelasi['table'] ?? d['table'];
    if (tableData != null) {
      tNo = "Meja ${tableData['name'] ?? tableData['id']}";
      tId = int.tryParse(tableData['id']?.toString() ?? '');
    } else if (d['table_id'] != null && d['table_id'] != 0) {
      tNo = "Meja ${d['table_id']}";
      tId = int.tryParse(d['table_id']?.toString() ?? '');
    }

    // ✅ PERBAIKAN 3: taxBreakdown selalu baca dari d
    List<dynamic>? taxBreakdown;
    final tbRaw = d['tax_breakdown'];
    if (tbRaw is String) {
      try {
        taxBreakdown = jsonDecode(tbRaw) as List<dynamic>?;
      } catch (_) {
        taxBreakdown = null;
      }
    } else if (tbRaw is List) {
      taxBreakdown = tbRaw;
    }

    return Order(
      id: int.tryParse(d['id']?.toString() ?? '0') ?? 0,
      orderId: int.tryParse(d['order_id']?.toString() ?? '0') ?? 0,
      invoiceNo: d['invoice_number']?.toString() ?? d['invoice_no'] ?? "-",
      date: formattedDate,
      cashierName: d['cashier_name'] ??
          d['cashier']?['name'] ??
          d['user']?['name'] ??
          "Staff",
      customerName: d['customer_name'] ?? "-",
      tableNo: tNo,
      tableId: tId,
      discountId: int.tryParse(d['discount_id']?.toString() ?? ''),

      // ✅ PERBAIKAN 1: nullable, tidak crash jika null
      paymentMethod: d['payment_method']?.toString(),

      status: d['status']?.toString() ?? 'unknown',
      subtotalPrice: double.tryParse(
        (d['subtotal_price'] ?? '0').toString(),
      ) ?? 0.0,
      discountAmount: double.tryParse(
        (d['discount_amount'] ?? '0').toString(),
      ) ?? 0.0,

      // ✅ PERBAIKAN 2: hapus 'taxAmount' camelCase yang tidak pernah match
      taxAmount: double.tryParse(
        (d['tax_amount'] ?? '0').toString(),
      ) ?? 0.0,

      taxBreakdown: taxBreakdown,
      totalPrice: double.tryParse(
        (d['total_price'] ?? '0').toString(),
      ) ?? 0.0,
      paidAmount: double.tryParse(
        (d['paid_amount'] ?? d['amount_paid'] ?? '0').toString(),
      ) ?? 0.0,
      changeAmount: double.tryParse(
        (d['change_amount'] ?? '0').toString(),
      ) ?? 0.0,
      items: itemsRaw.map((i) => OrderItem.fromJson(i)).toList(),
      logs: logsRaw.map((l) => OrderLog.fromJson(l)).toList(),

      // ✅ PERBAIKAN 4: parse ke OrderPayment, type-safe
      payments: (d['payments'] as List? ?? [])
          .map((p) => OrderPayment.fromJson(p))
          .toList(),
    );
  }

  bool get isAccepted {
    final acceptedAt = latestAcceptance?['accepted_at']?.toString();
    return acceptedAt != null && acceptedAt.isNotEmpty;
  }
}
