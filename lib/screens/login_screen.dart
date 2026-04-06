import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'main_navigation.dart';

// --- IMPORT SERVICE YANG DIBUTUHKAN ---
import '../services/storage_service.dart';
import '../services/api_service.dart';

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

 // --- LOGIKA UTAMA LOGIN API (VERSI FIX) ---
  void _verifyPin() async {
    // 1. Validasi awal: Pastikan PIN sudah 6 digit
    if (_pin.length < _pinLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Masukkan 6 digit PIN secara lengkap'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // --- BARIS DARURAT UNTUK TESTING ---
      // Karena belum ada menu Manager, kita paksa simpan Outlet ID = 1 ke memori HP
      await StorageService.saveOutletId(1); 

      // 2. Ambil Outlet ID dari memori
      final int? outletId = await StorageService.getOutletId();
      print("DEBUG: Menjalankan Login untuk Outlet ID: $outletId");

      if (outletId == null) {
        throw Exception("Outlet ID tidak ditemukan di memori perangkat.");
      }

      // 3. Panggil API ke api.etres.my.id
      final result = await ApiService.loginPin(_pin, outletId);

      if (!mounted) return;

      // 4. Cek Hasil Respon API
      if (result['success'] == true) {
        print("DEBUG: Login Berhasil!");
        
        // Pindah ke halaman utama
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const MainNavigationScaffold(requireCashInput: true),
          ),
        );
      } else {
        // Jika PIN Salah atau Error dari Server
        print("DEBUG: Login Gagal -> ${result['message']}");
        _handleLoginError(result['message']);
      }
    } catch (e) {
      print("DEBUG: Terjadi Error System -> $e");
      _handleLoginError("Terjadi kesalahan sistem atau koneksi: $e");
    }
  }

  // Helper untuk reset UI saat error
  void _handleLoginError(String message) {
    setState(() {
      _isLoading = false;
      _pin = ''; // Reset PIN agar kasir bisa input ulang
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // UI TETAP SAMA (Hanya bagian loading button yang sedikit diubah logicnya)
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

                        // NUMPAD
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

  // (Helper Widgets: _buildPinDots, _buildNumPad, dll, tetap dibiarkan seperti aslinya karena UI-nya sudah pas)
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