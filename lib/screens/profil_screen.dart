import 'package:flutter/material.dart';
import '../constants/style.dart';
import '../services/api_service.dart';

class ProfilHistory extends StatefulWidget {
  const ProfilHistory({super.key});

  @override
  State<ProfilHistory> createState() => _ProfilHistoryState();
}

class _ProfilHistoryState extends State<ProfilHistory>
    with SingleTickerProviderStateMixin {
  late Future<Map<String, dynamic>> _outletDataFuture;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _outletDataFuture = ApiService.fetchOutletInfoLive();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
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
          final String? imageUrl = data['image'];

          return Stack(
            children: [
              // ── Subtle decorative blobs ──
              _buildBgDecor(),

              // ── Back button ──
              Positioned(
                top: 40,
                left: 24,
                child: _BackButton(onTap: () => Navigator.pop(context)),
              ),

              // ── Centered floating card ──
              Center(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: _buildFloatingCard(
                      imageUrl: imageUrl,
                      outletName: outletName,
                      ownerName: ownerName,
                      ownerEmail: ownerEmail,
                      phone: phone,
                      address: address,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Background decoration
  // ─────────────────────────────────────────────────────────────

  Widget _buildBgDecor() {
    return Stack(
      children: [
        Positioned(
          top: -80,
          right: -60,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppStyle.primaryBlue.withValues(alpha: 0.07),
            ),
          ),
        ),
        Positioned(
          bottom: -60,
          left: -40,
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppStyle.primaryBlue.withValues(alpha: 0.05),
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Floating card
  // ─────────────────────────────────────────────────────────────

  Widget _buildFloatingCard({
    required String? imageUrl,
    required String outletName,
    required String ownerName,
    required String ownerEmail,
    required String phone,
    required String address,
  }) {
    return Container(
      width: 980,
      margin: const EdgeInsets.symmetric(horizontal: 40),
      decoration: BoxDecoration(
        color: AppStyle.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppStyle.primaryBlue.withValues(alpha: 0.10),
            blurRadius: 60,
            offset: const Offset(0, 24),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(64),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Left: Photo ──
            _buildPhotoSection(imageUrl, outletName),

            // ── Divider ──
            Container(
              width: 1.5,
              height: 400,
              margin: const EdgeInsets.symmetric(horizontal: 56),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppStyle.primaryBlue.withValues(alpha: 0.2),
                    AppStyle.primaryBlue.withValues(alpha: 0.2),
                    Colors.transparent,
                  ],
                ),
              ),
            ),

            // ── Right: Info ──
            Expanded(
              child: _buildInfoSection(
                ownerName: ownerName,
                ownerEmail: ownerEmail,
                phone: phone,
                address: address,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Photo section (left)
  // ─────────────────────────────────────────────────────────────

  Widget _buildPhotoSection(String? imageUrl, String outletName) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          children: [
            // Photo box
            Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: AppStyle.bgLightBlue,
                border: Border.all(
                  color: AppStyle.primaryBlue.withValues(alpha: 0.15),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppStyle.primaryBlue.withValues(alpha: 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22.5),
                child: (imageUrl != null && imageUrl.isNotEmpty)
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _buildPhotoFallback(),
                      )
                    : _buildPhotoFallback(),
              ),
            ),

            // Camera badge (top-left)
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppStyle.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.photo_camera_rounded,
                  size: 16,
                  color: AppStyle.primaryBlue,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Outlet name
        SizedBox(
          width: 340,
          child: Text(
            outletName,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppStyle.titleText.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Status badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F0FE),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppStyle.primaryBlue,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                "Outlet Aktif",
                style: AppStyle.subTitleText.copyWith(
                  color: AppStyle.primaryBlue,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoFallback() {
    return Container(
      color: AppStyle.bgLightBlue,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.store_rounded,
            size: 64,
            color: AppStyle.primaryBlue.withValues(alpha: 0.30),
          ),
          const SizedBox(height: 8),
          Text(
            "No Image",
            style: AppStyle.subTitleText.copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Info section (right)
  // ─────────────────────────────────────────────────────────────

  Widget _buildInfoSection({
    required String ownerName,
    required String ownerEmail,
    required String phone,
    required String address,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        Row(
          children: [
            Container(
              width: 4,
              height: 22,
              decoration: BoxDecoration(
                color: AppStyle.primaryBlue,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              "Informasi Profil",
              style: AppStyle.titleText.copyWith(fontSize: 22),
            ),
          ],
        ),

        const SizedBox(height: 36),

        _buildInfoRow(
          label: "Nama Pemilik",
          value: ownerName,
          icon: Icons.person_outline_rounded,
        ),
        _buildDivider(),
        _buildInfoRow(
          label: "Email",
          value: ownerEmail,
          icon: Icons.mail_outline_rounded,
        ),
        _buildDivider(),
        _buildInfoRow(
          label: "Nomor Telepon",
          value: phone,
          icon: Icons.phone_outlined,
        ),
        _buildDivider(),
        _buildInfoRow(
          label: "Alamat",
          value: address,
          icon: Icons.location_on_outlined,
        ),
      ],
    );
  }

  Widget _buildInfoRow({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon pill
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F0FE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 22, color: AppStyle.primaryBlue),
          ),

          const SizedBox(width: 18),

          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppStyle.subTitleText.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: AppStyle.menuText.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppStyle.textMain,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: AppStyle.primaryBlue.withValues(alpha: 0.07),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Back button
// ─────────────────────────────────────────────────────────────

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;

  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppStyle.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: AppStyle.primaryBlue,
          size: 18,
        ),
      ),
    );
  }
}