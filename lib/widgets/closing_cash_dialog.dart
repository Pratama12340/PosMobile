import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../style.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class ClosingCashDialog extends StatefulWidget {
  const ClosingCashDialog({super.key});

  @override
  State<ClosingCashDialog> createState() => _ClosingCashDialogState();
}

class _ClosingCashDialogState extends State<ClosingCashDialog> {
  final TextEditingController _actualCashController = TextEditingController();
  bool _isLoading = false;

  // Mendapatkan angka murni tanpa titik untuk dikirim ke API
  int get _rawAmount {
    String clean = _actualCashController.text.replaceAll('.', '');
    return int.tryParse(clean) ?? 0;
  }

  // Format angka ke ribuan (titik) untuk tampilan UI
  String _formatNumber(String s) {
    if (s.isEmpty) return "";
    return s.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  // FUNGSI UTAMA: Memproses Penutupan Shift
  Future<void> _processClosing() async {
    if (_rawAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Harap masukkan total uang fisik.")),
      );
      return;
    }

    setState(() => _isLoading = true);
    debugPrint("--- MEMPROSES TUTUP SHIFT ---");

    try {
      // 1. Panggil API endShift (disesuaikan dengan ApiService yang tidak menerima parameter)
      final result = await ApiService.endShift();

      if (result['success']) {
        debugPrint("API Berhasil: Shift Ditutup.");

        // 2. Bersihkan data lokal (PENTING agar sistem restart)
        await StorageService.saveOpeningCash(0);
        await StorageService.logoutKasir();

        if (mounted) {
          Navigator.pop(context); // Tutup dialog
          // Arahkan kembali ke login dan hapus semua history page sebelumnya
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
        }
      } else {
        debugPrint("API Gagal: ${result['message']}");
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? "Gagal tutup shift"),
              backgroundColor: AppStyle.errorRed,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("TERJADI EXCEPTION: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Terjadi kesalahan: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      backgroundColor: Colors.white,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 450),
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_clock, size: 60, color: AppStyle.errorRed),
            const SizedBox(height: 20),
            Text("Tutup Shift", style: AppStyle.titleText.copyWith(fontSize: 24)),
            const SizedBox(height: 10),
            const Text(
              "Hitung semua uang fisik di laci dan masukkan totalnya di bawah ini:",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, height: 1.4),
            ),
            const SizedBox(height: 25),
            TextField(
              controller: _actualCashController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: AppStyle.numPadText.copyWith(fontSize: 30, color: AppStyle.textMain),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                filled: true,
                fillColor: AppStyle.bgLightBlue,
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(left: 20, right: 10),
                  child: Text(
                    "Rp", 
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppStyle.primaryBlue)
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                if (value.isNotEmpty) {
                  String formatted = _formatNumber(value);
                  _actualCashController.value = TextEditingValue(
                    text: formatted,
                    selection: TextSelection.collapsed(offset: formatted.length),
                  );
                }
              },
            ),
            const SizedBox(height: 30),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    child: const Text("Batal", style: TextStyle(color: Colors.grey, fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppStyle.primaryBlue,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: _isLoading ? null : _processClosing,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            "Tutup Shift", 
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
                          ),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}