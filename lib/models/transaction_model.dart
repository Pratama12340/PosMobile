class CartItem {
  final String itemName;
  final int quantity;
  final double unitPrice;
  final String notes;

  CartItem({
    required this.itemName,
    required this.quantity,
    required this.unitPrice,
    required this.notes,
  });
}

class TransactionModel {
  final String orderId;
  final String outletName;
  final String outletAddress;
  final String cashierName;
  final String customerName;
  final String tableNumber;
  final List<CartItem> items;
  final double discountAmount;
  final List<Map<String, dynamic>> taxBreakdown;
  final double totalDariHalaman;

  TransactionModel({
    required this.orderId,
    required this.outletName,
    required this.outletAddress,
    required this.cashierName,
    required this.customerName,
    required this.tableNumber,
    required this.items,
    required this.discountAmount,
    required this.taxBreakdown,
    required this.totalDariHalaman,
  });

  double get subtotal =>
      items.fold(0, (sum, item) => sum + (item.quantity * item.unitPrice));
}
