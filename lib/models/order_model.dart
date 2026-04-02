// ==========================================
// MODEL DATA TRANSAKSI
// ==========================================
class OrderItem {
  final int quantity;
  final String itemName;
  final double unitPrice;
  final String notes;

  OrderItem({required this.quantity, required this.itemName, required this.unitPrice, this.notes = ""});
  
  double get subtotal => quantity * unitPrice; 

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      quantity: int.tryParse(json['quantity']?.toString() ?? '1') ?? 1,
      itemName: json['product_name'] ?? json['name'] ?? 'Tanpa Nama',
      unitPrice: double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
      notes: json['notes'] ?? "-",
    );
  }
}

class Order {
  final String orderNo;
  final String date;
  final String cashierName;
  final String tableNo;
  final String paymentMethod;
  final String status;
  final List<OrderItem> items;

  Order({required this.orderNo, required this.date, required this.cashierName, required this.tableNo, required this.paymentMethod, required this.status, required this.items});
  
  double get totalAmount => items.fold(0, (sum, item) => sum + item.subtotal);

  factory Order.fromJson(Map<String, dynamic> json) {
    var itemsList = json['items'] ?? json['details'] as List? ?? [];
    List<OrderItem> parsedItems = itemsList.map((i) => OrderItem.fromJson(i)).toList();

    return Order(
      orderNo: json['order_number']?.toString() ?? json['id']?.toString() ?? "-",
      date: json['created_at'] ?? "-", 
      cashierName: json['cashier_name'] ?? "Kasir",
      tableNo: json['table_number']?.toString() ?? "-",
      paymentMethod: json['payment_method'] ?? "-",
      status: json['status'] ?? "Selesai",
      items: parsedItems,
    );
  }
}