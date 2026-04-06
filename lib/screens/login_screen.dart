import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'main_navigation.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String _pin = '';
  final int _pinLength = 6;
  bool _isLoading = false;

  void _onNumPadTap(String value) {
    if (_isLoading) return;
    setState(() {
      if (value == 'clear') {
        _pin = '';
      } else if (value == 'delete') {
        if (_pin.isNotEmpty) {
          _pin = _pin.substring(0, _pin.length - 1);
        }
      } else {
        if (_pin.length < _pinLength) {
          _pin += value;
        }
      }
    });
  }

  void _verifyPin() async {
    if (_pin.length < _pinLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan 6 digit PIN'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 800));

    // PIN DEMO: 123456
    if (_pin == '123456') {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            // FIX: Tidak menggunakan 'const' agar tidak error
            builder: (context) => MainNavigationScaffold(requireCashInput: true),
          ),
        );
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _pin = '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PIN Salah! Gunakan 123456'), 
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F8FE),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 850),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: Colors.blue.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))
              ],
            ),
            child: Row(
              children: [
                // SISI KIRI: ILUSTRASI
                Expanded(
                  flex: 1,
                  child: Container(
                    padding: const EdgeInsets.all(40),
                    child: SvgPicture.asset('assets/images/login.svg', height: 250),
                  ),
                ),
                Container(width: 1, height: 400, color: Colors.grey.shade100),
                
                // SISI KANAN: FORM & NUMPAD
                Expanded(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 50),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text("Sign In", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, fontFamily: 'Poppins')),
                        const SizedBox(height: 5),
                        const Text("Masukkan 6 digit PIN akses", style: TextStyle(color: Colors.grey, fontSize: 13)),
                        const SizedBox(height: 35),

                        // INDIKATOR PIN (DOTS)
                        _buildPinDots(),
                        const SizedBox(height: 35),

                        // NUMPAD (INI YANG TADI HILANG)
                        _buildNumPad(),
                        const SizedBox(height: 35),

                        // TOMBOL LOGIN
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _verifyPin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4285F4),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            ),
                            child: _isLoading 
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('LOGIN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Poppins')),
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
          width: 14, height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled ? const Color(0xFF4285F4) : Colors.grey.shade100,
            border: Border.all(color: isFilled ? const Color(0xFF4285F4) : Colors.grey.shade300, width: 2),
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
          _numButton('1'), _numButton('2'), _numButton('3'),
          _numButton('4'), _numButton('5'), _numButton('6'),
          _numButton('7'), _numButton('8'), _numButton('9'),
          _actionButton('C', 'clear', const Color(0xFFFFEBEE), Colors.redAccent),
          _numButton('0'),
          _actionButton('<', 'delete', const Color(0xFFE3F2FD), const Color(0xFF4285F4)),
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
        child: Center(
          child: Text(number, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A1C1E))),
        ),
      ),
    );
  }

  Widget _actionButton(String label, String action, Color bgColor, Color textColor) {
    return InkWell(
      onTap: () => _onNumPadTap(action),
      borderRadius: BorderRadius.circular(15),
      child: Container(
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(15)),
        child: Center(
          child: label == '<' 
            ? Icon(Icons.backspace_outlined, color: textColor, size: 22)
            : Text(label, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
        ),
      ),
    );
  }
}