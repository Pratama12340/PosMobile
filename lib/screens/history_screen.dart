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
    _loadHistory();
  }

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
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("Belum ada data"));
          }

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
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                // PERBAIKAN: Hanya ada satu properti child di sini
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Row(
                    children: [
                      // Sisi Kiri: Garis Tebal + Nomor Urut
                      Container(
                        width: 45,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              sideColor,
                              sideColor.withOpacity(0.7),
                            ],
                          ),
                        ),
                        child: Center(
                          child: Text(
                            "${index + 1}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Konten Tengah: Detail Pesanan
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.invoiceNo,
                              style: AppStyle.menuText.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey[900],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.person_outline,
                                    size: 12, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    order.customerName,
                                    style: AppStyle.subTitleText
                                        .copyWith(fontSize: 11),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Icon(Icons.table_restaurant_outlined,
                                    size: 12, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text(
                                  order.tableNo,
                                  style: AppStyle.subTitleText
                                      .copyWith(fontSize: 11),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Konten Kanan: Harga & Badge Metode Pembayaran
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              style.formatHarga(order.totalPrice),
                              style: AppStyle.priceText.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppStyle.primaryBlue,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: sideColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                order.paymentMethod,
                                style: TextStyle(
                                  color: sideColor,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Tombol Aksi: Lihat Struk
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () async {
                            await showDialog(
                              context: context,
                              builder: (context) =>
                                  ReceiptDialog(orderId: order.id),
                            );
                            _loadHistory(); // Refresh data setelah dialog tutup
                          },
                          child: Container(
                            height: double.infinity,
                            width: 50,
                            decoration: BoxDecoration(
                              border: Border(
                                left: BorderSide(color: Colors.grey.shade100),
                              ),
                            ),
                            child: const Icon(
                              Icons.receipt_long_rounded,
                              color: AppStyle.primaryBlue,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}