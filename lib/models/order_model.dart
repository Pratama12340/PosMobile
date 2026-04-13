class OrderItem {
  final int id; // Tambahkan ini agar tidak error di line 18
  int quantity;
  final String itemName;
  final double unitPrice;
  String notes;

  OrderItem({
    required this.id, // Tambahkan ke constructor
    required this.quantity,
    required this.itemName,
    required this.unitPrice,
    this.notes = "",
  });

  double get subtotal => quantity * unitPrice;

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      // Mencari ID dari product_id (biasanya untuk transaksi baru) atau id (dari riwayat)
      id: int.tryParse(json['product_id']?.toString() ?? json['id']?.toString() ?? '0') ?? 0,
      quantity: int.tryParse(json['quantity']?.toString() ?? '1') ?? 1,
      itemName: json['product_name'] ?? json['name'] ?? 'Tanpa Nama',
      unitPrice: double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
      notes: json['notes'] ?? "",
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': id, // Mengirim kembali ID produk
      'quantity': quantity,
      'product_name': itemName,
      'price': unitPrice,
      'notes': notes,
    };
  }
}

class Order {
  final int id; 
  final String orderNo;
  final String date;
  final String cashierName;
  final String tableNo;
  final String paymentMethod;
  final String status;
  final List<OrderItem> items;

  Order({
    required this.id,
    required this.orderNo,
    required this.date,
    required this.cashierName,
    required this.tableNo,
    required this.paymentMethod,
    required this.status,
    required this.items,
  });

  // Getter untuk menghitung total keseluruhan belanja
  double get totalAmount => items.fold(0.0, (sum, item) => sum + item.subtotal);

  factory Order.fromJson(Map<String, dynamic> json) {
    // Menangani list items yang mungkin datang dengan nama field berbeda (items atau details)
    var itemsList = (json['items'] as List?) ?? (json['details'] as List?) ?? [];
    List<OrderItem> parsedItems = itemsList.map((i) => OrderItem.fromJson(i)).toList();

    return Order(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      orderNo: json['order_number']?.toString() ?? json['order_no']?.toString() ?? "-",
      date: json['created_at'] ?? "-",
      cashierName: json['cashier_name'] ?? "Kasir",
      tableNo: json['table_number']?.toString() ?? json['table_no']?.toString() ?? "-",
      paymentMethod: json['payment_method'] ?? "-",
      status: json['status'] ?? "Selesai",
      items: parsedItems,
    );
  }
}