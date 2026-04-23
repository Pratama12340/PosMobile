import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/order_model.dart';
import '../style.dart'; 
import '../services/storage_service.dart';
import 'checkout_dialog.dart';

class CartPanel extends StatefulWidget {
  final Map<int, OrderItem> cart;
  final String Function(double) formatCurrency;
  
  final String? initialCustomerName;
  final String? initialTableNumber;
  
  final Function(int) onIncrease; 
  final Function(int) onDecrease;
  final Function(int) onDelete;
  final Function(Map<String, dynamic>) onCheckoutSuccess; 
  final Function(String customerName, String tableNumber) onSaveDraft; 

  const CartPanel({
    super.key,
    required this.cart,
    required this.formatCurrency,
    this.initialCustomerName,
    this.initialTableNumber,
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
  late TextEditingController _tableController;
  late TextEditingController _customerController;
  
  // 🔥 Map untuk mengelola controller catatan tiap item menu secara dinamis
  final Map<int, TextEditingController> _noteControllers = {};
  
  String _currentTime = "";
  String _currentDate = "";
  String _orderId = "";
  String _cashierName = "Loading...";

  @override
  void initState() {
    super.initState();
    _customerController = TextEditingController(text: widget.initialCustomerName);
    _tableController = TextEditingController(text: widget.initialTableNumber);
    
    _generateOrderData();
    _loadCashierData();
    _syncNoteControllers(); // Inisialisasi catatan
  }

  // 🔥 Sinkronisasi saat Draf dipilih atau Cart berubah
  @override
  void didUpdateWidget(covariant CartPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Update Nama & Meja
    if (widget.initialCustomerName != oldWidget.initialCustomerName) {
      _customerController.text = widget.initialCustomerName ?? "";
    }
    if (widget.initialTableNumber != oldWidget.initialTableNumber) {
      _tableController.text = widget.initialTableNumber ?? "";
    }

    // Update Catatan (Notes) untuk setiap item
    _syncNoteControllers();
  }

  // Fungsi untuk menyinkronkan teks catatan di model ke dalam Controller
  void _syncNoteControllers() {
    widget.cart.forEach((id, item) {
      if (!_noteControllers.containsKey(id)) {
        _noteControllers[id] = TextEditingController(text: item.notes ?? "");
      } else {
        // Hanya update jika teks di controller berbeda dengan di model (mencegah kursor lompat)
        if (_noteControllers[id]!.text != item.notes) {
          _noteControllers[id]!.text = item.notes ?? "";
        }
      }
    });

    // Bersihkan controller yang itemnya sudah dihapus dari cart
    _noteControllers.removeWhere((id, controller) => !widget.cart.containsKey(id));
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
    _customerController.dispose();
    // Dispose semua note controllers
    for (var controller in _noteControllers.values) {
      controller.dispose();
    }
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
          BoxShadow(
            color: Colors.black.withOpacity(0.06), 
            blurRadius: 20, 
            offset: const Offset(0, 8)
          )
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Pesanan Saat Ini",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87, fontFamily: 'Poppins'),
                    ),
                    TextButton.icon(
                      onPressed: () => widget.onSaveDraft(_customerController.text, _tableController.text),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        backgroundColor: AppStyle.primaryBlue.withOpacity(0.1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.inventory_2_outlined, color: AppStyle.primaryBlue, size: 16),
                      label: const Text("Draft", style: TextStyle(color: AppStyle.primaryBlue, fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                _buildInput(controller: _customerController, hint: "Nama Customer", icon: Icons.person_outline_rounded),
                const SizedBox(height: 10),
                _buildInput(controller: _tableController, hint: "Nomor Meja / Area", icon: Icons.table_bar_rounded), 
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF5F5F5)),
          Expanded(
            child: ListView.builder(
              itemCount: widget.cart.length,
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              itemBuilder: (context, index) {
                int id = widget.cart.keys.elementAt(index);
                OrderItem item = widget.cart[id]!;
                
                // Pastikan controller sudah ada sebelum build
                if (!_noteControllers.containsKey(id)) {
                  _noteControllers[id] = TextEditingController(text: item.notes ?? "");
                }

                return _buildCartItem(id, item, _noteControllers[id]!, key: ValueKey("cart_$id"));
              },
            ),
          ),
          _buildFooter(total),
        ],
      ),
    );
  }

  Widget _buildInput({required TextEditingController controller, required String hint, required IconData icon}) {
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
          Icon(icon, size: 18, color: AppStyle.primaryBlue),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppStyle.primaryBlue, fontFamily: 'Poppins'),
              decoration: InputDecoration(hintText: hint, border: InputBorder.none, isDense: true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(int id, OrderItem item, TextEditingController noteController, {Key? key}) {
    return Container(
      key: key,
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
                    child: SizedBox(
                      width: 30,
                      child: Text("${item.quantity}", textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Poppins')),
                    )
                  ),
                  _qtyButton(Icons.add, () => widget.onIncrease(id), isPrimary: true),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  // 🔥 Gunakan Controller agar teks muncul saat Draft dibuka
                  controller: noteController,
                  onChanged: (v) => item.notes = v,
                  style: const TextStyle(fontSize: 11),
                  decoration: InputDecoration(
                    hintText: "Catatan (mis: Pedas)...",
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
    return Material(
      color: isPrimary ? AppStyle.primaryBlue : const Color(0xFFF0F4F8), 
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Icon(icon, size: 16, color: isPrimary ? Colors.white : AppStyle.primaryBlue),
        ),
      ),
    );
  }

  Widget _buildFooter(double total) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFF5F5F5)))),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Total Bayar", style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Poppins')),
              Text(widget.formatCurrency(total), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppStyle.primaryBlue, fontFamily: 'Poppins')),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48, 
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppStyle.primaryBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
              onPressed: widget.cart.isEmpty ? null : () async {
                final result = await showDialog<Map<String, dynamic>>(
                  context: context,
                  builder: (context) => CheckoutDialog(
                    cart: widget.cart,
                    totalAmount: total,
                    orderId: _orderId,
                    tableNumber: _tableController.text,
                    customerName: _customerController.text, 
                    cashierName: _cashierName,
                    formatCurrency: widget.formatCurrency,
                  ),
                );
                if (result != null) widget.onCheckoutSuccess(result);
              },
              child: const Text("Checkout", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Poppins')),
            ),
          )
        ],
      ),
    );
  }
}