import 'package:flutter/material.dart';
import '../style.dart'; 

class RekapScreen extends StatelessWidget {
  // Tambahkan variabel untuk menampung modal awal dari inputan dialog
  final int openingCash;

  const RekapScreen({
    super.key, 
    this.openingCash = 0, // Default 0 jika tidak ada inputan
  });

  // Fungsi helper untuk format ribuan
  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyle.bgLightBlue,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row kartu ringkasan
            _buildSummaryCards(),
            const SizedBox(height: 24),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sisi Kiri: Produk Terlaris
                  Expanded(flex: 2, child: _buildTopProducts()),
                  const SizedBox(width: 24),
                  // Sisi Kanan: Breakdown Jumlah Orang Per Metode Bayar
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
        // Menggunakan data dari openingCash yang diinput sebelumnya
        _cardItem("Modal Awal", _formatNumber(openingCash), Icons.wallet, Colors.blue),
        _cardItem("Total Jual", "3.400.000", Icons.shopping_cart, Colors.orange),
        _cardItem("Total Tunai", "1.200.000", Icons.payments, Colors.green),
        _cardItem("Total Transaksi", "42", Icons.receipt, Colors.purple),
      ],
    );
  }

  Widget _cardItem(String label, String value, IconData icon, Color color) {
    bool isPrice = label != "Total Transaksi";
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
                  Text(label, style: AppStyle.subTitleText.copyWith(fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(
                    isPrice ? "Rp $value" : value, 
                    style: AppStyle.numPadText.copyWith(fontSize: 18, color: AppStyle.textMain), // Menggunakan JetBrains
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppStyle.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Produk Terlaris", style: AppStyle.titleText.copyWith(fontSize: 20)),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.separated(
              itemCount: 5,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                List<Map<String, dynamic>> topProducts = [
                  {"name": "Kopi Susu Aranus", "qty": 24, "total": "480.000"},
                  {"name": "Brownies Panggang", "qty": 18, "total": "360.000"},
                  {"name": "Ice Lychee Tea", "qty": 12, "total": "180.000"},
                  {"name": "Croissant Cheese", "qty": 10, "total": "250.000"},
                  {"name": "Espresso Double", "qty": 8, "total": "120.000"},
                ];

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppStyle.bgLightBlue.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: AppStyle.primaryBlue,
                      child: Text("${index + 1}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    title: Text(topProducts[index]["name"], style: AppStyle.menuText.copyWith(fontWeight: FontWeight.bold)),
                    subtitle: Text("${topProducts[index]["qty"]} Terjual", style: AppStyle.subTitleText),
                    trailing: Text("Rp ${topProducts[index]["total"]}", style: AppStyle.numPadText.copyWith(fontSize: 14)),
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppStyle.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Metode Bayar", style: AppStyle.titleText.copyWith(fontSize: 20)),
          Text("Jumlah orang/transaksi", style: AppStyle.subTitleText),
          const SizedBox(height: 32),
          // Data diganti menjadi jumlah orang (Qty)
          _paymentRow("Tunai", "15 Orang", 0.4, Colors.green),
          _paymentRow("QRIS", "22 Orang", 0.7, Colors.blue),
          _paymentRow("Transfer", "5 Orang", 0.2, Colors.orange),
        ],
      ),
    );
  }

  Widget _paymentRow(String label, String count, double progress, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: AppStyle.menuText),
              Text(count, style: AppStyle.numPadText.copyWith(fontSize: 14)), // JetBrains
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: AppStyle.bgLightBlue,
            color: color,
            minHeight: 10,
            borderRadius: BorderRadius.circular(10),
          ),
        ],
      ),
    );
  }
}