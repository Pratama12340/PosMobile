import 'package:flutter/material.dart';
import 'screens/login_screen.dart';

void main() {
  // BARIS INI WAJIB DITAMBAHKAN
  // Sebagai jembatan agar SharedPreferences dan API bisa berjalan sebelum UI muncul
  WidgetsFlutterBinding.ensureInitialized();

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
      // --- PERHATIKAN DI SINI ---
      // Jika kamu pakai LoginScreen(), maka import main_navigation akan kuning (unused).
      // Biarkan saja kuning, itu wajar dan tidak menyebabkan error (hanya peringatan file tidak dipakai di halaman ini).
      home: const LoginScreen(),
    );
  }
}
