import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'main_navigation.dart'; // Pastikan file ini ada sesuai kode asli Anda

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // --- STATE UNTUK PIN ---
  String _pin = '';
  final int _pinLength = 4;
  final String _correctPin = '1234'; // PIN Dummy untuk testing

  void _onNumPadTap(String value) {
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

  void _verifyPin() {
    if (_pin.length < _pinLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan masukkan 4 digit PIN', style: TextStyle(fontFamily: 'Poppins')),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_pin == _correctPin) {
      // Masuk ke Main Navigation (Sesuai kode asli Anda)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainNavigationScaffold()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PIN Salah! Silakan coba lagi.', style: TextStyle(fontFamily: 'Poppins')),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() {
        _pin = ''; // Reset PIN jika salah
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F8FE), 
      body: LayoutBuilder(
        builder: (context, constraints) {
          bool isMobile = constraints.maxWidth < 800;
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: isMobile ? _buildMobileLayout() : _buildWebLayout(constraints),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWebLayout(BoxConstraints constraints) {
    return Row(
      children: [
        // Sisi Ilustrasi (Kiri)
        Expanded(
          flex: 1,
          child: SvgPicture.asset(
            'assets/images/login.svg', // Pastikan asset ini sudah ada
            height: constraints.maxHeight * 0.4,
          ),
        ),
        // Sisi Form dengan Card (Kanan)
        Expanded(
          flex: 1,
          child: _buildPinForm(false),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        SvgPicture.asset('assets/images/login.svg', height: 200),
        const SizedBox(height: 30),
        _buildPinForm(true),
      ],
    );
  }

  Widget _buildPinForm(bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center, // Diubah ke center agar Numpad rapi
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Sign In',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              fontFamily: 'Poppins',
              color: Color(0xFF1A1C1E),
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Welcome back! Please enter your PIN.',
            style: TextStyle(color: Colors.grey, fontSize: 14, fontFamily: 'Poppins'),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),

          // --- INDIKATOR PIN (TITIK) ---
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_pinLength, (index) {
              bool isFilled = index < _pin.length;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFilled ? Colors.blue.shade700 : Colors.grey.shade100,
                  border: Border.all(
                    color: isFilled ? Colors.blue.shade700 : Colors.grey.shade300,
                    width: 2,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 30),

          // --- NUMPAD ---
          _buildNumPad(),
          const SizedBox(height: 30),

          // --- TOMBOL LOGIN ---
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _verifyPin, // Harus diklik untuk verifikasi
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Login to Account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Poppins')),
            ),
          ),
        ],
      ),
    );
  }

  // Desain Grid Angka (Numpad)
  Widget _buildNumPad() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 300), // Membatasi lebar Numpad agar proporsional
      child: GridView.count(
        shrinkWrap: true,
        crossAxisCount: 3,
        mainAxisSpacing: 15,
        crossAxisSpacing: 15,
        childAspectRatio: 1.3, // Menyesuaikan tinggi tombol
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _numButton('1'), _numButton('2'), _numButton('3'),
          _numButton('4'), _numButton('5'), _numButton('6'),
          _numButton('7'), _numButton('8'), _numButton('9'),
          _actionButton('C', 'clear', Colors.red.shade50, Colors.red),
          _numButton('0'),
          _actionButton('<', 'delete', Colors.blue.shade50, Colors.blue),
        ],
      ),
    );
  }

  Widget _numButton(String number) {
    return InkWell(
      onTap: () => _onNumPadTap(number),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Center(
          child: Text(
            number,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'JetBrains', color: Color(0xFF1A1C1E)),
          ),
        ),
      ),
    );
  }

  Widget _actionButton(String label, String action, Color bgColor, Color textColor) {
    return InkWell(
      onTap: () => _onNumPadTap(action),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: textColor.withOpacity(0.1)),
        ),
        child: Center(
          child: label == '<' 
            ? Icon(Icons.backspace_outlined, color: textColor, size: 22)
            : Text(label, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor, fontFamily: 'Poppins')),
        ),
      ),
    );
  }
}