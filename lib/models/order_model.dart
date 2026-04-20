import 'package:intl/intl.dart';

class OrderItem {
  final int id;
  final int productId;
  int quantity;
  final String itemName;
  final double unitPrice;
  final bool isVoided;
  String note;

  OrderItem({
    required this.id,
    required this.productId,
    required this.quantity,
    required this.itemName,
    required this.unitPrice,
    this.isVoided = false,
    this.note = "",
  });

  // Jika item di-void, maka subtotal dianggap 0
  double get subtotal => isVoided ? 0 : (quantity * unitPrice);

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    var product = json['product'] ?? {};
    return OrderItem(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      productId: int.tryParse(json['product_id']?.toString() ?? '0') ?? 0,
      quantity: int.tryParse((json['qty'] ?? json['quantity'])?.toString() ?? '1') ?? 1,
      itemName: product['name'] ?? json['product_name'] ?? json['item_name'] ?? 'Tanpa Nama',
      unitPrice: double.tryParse((json['price'] ?? json['unit_price'])?.toString() ?? '0') ?? 0.0,
      isVoided: json['is_void'] == 1 || json['status'] == 'void',
      note: json['note'] ?? json['notes'] ?? "",
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId != 0 ? productId : id,
      'qty': quantity,
      'price': unitPrice.toInt(),
      'note': note,
      'is_void': isVoided ? 1 : 0,
    };
  }
}

class Order {
  final int id;
  final String invoiceNo;
  final String date;
  final String cashierName;
  final String customerName;
  final String tableNo;
  final String paymentMethod;
  final String status;
  final double subtotalPrice;
  final double discountAmount;
  final double taxAmount;
  final double totalPrice;
  final double paidAmount;
  final double changeAmount;
  final List<OrderItem> items;
  String? note;

  Order({
    required this.id,
    required this.invoiceNo,
    required this.date,
    required this.cashierName,
    required this.customerName,
    required this.tableNo,
    required this.paymentMethod,
    required this.status,
    required this.subtotalPrice,
    required this.discountAmount,
    required this.taxAmount,
    required this.totalPrice,
    required this.paidAmount,
    required this.changeAmount,
    required this.items,
    this.note,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    // 1. Deteksi Wrapper (Data Detail vs List History)
    final Map<String, dynamic> d = (json['data'] != null && json['data'] is Map) ? json['data'] : json;
    
    // 2. Akses Relasi Order (sering muncul di API detail history)
    final Map<String, dynamic> orderRelasi = d['order'] is Map ? d['order'] : {};
    
    // 3. Ambil List Items dari berbagai kemungkinan key API
    var itemsRaw = (orderRelasi['order_items'] ?? orderRelasi['items'] ?? d['items'] ?? []) as List;

    // 4. Format Tanggal & Waktu
    String rawDate = d['paid_at'] ?? d['created_at'] ?? orderRelasi['created_at'] ?? "";
    String formattedDate = "-";
    if (rawDate.isNotEmpty) {
      try {
        DateTime parsedDate = DateTime.parse(rawDate).toLocal();
        formattedDate = DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(parsedDate);
      } catch (e) {
        // Fallback jika format ISO gagal, hapus karakter aneh
        formattedDate = rawDate.replaceAll('T', ' ').split('.')[0];
      }
    }

    // 5. Logika Penamaan Meja
    String tNo = "Takeaway";
    var tableData = orderRelasi['table'] ?? d['table'];
    if (tableData != null) {
      tNo = "Meja ${tableData['name'] ?? tableData['id']}";
    } else if (d['table_id'] != null && d['table_id'] != 0) {
      tNo = "Meja ${d['table_id']}";
    }

    // 6. Nama Kasir
    String cName = d['cashier_name'] ?? d['cashier']?['name'] ?? d['user']?['name'] ?? "Staff";

    return Order(
      id: int.tryParse(d['id']?.toString() ?? '0') ?? 0,
      invoiceNo: d['invoice_number']?.toString() ?? d['invoice_no'] ?? "-",
      date: formattedDate,
      cashierName: cName,
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
      note: d['notes'] ?? d['note'],
    );
  }
}