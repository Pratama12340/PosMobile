import 'package:intl/intl.dart';

class OrderLog {
  final String title, reason, date, actor;

  OrderLog({required this.title, required this.reason, required this.date, required this.actor});

  factory OrderLog.fromJson(Map<String, dynamic> json) {
    String rawDate = json['created_at'] ?? "";
    String formattedLogDate = rawDate;
    if (rawDate.isNotEmpty) {
      try {
        DateTime parsedDate = DateTime.parse(rawDate).toLocal();
        formattedLogDate = DateFormat('dd MMM yyyy HH:mm', 'id_ID').format(parsedDate);
      } catch (e) {
        formattedLogDate = rawDate.replaceAll('T', ' ').split('.')[0];
      }
    }
    return OrderLog(
      title: json['title'] ?? json['action'] ?? "Perubahan Pesanan",
      reason: json['reason'] ?? json['notes'] ?? "-",
      date: formattedLogDate,
      actor: json['user']?['name'] ?? json['cashier_name'] ?? "Staff",
    );
  }
}

class OrderItem {
  final int id, productId;
  int originalQty; // 👈 PERBAIKAN 1: Hapus 'final' agar bisa disesuaikan di keranjang
  int activeQty;   
  
  final String itemName;
  final double unitPrice;
  final bool isVoided;
  String notes;

  int get quantity => activeQty;
  
  // 👈 PERBAIKAN 2: Sesuaikan setter agar tidak mengunci saat menambah pesanan baru
  set quantity(int val) {
    activeQty = val;
    // Jika activeQty bertambah melebihi originalQty (seperti di keranjang belanja),
    // maka originalQty harus mengikuti agar tidak dianggap 'void' (negatif) saat kirim ke backend.
    if (activeQty > originalQty) {
      originalQty = activeQty;
    }
  }

  OrderItem({
    required this.id, 
    required this.productId, 
    required this.originalQty,
    required this.activeQty,
    required this.itemName, 
    required this.unitPrice, 
    this.isVoided = false, 
    this.notes = "",
  });

  double get subtotal => (isVoided || activeQty == 0) ? 0 : (activeQty * unitPrice);

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    var product = json['product'] ?? {};
    
    int orig = int.tryParse((json['qty'] ?? json['quantity'])?.toString() ?? '1') ?? 1;
    int canc = int.tryParse(json['cancelled_qty']?.toString() ?? '0') ?? 0;

    return OrderItem(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      productId: int.tryParse(json['product_id']?.toString() ?? '0') ?? 0,
      originalQty: orig,
      activeQty: orig - canc, 
      itemName: product['name'] ?? json['product_name'] ?? json['item_name'] ?? 'Tanpa Nama',
      unitPrice: double.tryParse((json['price'] ?? json['unit_price'])?.toString() ?? '0') ?? 0.0,
      isVoided: json['is_void'] == 1 || json['status'] == 'void' || (orig - canc <= 0),
      notes: json['notes'] ?? json['note'] ?? "",
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'cancelled_qty': originalQty - activeQty,
    };
  }
}

class Order {
  final int id;              
  final int orderId;         
  final String invoiceNo, date, cashierName, customerName, tableNo, paymentMethod, status;
  final double subtotalPrice, discountAmount, taxAmount, totalPrice, paidAmount, changeAmount;
  final List<OrderItem> items;
  final List<OrderLog> logs;

  Order({
    required this.id,
    required this.orderId,    
    required this.invoiceNo, required this.date, required this.cashierName,
    required this.customerName, required this.tableNo, required this.paymentMethod, required this.status,
    required this.subtotalPrice, required this.discountAmount, required this.taxAmount,
    required this.totalPrice, required this.paidAmount, required this.changeAmount,
    required this.items, required this.logs,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> d = (json['data'] != null && json['data'] is Map) ? json['data'] : json;
    
    final int actualOrderId = int.tryParse(d['order_id']?.toString() ?? '0') ?? 0;

    final Map<String, dynamic> orderRelasi = d['order'] is Map ? d['order'] : {};
    var itemsRaw = (orderRelasi['order_items'] ?? orderRelasi['items'] ?? d['items'] ?? []) as List;
    var logsRaw = (d['logs'] ?? d['order_logs'] ?? orderRelasi['logs'] ?? orderRelasi['order_logs'] ?? []) as List;

    String rawDate = d['paid_at'] ?? d['created_at'] ?? orderRelasi['created_at'] ?? "";
    String formattedDate = "-";
    if (rawDate.isNotEmpty) {
      try {
        DateTime parsedDate = DateTime.parse(rawDate).toLocal();
        formattedDate = DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(parsedDate);
      } catch (e) {
        formattedDate = rawDate.replaceAll('T', ' ').split('.')[0];
      }
    }

    String tNo = "Takeaway";
    var tableData = orderRelasi['table'] ?? d['table'];
    if (tableData != null) {
      tNo = "Meja ${tableData['name'] ?? tableData['id']}";
    } else if (d['table_id'] != null && d['table_id'] != 0) {
      tNo = "Meja ${d['table_id']}";
    }

    return Order(
      id: int.tryParse(d['id']?.toString() ?? '0') ?? 0, 
      orderId: actualOrderId,                            
      invoiceNo: d['invoice_number']?.toString() ?? d['invoice_no'] ?? "-",
      date: formattedDate,
      cashierName: d['cashier_name'] ?? d['cashier']?['name'] ?? d['user']?['name'] ?? "Staff",
      customerName: d['customer_name'] ?? "-",
      tableNo: tNo,
      paymentMethod: (d['payment_method']?.toString() ?? "CASH").toUpperCase(),
      status: d['status'] ?? "paid",
      subtotalPrice: double.tryParse((d['subtotal_price'] ?? '0').toString()) ?? 0.0,
      discountAmount: double.tryParse((d['discount_amount'] ?? '0').toString()) ?? 0.0,
      taxAmount: double.tryParse((d['tax_amount'] ?? '0').toString()) ?? 0.0,
      totalPrice: double.tryParse((d['total_price'] ?? '0').toString()) ?? 0.0,
      paidAmount: double.tryParse((d['paid_amount'] ?? d['amount_paid'] ?? '0').toString()) ?? 0.0,
      changeAmount: double.tryParse((d['change_amount'] ?? '0').toString()) ?? 0.0,
      items: itemsRaw.map((i) => OrderItem.fromJson(i)).toList(),
      logs: logsRaw.map((l) => OrderLog.fromJson(l)).toList(),
    );
  }
}