import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/order_model.dart';
import '../style.dart'; 
import '../services/storage_service.dart';
import 'checkout_dialog.dart';

class CartPanel extends StatefulWidget {
  final Map<int, OrderItem> cart;
  final String Function(double) formatCurrency;
  final Function(OrderItem) onIncrease;
  final Function(int) onDecrease;
  final Function(int) onDelete;
  final Function(Map<String, dynamic>) onCheckoutSuccess; 
  final VoidCallback onSaveDraft; 

  const CartPanel({
    super.key,
    required this.cart,
    required this.formatCurrency,
    required this.onIncrease,
    required this.onDecrease,
    required this.onDelete,
    required this.onCheckoutSuccess,
    required this.onSaveDraft, 
  });

  @override
  State<CartPanel> createState() => _CartPanelState();
}

class _CartPanelState extends State<CartPanel> {
  final TextEditingController _tableController = TextEditingController();
  
  // Variabel tetap disimpan untuk dikirim ke CheckoutDialog
  String _currentTime = "";
  String _currentDate = "";
  String _orderId = "";
  String _cashierName = "Loading...";

  @override
  void initState() {
    super.initState();
    _generateOrderData();
    _loadCashierData();
  }

  Future<void> _loadCashierData() async {
    final name = await StorageService.getCashierName();
    if (mounted) setState(() => _cashierName = name);
  }

  void _generateOrderData() {
    final now = DateTime.now();
    setState(() {
      _currentDate = DateFormat('dd MMM yyyy').format(now);
      _currentTime = DateFormat('HH:mm').format(now);
      _orderId = "ORD-${DateFormat('yyyyMMdd-HHmm').format(now)}";
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
      width: 340, 
      margin: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 8))
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15), // Vertical padding sedikit dikurangi
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 👇 BAGIAN ATAS (Header & Tombol Draft)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Teks Pesanan Baru (opsional, agar tidak terlalu kosong di kiri)
                    const Text(
                      "Pesanan Saat Ini",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                    ),
                    
                    // TOMBOL SIMPAN KE DRAFT (Menggantikan ikon X)
                    TextButton.icon(
                      onPressed: widget.onSaveDraft,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        backgroundColor: AppStyle.primaryBlue.withOpacity(0.1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.inventory_2_outlined, color: AppStyle.primaryBlue, size: 16),
                      label: const Text(
                        "Draft", 
                        style: TextStyle(color: AppStyle.primaryBlue, fontSize: 13, fontWeight: FontWeight.bold)
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 15),
                
                // 👇 INPUT NOMOR MEJA (Dinaikkan ke atas sini)
                _buildTableInput(), 
              ],
            ),
          ),
          
          const Divider(height: 1, thickness: 1, color: Color(0xFFF5F5F5)),
          
          // LIST MENU PESANAN
          Expanded(
            child: ListView.builder(
              itemCount: widget.cart.length,
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
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
      height: 45, 
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC), 
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppStyle.primaryBlue.withOpacity(0.1))
      ),
      child: Row(
        children: [
          const Icon(Icons.table_bar_rounded, size: 18, color: AppStyle.primaryBlue),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _tableController,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppStyle.primaryBlue),
              decoration: const InputDecoration(
                hintText: "Nomor Meja / Area",
                hintStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.normal, color: Colors.grey),
                border: InputBorder.none, 
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(int id, OrderItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15), 
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.itemName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black)),
                    Text(widget.formatCurrency(item.unitPrice), style: const TextStyle(color: Colors.black45, fontSize: 12)),
                  ],
                ),
              ),
              Row(
                children: [
                  _qtyButton(Icons.remove, () => widget.onDecrease(id), isPrimary: false),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10), 
                    child: Text("${item.quantity}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))
                  ),
                  _qtyButton(Icons.add, () => widget.onIncrease(item), isPrimary: true),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => item.notes = v,
                  style: const TextStyle(fontSize: 11),
                  decoration: InputDecoration(
                    hintText: "Catatan...",
                    hintStyle: const TextStyle(color: Colors.grey, fontSize: 11),
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => widget.onDelete(id),
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              )
            ],
          ),
        ],
      ),
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback onTap, {required bool isPrimary}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isPrimary ? AppStyle.primaryBlue : const Color(0xFFF0F4F8), 
          borderRadius: BorderRadius.circular(6)
        ),
        child: Icon(icon, size: 16, color: isPrimary ? Colors.white : AppStyle.primaryBlue),
      ),
    );
  }

  Widget _buildFooter(double total) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        border: Border(top: BorderSide(color: Color(0xFFF5F5F5)))
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Total Bayar", style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold, fontSize: 13)),
              Text(widget.formatCurrency(total), 
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppStyle.primaryBlue)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48, 
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
                    orderId: _orderId,
                    tableNumber: _tableController.text,
                    cashierName: _cashierName,
                    formatCurrency: widget.formatCurrency,
                  ),
                );
                if (result != null) widget.onCheckoutSuccess(result);
              },
              child: const Text("Checkout", 
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          )
        ],
      ),
    );
  }
}