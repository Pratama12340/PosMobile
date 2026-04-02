import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  // Fungsi format titik otomatis
  String _formatNumber(String s) {
    if (s.isEmpty) return "";
    return s.replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.');
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double dialogWidth = screenWidth > 600 ? 400 : screenWidth * 0.9;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: dialogWidth,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppStyle.bgLightBlue,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          // Perubahan: Mengatur Column agar konten di dalamnya bisa di-center
          crossAxisAlignment: CrossAxisAlignment.center, 
          children: [
            // Judul: Sekarang berada di tengah
            Text(
              "Kas Awal",
              textAlign: TextAlign.center,
              style: AppStyle.titleText.copyWith(fontSize: 22),
            ),
            const SizedBox(height: 6),
            // Sub-judul: Sekarang berada di tengah
            Text(
              "Masukkan saldo awal laci kasir untuk memulai transaksi hari ini.",
              textAlign: TextAlign.center,
              style: AppStyle.hintText.copyWith(fontSize: 13),
            ),
            const SizedBox(height: 24),
            
            // Label input tetap di kiri atau tengah sesuai selera (di sini saya buat kiri agar rapi dengan input)
            Align(
              alignment: Alignment.centerLeft,
              child: Text("Jumlah Saldo", style: AppStyle.labelText),
            ),
            const SizedBox(height: 8),
            
            TextField(
              controller: _cashController,
              keyboardType: TextInputType.number,
              style: AppStyle.labelText.copyWith(fontSize: 18),
              onChanged: (value) {
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Judul Pecahan Cepat di Tengah
            const Text(
              "Pilih Pecahan Cepat", 
              style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500, fontFamily: 'Poppins')
            ),
            const SizedBox(height: 12),
            
            // Grid Pecahan Cepat: Disesuaikan jaraknya agar rapi (2 kolom)
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.8, // Mengatur tinggi-lebar tombol pecahan
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
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF4285F4).withOpacity(0.2)),
                    ),
                    child: Center(
                      child: Text(
                        "Rp ${_formatNumber(amount.toString())}",
                        style: const TextStyle(
                          fontSize: 13, 
                          fontWeight: FontWeight.bold, 
                          color: Color(0xFF4285F4),
                          fontFamily: 'Poppins'
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 28),
            
            // Tombol Submit
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4285F4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
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