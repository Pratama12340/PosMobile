import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
  
  String _outletName = "Loading...";
  int _outletId = 0;

  @override
  void initState() {
    super.initState();
    _loadOutletData();
  }

  Future<void> _loadOutletData() async {
    final id = await StorageService.getOutletId();
    final name = await StorageService.getOutletName();
    
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
        _outletName = name;
      });
    }
  }

  void _onNumPadTap(String value) {
    if (_isLoading) return;
    setState(() {
      if (value == 'clear') {
        _pin = '';
      } else if (value == 'delete') {
        if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
      } else {
        if (_pin.length < _pinLength) _pin += value;
      }
    });
  }

  void _verifyPin() async {
    if (_pin.length < _pinLength) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Masukkan 6 digit PIN')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await ApiService.loginPin(_pin, _outletId);

      if (!mounted) return;

      if (result['success'] == true) {
        // --- AWAL BAGIAN SINGKRONISASI ---
        String nameFromServer = result['data']['user']['name'] ?? "Cashier";
        
        // Mengambil waktu login saat ini
        DateTime now = DateTime.now();
        String loginTime = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

        // Menyimpan ke Storage
        await StorageService.saveCashierName(nameFromServer);
        await StorageService.saveLoginTime(loginTime); 
        // --- AKHIR BAGIAN SINGKRONISASI ---
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainNavigationScaffold(requireCashInput: true)),
        );
      } else {
        _handleLoginError(result['message']);
      }
    } catch (e) {
      _handleLoginError("Koneksi bermasalah: $e");
    }
  }

  void _handleLoginError(String message) {
    setState(() { _isLoading = false; _pin = ''; });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: AppStyle.errorRed));
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
                    child: SvgPicture.asset('assets/images/login.svg', height: 250),
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
                        Text("Sign In", style: AppStyle.titleText),
                        const SizedBox(height: 5),
                        Text("Masukkan 6 digit PIN akses", style: AppStyle.subTitleText), 
                        const SizedBox(height: 15),

                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppStyle.primaryBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.storefront, size: 16, color: AppStyle.primaryBlue),
                              const SizedBox(width: 8),
                              Text(_outletName, style: const TextStyle(color: AppStyle.primaryBlue, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 25),

                        _buildPinDots(),
                        const SizedBox(height: 35),
                        _buildNumPad(),
                        const SizedBox(height: 35),

                        SizedBox(
                          width: double.infinity, height: 54,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _verifyPin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppStyle.primaryBlue,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            ),
                            child: _isLoading 
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('LOGIN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), 
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
      onTap: () => _onNumPadTap(number), borderRadius: BorderRadius.circular(15),
      child: Container(
        decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)),
        child: Center(child: Text(number, style: AppStyle.numPadText)), 
      ),
    );
  }

  Widget _actionButton(String label, String action, Color bgColor, Color textColor) {
    return InkWell(
      onTap: () => _onNumPadTap(action), borderRadius: BorderRadius.circular(15),
      child: Container(
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(15)),
        child: Center(child: label == '<' ? Icon(Icons.backspace_outlined, color: textColor, size: 22) : Text(label, style: AppStyle.numPadText.copyWith(color: textColor))), 
      ),
    );
  }
}