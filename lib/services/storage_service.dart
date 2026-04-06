import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  // Definisi Kunci (Keys) agar konsisten dan tidak typo
  static const String _outletIdKey = 'outlet_id';
  static const String _cashierNameKey = 'cashier_name';
  static const String _isLoggedInKey = 'is_logged_in';

  // ==========================================
  // SECTION: OUTLET (IDENTITAS TOKO)
  // ==========================================

  /// Menyimpan ID Outlet secara permanen di perangkat
  static Future<void> saveOutletId(int id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_outletIdKey, id);
    print("DEBUG: Outlet ID $id berhasil disimpan.");
  }

  /// Mengambil ID Outlet untuk keperluan Login API
  static Future<int?> getOutletId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_outletIdKey); 
  }

  // ==========================================
  // SECTION: CASHIER (DATA SESI KASIR)
  // ==========================================

  /// Menyimpan Nama Kasir setelah login berhasil
  static Future<void> saveCashierName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cashierNameKey, name);
    await prefs.setBool(_isLoggedInKey, true); // Tandai sudah login
    print("DEBUG: Nama Kasir '$name' disimpan.");
  }

  /// Mengambil Nama Kasir untuk ditampilkan di Top Bar
  static Future<String> getCashierName() async {
    final prefs = await SharedPreferences.getInstance();
    // Jika data tidak ada, kembalikan teks default "Kasir"
    return prefs.getString(_cashierNameKey) ?? "Kasir"; 
  }

  // ==========================================
  // SECTION: LOGOUT (KELUAR SESI)
  // ==========================================

  /// Menghapus sesi Kasir tanpa menghapus identitas Outlet
  static Future<void> logoutKasir() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Kita hapus data spesifik kasir saja
    await prefs.remove(_cashierNameKey);
    await prefs.remove(_isLoggedInKey); 
    
    // JANGAN gunakan prefs.clear()! 
    // Jika di-clear, outlet_id akan hilang dan aplikasi harus setup dari awal lagi.
    
    print("DEBUG: Sesi kasir dihapus. Outlet ID tetap aman di memori.");
  }
}