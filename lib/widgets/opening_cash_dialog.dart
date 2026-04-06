import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OpeningCashDialog extends StatefulWidget {
  const OpeningCashDialog({super.key});

  @override
  State<OpeningCashDialog> createState() => _OpeningCashDialogState();
}

class _OpeningCashDialogState extends State<OpeningCashDialog> {
  final TextEditingController _cashController = TextEditingController();
  final List<int> _quickAmounts = [50000, 100000, 200000, 500000];

  // Logic untuk mengambil angka murni dari string format ribuan
  int get _rawAmount {
    String clean = _cashController.text.replaceAll('.', '');
    return int.tryParse(clean) ?? 0;
  }

  String _formatNumber(String s) {
    if (s.isEmpty) return "";
    return s.replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.');
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white, // Sesuaikan dengan AppStyle.bgLightBlue jika mau
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Kas Awal", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text("Masukkan saldo awal laci kasir.", textAlign: TextAlign.center),
            const SizedBox(height: 24),
            TextField(
              controller: _cashController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                filled: true,
                prefixText: "Rp ",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
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
            const SizedBox(height: 20),
            // Pecahan Cepat
            Wrap(
              spacing: 10,
              children: _quickAmounts.map((amount) {
                return ActionChip(
                  label: Text("Rp ${_formatNumber(amount.toString())}"),
                  onPressed: () {
                    setState(() {
                      _cashController.text = _formatNumber(amount.toString());
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                onPressed: () {
                  if (_rawAmount > 0) {
                    // PENTING: Kirim _rawAmount kembali ke pemanggil
                    Navigator.pop(context, _rawAmount); 
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Masukkan nominal dulu!")),
                    );
                  }
                },
                child: const Text("Buka Kasir", style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}