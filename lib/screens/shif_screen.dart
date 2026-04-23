import 'package:flutter/material.dart';
import '../style.dart';
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
  // Variabel untuk menampung Future agar tidak reload saat build
  late Future<List<dynamic>> _shiftDataFuture;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  // Fungsi untuk memicu pengambilan data
  void _loadInitialData() {
    _shiftDataFuture = Future.wait([
      StorageService.getCashierName(),    // [0]
      ApiService.getShiftHistory(),       // [1]
      ApiService.fetchHistory(),          // [2]
      ApiService.getMasterShifts(),       // [3]
      StorageService.getOpeningBalance(), // [4] Data Lokal
    ]);
  }

  // Helper untuk memastikan angka dari storage terbaca dengan benar (int/double/string)
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
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.');

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
          
          // --- PERBAIKAN: Safe Parsing Kas Awal ---
          final int localOpeningBalance = _parseToInt(snapshot.data?[4]);

          // --- PERBAIKAN: Sorting Shift Terkini ---
          if (shiftList.isNotEmpty) {
            shiftList.sort((a, b) => (b.startedAt ?? DateTime.now()).compareTo(a.startedAt ?? DateTime.now()));
          }

          // Mapping Master Info (Join Data)
          for (var rekap in shiftList) {
            rekap.masterInfo = masterData.firstWhere(
              (m) => m.id == rekap.shiftId,
              orElse: () => ShiftMaster(
                  id: 0, name: 'Shift?', startTime: '00:00:00', endTime: '00:00:00'),
            );
          }

          // Cari shift aktif (pilih yang paling baru)
          final RekapShift? activeShift = shiftList.firstWhere(
            (s) => s.status == 'active',
            orElse: () => shiftList.isNotEmpty ? shiftList.first : RekapShift(id: 0, shiftId: 0, status: 'none'),
          );

          // SINKRONISASI KAS AWAL (Lokal > Server)
          int kasAwal = localOpeningBalance > 0 
              ? localOpeningBalance 
              : (activeShift?.uangAwal?.toInt() ?? 0);
          
          int bersih = 0;
          int count = 0;

          // --- PERBAIKAN: Logika Perhitungan dengan Waktu Lokal (WIB) ---
          if (activeShift != null && activeShift.startedAt != null) {
            DateTime startShiftWIB = activeShift.startedAt!.toLocal();
            
            final df = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');
            for (var order in allOrders) {
              try {
                DateTime orderTime = df.parse(order.date);
                if (orderTime.isAfter(startShiftWIB)) {
                  bersih += order.totalPrice.round();
                  count++;
                }
              } catch (e) {
                debugPrint("Error parsing date: $e");
              }
            }
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _loadInitialData();
              });
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  _buildProfileHeader(
                      context, cashierName, activeShift, kasAwal, count, bersih),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, String name,
      RekapShift? shift, int awal, int count, int bersih) {
    
    // --- PERBAIKAN: Format Jam WIB ---
    String loginTime = shift?.startedAt != null
        ? DateFormat('HH:mm').format(shift!.startedAt!.toLocal())
        : "--:--";

    bool isActuallyLate = false;
    String statusText = "Tepat Waktu";

    if (shift != null && shift.startedAt != null && shift.masterInfo != null) {
      try {
        final timeParts = shift.masterInfo!.startTime.split(':');
        final loginTimeLocal = shift.startedAt!.toLocal();
        
        // Membandingkan jadwal pada tanggal yang sama dengan waktu login
        final scheduledTime = DateTime(
          loginTimeLocal.year,
          loginTimeLocal.month,
          loginTimeLocal.day,
          int.parse(timeParts[0]),
          int.parse(timeParts[1]),
        );
        
        // Toleransi 10 menit
        if (loginTimeLocal.isAfter(scheduledTime.add(const Duration(minutes: 10)))) {
          isActuallyLate = true;
          statusText = "Telat";
        }
      } catch (e) {
        isActuallyLate = shift.isLate;
        statusText = shift.lateStatusText;
      }
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: Column(
        children: [
          Row(
            children: [
              const CircleAvatar(
                  radius: 30,
                  backgroundColor: AppStyle.bgLightBlue,
                  child: Icon(Icons.person, color: AppStyle.primaryBlue)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(name,
                            style: AppStyle.titleText.copyWith(fontSize: 20)),
                        const SizedBox(width: 8),
                        if (shift != null && shift.status != 'none')
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isActuallyLate
                                  ? Colors.red.shade50
                                  : Colors.green.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color:
                                      isActuallyLate ? Colors.red : Colors.green),
                            ),
                            child: Text(statusText,
                                style: TextStyle(
                                    color: isActuallyLate
                                        ? Colors.red
                                        : Colors.green,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                    Text(
                        "Shift: ${shift?.masterInfo?.name ?? '-'} • Masuk: $loginTime WIB",
                        style: AppStyle.subTitleText),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => const ClosingCashDialog(),
                  );
                },
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text("Tutup Shift"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
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
                  "Kas Awal", "Rp ${_formatNumber(awal)}", Icons.wallet, Colors.blue),
              _infoItem("Transaksi", "$count", Icons.payments, Colors.orange),
              _infoItem("Kas Bersih", "Rp ${_formatNumber(bersih)}",
                  Icons.shopping_bag, Colors.green),
              _infoItem("Total Akhir", "Rp ${_formatNumber(awal + bersih)}",
                  Icons.summarize, AppStyle.primaryBlue,
                  isBold: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoItem(String label, String value, IconData icon, Color color,
      {bool isBold = false}) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 8),
        Text(value,
            style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                fontSize: 16,
                color: isBold ? AppStyle.primaryBlue : Colors.black87)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}