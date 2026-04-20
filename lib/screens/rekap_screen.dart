import 'package:flutter/material.dart';
import '../style.dart'; 
import '../services/storage_service.dart';

class RekapScreen extends StatefulWidget {
  final TextEditingController searchController; 
  const RekapScreen({super.key, required this.searchController}); 

  @override
  State<RekapScreen> createState() => _RekapScreenState();
}

class _RekapScreenState extends State<RekapScreen> {
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    widget.searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    widget.searchController.removeListener(_onSearchChanged);
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = widget.searchController.text.toLowerCase();
    });
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyle.bgLightBlue,
      body: FutureBuilder<List<dynamic>>(
        // Tambahkan fetch data Shift dari Storage
        future: Future.wait([
          StorageService.getCashierName(),
          StorageService.getLoginTime(),
          StorageService.getOpeningCash(),
          StorageService.getShiftName(),     // Indeks ke-3
          StorageService.getShiftSchedule(), // Indeks ke-4
        ]),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final String cashierName = snapshot.data?[0] ?? "Kasir";
          final String loginTime = snapshot.data?[1] ?? "--:--";
          final int openingCash = snapshot.data?[2] ?? 0;
          final String shiftName = snapshot.data?[3] ?? "Shift -";
          final String shiftSchedule = snapshot.data?[4] ?? "00:00 - 00:00";

          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // Kirim data shift ke dalam fungsi _buildProfileHeader
                  _buildProfileHeader(cashierName, loginTime, openingCash, shiftName, shiftSchedule),
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: _buildTopProducts()),
                      const SizedBox(width: 24),
                      Expanded(flex: 1, child: _buildPaymentMethodBreakdown()),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileHeader(String name, String time, int cash, String shiftName, String shiftSchedule) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Avatar dengan Indikator Online
              Stack(
                children: [
                  CircleAvatar(
                    radius: 35,
                    backgroundColor: AppStyle.bgLightBlue,
                    child: const Icon(Icons.person, size: 40, color: AppStyle.primaryBlue),
                  ),
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      width: 15,
                      height: 15,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 20),
              
              // 2. Data Karyawan, Shift, dan Waktu Login
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: AppStyle.titleText.copyWith(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppStyle.primaryBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            shiftName.toUpperCase(), 
                            style: const TextStyle(
                              color: AppStyle.primaryBlue, 
                              fontWeight: FontWeight.bold, 
                              fontSize: 11
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          shiftSchedule,
                          style: AppStyle.subTitleText.copyWith(fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.login_rounded, size: 14, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text(
                          "Mulai: $time WIB",
                          style: AppStyle.subTitleText.copyWith(fontSize: 13, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 3. Tombol Tutup Shift
              ElevatedButton.icon(
                onPressed: () async {
                  await StorageService.logoutKasir(); 
                  
                  if (mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                  }
                },
                icon: const Icon(Icons.power_settings_new, size: 18),
                label: const Text("Tutup Shift"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5C5C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          const Divider(color: AppStyle.bgLightBlue, thickness: 1),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _infoKasItem("Kas Awal", "Rp ${_formatNumber(cash)}", Icons.account_balance_wallet, Colors.blue),
              _infoKasItem("Banyak Transaksi", "0", Icons.payments, Colors.blue),
              _infoKasItem("Pengeluaran Outlet", "Rp 0", Icons.shopping_bag, Colors.red),
              _infoKasItem("Total Kas Akhir", "Rp ${_formatNumber(cash)}", Icons.assessment, AppStyle.primaryBlue, isHighlight: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoKasItem(String label, String value, IconData icon, Color color, {bool isHighlight = false}) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 12),
        Text(
          value, 
          style: AppStyle.numPadText.copyWith(
            fontSize: 20, 
            color: isHighlight ? AppStyle.primaryBlue : AppStyle.textMain,
            fontWeight: FontWeight.bold
          )
        ),
        Text(label, style: AppStyle.subTitleText.copyWith(fontSize: 12)),
      ],
    );
  }

  Widget _buildTopProducts() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Produk Terlaris", style: AppStyle.titleText.copyWith(fontSize: 18)),
          const SizedBox(height: 40),
          Center(
            child: Text(
              _searchQuery.isEmpty 
                  ? "Belum ada data transaksi" 
                  : "Hasil pencarian '$_searchQuery' tidak ditemukan",
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodBreakdown() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Metode Bayar", style: AppStyle.titleText.copyWith(fontSize: 18)),
          const SizedBox(height: 24),
          const Text("Belum ada data"),
        ],
      ),
    );
  }
}