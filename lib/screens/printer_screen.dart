import 'package:flutter/material.dart';
import '../style.dart';

class PrinterScreen extends StatelessWidget {
  const PrinterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyle.bgLightBlue,
      appBar: AppBar(
        title: Text("Koneksi Printer", style: AppStyle.labelText.copyWith(color: Colors.white)),
        backgroundColor: const Color(0xFF4285F4),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(30),
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bluetooth_searching, size: 64, color: Color(0xFF4285F4)),
              const SizedBox(height: 20),
              Text(
                "Mencari Perangkat...",
                style: AppStyle.labelText,
              ),
              const SizedBox(height: 8),
              const Text(
                "Pastikan Bluetooth printer Anda sudah menyala",
                textAlign: TextAlign.center,
                style: AppStyle.hintText,
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4285F4),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {}, 
                  child: Text(
                    "Scan Ulang", 
                    style: AppStyle.buttonText.copyWith(color: Colors.white)
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}