import 'package:flutter/material.dart';
import '../style.dart'; // Pastikan path import benar

class PrinterScreen extends StatelessWidget {
  const PrinterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyle.bgLightBlue, // Menggunakan Style
      appBar: AppBar(
        title: Text(
          "Koneksi Printer", 
          style: AppStyle.menuText.copyWith(color: Colors.white, fontWeight: FontWeight.bold)
        ),
        backgroundColor: AppStyle.primaryBlue, // Menggunakan Style
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(30),
          margin: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: AppStyle.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05), 
                blurRadius: 15, 
                offset: const Offset(0, 5)
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.bluetooth_searching, 
                size: 80, 
                color: AppStyle.primaryBlue
              ),
              const SizedBox(height: 25),
              Text(
                "Mencari Perangkat...",
                style: AppStyle.menuText.copyWith(
                  fontSize: 18, 
                  fontWeight: FontWeight.bold
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Pastikan Bluetooth printer Anda sudah menyala dan dalam jangkauan",
                textAlign: TextAlign.center,
                style: AppStyle.subTitleText, // Mengganti hintText ke subTitleText
              ),
              const SizedBox(height: 35),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppStyle.primaryBlue,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)
                    ),
                  ),
                  onPressed: () {
                    // Logika Scan Ulang
                  }, 
                  child: Text(
                    "Scan Ulang", 
                    style: AppStyle.buttonText
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