import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart'; 
import 'screens/splash_screen.dart';

void main() async {
  // BARIS INI WAJIB DITAMBAHKAN
  // Sebagai jembatan agar SharedPreferences dan API bisa berjalan sebelum UI muncul
  WidgetsFlutterBinding.ensureInitialized();

  // 👇 --- FIX LOCALE DATA EXCEPTION --- 👇
  // Inisialisasi format tanggal Indonesia agar bisa dipakai di seluruh aplikasi
  await initializeDateFormatting('id_ID', null);
  // 👆 --------------------------------- 👆

  // 👇 --- TRIK SAPU BERSIH (HANYA JIKA PERLU) --- 👇
  // final prefs = await SharedPreferences.getInstance();
  // await prefs.clear(); 
  // 👆 ------------------------------------------- 👆

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Aranus POS',
      theme: ThemeData(
        // Menyesuaikan dengan preferensi desain modern Anda (Blue/White)
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4285F4)),
        useMaterial3: true,
        fontFamily: 'Poppins', // Menetapkan Poppins sebagai font default
      ),
      // PINTU MASUK KE SPLASH SCREEN
      home: const SplashScreen(),
    );
  }
}