import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'history_screen.dart';
import 'login_screen.dart'; // Pastikan import ini ada
import '../services/storage_service.dart'; // Pastikan import ini ada
import '../widgets/opening_cash_dialog.dart';

class MainNavigationScaffold extends StatefulWidget {
  final bool requireCashInput;
  const MainNavigationScaffold({super.key, this.requireCashInput = false});

  @override
  State<MainNavigationScaffold> createState() => _MainNavigationScaffoldState();
}

class _MainNavigationScaffoldState extends State<MainNavigationScaffold> {
  int _currentIndex = 0;
  bool _isSidebarVisible = false;

  @override
  void initState() {
    super.initState();
    if (widget.requireCashInput) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const OpeningCashDialog(),
        );
      });
    }
  }

  // --- FUNGSI LOGOUT (FIX) ---
  void _handleLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Konfirmasi Keluar", 
            style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
        content: const Text("Apakah Anda yakin ingin keluar dari sesi kasir?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              // 1. Hapus data sesi (tapi simpan outlet_id)
              await StorageService.logoutKasir();

              // 2. Tendang ke Login dan hapus semua history halaman
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text("Ya, Keluar", 
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: Row(
                children: [
                  if (_isSidebarVisible) _buildSidebar(),
                  if (_isSidebarVisible)
                    VerticalDivider(width: 1, thickness: 1, color: Colors.grey[200]),
                  Expanded(
                    child: IndexedStack(
                      index: _currentIndex,
                      children: const [
                        HomeScreen(),
                        HistoryScreenContent(),
                        Center(child: Text("Halaman Rekapitulasi")),
                        Center(child: Text("Halaman Pengaturan")),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.black87),
            onPressed: () => setState(() => _isSidebarVisible = !_isSidebarVisible),
          ),
          const SizedBox(width: 10),
          const Text("ARANUS POS", 
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 0.5)),
          const Spacer(),
          Container(
            constraints: const BoxConstraints(maxWidth: 400),
            height: 42,
            child: TextField(
              textAlignVertical: TextAlignVertical.center,
              decoration: InputDecoration(
                hintText: 'Search menu...',
                prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFFF1F3F4),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          const Spacer(),
          const Row(
            children: [
              CircleAvatar(
                  radius: 18,
                  backgroundColor: Color(0xFF4285F4),
                  child: Icon(Icons.person, color: Colors.white, size: 20)),
              SizedBox(width: 12),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Fatimah", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text("Cashier", style: TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 220,
      color: Colors.white,
      child: Column(
        children: [
          const SizedBox(height: 10),
          _buildMenuItem(Icons.home_outlined, "Home", 0),
          _buildMenuItem(Icons.history, "History", 1),
          _buildMenuItem(Icons.assessment_outlined, "Rekapitulasi", 2),
          const Spacer(),
          const Divider(indent: 20, endIndent: 20),
          _buildMenuItem(Icons.settings_outlined, "Setting", 3),
          _buildMenuItem(Icons.logout, "Logout", -1, isLogout: true),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, int index, {bool isLogout = false}) {
    bool isActive = _currentIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        onTap: () {
          if (isLogout) {
            _handleLogout(context); // Panggil fungsi logout jika diklik
          } else {
            setState(() => _currentIndex = index);
          }
        },
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        tileColor: isActive ? const Color(0xFFE3F2FD) : Colors.transparent,
        leading: Icon(icon, 
            color: isActive ? Colors.blue : (isLogout ? Colors.red : Colors.grey[700]), 
            size: 22),
        title: Text(
          title,
          style: TextStyle(
              color: isActive ? Colors.blue : (isLogout ? Colors.red : Colors.black87),
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              fontFamily: 'Poppins'),
        ),
      ),
    );
  }
}