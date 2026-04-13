// ==========================================
// MODEL DATA TRANSAKSI
// ==========================================

class OrderItem {
  final int id;
  int quantity;          // DIHAPUS 'final' agar bisa ditambah/kurang
  final String itemName; // Tetap 'final' karena nama barang tidak berubah
  final double unitPrice;// Tetap 'final' karena harga satuan tetap
  String notes;          // DIHAPUS 'final' agar bisa diisi notes dari TextField

  OrderItem({
    required this.id,
    required this.quantity, 
    required this.itemName, 
    required this.unitPrice, 
    this.notes = ""
  });
  
  double get subtotal => quantity * unitPrice; 

  // Fungsi untuk mengubah Map dari API menjadi Objek OrderItem
  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: int.tryParse(json['product_id']?.toString() ?? json['id']?.toString() ?? '0') ?? 0,
      quantity: int.tryParse(json['quantity']?.toString() ?? '1') ?? 1,
      // Menangani berbagai kemungkinan key dari API (product_name atau name)
      itemName: json['product_name'] ?? json['name'] ?? 'Tanpa Nama',
      unitPrice: double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
      notes: json['notes'] ?? "",
    );
  }

  // Fungsi untuk mengubah Objek menjadi Map (Berguna saat POST/Checkout ke API)
  Map<String, dynamic> toJson() {
    return {
      'quantity': quantity,
      'product_name': itemName,
      'price': unitPrice,
      'notes': notes,
    };
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

  Order({
    required this.orderNo, 
    required this.date, 
    required this.cashierName, 
    required this.tableNo, 
    required this.paymentMethod, 
    required this.status, 
    required this.items
  });
  
  double get totalAmount => items.fold(0, (sum, item) => sum + item.subtotal);

  factory Order.fromJson(Map<String, dynamic> json) {
    // Perbaikan logika pengambilan list agar lebih aman dari error null
    var itemsList = (json['items'] as List?) ?? (json['details'] as List?) ?? [];
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