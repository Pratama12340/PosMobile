import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/style.dart';
import '../models/order_model.dart';
import '../services/api_service.dart';
import '../widgets/edit_dialog.dart';
import '../services/reverb_service.dart';
import '../services/storage_service.dart';

class HistoryScreen extends StatefulWidget {
  final TextEditingController searchController;

  const HistoryScreen({super.key, required this.searchController});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<Order>> _historyFuture;
  final ReverbService _reverbService = ReverbService();

  @override
  void initState() {
    super.initState();
    widget.searchController.addListener(_onSearchChanged);
    _loadHistory();
    _connectReverb();
  }

  @override
  void dispose() {
    widget.searchController.removeListener(_onSearchChanged);
    _reverbService.disconnect();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {});
  }

  void _loadHistory() {
    setState(() {
      _historyFuture = ApiService.fetchHistory();
    });
  }

  void _connectReverb() async {
    final int? outletId = await StorageService.getOutletId();
    if (outletId == null) return;

    _reverbService.initConnection(
      channelName: 'private-orders.outlet.$outletId',
      eventName: '.order.updated',
      onEventReceived: (data) {
        debugPrint('⚡ [HISTORY] Order updated: $data');
        _loadHistory();
      },
    );
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

          final query = widget.searchController.text.toLowerCase();

          final String todayStr = DateFormat('yyyyMMdd').format(DateTime.now());

          final filteredOrders = snapshot.data!.where((order) {
            bool isCurrentShift = order.invoiceNo.contains(todayStr);
            bool matchesSearch =
                order.invoiceNo.toLowerCase().contains(query) ||
                order.customerName.toLowerCase().contains(query);

            return isCurrentShift && matchesSearch;
          }).toList();

          if (filteredOrders.isEmpty) {
            return const Center(
              child: Text("Data tidak ditemukan untuk shift ini"),
            );
          }

          return GridView.builder(
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
              final sideColor = _getSideColor(order.paymentMethod);

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
                                order.paymentMethod.toUpperCase(),
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
                            _loadHistory();
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
