import 'package:flutter/material.dart';

class AppStyle {
  // --- KUMPULAN WARNA (COLORS) ---

  // Warna background halaman (biru sangat muda)
  static const Color bgLightBlue = Color.fromARGB(255, 227, 240, 245);

  // Warna kotak input email/password dan tombol (abu-abu muda)
  static const Color formGrey = Color(0xFFE2E2E2);

  // Warna teks utama
  static const Color textBlack = Color(0xFF111111);

  // Warna teks placeholder (seperti "Enter your email")
  static const Color textHint = Color(0xFF757575);

  // --- KUMPULAN GAYA TEKS (TEXT STYLES) ---

  // Gaya untuk judul "Welcome to Aranus PoS"
  static const TextStyle titleText = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 28,
    fontWeight: FontWeight.w800, // ExtraBold
    color: textBlack,
  );

  // Gaya untuk teks "Email" dan "Password"
  static const TextStyle labelText = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 16,
    fontWeight: FontWeight.w600, // SemiBold
    color: textBlack,
  );

  // Gaya untuk teks di dalam kotak input
  static const TextStyle hintText = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 14,
    fontWeight: FontWeight.w400, // Regular
    color: textHint,
  );

  // Gaya untuk teks di dalam tombol "Login"
  static const TextStyle buttonText = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 16,
    fontWeight: FontWeight.w700, // Bold
    color: textBlack,
  );
}
