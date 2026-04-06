import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _outletIdKey = 'outlet_id';

  // Menyimpan ID Outlet (Biasanya dipanggil saat Manager Login pertama kali)
  static Future<void> saveOutletId(int id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_outletIdKey, id);
  }

  // Mengambil ID Outlet (Dipanggil saat Kasir Login PIN)
  static Future<int?> getOutletId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_outletIdKey); 
  }

  // Tambahkan fungsi ini di dalam class StorageService
  static Future<void> logoutKasir() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Hapus data spesifik kasir (misal nama atau token)
    // JANGAN gunakan prefs.clear() karena outlet_id akan ikut terhapus
    await prefs.remove('cashier_name');
    await prefs.remove('is_logged_in'); 
    
    print("DEBUG: Sesi kasir dihapus, Outlet ID tetap aman.");
  }
}