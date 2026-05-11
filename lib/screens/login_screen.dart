import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'main_navigation.dart';
import '../constants/style.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart';
import 'outlet_selection_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String _pin = '';
  final int _pinLength = 6;
  bool _isLoading = false;
  int _outletId = 0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadOutletData();
  }

  Future<void> _loadOutletData() async {
    await Future.delayed(const Duration(milliseconds: 100));
    final id = await StorageService.getOutletId();

    if (id == null || id == 0) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const OutletSelectionScreen(),
          ),
        );
      }
      return;
    }

    if (mounted) {
      setState(() {
        _outletId = id;
      });
    }
  }

  void _showResetOutletDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            "Reset Outlet?",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            "Data outlet akan dihapus. Anda harus memilih outlet kembali.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "BATAL",
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final navigator = Navigator.of(context);

                await StorageService.saveOutletId(0);

                if (!mounted) return;
                navigator.pop();
                navigator.pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => const OutletSelectionScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              child: const Text(
                "YA, RESET",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _onNumPadTap(String value) {
    if (_isLoading) return;
    setState(() {
      if (_errorMessage != null) {
        _errorMessage = null;
      }

      if (value == 'clear') {
        _pin = '';
      } else if (value == 'delete') {
        if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
      } else {
        if (_pin.length < _pinLength) {
          _pin += value;
          if (_pin.length == _pinLength) {
            _verifyPin();
          }
        }
      }
    });
  }

  void _verifyPin() async {
    setState(() => _isLoading = true);

    try {
      final currentId = await StorageService.getOutletId();
      if (currentId == null || currentId == 0) {
        _handleLoginError("ID Outlet tidak valid. Silakan reset.");
        return;
      }

      _outletId = currentId;

      final result = await ApiService.loginPin(_pin, _outletId);

      if (!mounted) return;

      if (result['success'] == true) {
        final bool isKasirOpened = result['data']['opening_balance'] != null;

        if (!isKasirOpened) {
          DateTime now = DateTime.now();
          String loginTime =
              "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
          await StorageService.saveLoginTime(loginTime);
        }

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  MainNavigationScaffold(requireCashInput: !isKasirOpened),
            ),
          );
        }
      } else {
        _handleLoginError(result['message'] ?? "PIN Salah");
      }
    } catch (e) {
      _handleLoginError("Koneksi bermasalah: $e");
    }
  }

  void _handleLoginError(String message) {
    if (mounted) {
      setState(() {
        _isLoading = false;
        _pin = '';
        _errorMessage = message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyle.bgLightBlue,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 850),
            decoration: BoxDecoration(
              color: AppStyle.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Container(
                    padding: const EdgeInsets.all(40),
                    child: SvgPicture.asset(
                      'assets/images/login.svg',
                      height: 320,
                    ),
                  ),
                ),
                Container(width: 1, height: 400, color: Colors.grey.shade100),
                Expanded(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 50,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Sign In",
                          style: AppStyle.titleText.copyWith(
                            color: AppStyle.primaryBlue,
                          ),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          "Masukkan 6 digit PIN akses",
                          style: AppStyle.subTitleText,
                        ),

                        SizedBox(height: _errorMessage != null ? 15 : 25),

                        if (_errorMessage != null)
                          Container(
                            width: 280,
                            margin: const EdgeInsets.only(bottom: 15),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: Colors.red.shade700,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontSize: 12,
                                      height: 1.2,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        SizedBox(
                          height: 30,
                          child: _isLoading
                              ? const Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : _buildPinDots(),
                        ),

                        const SizedBox(height: 30),
                        _buildNumPad(),

                        const SizedBox(height: 15),
                        TextButton(
                          onPressed: _showResetOutletDialog,
                          child: const Text(
                            "Ganti Outlet?",
                            style: TextStyle(
                              color: Color.fromARGB(255, 20, 20, 20),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPinDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_pinLength, (index) {
        bool isFilled = index < _pin.length;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled ? AppStyle.primaryBlue : Colors.grey.shade100,
            border: Border.all(
              color: isFilled ? AppStyle.primaryBlue : Colors.grey.shade300,
              width: 2,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildNumPad() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      child: GridView.count(
        shrinkWrap: true,
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.4,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _numButton('1'),
          _numButton('2'),
          _numButton('3'),
          _numButton('4'),
          _numButton('5'),
          _numButton('6'),
          _numButton('7'),
          _numButton('8'),
          _numButton('9'),
          _actionButton(
            'C',
            'clear',
            const Color(0xFFFFEBEE),
            Colors.redAccent,
          ),
          _numButton('0'),
          _actionButton(
            '<',
            'delete',
            const Color(0xFFE3F2FD),
            AppStyle.primaryBlue,
          ),
        ],
      ),
    );
  }

  Widget _numButton(String number) {
    return InkWell(
      onTap: () => _onNumPadTap(number),
      borderRadius: BorderRadius.circular(15),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Center(child: Text(number, style: AppStyle.numPadText)),
      ),
    );
  }

  Widget _actionButton(
    String label,
    String action,
    Color bgColor,
    Color textColor,
  ) {
    return InkWell(
      onTap: () => _onNumPadTap(action),
      borderRadius: BorderRadius.circular(15),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Center(
          child: label == '<'
              ? Icon(Icons.backspace_outlined, color: textColor, size: 22)
              : Text(
                  label,
                  style: AppStyle.numPadText.copyWith(color: textColor),
                ),
        ),
      ),
    );
  }
}
