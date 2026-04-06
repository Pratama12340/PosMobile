import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../style.dart';

class OpeningCashDialog extends StatefulWidget {
  const OpeningCashDialog({super.key});

  @override
  State<OpeningCashDialog> createState() => _OpeningCashDialogState();
}

class _OpeningCashDialogState extends State<OpeningCashDialog> {
  final TextEditingController _cashController = TextEditingController();
  final List<int> _quickAmounts = [50000, 100000, 200000, 500000];

  int get _rawAmount {
    String clean = _cashController.text.replaceAll('.', '');
    return int.tryParse(clean) ?? 0;
  }

  String _formatNumber(String s) {
    if (s.isEmpty) return "";
    return s.replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.');
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isTablet = screenWidth > 600;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      // Memberikan jarak luar sedikit lebih kecil agar dialog bisa lebih lebar
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        // PENYESUAIAN LEBAR: Naik ke 55% layar untuk tablet, maksimal 650 unit
        width: isTablet ? screenWidth * 0.55 : 450,
        constraints: const BoxConstraints(maxWidth: 650), 
        padding: const EdgeInsets.all(48), // Padding dalam lebih luas (lega)
        decoration: BoxDecoration(
          color: AppStyle.white,
          borderRadius: BorderRadius.circular(35),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 30,
              offset: const Offset(0, 15),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ornamen Ikon yang lebih proporsional dengan lebar baru
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppStyle.bgLightBlue,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded, 
                color: AppStyle.primaryBlue, 
                size: 45
              ),
            ),
            const SizedBox(height: 28),
            
            Text(
              "Kas Awal",
              style: AppStyle.titleText.copyWith(fontSize: 30), 
            ),
            const SizedBox(height: 12),
            Text(
              "Masukkan saldo awal di laci kasir untuk pencatatan transaksi yang akurat.",
              textAlign: TextAlign.center,
              style: AppStyle.subTitleText.copyWith(fontSize: 17, height: 1.5),
            ),
            const SizedBox(height: 40),
            
            // TextField yang lebih lebar dan tinggi
            TextField(
              controller: _cashController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: AppStyle.numPadText.copyWith(
                fontSize: 36, // Angka lebih besar karena area lebih luas
                color: AppStyle.textMain,
                letterSpacing: 2,
              ),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                filled: true,
                fillColor: AppStyle.bgLightBlue,
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(left: 30, right: 10),
                  child: Text("Rp", style: TextStyle(
                    fontSize: 22, 
                    fontWeight: FontWeight.w800, 
                    color: AppStyle.primaryBlue,
                    fontFamily: AppStyle.fontPoppins
                  )),
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 30),
              ),
              onChanged: (value) {
                if (value.isNotEmpty) {
                  String formatted = _formatNumber(value);
                  _cashController.value = TextEditingValue(
                    text: formatted,
                    selection: TextSelection.collapsed(offset: formatted.length),
                  );
                }
              },
            ),
            
            const SizedBox(height: 30),
            
            // Chip Pecahan dengan jarak yang lebih lega
            Wrap(
              spacing: 15,
              runSpacing: 15,
              alignment: WrapAlignment.center,
              children: _quickAmounts.map((amount) {
                return ActionChip(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  label: Text(
                    "Rp ${_formatNumber(amount.toString())}",
                    style: AppStyle.numPadText.copyWith(fontSize: 16, color: AppStyle.primaryBlue),
                  ),
                  backgroundColor: AppStyle.white,
                  side: BorderSide(color: AppStyle.primaryBlue.withOpacity(0.2), width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  onPressed: () {
                    setState(() {
                      _cashController.text = _formatNumber(amount.toString());
                    });
                  },
                );
              }).toList(),
            ),
            
            const SizedBox(height: 45),
            
            // Tombol Utama
            SizedBox(
              width: double.infinity,
              height: 70, 
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppStyle.primaryBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 0,
                ),
                onPressed: () {
                  if (_rawAmount > 0) {
                    Navigator.pop(context, _rawAmount);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Harap masukkan nominal kas awal."),
                        backgroundColor: AppStyle.errorRed,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                child: Text(
                  "BUKA KASIR SEKARANG",
                  style: AppStyle.buttonText.copyWith(fontSize: 20, letterSpacing: 1.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}