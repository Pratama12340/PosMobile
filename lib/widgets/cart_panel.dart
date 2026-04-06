import 'package:flutter/material.dart';
import '../models/order_model.dart';
import 'checkout_dialog.dart';

class CartPanel extends StatefulWidget {
  // 1. UPDATE TIPE DATA CART MENJADI MODEL ORDERITEM
  final Map<int, OrderItem> cart;
  
  // 2. UPDATE FUNGSI AGAR MENERIMA MODEL DAN TIPE DATA YANG BENAR
  final Function(OrderItem) onAdd;
  final Function(int) onRemove;
  final Function(int) onDelete;
  final String Function(double) formatCurrency; // Update int menjadi double
  
  // 3. TAMBAHAN VARIABEL YANG DIBUTUHKAN OLEH CHECKOUT DIALOG
  final String cashierName;

  const CartPanel({
    super.key,
    required this.cart,
    required this.onAdd,
    required this.onRemove,
    required this.onDelete,
    required this.formatCurrency,
    required this.cashierName,
  });

  @override
  State<CartPanel> createState() => _CartPanelState();
}

class _CartPanelState extends State<CartPanel> {
  final TextEditingController _tableController = TextEditingController();
  // Generate Order ID sederhana
  final String _orderId = "ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}";

  @override
  Widget build(BuildContext context) {
    // 4. PERHITUNGAN TOTAL MENGGUNAKAN GETTER MODEL (subtotal)
    double total = widget.cart.values.fold(0, (sum, item) => sum + item.subtotal);

    return Container(
      width: 400,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: Column(
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _orderId,
                style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
              ),
              const Icon(Icons.receipt_long, color: Colors.blue),
            ],
          ),
          const SizedBox(height: 20),
          
          // Field Meja
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFEEEEEE)),
            ),
            child: Row(
              children: [
                const Icon(Icons.table_restaurant, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                const Text("Table No : ", style: TextStyle(fontSize: 12, fontFamily: 'Poppins')),
                Expanded(
                  child: TextField(
                    controller: _tableController,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'JetBrains'),
                    decoration: const InputDecoration(
                      hintText: "...",
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),

          // List Pesanan
          Expanded(
            child: widget.cart.isEmpty
                ? const Center(
                    child: Text(
                      "Keranjang Masih Kosong",
                      style: TextStyle(color: Colors.grey, fontFamily: 'Poppins'),
                    ),
                  )
                : ListView.builder(
                    itemCount: widget.cart.length,
                    itemBuilder: (context, index) {
                      int productId = widget.cart.keys.elementAt(index);
                      OrderItem item = widget.cart[productId]!;
                      return _itemCart(productId, item);
                    },
                  ),
          ),
          const Divider(),
          
          // Total & Button Checkout
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Total",
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontFamily: 'Poppins'),
              ),
              Text(
                widget.formatCurrency(total),
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, fontFamily: 'JetBrains', color: Colors.blue),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: widget.cart.isEmpty
                  ? null
                  : () {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => CheckoutDialog(
                          cart: widget.cart,
                          totalAmount: total,
                          orderId: _orderId,
                          tableNumber: _tableController.text,
                          cashierName: widget.cashierName,
                          formatCurrency: widget.formatCurrency,
                        ),
                      );
                    },
              child: const Text(
                "Checkout",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Poppins'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 5. UPDATE WIDGET ITEM MENGGUNAKAN MODEL
  Widget _itemCart(int productId, OrderItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.itemName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Poppins'),
                ),
                Text(
                  widget.formatCurrency(item.unitPrice),
                  style: const TextStyle(color: Colors.grey, fontSize: 11, fontFamily: 'JetBrains'),
                ),
              ],
            ),
          ),
          Row(
            children: [
              // Tombol Minus
              GestureDetector(
                onTap: () => widget.onRemove(productId),
                child: const Icon(Icons.remove_circle_outline, color: Colors.blue, size: 22),
              ),
              // Jumlah Barang
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  "${item.quantity}",
                  style: const TextStyle(fontFamily: 'JetBrains', fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
              // Tombol Plus
              GestureDetector(
                onTap: () => widget.onAdd(item),
                child: const Icon(Icons.add_circle_outline, color: Colors.blue, size: 22),
              ),
            ],
          )
        ],
      ),
    );
  }
}