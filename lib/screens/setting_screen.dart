import 'package:flutter/material.dart';
import '../style.dart'; // Import file style
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
          // Bagian judul "Pengaturan" telah dihapus
          const SizedBox(height: 16), // Memberikan sedikit jarak di bagian atas
          Expanded(
            child: ListView(
              children: [
                _buildSettingItem(
                  context,
                  icon: Icons.print_outlined,
                  title: "Koneksi Printer",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const PrinterScreen()),
                    );
                  },
                ),
                // Anda bisa menambahkan item pengaturan lain di sini
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
    required VoidCallback onTap
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF4285F4).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFF4285F4)), // Menggunakan parameter icon
        ),
        title: Text(
          title,
          // Menggunakan gaya label dari AppStyle
          style: AppStyle.labelText.copyWith(fontSize: 16, fontFamily: 'Poppins'),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppStyle.textHint),
      ),
    );
  }
}