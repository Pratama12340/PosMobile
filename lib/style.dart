import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // <--- Tambahkan ini agar NumberFormat terbaca

class AppStyle {
  // --- WARNA UTAMA ---
  static const Color primaryBlue = Color(0xFF4285F4);

  // Tambahkan baris ini (Penting! Agar error di baris 101 hilang)
  static const Color bgLightBlue = Color(0xFFF3F8FE);

  // Tambahkan baris ini (Penting! Agar error di baris 92 hilang)
  static const Color errorRed = Colors.redAccent;

  static const Color textMain = Color(0xFF1A1C1E);
  static const Color textGrey = Color(0xFF757575);
  static const Color white = Colors.white;

  // --- FONT FAMILY ---
  static const String fontPoppins = 'Poppins';
  static const String fontNumbers = 'JetBrains';

  // --- TEXT STYLES ---
  static const TextStyle titleText = TextStyle(
    fontFamily: fontPoppins,
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: textMain,
  );

  static const TextStyle subTitleText = TextStyle(
    fontFamily: fontPoppins,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: textGrey,
  );

  static const TextStyle numPadText = TextStyle(
    fontFamily: fontNumbers,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: textMain,
  );

  static const TextStyle buttonText = TextStyle(
    fontFamily: fontPoppins,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: white,
  );

  // Tambahkan ini di dalam class AppStyle di file style.dart
  static const TextStyle menuText = TextStyle(
    fontFamily: fontPoppins,
    fontSize: 14,
    fontWeight: FontWeight.w500, // Medium
    color: textMain,
  );

  // Tambahkan ini di dalam class AppStyle (di file style.dart)
  static const TextStyle priceText = TextStyle(
    fontFamily: fontNumbers, // Menggunakan JetBrains
    fontSize: 14,
    fontWeight: FontWeight.w800, // ExtraBold
    color: primaryBlue,
  );

  // Fungsi untuk memformat angka ke Rupiah dengan titik
  String formatHarga(double price) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(price);
  }
}
