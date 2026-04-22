import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/order_model.dart';
import '../style.dart'; // Pastikan import style Anda untuk warna yang konsisten

class SuccessPaymentPage extends StatelessWidget {
  final String orderId;
  final String paymentMethod;
  final double grandTotal;
  final double amountPaid;
  final double change;
  final Map<int, OrderItem> cart;
  final String tableNumber;
  final String customerName; // Tambahan parameter Nama Customer
  final String cashierName;
  final String outletName;
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
    required this.customerName, // Tambahan di constructor
    required this.cashierName,
    required this.outletName,
    required this.formatCurrency,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F3F9), // Background abu muda agar kartu terlihat floating
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            // Memberikan batas lebar maksimal agar proporsional di layar lebar (Tablet/Web)
            constraints: const BoxConstraints(maxWidth: 600),
            margin: const EdgeInsets.all(40.0),
            padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon Centang
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF4CAF50),
                  size: 120,
                ),
                const SizedBox(height: 24),
                
                // Judul
                const Text(
                  "Pembayaran Berhasil!",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Order ID: $orderId",
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontFamily: 'Poppins',
                  ),
                ),
                
                // Menampilkan Nama Customer jika ada
                if (customerName.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    "Customer: $customerName",
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppStyle.primaryBlue, // Menggunakan warna biru Aranus POS
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
                
                const SizedBox(height: 40),

                // Box Kembalian (Hanya muncul jika Cash)
                if (paymentMethod == 'Cash' || paymentMethod == 'Tunai')
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 30),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFF),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE8F0FE)),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          "Uang Kembalian",
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 18,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          formatCurrency(change),
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF4CAF50),
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  // Jika Non-Tunai, tampilkan Total yang dibayar
                  Column(
                    children: [
                      const Text("Total Pembayaran", style: TextStyle(color: Colors.grey, fontSize: 16)),
                      Text(formatCurrency(grandTotal), 
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF4285F4))),
                    ],
                  ),

                const SizedBox(height: 60),

                // Tombol Aksi
                Row(
                  children: [
                    Expanded(
                      child: _buildActionBtn(
                        context,
                        "Transaksi Baru",
                        const Color(0xFF4CAF50),
                        Icons.add_shopping_cart_rounded,
                        true,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildActionBtn(
                        context,
                        "Cetak Struk",
                        const Color(0xFF4285F4),
                        Icons.print_rounded,
                        false,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionBtn(BuildContext context, String label, Color color, IconData icon, bool isBack) {
    return SizedBox(
      height: 65,
      child: ElevatedButton.icon(
        onPressed: isBack 
            ? () => Navigator.of(context).popUntil((route) => route.isFirst) 
            : () {
                // Logika cetak struk di sini
              },
        icon: Icon(icon, size: 22),
        label: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            fontFamily: 'Poppins',
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
      ),
    );
  }
}