import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
// Pastikan path style benar

class SuccessPaymentPage extends StatelessWidget {
  final String orderId;
  final String paymentMethod;
  final double grandTotal;
  final String Function(double) formatCurrency;

  const SuccessPaymentPage({
    super.key,
    required this.orderId,
    required this.paymentMethod,
    required this.grandTotal,
    required this.formatCurrency,
  });

  @override
  Widget build(BuildContext context) {
    String currentDateTime = DateFormat(
      'dd/MM/yyyy HH:mm a',
    ).format(DateTime.now());

    return Scaffold(
      backgroundColor: const Color(0xFFE9ECEF), // Background abu-abu lembut
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // --- KARTU STRUK ---
            Container(
              width: 400,
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 30),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Icon Checkmark Hijau
                  Container(
                    height: 80,
                    width: 80,
                    decoration: const BoxDecoration(
                      color: Color(0xFF28A745),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 50,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "Payment Success!",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                      color: Color(0xFF212529),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    formatCurrency(grandTotal),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Poppins',
                      color: Color(0xFF28A745),
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0xFFF1F3F5),
                  ),
                  const SizedBox(height: 25),

                  // Detail Info
                  _buildDetailRow("Order ID", orderId),
                  const SizedBox(height: 16),
                  _buildDetailRow("Payment Method", paymentMethod),
                  const SizedBox(height: 16),
                  _buildDetailRow("Payment Time", currentDateTime),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // --- TOMBOL ACTIONS (Sejajar di bawah) ---
            SizedBox(
              width: 400,
              child: Row(
                children: [
                  // Tombol New Order
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF28A745),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        // Logika untuk reset order / kembali ke home
                        Navigator.of(
                          context,
                        ).popUntil((route) => route.isFirst);
                      },
                      child: const Text(
                        "New Order",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  // Tombol Print Receipt
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        side: const BorderSide(color: Color(0xFFCED4DA)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        backgroundColor: Colors.white,
                      ),
                      onPressed: () {
                        // Logika Print
                      },
                      icon: const Icon(
                        Icons.print_outlined,
                        color: Color(0xFF495057),
                      ),
                      label: const Text(
                        "Print",
                        style: TextStyle(
                          color: Color(0xFF495057),
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF6C757D),
            fontSize: 14,
            fontFamily: 'Poppins',
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF212529),
            fontWeight: FontWeight.w600,
            fontSize: 14,
            fontFamily: 'Poppins',
          ),
        ),
      ],
    );
  }
}
