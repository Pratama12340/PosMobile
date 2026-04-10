import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Dibutuhkan jika ingin pakai sapu bersih
import 'screens/splash_screen.dart'; // 👇 1. IMPORT SPLASH SCREEN

void main() async {
  // BARIS INI WAJIB DITAMBAHKAN
  // Sebagai jembatan agar SharedPreferences dan API bisa berjalan sebelum UI muncul
  WidgetsFlutterBinding.ensureInitialized();

  // 👇 --- TRIK SAPU BERSIH (HANYA JIKA PERLU) --- 👇
  // Jika aplikasimu masih nyangkut di Login dan error merah, 
  // hapus tanda "//" di 2 baris bawah ini, lakukan Hot Restart, lalu beri tanda "//" lagi.
  
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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      // 👇 2. UBAH PINTU MASUKNYA KE SPLASH SCREEN
      home: const SplashScreen(),
    );
  }
}