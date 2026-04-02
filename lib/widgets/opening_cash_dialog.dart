import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Perlu untuk TextInputFormatter
import '../style.dart';

class CashInitialDialog extends StatefulWidget {
  const CashInitialDialog({super.key});

  @override
  State<CashInitialDialog> createState() => _CashInitialDialogState();
}

class _CashInitialDialogState extends State<CashInitialDialog> {
  final TextEditingController _cashController = TextEditingController();

  // Daftar pecahan cepat yang sering digunakan
  final List<int> _quickAmounts = [50000, 100000, 200000, 500000];

  // Fungsi untuk memformat angka ke ribuan (1.000.000)
  String _formatNumber(String s) {
    if (s.isEmpty) return "";
    return s.replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.');
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double dialogWidth = screenWidth > 600 ? 420 : screenWidth * 0.9;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: dialogWidth,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppStyle.bgLightBlue,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Judul yang ukurannya sudah disesuaikan (tidak kebesaran)
            Text(
              "Kas Awal",
              style: AppStyle.titleText.copyWith(fontSize: 22),
            ),
            const SizedBox(height: 4),
            const Text(
              "Masukkan saldo awal laci kasir.",
              style: AppStyle.hintText,
            ),
            const SizedBox(height: 20),
            
            const Text("Jumlah Saldo", style: AppStyle.labelText),
            const SizedBox(height: 8),
            
            // Input dengan Auto-Formatting Titik
            TextField(
              controller: _cashController,
              keyboardType: TextInputType.number,
              style: AppStyle.labelText.copyWith(fontSize: 18),
              onChanged: (value) {
                // Hapus titik lama, lalu format ulang
                String cleanValue = value.replaceAll('.', '');
                if (cleanValue.isNotEmpty) {
                  String formatted = _formatNumber(cleanValue);
                  _cashController.value = TextEditingValue(
                    text: formatted,
                    selection: TextSelection.collapsed(offset: formatted.length),
                  );
                }
              },
              decoration: InputDecoration(
                filled: true,
                fillColor: AppStyle.formGrey,
                prefixText: "Rp ",
                prefixStyle: AppStyle.labelText,
                hintText: "0",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Pilihan Pecahan Cepat
            const Text("Pecahan Cepat:", style: TextStyle(fontSize: 12, color: Colors.grey, fontFamily: 'Poppins')),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _quickAmounts.map((amount) {
                return InkWell(
                  onTap: () {
                    setState(() {
                      String formatted = _formatNumber(amount.toString());
                      _cashController.text = formatted;
                      _cashController.selection = TextSelection.collapsed(offset: formatted.length);
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Text(
                      "Rp ${_formatNumber(amount.toString())}",
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4285F4)),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),
            
            // Tombol Submit
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4285F4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Text(
                  "Buka Kasir",
                  style: AppStyle.buttonText.copyWith(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}