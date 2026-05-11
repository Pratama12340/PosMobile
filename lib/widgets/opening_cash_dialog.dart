import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/style.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart';

class OpeningCashDialog extends StatefulWidget {
  const OpeningCashDialog({super.key});

  @override
  State<OpeningCashDialog> createState() => _OpeningCashDialogState();
}

class _OpeningCashDialogState extends State<OpeningCashDialog> {
  final TextEditingController _cashController = TextEditingController();
  final List<int> _quickAmounts = [50000, 100000, 200000, 500000];

  bool _isSaving = false;
  String? _errorMessage;

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
              color: Colors.black.withValues(alpha: 0.08),
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
                    if (_errorMessage != null)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red.shade700,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

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
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(left: 30, right: 10),
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
                        suffixIcon: const SizedBox(width: 65),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 20,
                        ),
                      ),
                      onChanged: (value) {
                        if (_errorMessage != null) {
                          setState(() => _errorMessage = null);
                        }

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
                            color: AppStyle.primaryBlue.withValues(alpha: 0.2),
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          onPressed: _isSaving
                              ? null
                              : () {
                                  setState(() {
                                    if (_errorMessage != null) {
                                      _errorMessage = null;
                                    }
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
                          debugPrint("\n[DIALOG] Memulai proses Buka Kasir...");
                          debugPrint("[DIALOG] Nominal Kas Awal: $_rawAmount");

                          setState(() {
                            _isSaving = true;
                            _errorMessage = null;
                          });

                          final navigator = Navigator.of(context);

                          try {
                            final int outletId =
                                await StorageService.getOutletId() ?? 0;
                            final apiResponse = await ApiService.startShift(
                              _rawAmount,
                              outletId,
                            );

                            if (!mounted) return;

                            if (apiResponse['success'] == true) {
                              debugPrint(
                                "✔ Berhasil menyimpan Kas Awal ke Server Database.",
                              );

                              await StorageService.saveOpeningCash(
                                _rawAmount.toDouble(),
                              );
                              await StorageService.saveShiftStatus(true);

                              DateTime now = DateTime.now();
                              String exactStartTime =
                                  "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
                              await StorageService.saveLoginTime(
                                exactStartTime,
                              );

                              debugPrint(
                                "✔ Berhasil menandai status Shift Lokal: AKTIF mulai jam $exactStartTime.",
                              );
                              debugPrint(
                                "[DIALOG] Proses Selesai. Menutup dialog...\n",
                              );

                              if (!mounted) return;
                              navigator.pop();
                            } else {
                              setState(() {
                                _isSaving = false;
                                _errorMessage =
                                    apiResponse['message'] ??
                                    "Gagal menyimpan kas awal di server.";
                              });
                              debugPrint("❌ GAGAL: ${apiResponse['message']}");
                            }
                          } catch (e) {
                            if (mounted) {
                              setState(() {
                                _isSaving = false;
                                _errorMessage =
                                    "Terjadi kesalahan koneksi jaringan.";
                              });
                            }
                            debugPrint("❌ ERROR pada OpeningCashDialog: $e");
                          }
                        } else {
                          debugPrint("⚠️ WARNING: Form Kas Awal masih kosong.");
                          setState(() {
                            _errorMessage = "Harap masukkan nominal kas awal.";
                          });
                        }
                      },
                child: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
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
