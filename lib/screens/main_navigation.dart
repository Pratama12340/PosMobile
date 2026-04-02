import 'package:flutter/material.dart';

// Karena main_navigation.dart sekarang SATU RUMAH (satu folder) dengan home dan history,
// kita tinggal panggil nama filenya langsung tanpa embel-embel nama folder.
import 'home_screen.dart'; 
import 'history_screen.dart';

// Karena hover_scale.dart ada di folder berbeda, 
// kita pakai '../' untuk mundur satu langkah keluar dari folder screens, lalu masuk ke folder widgets.
import '../widgets/hover_scale.dart';

class MainNavigationScaffold extends StatefulWidget {
  const MainNavigationScaffold({super.key});

  @override
  State<MainNavigationScaffold> createState() => _MainNavigationScaffoldState();
}

class _MainNavigationScaffoldState extends State<MainNavigationScaffold> {
  // 1. Kontrol Sidebar & Halaman
  bool _isSidebarVisible = false;
  int _currentIndex = 0; // 0 untuk Home, 1 untuk History

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        children: [
          // ==========================================
          // PART A: TOP BAR (SEARCH POSISI TENGAH)
          // ==========================================
          Container(
            height: 75,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                // --- BAGIAN KIRI: MENU & LOGO ---
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.menu,
                        size: 28,
                        color: Colors.black87,
                      ),
                      onPressed: () => setState(
                        () => _isSidebarVisible = !_isSidebarVisible,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'ARANUS',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            height: 1.0,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        Text(
                          'POS',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            height: 1.0,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // --- BAGIAN TENGAH: SEARCH BAR (DI-CENTER) ---
                Expanded(
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(
                        maxWidth: 400,
                      ), // Batas lebar agar tetap proporsional
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: TextField(
                        textAlignVertical: TextAlignVertical.center,
                        decoration: InputDecoration(
                          prefixIcon: Icon(
                            Icons.search,
                            color: Colors.grey.shade600,
                            size: 20,
                          ),
                          hintText: 'Cari menu atau pesanan...',
                          hintStyle: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 14,
                            fontFamily: 'Poppins',
                          ),
                          border: InputBorder.none,
                          // Mengatur padding agar teks pas di tengah secara vertikal
                          contentPadding: const EdgeInsets.only(bottom: 12),
                        ),
                      ),
                    ),
                  ),
                ),

                // --- BAGIAN KANAN: PROFIL KASIR ---
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircleAvatar(
                      backgroundColor: Colors.blueAccent,
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Fatimah',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        Text(
                          'Cashier',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ==========================================
          // PART B: BODY (SIDEBAR + KONTEN DINAMIS)
          // ==========================================
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- SIDEBAR ---
                if (_isSidebarVisible)
                  Container(
                    width: 220,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        right: BorderSide(color: Colors.grey.shade100),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Column(
                      children: [
                        _buildMenuItem(Icons.home_filled, 'Home', index: 0),
                        _buildMenuItem(Icons.history, 'History', index: 1),
                        const Spacer(),
                        _buildMenuItem(Icons.settings, 'Setting', index: -1),
                        _buildMenuItem(
                          Icons.logout,
                          'Logout',
                          index: -2,
                          isLogout: true,
                        ),
                      ],
                    ),
                  ),

                // --- AREA KONTEN (SMOOTH TRANSITION) ---
                Expanded(
                  child: IndexedStack(
                    index: _currentIndex,
                    children: const [
                      HomeScreen(),   
                      HistoryScreenContent(), 
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // WIDGET BANTUAN UNTUK MENU SIDEBAR
  // ==========================================
  Widget _buildMenuItem(
    IconData icon,
    String title, {
    required int index,
    bool isLogout = false,
  }) {
    // Mengecek apakah menu ini yang sedang aktif
    bool isActive = _currentIndex == index;

    Color color = isActive
        ? Colors.blue
        : (isLogout ? Colors.red : Colors.grey.shade700);

    // --- HOVER ANIMASI DITAMBAHKAN DI SINI ---
    return HoverScale(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? Colors.blue.shade50 : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: ListTile(
          leading: Icon(icon, color: color),
          title: Text(
            title,
            style: TextStyle(
              color: color,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              fontFamily: 'Poppins',
            ),
          ),
          onTap: () {
            if (index >= 0) {
              // Berpindah halaman
              setState(() => _currentIndex = index);
            } else if (isLogout) {
              // Kembali ke Login
              Navigator.pushReplacementNamed(context, '/');
              // Catatan: Pastikan di main.dart rute '/' adalah LoginScreen
            }
          },
        ),
      ),
    );
  }
}