import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../style.dart';
import '../services/storage_service.dart'; 

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
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isTablet = screenWidth > 600;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: isTablet ? screenWidth * 0.55 : 450,
        constraints: const BoxConstraints(maxWidth: 650, maxHeight: 750), 
        padding: const EdgeInsets.all(35),
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
            // 1. Icon & Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppStyle.bgLightBlue,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                color: AppStyle.primaryBlue,
                size: 45,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "Kas Awal",
              style: AppStyle.titleText.copyWith(fontSize: 28),
            ),
            const SizedBox(height: 10),
            Text(
              "Masukkan saldo awal di laci kasir untuk pencatatan transaksi yang akurat.",
              textAlign: TextAlign.center,
              style: AppStyle.subTitleText.copyWith(fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 30),

            // 2. Input Area
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _cashController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: AppStyle.numPadText.copyWith(
                        fontSize: 34,
                        color: AppStyle.textMain,
                        letterSpacing: 2,
                      ),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppStyle.bgLightBlue,
                        prefixIcon: Padding(
                          padding: const EdgeInsets.only(left: 30, right: 10),
                          child: Text(
                            "Rp",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppStyle.primaryBlue,
                              fontFamily: AppStyle.fontPoppins,
                            ),
                          ),
                        ),
                        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 20), 
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
                    const SizedBox(height: 25),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: _quickAmounts.map((amount) {
                        return ActionChip(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          label: Text(
                            "Rp ${_formatNumber(amount.toString())}",
                            style: AppStyle.numPadText.copyWith(
                              fontSize: 16,
                              color: AppStyle.primaryBlue,
                            ),
                          ),
                          backgroundColor: AppStyle.white,
                          side: BorderSide(
                            color: AppStyle.primaryBlue.withOpacity(0.2),
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          onPressed: () {
                            setState(() {
                              _cashController.text = _formatNumber(amount.toString());
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),

            // 3. Action Button (Di sini perubahan utamanya)
            SizedBox(
              width: double.infinity,
              height: 65,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppStyle.primaryBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 0,
                ),
                onPressed: () async {
                  if (_rawAmount > 0) {
                    // SINKRONISASI: Simpan data ke memori permanen sebelum menutup dialog
                    await StorageService.saveOpeningCash(_rawAmount);
                    
                    if (!mounted) return;
                    Navigator.pop(context);
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
                  style: AppStyle.buttonText.copyWith(
                    fontSize: 18,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}