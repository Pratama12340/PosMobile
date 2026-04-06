import 'package:flutter/material.dart';
import '../style.dart'; // Import file style Anda
import 'printer_screen.dart';

class SettingScreen extends StatelessWidget {
  const SettingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Menggunakan warna background dari AppStyle
      backgroundColor: AppStyle.bgLightBlue, 
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20), // Jarak atas agar rapi
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 10),
              children: [
                _buildSettingItem(
                  context,
                  icon: Icons.print_outlined,
                  title: "Koneksi Printer",
                  subtitle: "Atur printer struk via Bluetooth",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const PrinterScreen()),
                    );
                  },
                ),
                _buildSettingItem(
                  context,
                  icon: Icons.storefront_outlined,
                  title: "Informasi Outlet",
                  subtitle: "Lihat detail lokasi cabang Anda",
                  onTap: () {
                    // Logic untuk info outlet
                  },
                ),
                _buildSettingItem(
                  context,
                  icon: Icons.info_outline,
                  title: "Tentang Aplikasi",
                  subtitle: "Versi 1.0.0 - Aranus POS",
                  onTap: () {
                    // Logic untuk info aplikasi
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem(BuildContext context, {
    required IconData icon, 
    required String title, 
    String? subtitle,
    required VoidCallback onTap
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: AppStyle.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppStyle.primaryBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppStyle.primaryBlue, size: 24),
        ),
        title: Text(
          title,
          // Menggunakan gaya menuText dari AppStyle (Poppins)
          style: AppStyle.menuText.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        subtitle: subtitle != null 
          ? Text(subtitle, style: AppStyle.subTitleText.copyWith(fontSize: 11))
          : null,
        trailing: const Icon(Icons.chevron_right, color: AppStyle.textGrey, size: 20),
      ),
    );
  }
}