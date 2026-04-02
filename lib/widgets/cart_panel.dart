import 'package:flutter/material.dart';
import 'checkout_dialog.dart';

class CartPanel extends StatefulWidget {
  final Map<String, Map<String, dynamic>> cart;
  final Function(String, int) onAdd;
  final Function(String) onRemove;
  final Function(String) onDelete;
  final String Function(int) formatCurrency;

  const CartPanel({
    super.key,
    required this.cart,
    required this.onAdd,
    required this.onRemove,
    required this.onDelete,
    required this.formatCurrency,
  });

  @override
  State<CartPanel> createState() => _CartPanelState();
}

class _CartPanelState extends State<CartPanel> {
  final TextEditingController _tableController = TextEditingController();
  final String _orderId = "#ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(9)}";

  @override
  Widget build(BuildContext context) {
    int total = widget.cart.values.fold(0, (sum, item) => sum + (item['qty'] as int) * (item['price'] as int));

    return Container(
      width: 400,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(color: Colors.white),
      child: Column(
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_orderId, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
              const Icon(Icons.more_horiz),
            ],
          ),
          const SizedBox(height: 20),
          // List Pesanan
          Expanded(
            child: ListView(
              children: widget.cart.entries.map((entry) => _itemCart(entry)).toList(),
            ),
          ),
          const Divider(),
          // Total & Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Total", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontFamily: 'Poppins')),
              Text(widget.formatCurrency(total), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, fontFamily: 'JetBrains', color: Colors.blue)),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () {
                if (widget.cart.isEmpty) return;
                showDialog(
                  context: context,
                  builder: (context) => CheckoutDialog(
                    cart: widget.cart,
                    totalAmount: total,
                    orderId: _orderId,
                    tableNumber: _tableController.text,
                    formatCurrency: widget.formatCurrency,
                  ),
                );
              },
              child: const Text("Checkout", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemCart(MapEntry<String, Map<String, dynamic>> entry) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Poppins')),
              Text(widget.formatCurrency(entry.value['price']), style: const TextStyle(color: Colors.grey, fontSize: 11, fontFamily: 'JetBrains')),
            ],
          ),
          Row(
            children: [
              GestureDetector(onTap: () => widget.onRemove(entry.key), child: const Icon(Icons.remove_circle_outline, color: Colors.blue, size: 20)),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text("${entry.value['qty']}", style: const TextStyle(fontFamily: 'JetBrains'))),
              GestureDetector(onTap: () => widget.onAdd(entry.key, entry.value['price']), child: const Icon(Icons.add_circle_outline, color: Colors.blue, size: 20)),
            ],
          )
        ],
      ),
    );
  }
}