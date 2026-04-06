import 'package:flutter/material.dart';
import '../style.dart'; 

class RekapScreen extends StatelessWidget {
  const RekapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyle.bgLightBlue,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header dihapus agar langsung menampilkan ringkasan data
            _buildSummaryCards(),
            const SizedBox(height: 24),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: _buildTopProducts()),
                  const SizedBox(width: 24),
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
        _cardItem("Modal Awal", "Rp 500k", Icons.wallet, Colors.blue),
        _cardItem("Total Jual", "Rp 3.4M", Icons.shopping_cart, Colors.orange),
        _cardItem("Total Tunai", "Rp 1.2M", Icons.payments, Colors.green),
        _cardItem("Trx", "42", Icons.receipt, Colors.purple),
      ],
    );
  }

  Widget _cardItem(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label, 
                    style: AppStyle.hintText.copyWith(fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    value, 
                    style: AppStyle.labelText.copyWith(fontSize: 15),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Produk Terlaris (Shift Ini)", style: AppStyle.labelText),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: 5,
              separatorBuilder: (_, __) => const Divider(color: AppStyle.formGrey),
              itemBuilder: (context, index) {
                List<Map<String, dynamic>> topProducts = [
                  {"name": "Kopi Susu Aranus", "qty": 24, "total": "Rp 480k"},
                  {"name": "Brownies Panggang", "qty": 18, "total": "Rp 360k"},
                  {"name": "Ice Lychee Tea", "qty": 12, "total": "Rp 180k"},
                  {"name": "Croissant Cheese", "qty": 10, "total": "Rp 250k"},
                  {"name": "Espresso Double", "qty": 8, "total": "Rp 120k"},
                ];

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: index == 0 ? Colors.amber.withOpacity(0.2) : AppStyle.bgLightBlue,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        "${index + 1}",
                        style: TextStyle(
                          color: index == 0 ? Colors.orange : Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  title: Text(topProducts[index]["name"], style: AppStyle.labelText.copyWith(fontSize: 14)),
                  subtitle: Text("${topProducts[index]["qty"]} Terjual", style: AppStyle.hintText),
                  trailing: Text(
                    topProducts[index]["total"], 
                    style: AppStyle.labelText.copyWith(fontSize: 14, color: AppStyle.textBlack)
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Metode Bayar", style: AppStyle.labelText),
          const SizedBox(height: 24),
          _paymentRow("Tunai", "Rp 750k", 0.4, Colors.blue),
          _paymentRow("QRIS", "Rp 2.1M", 0.7, Colors.orange),
          _paymentRow("Transfer", "Rp 600k", 0.2, Colors.purple),
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
              Text(label, style: AppStyle.hintText),
              Text(amount, style: AppStyle.labelText.copyWith(fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: AppStyle.formGrey,
            color: color,
            minHeight: 6,
            borderRadius: BorderRadius.circular(10),
          ),
        ],
      ),
    );
  }
}