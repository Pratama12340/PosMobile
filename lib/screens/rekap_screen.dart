import 'package:flutter/material.dart';
import '../style.dart'; // Pastikan path import benar

class RekapScreen extends StatelessWidget {
  const RekapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyle.bgLightBlue, // Menggunakan Style
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
            // Row kartu ringkasan di paling atas
            _buildSummaryCards(),
            const SizedBox(height: 24),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sisi Kiri: Produk Terlaris
                  Expanded(flex: 2, child: _buildTopProducts()),
                  const SizedBox(width: 24),
                  // Sisi Kanan: Breakdown Pembayaran
                  Expanded(flex: 1, child: _buildPaymentMethodBreakdown()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Row(
      children: [
        _cardItem("Modal Awal", "500.000", Icons.wallet, Colors.blue),
        _cardItem("Total Jual", "3.400.000", Icons.shopping_cart, Colors.orange),
        _cardItem("Total Tunai", "1.200.000", Icons.payments, Colors.green),
        _cardItem("Total Transaksi", "42", Icons.receipt, Colors.purple),
      ],
    );
  }

  Widget _cardItem(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppStyle.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label, 
                    style: AppStyle.subTitleText.copyWith(fontSize: 10), // Poppins
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label == "Total Transaksi" ? value : "Rp $value", 
                    style: AppStyle.priceText.copyWith(fontSize: 16, color: AppStyle.textMain), // JetBrains
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTopProducts() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppStyle.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Produk Terlaris (Shift Ini)", style: AppStyle.menuText.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: 5,
              separatorBuilder: (_, __) => Divider(color: Colors.grey.shade100),
              itemBuilder: (context, index) {
                List<Map<String, dynamic>> topProducts = [
                  {"name": "Kopi Susu Aranus", "qty": 24, "total": "480.000"},
                  {"name": "Brownies Panggang", "qty": 18, "total": "360.000"},
                  {"name": "Ice Lychee Tea", "qty": 12, "total": "180.000"},
                  {"name": "Croissant Cheese", "qty": 10, "total": "250.000"},
                  {"name": "Espresso Double", "qty": 8, "total": "120.000"},
                ];

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: index == 0 ? Colors.amber.withOpacity(0.2) : AppStyle.bgLightBlue,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        "${index + 1}",
                        style: AppStyle.numPadText.copyWith(fontSize: 14, color: index == 0 ? Colors.orange : AppStyle.primaryBlue), // JetBrains
                      ),
                    ),
                  ),
                  title: Text(topProducts[index]["name"], style: AppStyle.menuText.copyWith(fontSize: 14, fontWeight: FontWeight.bold)),
                  subtitle: Text("${topProducts[index]["qty"]} Terjual", style: AppStyle.subTitleText),
                  trailing: Text(
                    "Rp ${topProducts[index]["total"]}", 
                    style: AppStyle.priceText.copyWith(fontSize: 14, color: AppStyle.textMain) // JetBrains
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodBreakdown() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppStyle.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Metode Bayar", style: AppStyle.menuText.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          _paymentRow("Tunai", "750.000", 0.4, Colors.blue),
          _paymentRow("QRIS", "2.100.000", 0.7, Colors.orange),
          _paymentRow("Transfer", "600.000", 0.2, Colors.purple),
        ],
      ),
    );
  }

  Widget _paymentRow(String label, String amount, double progress, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: AppStyle.subTitleText),
              Text("Rp $amount", style: AppStyle.priceText.copyWith(fontSize: 13, color: AppStyle.textMain)), // JetBrains
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.shade100,
            color: color,
            minHeight: 6,
            borderRadius: BorderRadius.circular(10),
          ),
        ],
      ),
    );
  }
}