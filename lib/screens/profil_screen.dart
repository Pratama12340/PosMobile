import 'package:flutter/material.dart';
import '../style.dart';
import '../services/api_service.dart';

class ProfilHistory extends StatefulWidget {
  const ProfilHistory({super.key});

  @override
  State<ProfilHistory> createState() => _ProfilHistoryState();
}

class _ProfilHistoryState extends State<ProfilHistory> {
  late Future<Map<String, dynamic>> _outletDataFuture;

  @override
  void initState() {
    super.initState();
    _outletDataFuture = ApiService.fetchOutletInfoLive(); 
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyle.bgLightBlue,
      body: FutureBuilder<Map<String, dynamic>>(
        future: _outletDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppStyle.primaryBlue),
            );
          }

          final data = snapshot.data ?? {};
          final String outletName = data['name'] ?? "NAMA OUTLET";
          final String phone = data['phone_number_outlet'] ?? "Belum diatur";
          final String address = data['address_outlet'] ?? "Belum diatur";
          final String ownerName = data['owner_name'] ?? "Belum diatur";
          final String ownerEmail = data['owner_email'] ?? "Belum diatur"; 
          
          // Ambil URL gambar dari data
          final String? imageUrl = data['image'];

          return SingleChildScrollView(
            child: Stack(
              children: [
                // --- 1. BACKGROUND HEADER GRADASI DENGAN WATERMARK ---
                Container(
                  height: 280,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF152A55),
                        Color(0xFF1E3C72),
                        AppStyle.primaryBlue,
                      ],
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -50,
                        top: -20,
                        child: Icon(
                          Icons.storefront_rounded,
                          size: 250,
                          color: Colors.white.withOpacity(0.05),
                        ),
                      ),
                    ],
                  ),
                ),

                // --- 2. TOMBOL KEMBALI (BACK BUTTON) ---
                Positioned(
                  top: 40, 
                  left: 24, 
                  child: IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                ),

                // --- 3. KONTEN UTAMA (LAPISAN ATAS) ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 60),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // SISI KIRI (FOTO PROFIL)
                      Expanded(
                        flex: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 80),

                            // Penanganan Gambar Dinamis
                            Container(
                              height: 400,
                              width: 300,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: Colors.white, width: 6),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
                                    blurRadius: 30,
                                    offset: const Offset(0, 15),
                                  ),
                                ],
                              ),
                              // Gunakan ClipRRect agar gambar terpotong mengikuti border radius
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(18), 
                                child: (imageUrl != null && imageUrl.isNotEmpty)
                                    ? Image.network(
                                        imageUrl,
                                        fit: BoxFit.cover,
                                        // errorBuilder akan dijalankan jika link rusak/mengalami 404
                                        errorBuilder: (context, error, stackTrace) {
                                          return _buildPlaceholderImage();
                                        },
                                      )
                                    // Jika imageUrl dari database memang null, langsung tampilkan placeholder
                                    : _buildPlaceholderImage(),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 50),

                      // SISI KANAN (NAMA OUTLET & KOTAK INFO)
                      Expanded(
                        flex: 6,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 160),

                            Transform.translate(
                              offset: const Offset(-40, 0),
                              child: Text(
                                outletName,
                                style: AppStyle.titleText.copyWith(
                                  color: Colors.white,
                                  fontSize: 36,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),

                            const SizedBox(height: 90),

                            _buildModernInfoBox(
                              label: "Owner Name",
                              value: ownerName,
                              baseColor: Colors.blue,
                              icon: Icons.person_outline_rounded,
                            ),

                            _buildModernInfoBox(
                              label: "Email Address",
                              value: ownerEmail,
                              baseColor: Colors.amber.shade600,
                              icon: Icons.email_outlined,
                            ),

                            _buildModernInfoBox(
                              label: "Phone Number",
                              value: phone,
                              baseColor: Colors.redAccent,
                              icon: Icons.phone_android_rounded,
                            ),

                            _buildModernInfoBox(
                              label: "Outlet Address",
                              value: address,
                              baseColor: Colors.green,
                              icon: Icons.location_on_outlined,
                            ),

                            const SizedBox(height: 60),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Widget Helper untuk Placeholder Gambar (Tampil jika DB null atau link error)
  Widget _buildPlaceholderImage() {
    return Container(
      color: Colors.grey.shade100,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.store_outlined, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 10),
            Text(
              "No Image",
              style: AppStyle.subTitleText.copyWith(color: Colors.grey.shade500),
            )
          ],
        ),
      ),
    );
  }

  // Widget Helper Card Modern
  Widget _buildModernInfoBox({
    required String label,
    required String value,
    required Color baseColor,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: baseColor.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: baseColor.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: baseColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: baseColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: AppStyle.subTitleText.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: baseColor.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: AppStyle.menuText.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppStyle.textMain,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}