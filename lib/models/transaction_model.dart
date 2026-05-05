class CartItem {
  final String itemName;
  final int quantity;
  final double unitPrice;

  CartItem({required this.itemName, required this.quantity, required this.unitPrice});
}

class TransactionModel {
  final String orderId;
  final String cashierName;
  final String customerName;
  final String tableNumber;
  final List<CartItem> items;
  final double discountAmount;
  final double taxAmount;
  final double totalDariHalaman;

  TransactionModel({
    required this.orderId,
    required this.cashierName,
    required this.customerName,
    required this.tableNumber,
    required this.items,
    required this.discountAmount,
    required this.taxAmount,
    required this.totalDariHalaman,
  });

  // Subtotal dihitung murni dari list items yang ada
  double get subtotal => items.fold(0, (sum, item) => sum + (item.quantity * item.unitPrice));
}