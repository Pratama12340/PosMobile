import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/order_model.dart';
import '../style.dart'; 
import 'checkout_dialog.dart';

class CartPanel extends StatefulWidget {
  final Map<int, OrderItem> cart;
  final String cashierName;
  final String Function(double) formatCurrency;
  final Function(OrderItem) onIncrease;
  final Function(int) onDecrease;
  final Function(int) onDelete;
  final Function(Map<String, dynamic>) onCheckoutSuccess; 

  const CartPanel({
    super.key,
    required this.cart,
    required this.cashierName,
    required this.formatCurrency,
    required this.onIncrease,
    required this.onDecrease,
    required this.onDelete,
    required this.onCheckoutSuccess,
  });

  @override
  State<CartPanel> createState() => _CartPanelState();
}

class _CartPanelState extends State<CartPanel> {
  final TextEditingController _tableController = TextEditingController();
  String _currentTime = "";
  String _currentDate = "";

  @override
  void initState() {
    super.initState();
    _updateTime();
  }

  void _updateTime() {
    final now = DateTime.now();
    setState(() {
      _currentDate = DateFormat('dd MMM yyyy').format(now);
      _currentTime = DateFormat('HH:mm').format(now);
    });
  }

  @override
  void dispose() {
    _tableController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double total = widget.cart.values.fold(0, (sum, item) => sum + item.subtotal);

    return Container(
      width: 350,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15)],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("ORD-${DateFormat('yyyyMMdd-HHmm').format(DateTime.now())}", 
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppStyle.primaryBlue)),
                    const Icon(Icons.print, color: AppStyle.primaryBlue, size: 20),
                  ],
                ),
                const SizedBox(height: 10),
                Text("Cashier : ${widget.cashierName}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Text("$_currentDate, $_currentTime", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 15),
                _buildTableInput(), // Baris 81 yang diperbaiki
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: widget.cart.length,
              padding: const EdgeInsets.all(15),
              itemBuilder: (context, index) {
                int id = widget.cart.keys.elementAt(index);
                return _buildCartItem(id, widget.cart[id]!);
              },
            ),
          ),
          _buildFooter(total),
        ],
      ),
    );
  }

  Widget _buildTableInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(12)),
      child: TextField(
        controller: _tableController, // Memastikan controller valid
        decoration: const InputDecoration(
          hintText: "Table No : ...", 
          border: InputBorder.none, 
          icon: Icon(Icons.table_bar, size: 18)
        ),
      ),
    );
  }

  Widget _buildCartItem(int id, OrderItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.itemName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(widget.formatCurrency(item.unitPrice), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              Row(
                children: [
                  GestureDetector(
                    onTap: () => widget.onDecrease(id),
                    child: Container(decoration: BoxDecoration(color: const Color(0xFFE8F0FE), borderRadius: BorderRadius.circular(5)), child: const Icon(Icons.remove, size: 18, color: AppStyle.primaryBlue)),
                  ),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text("${item.quantity}", style: const TextStyle(fontWeight: FontWeight.bold))),
                  GestureDetector(
                    onTap: () => widget.onIncrease(item),
                    child: Container(decoration: BoxDecoration(color: AppStyle.primaryBlue, borderRadius: BorderRadius.circular(5)), child: const Icon(Icons.add, size: 18, color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => item.notes = v,
                  style: const TextStyle(fontSize: 11),
                  decoration: InputDecoration(
                    hintText: "Notes",
                    filled: true,
                    fillColor: const Color(0xFFF8F9FA),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => widget.onDelete(id),
                child: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(double total) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFEEEEEE)))),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Total", style: TextStyle(color: Colors.grey)),
              Text(widget.formatCurrency(total), style: AppStyle.priceText.copyWith(fontSize: 22, color: AppStyle.primaryBlue)),
            ],
          ),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppStyle.primaryBlue, 
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: widget.cart.isEmpty ? null : () async {
                final result = await showDialog<Map<String, dynamic>>(
                  context: context,
                  builder: (context) => CheckoutDialog(
                    cart: widget.cart,
                    totalAmount: total,
                    orderId: "ORD-${DateFormat('yyyyMMdd-HHmm').format(DateTime.now())}",
                    tableNumber: _tableController.text,
                    cashierName: widget.cashierName,
                    formatCurrency: widget.formatCurrency,
                  ),
                );
                if (result != null) widget.onCheckoutSuccess(result);
              },
              child: const Text("Checkout", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }
}