import 'package:flutter/material.dart';
import 'screens/login_screen.dart'; 

void main() {
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
      // Jika kamu pakai MainNavigationScaffold(), maka import login_screen akan kuning.
      home: const LoginScreen(), 
    );
  }
}