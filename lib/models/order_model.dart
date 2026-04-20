import 'package:intl/intl.dart';

class OrderItem {
  final int id;
  final int productId; // Field yang menyebabkan error di HomeScreen
  int quantity;
  final String itemName;
  final double unitPrice;
  String note;

  OrderItem({
    required this.id,
    required this.productId, // Diperlukan untuk sinkronisasi
    required this.quantity,
    required this.itemName,
    required this.unitPrice,
    this.note = "",
  });

  double get subtotal => quantity * unitPrice;

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    var product = json['product'] ?? {};
    return OrderItem(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      productId: int.tryParse(json['product_id']?.toString() ?? '0') ?? 0,
      quantity: int.tryParse(json['qty']?.toString() ?? '1') ?? 1,
      itemName: product['name'] ?? json['product_name'] ?? 'Tanpa Nama',
      unitPrice: double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
      note: json['note'] ?? json['notes'] ?? "",
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId != 0 ? productId : id,
      'qty': quantity,
      'price': unitPrice.toInt(),
      'note': note,
    };
  }
}

class Order {
  final int id;
  final String invoiceNo;
  final String date;
  final String cashierName;
  final String tableNo;
  final String paymentMethod;
  final String status;
  final double subtotalPrice;
  final double discountAmount;
  final double taxAmount;
  final double totalPrice;
  final double amountPaid;
  final double changeAmount;
  final List<OrderItem> items;
  String? note;

  Order({
    required this.id,
    required this.invoiceNo,
    required this.date,
    required this.cashierName,
    required this.tableNo,
    required this.paymentMethod,
    required this.status,
    required this.subtotalPrice,
    required this.discountAmount,
    required this.taxAmount,
    required this.totalPrice,
    required this.amountPaid,
    required this.changeAmount,
    required this.items,
    this.note,
  });

  // Tambahkan Getter ini agar HistoryScreen & ReceiptDialog tidak Error
  double get totalAmount => totalPrice;

  factory Order.fromJson(Map<String, dynamic> json) {
    var orderData = json['order'] is Map ? json['order'] : json;
    var itemsList = (orderData['items'] as List?) ?? (json['items'] as List?) ?? [];

    String rawDate = json['paid_at'] ?? json['created_at'] ?? "";
    String formattedDate = "-";
    if (rawDate.isNotEmpty) {
      try {
        DateTime parsedDate = DateTime.parse(rawDate).toLocal();
        formattedDate = DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(parsedDate);
      } catch (e) {
        formattedDate = rawDate.split('T')[0];
      }
    }

    return Order(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      invoiceNo: json['invoice_number']?.toString() ?? json['invoice_no'] ?? "-",
      date: formattedDate,
      cashierName: json['cashier']?['name'] ?? json['cashier_name'] ?? "Karyawan",
      tableNo: json['table_id'] != null ? "Meja ${json['table_id']}" : "Takeaway",
      paymentMethod: (json['payment_method']?.toString() ?? "CASH").toUpperCase(),
      status: json['status'] ?? "paid",
      subtotalPrice: double.tryParse(json['subtotal_price']?.toString() ?? '0') ?? 0.0,
      discountAmount: double.tryParse(json['discount_amount']?.toString() ?? '0') ?? 0.0,
      taxAmount: double.tryParse(json['tax_amount']?.toString() ?? '0') ?? 0.0,
      totalPrice: double.tryParse(json['total_price']?.toString() ?? '0') ?? 0.0,
      amountPaid: double.tryParse(json['amount_paid']?.toString() ?? '0') ?? 0.0,
      changeAmount: double.tryParse(json['change_amount']?.toString() ?? '0') ?? 0.0,
      items: itemsList.map((i) => OrderItem.fromJson(i)).toList(),
      note: json['notes'] ?? json['note'],
    );
  }
}