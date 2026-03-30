import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'main_navigation.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isObscure = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Background biru pucat agar form putih terlihat "pop" (menonjol)
      backgroundColor: const Color(0xFFF3F8FE), 
      body: LayoutBuilder(
        builder: (context, constraints) {
          bool isMobile = constraints.maxWidth < 800;
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: isMobile ? _buildMobileLayout() : _buildWebLayout(constraints),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWebLayout(BoxConstraints constraints) {
    return Row(
      children: [
        // Sisi Ilustrasi
        Expanded(
          flex: 1,
          child: SvgPicture.asset(
            'assets/images/login.svg',
            height: constraints.maxHeight * 0.4,
          ),
        ),
        // Sisi Form dengan Card
        Expanded(
          flex: 1,
          child: _buildLoginForm(false),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        SvgPicture.asset('assets/images/login.svg', height: 200),
        const SizedBox(height: 30),
        _buildLoginForm(true),
      ],
    );
  }

  Widget _buildLoginForm(bool isMobile) {
    return Container(
      // --- EFEK KARTU ELEGAN ---
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Sign In',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                fontFamily: 'Poppins',
                color: Color(0xFF1A1C1E),
              ),
            ),
            const Text(
              'Welcome back! Please enter your details.',
              style: TextStyle(color: Colors.grey, fontSize: 14, fontFamily: 'Poppins'),
            ),
            const SizedBox(height: 40),

            // Input Email
            _buildLabel('Email Address'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _emailController,
              decoration: _inputDecoration('name@company.com', Icons.email_outlined),
              validator: (v) => v!.isEmpty ? 'Email wajib diisi' : null,
            ),
            
            const SizedBox(height: 20),

            // Input Password
            _buildLabel('Password'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _passwordController,
              obscureText: _isObscure,
              decoration: _inputDecoration('••••••••', Icons.lock_outline).copyWith(
                suffixIcon: IconButton(
                  icon: Icon(_isObscure ? Icons.visibility_off : Icons.visibility, size: 20),
                  onPressed: () => setState(() => _isObscure = !_isObscure),
                ),
              ),
              validator: (v) => v!.isEmpty ? 'Password wajib diisi' : null,
            ),

            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {},
                child: const Text('Forgot Password?', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
              ),
            ),

            const SizedBox(height: 30),

            // --- TOMBOL LOGIN BIRU MODERN ---
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const MainNavigationScaffold()),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Login to Account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1A1C1E)));
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, size: 20, color: Colors.grey),
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      filled: true,
      fillColor: Colors.grey.shade50,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.blue, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 18),
    );
  }
}