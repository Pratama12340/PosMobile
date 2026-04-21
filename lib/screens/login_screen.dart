import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart'; // TAMBAHAN IMPORT
import 'main_navigation.dart';
import '../style.dart';
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
          MaterialPageRoute(builder: (context) => const OutletSelectionScreen()),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Reset Outlet?", style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text("Data outlet akan dihapus. Anda harus memilih outlet kembali."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("BATAL", style: TextStyle(color: Colors.grey.shade600)),
            ),
            ElevatedButton(
              onPressed: () async {
                await StorageService.saveOutletId(0);
                if (mounted) {
                  Navigator.pop(context);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const OutletSelectionScreen()),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text("YA, RESET", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _onNumPadTap(String value) {
    if (_isLoading) return;
    setState(() {
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
        final userFromServer = result['data']['user'];
        final int userOutletId = int.tryParse(userFromServer['outlet_id'].toString()) ?? 0;

        print("--- AUDIT KEAMANAN LOGIN ---");
        print("Cabang pilihan App: $_outletId");
        print("Cabang asli User di DB: $userOutletId");

        // Validasi Cabang
        if (userOutletId != _outletId) {
          _handleLoginError("Akses Ditolak: Akun Anda terdaftar di Cabang lain.");
          return; 
        }

        // =============================================================
        // LOGIKA BYPASS KAS AWAL (DIPERBAIKI SECARA PERMANEN)
        // =============================================================
        final String? oldShiftId = await StorageService.getCurrentShiftId();
        final String? newShiftId = result['data']['shift_id']?.toString();
        
        // Menggunakan ID Karyawan untuk mendeteksi orang yang berbeda
        // Ini menghindari bug memori terhapus saat karyawan klik tombol "Logout"
        final prefs = await SharedPreferences.getInstance();
        final int lastUserId = prefs.getInt('last_shift_user_id') ?? 0;
        final int currentUserId = int.tryParse(userFromServer['id'].toString()) ?? 0;

        bool isKasirOpened = await StorageService.getShiftStatus() ?? false;

        // 🌟 PERBAIKAN 1: Jika Shift-nya beda ATAU ID User-nya beda -> Wajib isi Kas Awal lagi!
        if (oldShiftId != newShiftId || lastUserId != currentUserId) {
            print("🔄 Shift atau Karyawan baru terdeteksi. Mereset status kasir...");
            isKasirOpened = false;
            await StorageService.saveShiftStatus(false);
        } else {
            if (isKasirOpened) print("⏩ Kasir sudah dibuka di shift ini. Bypass Kas Awal.");
        }

        // Simpan ID User yang berhasil login untuk pengecekan berikutnya
        await prefs.setInt('last_shift_user_id', currentUserId);
        // =============================================================

        // Simpan Token di memori
        final String? tokenFromServer = result['data']['token'];
        if (tokenFromServer != null) {
          await StorageService.saveToken(tokenFromServer);
          print("🔑 Token Akses Berhasil Disimpan!");
        }

        // 🌟 PERBAIKAN 2: Cegah penimpaan Waktu Start Shift
        // Jika sedang bypass, JANGAN simpan ulang waktu login,
        // agar waktu awal shift tidak rusak.
        if (!isKasirOpened) {
          DateTime now = DateTime.now();
          String loginTime = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
          await StorageService.saveLoginTime(loginTime);
        }

        final String newCashierName = userFromServer['name'] ?? "Cashier";
        await StorageService.saveCashierName(newCashierName);

        // Jika berhasil mendapat shift_id, pastikan kita simpan juga ke Storage
        if (newShiftId != null) {
          await StorageService.saveCurrentShiftId(newShiftId);
        }

        String liveOutletName = await ApiService.fetchOutletNameLive();
        await StorageService.saveOutletName(liveOutletName);

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => MainNavigationScaffold(requireCashInput: !isKasirOpened)),
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
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppStyle.errorRed),
      );
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
              boxShadow: [BoxShadow(color: AppStyle.primaryBlue.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Container(
                    padding: const EdgeInsets.all(40),
                    child: SvgPicture.asset('assets/images/login.svg', height: 320),
                  ),
                ),
                Container(width: 1, height: 400, color: Colors.grey.shade100),
                Expanded(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 50),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onLongPress: _showResetOutletDialog,
                          child: Text("Sign In", style: AppStyle.titleText.copyWith(color: AppStyle.primaryBlue)),
                        ),
                        const SizedBox(height: 5),
                        Text("Masukkan 6 digit PIN akses", style: AppStyle.subTitleText),
                        const SizedBox(height: 35),
                        
                        SizedBox(
                          height: 30, 
                          child: _isLoading
                              ? const Center(
                                  child: SizedBox(
                                    width: 24, 
                                    height: 24, 
                                    child: CircularProgressIndicator(strokeWidth: 2)
                                  ),
                                )
                              : _buildPinDots(),
                        ),

                        const SizedBox(height: 35),
                        _buildNumPad(),
                        const SizedBox(height: 20),
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
            color: isFilled ? AppStyle.primaryBlue : Colors.grey.shade100,
            border: Border.all(color: isFilled ? AppStyle.primaryBlue : Colors.grey.shade300, width: 2),
          ),
        );
      }),
    );
  }

  Widget _buildNumPad() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      child: GridView.count(
        shrinkWrap: true, crossAxisCount: 3, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.4,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _numButton('1'), _numButton('2'), _numButton('3'),
          _numButton('4'), _numButton('5'), _numButton('6'),
          _numButton('7'), _numButton('8'), _numButton('9'),
          _actionButton('C', 'clear', const Color(0xFFFFEBEE), Colors.redAccent),
          _numButton('0'),
          _actionButton('<', 'delete', const Color(0xFFE3F2FD), AppStyle.primaryBlue),
        ],
      ),
    );
  }

  Widget _numButton(String number) {
    return InkWell(
      onTap: () => _onNumPadTap(number),
      borderRadius: BorderRadius.circular(15),
      child: Container(
        decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)),
        child: Center(child: Text(number, style: AppStyle.numPadText)),
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
              : Text(label, style: AppStyle.numPadText.copyWith(color: textColor)),
        ),
      ),
    );
  }
}