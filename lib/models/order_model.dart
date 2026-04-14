import 'package:intl/intl.dart';

class OrderItem {
  final int id;
  int quantity;
  final String itemName;
  final double unitPrice;
  String notes;

  OrderItem({
    required this.id,
    required this.quantity,
    required this.itemName,
    required this.unitPrice,
    this.notes = "",
  });

  double get subtotal => quantity * unitPrice;

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    var product = json['product'] ?? {};
    return OrderItem(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      quantity: int.tryParse(json['qty']?.toString() ?? '1') ?? 1,
      itemName: product['name'] ?? json['product_name'] ?? 'Tanpa Nama',
      unitPrice: double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
      notes: json['notes'] ?? "",
    );
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
  final double totalPrice;
  final List<OrderItem> items;

  Order({
    required this.id,
    required this.invoiceNo,
    required this.date,
    required this.cashierName,
    required this.tableNo,
    required this.paymentMethod,
    required this.status,
    required this.totalPrice,
    required this.items,
  });

  double get totalAmount => items.isEmpty ? totalPrice : items.fold(0.0, (sum, item) => sum + item.subtotal);

  factory Order.fromJson(Map<String, dynamic> json) {
    var orderData = json['order'] is Map ? json['order'] : json;
    var itemsList = (orderData['items'] as List?) ?? (json['items'] as List?) ?? [];

    // Membersihkan format tanggal
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
      // Mengambil nama kasir dari relasi cashier
      cashierName: json['cashier']?['name'] ?? "Karyawan", 
      // Mengambil nomor meja
      tableNo: orderData['table_id'] != null ? "Meja ${orderData['table_id']}" : "Takeaway",
      paymentMethod: (json['payment_method']?.toString() ?? "-").toUpperCase(),
      status: json['status'] ?? "paid",
      totalPrice: double.tryParse(json['total_price']?.toString() ?? '0') ?? 0.0,
      items: itemsList.map((i) => OrderItem.fromJson(i)).toList(),
    );
  }
}