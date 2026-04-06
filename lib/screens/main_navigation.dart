import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'history_screen.dart';
import 'login_screen.dart'; 
import 'rekap_screen.dart';
import 'setting_screen.dart'; 
import '../style.dart'; // IMPORT STYLE ANDA
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
  String _cashierName = "Loading..."; 

  @override
  void initState() {
    super.initState();
    _loadDataKasir();

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

  Future<void> _loadDataKasir() async {
    String name = await StorageService.getCashierName();
    setState(() {
      _cashierName = name;
    });
  }

  void _handleLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Konfirmasi Keluar", 
          style: AppStyle.titleText.copyWith(fontSize: 18)), // Poppins ExtraBold
        content: Text("Apakah Anda yakin ingin keluar dari sesi kasir?", 
          style: AppStyle.subTitleText.copyWith(fontSize: 14)), // Poppins Regular
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: Text("Batal", style: TextStyle(color: AppStyle.textGrey, fontFamily: AppStyle.fontPoppins)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppStyle.errorRed),
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
            child: Text("Ya, Keluar", 
              style: AppStyle.buttonText.copyWith(fontSize: 14)), // Poppins Bold
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyle.bgLightBlue, // PAKAI STYLE
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
                        RekapScreen(),
                        SettingScreen(), 
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
          color: AppStyle.white,
          border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.menu, color: AppStyle.textMain),
            onPressed: () => setState(() => _isSidebarVisible = !_isSidebarVisible),
          ),
          const SizedBox(width: 10),
          Text("ARANUS POS", 
            style: AppStyle.titleText.copyWith(fontSize: 18, letterSpacing: 0.5)), // Poppins ExtraBold
          const Spacer(),
          
          Row(
            children: [
              CircleAvatar(
                  radius: 18,
                  backgroundColor: AppStyle.primaryBlue,
                  child: const Icon(Icons.person, color: Colors.white, size: 20)),
              const SizedBox(width: 12),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_cashierName, 
                    style: AppStyle.menuText.copyWith(fontWeight: FontWeight.bold)), // Poppins Bold
                  Text("Cashier", 
                    style: AppStyle.subTitleText.copyWith(fontSize: 11)), // Poppins Regular
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
      color: AppStyle.white,
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
            _handleLogout(context);
          } else {
            setState(() => _currentIndex = index);
          }
        },
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        tileColor: isActive ? AppStyle.primaryBlue.withOpacity(0.1) : Colors.transparent,
        leading: Icon(icon, 
          color: isActive ? AppStyle.primaryBlue : (isLogout ? AppStyle.errorRed : AppStyle.textGrey)),
        title: Text(title, 
          style: AppStyle.menuText.copyWith(
            color: isActive ? AppStyle.primaryBlue : (isLogout ? AppStyle.errorRed : AppStyle.textMain),
            fontWeight: isActive || isLogout ? FontWeight.bold : FontWeight.normal,
          )), // SEMUA PAKAI POPPINS
      ),
    );
  }
}