import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/style.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../screens/login_screen.dart';

class ClosingCashDialog extends StatefulWidget {
  const ClosingCashDialog({super.key});

  @override
  State<ClosingCashDialog> createState() => _ClosingCashDialogState();
}

class _ClosingCashDialogState extends State<ClosingCashDialog> {
  final TextEditingController _actualCashController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  int get _rawAmount {
    String clean = _actualCashController.text.replaceAll('.', '');
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

  Future<void> _processClosing() async {
    if (_actualCashController.text.isEmpty || _rawAmount <= 0) {
      setState(
        () => _errorMessage = "Harap masukkan total uang fisik di laci.",
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await ApiService.endShift(
        _rawAmount,
        _notesController.text,
      );

      if (result['success']) {
        await StorageService.tutupKasir();
        if (mounted) {
          Navigator.pop(context);
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = result['message'] ?? "Gagal tutup shift";
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Terjadi kesalahan koneksi: $e";
        });
      }
    }
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
          color: Colors.white,
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
                Icons.lock_reset_rounded,
                color: AppStyle.primaryBlue,
                size: 45,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "Tutup Shift",
              style: AppStyle.titleText.copyWith(fontSize: 28),
            ),
            const SizedBox(height: 10),
            Text(
              "Hitung semua uang fisik di laci dan masukkan totalnya di bawah ini untuk mengakhiri shift.",
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
                      controller: _actualCashController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      enabled: !_isLoading,
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
                          _actualCashController.value = TextEditingValue(
                            text: formatted,
                            selection: TextSelection.collapsed(
                              offset: formatted.length,
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _notesController,
                      maxLines: 2,
                      enabled: !_isLoading,
                      decoration: InputDecoration(
                        hintText: "Tambahkan catatan (opsional)...",
                        hintStyle: const TextStyle(fontSize: 14),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                      onChanged: (value) {
                        if (_errorMessage != null) {
                          setState(() => _errorMessage = null);
                        }
                      },
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
                onPressed: _isLoading ? null : _processClosing,
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                    : const Text(
                        "TUTUP SHIFT SEKARANG",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _isLoading ? null : () => Navigator.pop(context),
              child: const Text(
                "Batal",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
