import 'package:flutter/material.dart';
import '../style.dart'; 
import '../services/storage_service.dart';

class RekapScreen extends StatefulWidget {
  const RekapScreen({super.key});

  @override
  State<RekapScreen> createState() => _RekapScreenState();
}

class _RekapScreenState extends State<RekapScreen> {
  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyle.bgLightBlue,
      body: FutureBuilder<List<dynamic>>(
        future: Future.wait([
          StorageService.getCashierName(),
          StorageService.getLoginTime(),
          StorageService.getOpeningCash(),
        ]),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final String cashierName = snapshot.data?[0] ?? "Kasir";
          final String loginTime = snapshot.data?[1] ?? "--:--";
          final int openingCash = snapshot.data?[2] ?? 0;

          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  _buildProfileHeader(cashierName, loginTime, openingCash),
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

  Widget _buildProfileHeader(String name, String time, int cash) {
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
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: AppStyle.bgLightBlue,
                child: const Icon(Icons.person, size: 35, color: AppStyle.primaryBlue),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: AppStyle.titleText.copyWith(fontSize: 22)),
                    Text("Shift Berjalan • Sejak $time WIB", style: AppStyle.subTitleText),
                  ],
                ),
              ),
              // PERBAIKAN DI SINI:
              ElevatedButton.icon(
                onPressed: () async {
                  // Memanggil fungsi dari StorageService
                  await StorageService.logoutKasir(); 
                  
                  if (mounted) {
                    // Gunakan pushNamedAndRemoveUntil agar kasir tidak bisa "back" lagi ke halaman rekap
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
          const Center(child: Text("Belum ada data transaksi")),
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