import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'history_screen.dart';
import 'shift_screen.dart';
import 'setting_screen.dart';
import '../constants/style.dart';
import '../services/storage_service.dart';
import '../widgets/opening_cash_dialog.dart';
import '../services/reverb_service.dart';
import '../utils/app_keys.dart';
import '../widgets/order_notification_overlay.dart';

class MainNavigationScaffold extends StatefulWidget {
  final bool requireCashInput;
  const MainNavigationScaffold({super.key, this.requireCashInput = false});

  @override
  State<MainNavigationScaffold> createState() => _MainNavigationScaffoldState();
}

class _MainNavigationScaffoldState extends State<MainNavigationScaffold> {
  int _currentIndex = 0;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<HomeScreenState> _homeKey = GlobalKey<HomeScreenState>();
  final GlobalKey<HistoryScreenState> _historyKey =
      GlobalKey<HistoryScreenState>();
  final GlobalKey<ShiftScreenState> _shiftKey = GlobalKey<ShiftScreenState>();
  final ReverbService _reverbService = ReverbService();

  String _cashierName = "Loading...";
  String _outletName = "Loading...";
  String _profilePhoto = "";
  String _userRole = "Cashier";

  final TextEditingController _globalSearchController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _connectReverb();

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
    final results = await Future.wait([
      StorageService.getCashierName(),
      StorageService.getOutletName(),
      StorageService.getProfilePhoto(),
      StorageService.getUserRole(),
    ]);
    if (mounted) {
      setState(() {
        _cashierName = results[0];
        _outletName = results[1];
        _profilePhoto = results[2];
        _userRole = results[3];
      });
    }
  }

  // ────────────────────────────────────────────────────────────
  // Kirim notifikasi ke overlay
  // ────────────────────────────────────────────────────────────
  void _fireNotification({
    required String paymentMethod,
    required String customerName,
    double? totalPrice,
    String? invoiceNo,
  }) {
    debugPrint('🔥 [_fireNotification] method=$paymentMethod customer=$customerName');

    final method = paymentMethod.toLowerCase().trim();
    final isQris = ['qris', 'midtrans', 'gopay', 'other_qris'].contains(method);

    OrderNotificationController().show(
      OrderNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: isQris ? 'Pesanan QRIS masuk!' : 'Pesanan tunai masuk!',
        subtitle: invoiceNo != null
            ? 'Invoice: $invoiceNo'
            : 'Segera proses pesanan',
        paymentMethod: paymentMethod,
        customerName: customerName,
        totalPrice: totalPrice,
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // Koneksi Reverb — dengan debug lengkap
  // ────────────────────────────────────────────────────────────
  void _connectReverb() async {
    debugPrint('🚀 [REVERB] _connectReverb START');

    final int? outletId = await StorageService.getOutletId();
    debugPrint('🚀 [REVERB] outletId = $outletId');

    if (outletId == null) {
      debugPrint('❌ [REVERB] outletId null, batalkan koneksi');
      return;
    }

    final channelName = 'private-orders.outlet.$outletId';
    debugPrint('🚀 [REVERB] channel = $channelName');

    await _reverbService.initConnection(
      channelName: channelName,
      eventName: '.order.created',
      onEventReceived: (data) {
        debugPrint('⚡ [ORDER DITERIMA RAW]: $data');
        debugPrint('⚡ [ORDER DITERIMA TYPE]: ${data.runtimeType}');

        // Backend bisa kirim: { order: {...} } ATAU langsung {...}
        Map<String, dynamic> orderData = {};
        if (data is Map) {
          final raw = Map<String, dynamic>.from(data);
          if (raw.containsKey('order') && raw['order'] is Map) {
            orderData = Map<String, dynamic>.from(raw['order'] as Map);
          } else {
            orderData = raw;
          }
        }

        debugPrint('⚡ [ORDER PARSED]: $orderData');

        final String paymentMethod =
            orderData['payment_method']?.toString() ?? '';
        final String customerName =
            orderData['customer_name']?.toString() ?? 'Pelanggan';
        final double? totalPrice = orderData['total_price'] != null
            ? double.tryParse(orderData['total_price'].toString())
            : null;
        final String? invoiceNo =
            orderData['invoice_number']?.toString() ??
            orderData['invoice_no']?.toString();

        debugPrint('⚡ [PARSED] method=$paymentMethod customer=$customerName total=$totalPrice');

        // Refresh UI
        _homeKey.currentState?.refreshPendingOrdersSilently();
        _historyKey.currentState?.loadHistory();
        _shiftKey.currentState?.refreshShift();

        // Tembak notifikasi overlay
        _fireNotification(
          paymentMethod: paymentMethod,
          customerName: customerName,
          totalPrice: totalPrice,
          invoiceNo: invoiceNo,
        );
      },
    );

    // Event order updated (lebih subtle)
    _reverbService.bindEvent(
      channelName,
      '.order.updated',
      (data) {
        debugPrint('⚡ [ORDER UPDATED]: $data');
        _homeKey.currentState?.refreshPendingOrdersSilently();
        _historyKey.currentState?.loadHistory();
        _shiftKey.currentState?.refreshShift();

        snackbarKey.currentState?.showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.sync_rounded, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text('Status pesanan diperbarui'),
              ],
            ),
            backgroundColor: Colors.blueAccent,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _globalSearchController.dispose();
    _reverbService.disconnect();
    super.dispose();
  }

  void _closeSidebar() {
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      _scaffoldKey.currentState?.closeDrawer();
    }
  }

  void _handleLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Konfirmasi Keluar',
            style: AppStyle.titleText.copyWith(fontSize: 18)),
        content:
            const Text('Apakah Anda yakin ingin keluar dari sesi kasir?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppStyle.errorRed),
            onPressed: () async {
              await StorageService.logoutKasir();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text('Ya, Keluar',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ KUNCI: Bungkus seluruh Scaffold dengan OrderNotificationLayer
    return OrderNotificationLayer(
      child: Scaffold(
        key: _scaffoldKey,
        resizeToAvoidBottomInset: false,
        backgroundColor: AppStyle.bgLightBlue,
        drawer: Drawer(
          backgroundColor: AppStyle.white,
          child: _buildSidebar(),
        ),
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: IndexedStack(
                  index: _currentIndex,
                  children: [
                    HomeScreen(
                      key: _homeKey,
                      searchController: _globalSearchController,
                      onCartToggled: (isOpen) {
                        if (isOpen) _closeSidebar();
                      },
                    ),
                    ShiftScreen(
                      key: _shiftKey,
                      searchController: _globalSearchController,
                    ),
                    HistoryScreen(
                      key: _historyKey,
                      searchController: _globalSearchController,
                    ),
                    SettingScreen(
                        searchController: _globalSearchController),
                  ],
                ),
              ),
            ],
          ),
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
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.menu, color: AppStyle.textMain, size: 30),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          const SizedBox(width: 10),
          Text(_outletName.toUpperCase(),
              style: AppStyle.titleText.copyWith(fontSize: 20)),
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
                  hintText: 'Cari menu, transaksi, atau laporan...',
                  prefixIcon:
                      Icon(Icons.search, color: AppStyle.primaryBlue),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const Spacer(flex: 1),
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundImage: _profilePhoto.isNotEmpty
                    ? NetworkImage(
                        'https://api.etres.my.id/storage/$_profilePhoto')
                    : null,
              ),
              const SizedBox(width: 15),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_cashierName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(_userRole,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.grey)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Column(
      children: [
        const SizedBox(height: 100),
        _buildMenuItem(Icons.home_rounded, 'Home', 0),
        _buildMenuItem(Icons.access_time_filled_rounded, 'Shift', 1),
        _buildMenuItem(Icons.history_rounded, 'History', 2),
        const Spacer(),
        const Divider(indent: 20, endIndent: 20),
        _buildMenuItem(Icons.settings_rounded, 'Setting', 3),
        _buildMenuItem(Icons.logout_rounded, 'Logout', -1,
            isLogout: true),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildMenuItem(IconData icon, String title, int index,
      {bool isLogout = false}) {
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
            _scaffoldKey.currentState?.closeDrawer();
          }
        },
        tileColor: isActive
            ? AppStyle.primaryBlue.withValues(alpha: 0.1)
            : Colors.transparent,
        leading: Icon(icon,
            color: isActive ? AppStyle.primaryBlue : AppStyle.textGrey),
        title: Text(title,
            style: TextStyle(
                color:
                    isActive ? AppStyle.primaryBlue : AppStyle.textMain)),
      ),
    );
  }
}