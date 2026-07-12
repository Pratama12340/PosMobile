import 'package:sistem_pos/core/utils/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sistem_pos/core/constants/style.dart';
import 'package:sistem_pos/features/orders/models/order_model.dart';
import 'package:sistem_pos/features/orders/services/order_api_service.dart';
import 'package:sistem_pos/features/orders/widgets/edit_dialog.dart';
import 'package:sistem_pos/core/services/storage_service.dart';

class HistoryScreen extends StatefulWidget {
  final TextEditingController searchController;

  const HistoryScreen({super.key, required this.searchController});

  @override
  State<HistoryScreen> createState() => HistoryScreenState();
}

class HistoryScreenState extends State<HistoryScreen> {
  // 🔥 1. HAPUS Future _historyFuture DAN GANTI DENGAN VARIABEL STATE MANUAL
  final ScrollController _scrollController = ScrollController();
  final List<Order> _orders = [];
  
  String? _cashierName;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    widget.searchController.addListener(_onSearchChanged);
    
    // 🔥 3. PANGGIL DATA AWAL LANGSUNG DI SINI
    _loadInitialData();
  }

  // 🔥 4. HAPUS didChangeDependencies() KARENA SUDAH TIDAK DIBUTUHKAN

  @override
  void dispose() {
    // 🔥 5. JANGAN LUPA DISPOSE SCROLL CONTROLLER
    _scrollController.dispose();
    widget.searchController.removeListener(_onSearchChanged);
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {});
  }

  void loadHistory() {
    _loadInitialData();
  }

  // 🔥 7. FUNGSI LOAD SELURUH DATA SHIFT
  Future<void> _loadInitialData() async {
    final cashierName = await StorageService.getCashierName();

    setState(() {
      _cashierName = cashierName;
      _isLoading = true;
      _orders.clear();
    });

    // Menggunakan fetchHistory() untuk mengambil semua data dalam shift sekaligus
    final data = await OrderApiService.fetchHistory();
    
    setState(() {
      _orders.addAll(data);
      _isLoading = false;
    });
  }

  Color _getSideColor(String method) {
    String m = method.toUpperCase();
    if (m.contains('CASH')) return AppStyle.primaryBlue;
    if (m.contains('QRIS')) return Colors.redAccent;
    if (m.contains('DEBIT') || m.contains('CARD')) return Colors.amber;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    final query = widget.searchController.text.toLowerCase();
    final String todayStr = DateFormat('yyyyMMdd').format(DateTime.now());

    // 🔥 9. FILTER DATA LANGSUNG DARI VARIABEL _orders (Bukan dari snapshot lagi)
    final filteredOrders = _orders.where((order) {
      // Pastikan pesanan adalah transaksi hari ini (mengandung string tanggal hari ini)
      bool isCurrentShift = order.invoiceNo.contains(todayStr);

      // Opsi B: Hanya tampilkan pesanan kasir ini, ATAU pesanan otomatis dari sistem (Self Order meja)
      // "Staff" adalah nilai fallback dari order_model jika cashier_name kosong.
      bool isMyOrderOrSystem = order.cashierName == _cashierName || 
                               order.cashierName == 'Staff' || 
                               order.cashierName.toLowerCase() == 'system';

      bool matchesSearch =
          order.invoiceNo.toLowerCase().contains(query) ||
          order.customerName.toLowerCase().contains(query);

      // Sembunyikan pesanan dari riwayat jika belum di-accept oleh kasir.
      // Pesanan POS QR yang sudah 'paid' tapi belum di-accept harusnya hanya muncul di Pesanan Masuk, bukan di Riwayat.
      // Tetap tampilkan jika statusnya dibatalkan (cancelled/void).
      // Riwayat seharusnya hanya untuk transaksi yang sudah selesai/dibayar/dibatalkan
      bool isNotPending = order.status.toLowerCase() != 'pending';
      
      // Untuk pesanan dari POS QR (Pelanggan), WAJIB sudah di-accept kasir baru masuk riwayat.
      // (Kecuali jika dibatalkan/void, maka tetap masuk riwayat).
      // Untuk pesanan yang dibuat kasir langsung, biasanya otomatis selesai setelah dibayar.
      bool isFinished = true;
      if (order.isFromPosQr) {
        isFinished = order.isAccepted || ['cancelled', 'void'].contains(order.status.toLowerCase());
      }

      return isCurrentShift && isMyOrderOrSystem && matchesSearch && isNotPending && isFinished;
    }).toList();

    return Scaffold(
      backgroundColor: AppStyle.bgLightBlue,
      // 🔥 10. HAPUS FutureBuilder, GANTI DENGAN KONDISI IF MANUAL
      body: _isLoading && _orders.isEmpty 
          ? const Center(child: CircularProgressIndicator())
          : (_orders.isEmpty 
              ? const Center(child: Text("Data tidak ditemukan untuk shift ini"))
              : RefreshIndicator(
                  onRefresh: _loadInitialData,
                  color: AppStyle.primaryBlue,
                  child: Column(
                    children: [
                      Expanded(
                        child: GridView.builder(
                          // 🔥 11. PASANG SCROLL CONTROLLER KE GRIDVIEW
                          controller: _scrollController, 
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(32),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 20,
                            mainAxisSpacing: 20,
                            mainAxisExtent: 100,
                          ),
                          itemCount: filteredOrders.length,
                          itemBuilder: (context, index) {
                            final order = filteredOrders[index];
                            final sideColor = _getSideColor(order.paymentMethod ?? '');

                            // BAGIAN UI DI BAWAH INI SAMA PERSIS DENGAN KODE ANDA
                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 45,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            sideColor,
                                            sideColor.withValues(alpha: 0.7),
                                          ],
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          "${filteredOrders.length - index}",
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 18,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
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
                                              Icon(
                                                Icons.person_outline,
                                                size: 12,
                                                color: Colors.grey[600],
                                              ),
                                              const SizedBox(width: 4),
                                              Flexible(
                                                child: Text(
                                                  order.customerName,
                                                  style: AppStyle.subTitleText.copyWith(
                                                    fontSize: 11,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.table_restaurant_outlined,
                                                size: 12,
                                                color: Colors.grey[600],
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                order.tableNo,
                                                style: AppStyle.subTitleText.copyWith(
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(right: 12),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            CurrencyFormatter.format(order.totalPrice),
                                            style: AppStyle.priceText.copyWith(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: AppStyle.primaryBlue,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: sideColor.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              order.paymentMethod?.toUpperCase() ?? '-',
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
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () async {
                                          bool needsReload = false;
                                          await showDialog(
                                            context: context,
                                            builder: (context) =>
                                                ReceiptDialog(
                                                  orderId: order.id,
                                                  onOrderUpdated: () {
                                                    needsReload = true;
                                                  },
                                                ),
                                          );
                                          if (needsReload) {
                                            _loadInitialData();
                                          }
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
                        ),
                      ),
                    ],
                  ),
                )),
    );
  }
}

