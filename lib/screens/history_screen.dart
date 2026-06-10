import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/style.dart';
import '../models/order_model.dart';
import '../services/api_service.dart';
import '../widgets/edit_dialog.dart';

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
  
  int _currentPage = 1;
  bool _isLoading = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    // 🔥 2. TAMBAHKAN LISTENER UNTUK MENDETEKSI SCROLL
    _scrollController.addListener(_onScroll);
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

  // 🔥 6. FUNGSI UNTUK MENDETEKSI SAAT PENGGUNA SCROLL KE PALING BAWAH
  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100) {
      if (!_isLoading && _hasMore) {
        _fetchMoreData();
      }
    }
  }

  void loadHistory() {
    _loadInitialData();
  }

  // 🔥 7. FUNGSI LOAD HALAMAN PERTAMA (Pengganti loadHistory)
  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _currentPage = 1;
      _orders.clear();
      _hasMore = true;
    });

    // PASTIKAN ANDA SUDAH MENAMBAHKAN fetchHistoryPage() DI api_service.dart 
    // SEPERTI PADA PENJELASAN SEBELUMNYA
    final data = await ApiService.fetchHistoryPage(page: _currentPage);
    
    setState(() {
      _orders.addAll(data);
      _isLoading = false;
      if (data.length < 20) { // Jika data kurang dari per_page, berarti sudah habis
        _hasMore = false;
      }
    });
  }

  // 🔥 8. FUNGSI LOAD HALAMAN BERIKUTNYA (Page 2, 3, dst)
  Future<void> _fetchMoreData() async {
    setState(() {
      _isLoading = true;
      _currentPage++;
    });

    final data = await ApiService.fetchHistoryPage(page: _currentPage);
    
    setState(() {
      _orders.addAll(data);
      _isLoading = false;
      if (data.isEmpty || data.length < 20) {
        _hasMore = false;
      }
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
    final style = AppStyle();
    
    final query = widget.searchController.text.toLowerCase();
    final String todayStr = DateFormat('yyyyMMdd').format(DateTime.now());

    // 🔥 9. FILTER DATA LANGSUNG DARI VARIABEL _orders (Bukan dari snapshot lagi)
    final filteredOrders = _orders.where((order) {
      bool isCurrentShift = order.invoiceNo.contains(todayStr);
      bool matchesSearch =
          order.invoiceNo.toLowerCase().contains(query) ||
          order.customerName.toLowerCase().contains(query);

      return isCurrentShift && matchesSearch;
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
                                          await showDialog(
                                            context: context,
                                            builder: (context) =>
                                                ReceiptDialog(orderId: order.id),
                                          );
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
                      // 🔥 12. INDIKATOR LOADING KECIL DI BAWAH SAAT LOAD PAGE BERIKUTNYA
                      if (_isLoading && _orders.isNotEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16.0),
                          child: CircularProgressIndicator(),
                        ),
                    ],
                  ),
                )),
    );
  }
}