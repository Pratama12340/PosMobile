import 'package:flutter/material.dart';
import '../style.dart';
import '../models/order_model.dart';
import '../services/api_service.dart';
import '../widgets/receipt_dialog.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<Order>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _loadHistory(); // Pindahkan inisialisasi ke fungsi terpisah
  }

  // Fungsi untuk memuat ulang data dari API
  void _loadHistory() {
    setState(() {
      _historyFuture = ApiService.fetchHistory();
    });
  }

  Color _getSideColor(String method) {
    if (method.contains('CASH')) return AppStyle.primaryBlue;
    if (method.contains('QRIS')) return Colors.redAccent;
    if (method.contains('DEBIT')) return Colors.green;
    return Colors.amber;
  }

  @override
  Widget build(BuildContext context) {
    final style = AppStyle();
    return Scaffold(
      backgroundColor: AppStyle.bgLightBlue,
      body: FutureBuilder<List<Order>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text("Belum ada data"));

          return GridView.builder(
            padding: const EdgeInsets.all(32),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, 
              crossAxisSpacing: 20, 
              mainAxisSpacing: 20, 
              mainAxisExtent: 100,
            ),
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final order = snapshot.data![index];
              final sideColor = _getSideColor(order.paymentMethod);

              return Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Container(width: 6, color: sideColor),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(order.invoiceNo, style: AppStyle.menuText.copyWith(fontWeight: FontWeight.bold)),
                          Text(order.customerName, style: AppStyle.subTitleText.copyWith(fontSize: 10, fontWeight: FontWeight.bold)),
                          Text(order.tableNo, style: AppStyle.subTitleText.copyWith(fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Harga ini sekarang akan update karena UI akan direbuild setelah dialog tutup
                        Text(style.formatHarga(order.totalPrice), style: AppStyle.priceText.copyWith(fontSize: 16)),
                        Text(order.paymentMethod, style: TextStyle(color: sideColor, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.receipt_long, color: AppStyle.primaryBlue, size: 28),
                      onPressed: () async {
                        // 1. Tunggu dialog selesai (di-pop)
                        await showDialog(
                          context: context,
                          builder: (context) => ReceiptDialog(orderId: order.id),
                        );
                        
                        // 2. Setelah dialog ditutup, panggil fungsi loadHistory untuk refresh data
                        _loadHistory();
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}