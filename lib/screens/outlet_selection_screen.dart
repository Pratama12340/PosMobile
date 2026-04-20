import 'package:flutter/material.dart';
import '../style.dart';
import '../services/storage_service.dart';
import 'login_screen.dart';

class OutletSelectionScreen extends StatefulWidget {
  const OutletSelectionScreen({super.key});

  @override
  State<OutletSelectionScreen> createState() => _OutletSelectionScreenState();
}

class _OutletSelectionScreenState extends State<OutletSelectionScreen> {
  final TextEditingController _outletIdController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _outletIdController.dispose();
    super.dispose();
  }

  void _saveAndContinue() async {
    String idText = _outletIdController.text.trim();

    if (idText.isEmpty) {
      _showSnackBar("ID Outlet wajib diisi!", isError: true);
      return;
    }

    int? id = int.tryParse(idText);
    if (id == null) {
      _showSnackBar("ID Outlet harus berupa angka!", isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Simpan ke Storage
      await StorageService.saveOutletId(id);
      print("DEBUG: Berhasil menyimpan ID $id ke Storage");

      // 2. Jeda Sinkronisasi (Penting agar Disk IO selesai)
      await Future.delayed(const Duration(milliseconds: 300));

      if (mounted) {
        // 3. Pindah ke Login dan bersihkan stack navigasi
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        _showSnackBar("Gagal menyimpan konfigurasi: $e", isError: true);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppStyle.errorRed : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyle.bgLightBlue,
      body: Center(
        child: Container(
          width: 450,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.storefront_rounded, size: 60, color: AppStyle.primaryBlue),
              const SizedBox(height: 20),
              Text("Konfigurasi Outlet", style: AppStyle.titleText.copyWith(fontSize: 22)),
              const SizedBox(height: 10),
              const Text(
                "Masukkan ID Outlet sesuai instruksi Manager.\nIdentitas ini akan mengunci menu dan akses kasir.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, height: 1.5),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _outletIdController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: "ID Outlet",
                  prefixIcon: const Icon(Icons.numbers),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveAndContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppStyle.primaryBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("SIMPAN & LANJUT LOGIN",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}