import 'package:flutter/material.dart';

class SnackbarHelper {
  /// Mem-parsing error string mentah dari Exception menjadi kalimat yang ramah pengguna
  static String getFriendlyErrorMessage(dynamic error) {
    String errorString = error.toString().toLowerCase();
    
    if (errorString.contains("token expired") || errorString.contains("unauthenticated")) {
      return "Sesi Anda telah habis. Silakan login kembali.";
    }
    if (errorString.contains("socketexception") || errorString.contains("network") || errorString.contains("timeout")) {
      return "Koneksi internet bermasalah. Periksa jaringan Anda.";
    }
    if (errorString.contains("not found") || errorString.contains("404")) {
      return "Data tidak ditemukan di server.";
    }
    if (errorString.contains("server error") || errorString.contains("500")) {
      return "Terjadi gangguan pada server. Coba beberapa saat lagi.";
    }
    
    // Default fallback
    // Hapus tulisan "Exception:" dari teks
    return error.toString().replaceAll("Exception: ", "").replaceAll("Exception", "").trim();
  }

  /// Menampilkan SnackBar error dengan desain modern dan rounded
  static void showError(BuildContext context, dynamic error, {String? customMessage}) {
    final String message = customMessage ?? getFriendlyErrorMessage(error);
    
    _show(context, message, Colors.red.shade600, Icons.error_outline_rounded);
  }

  /// Menampilkan SnackBar sukses dengan desain modern
  static void showSuccess(BuildContext context, String message) {
    _show(context, message, Colors.green.shade600, Icons.check_circle_outline_rounded);
  }

  /// Menampilkan SnackBar info umum
  static void showInfo(BuildContext context, String message) {
    _show(context, message, Colors.blue.shade600, Icons.info_outline_rounded);
  }

  static void _show(BuildContext context, String message, Color bgColor, IconData icon) {
    final snackBar = SnackBar(
      content: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white, 
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: bgColor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.all(16),
      elevation: 4,
      duration: const Duration(seconds: 3),
    );

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);
  }
}
