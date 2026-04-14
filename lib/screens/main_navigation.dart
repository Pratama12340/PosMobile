import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'history_screen.dart'; 
import 'rekap_screen.dart';
import 'setting_screen.dart';
import '../style.dart';
import '../services/storage_service.dart';
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
  
  // Variabel untuk data profil & outlet
  String _cashierName = "Loading...";
  String _outletName = "Loading...";
  String _profilePhoto = "";
  String _userRole = "Cashier";
  
  final TextEditingController _globalSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInitialData();

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

  Future<void> _loadInitialData() async {
    final name = await StorageService.getCashierName();
    final outlet = await StorageService.getOutletName();
    final photo = await StorageService.getProfilePhoto();
    final role = await StorageService.getUserRole();
    
    if (mounted) {
      setState(() {
        _cashierName = name;
        _outletName = outlet;
        _profilePhoto = photo;
        _userRole = role;
      });
    }
  }

  @override
  void dispose() {
    _globalSearchController.dispose();
    super.dispose();
  }

  void _handleLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Konfirmasi Keluar", style: AppStyle.titleText.copyWith(fontSize: 18)),
        content: const Text("Apakah Anda yakin ingin keluar dari sesi kasir?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text("Batal"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppStyle.errorRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
            ),
            onPressed: () async {
              await StorageService.logoutKasir();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text("Ya, Keluar", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyle.bgLightBlue,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: Row(
                children: [
                  if (_isSidebarVisible) _buildSidebar(),
                  Expanded(
                    child: IndexedStack(
                      index: _currentIndex,
                      children: [
                        HomeScreen(searchController: _globalSearchController),
                        const Center(child: Text("Shift Screen")), 
                        const RekapScreen(), 
                        // PERBAIKAN DI SINI: Ganti HistoryScreenContent menjadi HistoryScreen
                        const HistoryScreen(), 
                        const SettingScreen(), 
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
      height: 85,
      padding: const EdgeInsets.symmetric(horizontal: 25),
      decoration: BoxDecoration(
          color: AppStyle.white,
          border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.menu, color: AppStyle.textMain, size: 30),
            onPressed: () => setState(() => _isSidebarVisible = !_isSidebarVisible),
          ),
          const SizedBox(width: 10),
          Text(
            _outletName.toUpperCase(),
            style: AppStyle.titleText.copyWith(
              fontSize: 20, 
              color: AppStyle.primaryBlue,
              letterSpacing: 0.5
            ),
          ),
          const Spacer(flex: 1),
          Expanded(
            flex: 6,
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FB),
                borderRadius: BorderRadius.circular(15),
              ),
              child: TextField(
                controller: _globalSearchController,
                decoration: const InputDecoration(
                  hintText: "Cari menu, transaksi, atau laporan...",
                  prefixIcon: Icon(Icons.search, color: AppStyle.primaryBlue),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
          ),
          const Spacer(flex: 1),
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppStyle.primaryBlue.withOpacity(0.1),
                backgroundImage: _profilePhoto.isNotEmpty 
                    ? NetworkImage("https://api.etres.my.id/storage/$_profilePhoto")
                    : null,
                child: _profilePhoto.isEmpty 
                    ? const Icon(Icons.person, color: AppStyle.primaryBlue, size: 28)
                    : null,
              ),
              const SizedBox(width: 15),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_cashierName, 
                    style: AppStyle.menuText.copyWith(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(_userRole, 
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: AppStyle.white,
        border: Border(right: BorderSide(color: Colors.grey.shade100))
      ),
      child: Column(
        children: [
          const SizedBox(height: 20),
          _buildMenuItem(Icons.home_rounded, "Home", 0),
          _buildMenuItem(Icons.access_time_filled_rounded, "Shift", 1),
          _buildMenuItem(Icons.assessment_rounded, "Rekapitulasi", 2),
          _buildMenuItem(Icons.history_rounded, "History", 3),
          const Spacer(),
          const Divider(indent: 20, endIndent: 20),
          _buildMenuItem(Icons.settings_rounded, "Setting", 4),
          _buildMenuItem(Icons.logout_rounded, "Logout", -1, isLogout: true),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, int index, {bool isLogout = false}) {
    bool isActive = _currentIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      child: ListTile(
        onTap: () {
          if (isLogout) {
            _handleLogout(context);
          } else {
            setState(() {
              _currentIndex = index;
              _globalSearchController.clear();
            });
          }
        },
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: isActive ? AppStyle.primaryBlue.withOpacity(0.1) : Colors.transparent,
        leading: Icon(icon, color: isActive ? AppStyle.primaryBlue : (isLogout ? AppStyle.errorRed : AppStyle.textGrey)),
        title: Text(title, style: AppStyle.menuText.copyWith(
          color: isActive ? AppStyle.primaryBlue : (isLogout ? AppStyle.errorRed : AppStyle.textMain), 
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal
        )),
      ),
    );
  }
}