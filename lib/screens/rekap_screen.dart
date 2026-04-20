import 'package:flutter/material.dart';
import '../style.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart';
import '../models/rekap_model.dart';
import '../models/order_model.dart';
import 'package:intl/intl.dart';

class RekapScreen extends StatefulWidget {
  final TextEditingController searchController;
  const RekapScreen({super.key, required this.searchController});

  @override
  State<RekapScreen> createState() => _RekapScreenState();
}

class _RekapScreenState extends State<RekapScreen> {
  String _formatNumber(int number) => number.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyle.bgLightBlue,
      body: FutureBuilder<List<dynamic>>(
        future: Future.wait([
          StorageService.getCashierName(), // [0]
          ApiService.getShiftHistory(),    // [1] Sudah List<RekapShift>
          ApiService.fetchHistory(),       // [2] Sudah List<Order>
          ApiService.getMasterShifts(),    // [3] Sudah List<ShiftMaster>
        ]),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));

          final String cashierName = snapshot.data?[0] ?? "Kasir";
          
          // PERBAIKAN: Langsung cast ke List Model tanpa mapping lagi
          final List<ShiftMaster> masterData = snapshot.data?[3] ?? [];
          final List<RekapShift> shiftList = snapshot.data?[1] ?? [];
          final List<Order> allOrders = snapshot.data?[2] ?? [];

          // Mapping Master Info ke dalam Rekap (Join Data)
          for (var rekap in shiftList) {
            rekap.masterInfo = masterData.firstWhere(
              (m) => m.id == rekap.shiftId,
              orElse: () => ShiftMaster(id: 0, name: 'Shift?', startTime: '00:00:00', endTime: '00:00:00'),
            );
          }

          final RekapShift? activeShift = shiftList.isNotEmpty ? shiftList.first : null;

          // Hitung Kas Bersih
          int kasAwal = activeShift?.uangAwal ?? 0;
          int bersih = 0;
          int count = 0;

          if (activeShift != null && activeShift.startedAt != null) {
            final df = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');
            for (var order in allOrders) {
              try {
                DateTime ot = df.parse(order.date);
                if (ot.isAfter(activeShift.startedAt!)) {
                  bersih += order.totalPrice.round();
                  count++;
                }
              } catch (_) {}
            }
          }

          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  _buildProfileHeader(cashierName, activeShift, kasAwal, count, bersih),
                  // Tambahkan widget lain jika diperlukan
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileHeader(String name, RekapShift? shift, int awal, int count, int bersih) {
    String loginTime = shift?.startedAt != null ? DateFormat('HH:mm').format(shift!.startedAt!) : "--:--";
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: Column(
        children: [
          Row(
            children: [
              const CircleAvatar(radius: 30, backgroundColor: AppStyle.bgLightBlue, child: Icon(Icons.person, color: AppStyle.primaryBlue)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(name, style: AppStyle.titleText.copyWith(fontSize: 20)),
                        const SizedBox(width: 8),
                        if (shift != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: shift.isLate ? Colors.red.shade50 : Colors.green.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: shift.isLate ? Colors.red : Colors.green),
                            ),
                            child: Text(shift.lateStatusText, style: TextStyle(color: shift.isLate ? Colors.red : Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                    Text("Shift: ${shift?.masterInfo?.name} • Masuk: $loginTime WIB", style: AppStyle.subTitleText),
                  ],
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
              _infoItem("Kas Awal", "Rp ${_formatNumber(awal)}", Icons.wallet, Colors.blue),
              _infoItem("Transaksi", "$count", Icons.payments, Colors.orange),
              _infoItem("Kas Bersih", "Rp ${_formatNumber(bersih)}", Icons.shopping_bag, Colors.green),
              _infoItem("Total Akhir", "Rp ${_formatNumber(awal + bersih)}", Icons.summarize, AppStyle.primaryBlue, isBold: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoItem(String label, String value, IconData icon, Color color, {bool isBold = false}) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: 16, color: isBold ? AppStyle.primaryBlue : Colors.black87)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}