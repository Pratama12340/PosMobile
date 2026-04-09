import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/order_model.dart';

class SuccessPaymentPage extends StatelessWidget {
  final String orderId;
  final String paymentMethod;
  final double grandTotal;
  final double amountPaid;
  final double change;
  final Map<int, OrderItem> cart;
  final String tableNumber;
  final String cashierName;
  final String outletName; // <--- 1. TAMBAHAN VARIABEL NAMA OUTLET
  final String Function(double) formatCurrency;

  const SuccessPaymentPage({
    super.key,
    required this.orderId,
    required this.paymentMethod,
    required this.grandTotal,
    required this.amountPaid,
    required this.change,
    required this.cart,
    required this.tableNumber,
    required this.cashierName,
    required this.outletName, // <--- 2. WAJIB DARI CONSTRUCTOR
    required this.formatCurrency,
  });

  @override
  Widget build(BuildContext context) {
    String currentDateTime = DateFormat('dd MMM yyyy').format(DateTime.now());
    String currentTime = DateFormat('HH:mm').format(DateTime.now());
    
    // Perhitungan pajak 10% 
    double subTotal = grandTotal / 1.1;
    double tax = grandTotal - subTotal;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F3F9),
      body: Row(
        children: [
          // --- SISI KIRI: STATUS & KEMBALIAN (MELAYANG) ---
          Expanded(
            flex: 6,
            child: Padding(
              padding: const EdgeInsets.all(40.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20)],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF4CAF50), size: 100),
                    const SizedBox(height: 20),
                    const Text("Pembayaran Berhasil!", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                    const SizedBox(height: 40),
                    
                    // Box Kembalian 
                    if (paymentMethod == 'Cash')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 25),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFF),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            const Text("Uang Kembalian", style: TextStyle(color: Colors.grey, fontSize: 18, fontFamily: 'Poppins')),
                            const SizedBox(height: 10),
                            Text(
                              formatCurrency(change),
                              style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: Color(0xFF4CAF50), fontFamily: 'Poppins'),
                            ),
                          ],
                        ),
                      ),
                    
                    const SizedBox(height: 50),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildActionBtn(context, "Transaksi Baru", const Color(0xFF4CAF50), Icons.add_shopping_cart, true),
                        const SizedBox(width: 20),
                        _buildActionBtn(context, "Cetak Struk", const Color(0xFF4285F4), Icons.print_rounded, false),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // --- SISI KANAN: STRUK ---
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.only(top: 40, bottom: 40, right: 40),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20)],
                ),
                padding: const EdgeInsets.all(35),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    
                    // ==========================================
                    // 3. PERBAIKAN: NAMA OUTLET & ORDER ID DIBUAT PROPORSIONAL
                    // ==========================================
                    Center(
                      child: Column(
                        children: [
                          Text(
                            outletName.toUpperCase(), // Nama Outlet lebih besar dan kapital
                            textAlign: TextAlign.center, 
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24, fontFamily: 'Poppins', color: Colors.black87)
                          ),
                          const SizedBox(height: 4),
                          Text(
                            orderId, // Order ID lebih kecil
                            style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF4285F4), fontSize: 13, fontFamily: 'Poppins')
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 25),
                    // ==========================================

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Date : $currentDateTime", style: const TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'Poppins')),
                        Text("Time : $currentTime", style: const TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'Poppins')),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Cashier : $cashierName", style: const TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'Poppins')),
                        Text("Table : ${tableNumber.isEmpty ? '-' : tableNumber}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'Poppins')),
                      ],
                    ),
                    const Divider(height: 25),
                    
                    // List Menu 
                    Expanded(
                      child: ListView.builder(
                        itemCount: cart.length,
                        itemBuilder: (context, index) {
                          var item = cart.values.elementAt(index);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 15),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.itemName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Poppins')),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text("${item.quantity} x ${formatCurrency(item.unitPrice)}", style: const TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'Poppins')),
                                    Text(formatCurrency(item.subtotal), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Poppins')),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    
                    const Divider(height: 30),
                    _rowCalc("Sub Total", subTotal),
                    _rowCalc("Tax (10%)", tax),
                    const SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Total", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, fontFamily: 'Poppins')),
                        Text(formatCurrency(grandTotal), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF4285F4), fontFamily: 'Poppins')),
                      ],
                    ),
                    const SizedBox(height: 25),
                    const Center(child: Text("Terima Kasih Atas Kunjungan Anda", style: TextStyle(color: Colors.grey, fontSize: 11, fontFamily: 'Poppins'))),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBtn(BuildContext context, String label, Color color, IconData icon, bool isBack) {
    return SizedBox(
      width: 200, height: 60,
      child: ElevatedButton.icon(
        onPressed: isBack ? () => Navigator.of(context).popUntil((route) => route.isFirst) : () {},
        icon: Icon(icon, size: 20),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Poppins')),
        style: ElevatedButton.styleFrom(
          backgroundColor: color, foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _rowCalc(String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13, fontFamily: 'Poppins')),
          Text(formatCurrency(value), style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
        ],
      ),
    );
  }
}