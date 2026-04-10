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
  final TextEditingController _outletNameController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _outletIdController.dispose();
    _outletNameController.dispose();
    super.dispose();
  }

  void _saveAndContinue() async {
    String idText = _outletIdController.text.trim();
    String nameText = _outletNameController.text.trim();

    if (idText.isEmpty || nameText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("ID dan Nama Outlet wajib diisi!")),
      );
      return;
    }

    int? id = int.tryParse(idText);
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("ID Outlet harus berupa angka!")),
      );
      return;
    }

    setState(() => _isLoading = true);

    // 👇 PROSES SIMPAN KE STORAGE (TANPA API)
    await StorageService.saveOutletId(id);
    await StorageService.saveOutletName(nameText);

    if (mounted) {
      // Langsung pindah ke Login
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyle.bgLightBlue,
      body: Center(
        child: Container(
          width: 450, // Ukuran form input yang proporsional
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
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
                "Masukkan ID Outlet sesuai instruksi Manager",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 30),

              // INPUT ID OUTLET (ANGKA)
              TextField(
                controller: _outletIdController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "ID Outlet (Contoh: 1, 2, 3)",
                  prefixIcon: const Icon(Icons.numbers),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),

              // INPUT NAMA OUTLET (TEKS)
              TextField(
                controller: _outletNameController,
                decoration: InputDecoration(
                  labelText: "Nama Outlet (Contoh: Cabang Jakarta)",
                  prefixIcon: const Icon(Icons.store),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 30),

              // TOMBOL SIMPAN
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveAndContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppStyle.primaryBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "SIMPAN & LANJUT LOGIN",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}