import 'package:flutter/material.dart';
import 'login_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // KITA HARUS MENGEMBALIKAN MaterialApp DI SINI
    return MaterialApp(
      title: 'Aranus PoS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      // --- PANGGIL HALAMAN UTAMANYA DI DALAM 'home' ---
      home: const LoginScreen(),
    );
  }
}