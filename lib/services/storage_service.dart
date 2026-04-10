import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  // Key untuk penyimpanan
  static const String _keyToken = 'token';
  static const String _keyOutletId = 'outlet_id';
  static const String _keyCashierName = 'cashier_name';
  static const String _keyOutletName = 'outlet_name';

  // --- 1. FUNGSI TOKEN (PENTING UNTUK API) ---
  
  // Simpan Token
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
  }

  // Ambil Token (Diperbaiki agar tidak return null)
  static Future<String> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken) ?? ''; // Kembalikan string kosong jika tidak ada
  }

  // --- 2. FUNGSI OUTLET ID ---

  static Future<void> saveOutletId(int id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyOutletId, id);
  }

  static Future<int?> getOutletId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyOutletId);
  }

  // --- 3. FUNGSI NAMA KASIR ---

  static Future<void> saveCashierName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCashierName, name);
  }

  static Future<String> getCashierName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyCashierName) ?? "Cashier";
  }

  // --- 4. FUNGSI NAMA OUTLET (UNTUK STRUK) ---

  // Tambahan fungsi untuk menyimpan nama outlet dari API (jika ada)
  static Future<void> saveOutletName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyOutletName, name);
  }

  static Future<String> getOutletName() async {
    final prefs = await SharedPreferences.getInstance();
    // Jika tidak ada di storage, default-nya 'Aranus PoS R&B'
    return prefs.getString(_keyOutletName) ?? "Aranus PoS R&B"; 
  }

  // --- 5. LOGOUT (HAPUS SESI KASIR SAJA, OUTLET TETAP AMAN) ---
  static Future<void> logoutKasir() async {
    final prefs = await SharedPreferences.getInstance();
    
    // HANYA menghapus token akses dan nama kasir yang sedang shift
    await prefs.remove(_keyToken);
    await prefs.remove(_keyCashierName);
    
    // _keyOutletId dan _keyOutletName tetap aman di dalam memori HP
  }
}