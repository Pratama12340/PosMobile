import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../style.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart'; // TAMBAHAN: Import ApiService

class OpeningCashDialog extends StatefulWidget {
  const OpeningCashDialog({super.key});

  @override
  State<OpeningCashDialog> createState() => _OpeningCashDialogState();
}

class _OpeningCashDialogState extends State<OpeningCashDialog> {
  final TextEditingController _cashController = TextEditingController();
  final List<int> _quickAmounts = [50000, 100000, 200000, 500000];

  bool _isSaving = false;

  int get _rawAmount {
    String clean = _cashController.text.replaceAll('.', '');
    return int.tryParse(clean) ?? 0;
  }

  String _formatNumber(String s) {
    if (s.isEmpty) return "";
    String clean = s.replaceAll('.', '');
    return clean.replaceAllMapped(
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
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
            Text("Kas Awal", style: AppStyle.titleText.copyWith(fontSize: 28)),
            const SizedBox(height: 10),
            Text(
              "Masukkan saldo awal di laci kasir untuk pencatatan transaksi yang akurat.",
              textAlign: TextAlign.center,
              style: AppStyle.subTitleText.copyWith(fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 30),

            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _cashController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      enabled: !_isSaving,
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
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 0,
                          minHeight: 0,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 20,
                        ),
                      ),
                      onChanged: (value) {
                        if (value.isNotEmpty) {
                          String formatted = _formatNumber(value);
                          _cashController.value = TextEditingValue(
                            text: formatted,
                            selection: TextSelection.collapsed(
                              offset: formatted.length,
                            ),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          onPressed: _isSaving
                              ? null
                              : () {
                                  setState(() {
                                    _cashController.text = _formatNumber(
                                      amount.toString(),
                                    );
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

            SizedBox(
              width: double.infinity,
              height: 65,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppStyle.primaryBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 0,
                ),
                onPressed: _isSaving
                    ? null
                    : () async {
                        if (_cashController.text.isNotEmpty) {
                          print("\n[DIALOG] Memulai proses Buka Kasir...");
                          print("[DIALOG] Nominal Kas Awal: $_rawAmount");
                          
                          setState(() => _isSaving = true);
                          
                          try {
                            // 1. Ambil Outlet ID dari Storage
                            final int outletId = await StorageService.getOutletId() ?? 0;

                            // 2. Kirim Data Kas Awal ke Backend via API
                            // Pastikan di ApiService kunci yang digunakan adalah 'opening_balance'
                            final apiResponse = await ApiService.startShift(_rawAmount, outletId);
                            
                            if (!mounted) return;

                            if (apiResponse['success'] == true) {
                              print("✔ Berhasil menyimpan Kas Awal ke Server Database.");
                              
                              // 3. Simpan ke Local Storage untuk menandai kasir sudah dibuka
                              await StorageService.saveOpeningCash(_rawAmount.toDouble());
                              await StorageService.saveShiftStatus(true);
                              
                              // Catat Waktu Buka Kasir sebagai Awal Shift Aktual
                              DateTime now = DateTime.now();
                              String exactStartTime = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
                              await StorageService.saveLoginTime(exactStartTime);

                              print("✔ Berhasil menandai status Shift Lokal: AKTIF mulai jam $exactStartTime.");
                              print("[DIALOG] Proses Selesai. Menutup dialog...\n");
                              
                              Navigator.pop(context);
                            } else {
                              // Gagal di server (biasanya error 422 karena key tidak cocok)
                              setState(() => _isSaving = false);
                              print("❌ GAGAL: ${apiResponse['message']}");
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(apiResponse['message'] ?? "Gagal menyimpan kas awal di server."),
                                  backgroundColor: AppStyle.errorRed,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) setState(() => _isSaving = false);
                            print("❌ ERROR pada OpeningCashDialog: $e");
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Terjadi kesalahan koneksi jaringan."),
                                backgroundColor: AppStyle.errorRed,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        } else {
                          print("⚠️ WARNING: Form Kas Awal masih kosong.");
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Harap masukkan nominal kas awal."),
                              backgroundColor: AppStyle.errorRed,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                child: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                      )
                    : Text(
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