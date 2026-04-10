import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../style.dart';
import 'outlet_selection_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkDeviceStatus();
  }

  Future<void> _checkDeviceStatus() async {
    await Future.delayed(const Duration(milliseconds: 1500)); // Animasi awal

    final int? outletId = await StorageService.getOutletId();

    if (!mounted) return;

    if (outletId == null) {
      // 1. INSTALASI PERTAMA -> Wajib masuk pilih Outlet
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const OutletSelectionScreen()));
    } else {
      // 2. SUDAH PERNAH DISETING -> Langsung lompat ke Login PIN
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyle.primaryBlue, 
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.storefront, size: 80, color: Colors.white),
            const SizedBox(height: 20),
            Text("ARANUS POS", style: AppStyle.titleText.copyWith(color: Colors.white, fontSize: 24)),
            const SizedBox(height: 30),
            const CircularProgressIndicator(color: Colors.white), 
          ],
        ),
      ),
    );
  }
}