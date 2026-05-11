import 'package:flutter/material.dart';
import '../constants/style.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart';
import '../models/rekap_model.dart';
import '../models/order_model.dart';
import '../widgets/closing_cash_dialog.dart';
import 'package:intl/intl.dart';

class ShiftScreen extends StatefulWidget {
  final TextEditingController searchController;
  const ShiftScreen({super.key, required this.searchController});

  @override
  State<ShiftScreen> createState() => _ShiftScreenState();
}

class _ShiftScreenState extends State<ShiftScreen> {
  late Future<List<dynamic>> _shiftDataFuture;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  void _loadInitialData() {
    _shiftDataFuture = Future.wait([
      StorageService.getCashierName(),
      ApiService.getShiftHistory(),
      ApiService.fetchHistory(),
      ApiService.getMasterShifts(),
      StorageService.getOpeningBalance(),
    ]);
  }

  int _parseToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      String cleaned = value.replaceAll(RegExp(r'[^0-9]'), '');
      return int.tryParse(cleaned) ?? 0;
    }
    return 0;
  }

  String _formatNumber(int number) => number.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (Match m) => '${m[1]}.',
  );

  void _handleTutupShift(RekapShift? activeShift) async {
    bool isShiftBelumHabis = false;

    if (activeShift != null && activeShift.masterInfo != null) {
      try {
        final now = DateTime.now();
        final String endTimeStr = activeShift.masterInfo!.endTime;
        final DateFormat timeFormat = DateFormat("HH:mm:ss");
        final DateTime shiftEndToday = timeFormat.parse(endTimeStr);
        final DateTime fullShiftEndTime = DateTime(
          now.year,
          now.month,
          now.day,
          shiftEndToday.hour,
          shiftEndToday.minute,
          shiftEndToday.second,
        );

        if (now.isBefore(fullShiftEndTime)) {
          isShiftBelumHabis = true;
        }
      } catch (e) {
        debugPrint("Error parsing shift time: $e");
      }
    }

    if (isShiftBelumHabis) {
      await showDialog(
        context: context,
        builder: (context) => _buildWarningModal(),
      );
      _showClosingDialog();
    } else {
      _showClosingDialog();
    }
  }

  Widget _buildWarningModal() {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange,
              size: 60,
            ),
            const SizedBox(height: 16),
            const Text(
              "Waktu Shift Belum Habis!",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Jam operasional shift Anda saat ini belum berakhir. Apakah Anda tetap ingin menutup shift sekarang?",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "Lanjutkan Tutup Shift",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showClosingDialog() {
    showDialog(
      context: context,
      builder: (context) => const ClosingCashDialog(),
    ).then((_) => _loadInitialData());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyle.bgLightBlue,
      body: FutureBuilder<List<dynamic>>(
        future: _shiftDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final String cashierName = snapshot.data?[0] ?? "Kasir";
          final List<ShiftMaster> masterData = snapshot.data?[3] ?? [];
          List<RekapShift> shiftList = snapshot.data?[1] ?? [];
          final List<Order> allOrders = snapshot.data?[2] ?? [];
          final int localOpeningBalance = _parseToInt(snapshot.data?[4]);

          if (shiftList.isNotEmpty) {
            shiftList.sort(
              (a, b) => (b.startedAt ?? DateTime.now()).compareTo(
                a.startedAt ?? DateTime.now(),
              ),
            );
          }

          for (var rekap in shiftList) {
            rekap.masterInfo = masterData.firstWhere(
              (m) => m.id == rekap.shiftId,
              orElse: () => ShiftMaster(
                id: 0,
                name: 'Shift?',
                startTime: '00:00:00',
                endTime: '00:00:00',
              ),
            );
          }

          final RekapShift activeShift = shiftList.firstWhere(
            (s) => s.status == 'active',
            orElse: () => shiftList.isNotEmpty
                ? shiftList.first
                : RekapShift(id: 0, shiftId: 0, status: 'none'),
          );

          int kasAwal = localOpeningBalance > 0
              ? localOpeningBalance
              : (activeShift.uangAwal?.toInt() ?? 0);
          int bersih = 0;
          int count = 0;

          Map<String, int> productSalesQty = {};
          Map<String, int> paymentAmount = {"CASH": 0, "CARD": 0, "QRIS": 0};

          if (activeShift.startedAt != null) {
            DateTime startShiftWIB = activeShift.startedAt!.toLocal();
            final df = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');

            for (var order in allOrders) {
              try {
                DateTime orderTime = df.parse(order.date);
                if (orderTime.isAfter(startShiftWIB)) {
                  int orderTotal = order.totalPrice.round();
                  bersih += orderTotal;
                  count++;
                  String method = order.paymentMethod.toUpperCase();
                  if (paymentAmount.containsKey(method)) {
                    paymentAmount[method] =
                        (paymentAmount[method] ?? 0) + orderTotal;
                  }
                  for (var item in order.items) {
                    productSalesQty[item.itemName] =
                        (productSalesQty[item.itemName] ?? 0) + item.quantity;
                  }
                }
              } catch (e) {
                debugPrint("Error parsing date: $e");
              }
            }
          }

          var filteredProducts =
              productSalesQty.entries.where((e) => e.value >= 10).toList()
                ..sort((a, b) => b.value.compareTo(a.value));
          var topProducts = filteredProducts.take(5).toList();

          return SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProfileHeader(
                  context,
                  cashierName,
                  activeShift,
                  kasAwal,
                  count,
                  bersih,
                ),
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth > 800) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 6,
                            child: _buildProdukTerlaris(topProducts),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 4,
                            child: _buildMetodeBayar(paymentAmount, bersih),
                          ),
                        ],
                      );
                    } else {
                      return Column(
                        children: [
                          _buildProdukTerlaris(topProducts),
                          const SizedBox(height: 24),
                          _buildMetodeBayar(paymentAmount, bersih),
                        ],
                      );
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileHeader(
    BuildContext context,
    String name,
    RekapShift? shift,
    int awal,
    int count,
    int bersih,
  ) {
    String loginTime = shift?.startedAt != null
        ? DateFormat('HH:mm').format(shift!.startedAt!.toLocal())
        : "--:--";
    bool isActuallyLate = shift?.isLate ?? false;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 30,
                backgroundColor: AppStyle.bgLightBlue,
                child: Icon(Icons.person, color: AppStyle.primaryBlue),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          name,
                          style: AppStyle.titleText.copyWith(fontSize: 20),
                        ),
                        const SizedBox(width: 8),
                        if (shift != null && shift.status != 'none')
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isActuallyLate
                                  ? Colors.red.shade50
                                  : Colors.green.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isActuallyLate
                                    ? Colors.red
                                    : Colors.green,
                              ),
                            ),
                            child: Text(
                              isActuallyLate ? "Telat" : "Tepat Waktu",
                              style: TextStyle(
                                color: isActuallyLate
                                    ? Colors.red
                                    : Colors.green,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    Text(
                      "${shift?.masterInfo?.name ?? '-'} • Masuk: $loginTime WIB",
                      style: AppStyle.subTitleText,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _loadInitialData()),
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: AppStyle.primaryBlue,
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () => _handleTutupShift(shift),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text("Tutup Shift"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _infoItem(
                "Kas Awal",
                "Rp ${_formatNumber(awal)}",
                Icons.wallet,
                Colors.blue,
              ),
              _infoItem("Transaksi", "$count", Icons.payments, Colors.orange),
              _infoItem(
                "Kas Bersih",
                "Rp ${_formatNumber(bersih)}",
                Icons.shopping_bag,
                Colors.green,
              ),
              _infoItem(
                "Total Akhir",
                "Rp ${_formatNumber(awal + bersih)}",
                Icons.summarize,
                AppStyle.primaryBlue,
                isBold: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoItem(
    String label,
    String value,
    IconData icon,
    Color color, {
    bool isBold = false,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: 16,
            color: isBold ? AppStyle.primaryBlue : Colors.black87,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _buildProdukTerlaris(List<MapEntry<String, int>> topProducts) {
    return Container(
      height: 380,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Produk Terlaris",
            style: AppStyle.titleText.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 16),
          if (topProducts.isEmpty)
            const Expanded(
              child: Center(
                child: Text(
                  "Belum ada produk mencapai 10 porsi",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: topProducts.asMap().entries.map((mapEntry) {
                    final index = mapEntry.key;
                    final entry = mapEntry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: AppStyle.primaryBlue,
                            child: Text(
                              "${index + 1}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              entry.key,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            "${entry.value}",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMetodeBayar(Map<String, int> paymentAmount, int totalMoney) {
    final Map<String, Color> methodColors = {
      "CASH": Colors.blue,
      "CARD": Colors.orange,
      "QRIS": Colors.red,
    };
    return Container(
      height: 380,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Metode Bayar",
            style: AppStyle.titleText.copyWith(fontSize: 18),
          ),
          const Text(
            "Total pendapatan",
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: paymentAmount.entries.map((entry) {
                  final double percentage = totalMoney > 0
                      ? (entry.value / totalMoney)
                      : 0;
                  final Color color =
                      methodColors[entry.key.toUpperCase()] ?? Colors.grey;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              entry.key,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              "Rp ${_formatNumber(entry.value)}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: percentage,
                          backgroundColor: Colors.grey.shade100,
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                          minHeight: 8,
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
