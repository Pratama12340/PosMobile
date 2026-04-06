import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  // Key untuk penyimpanan
  static const String _keyToken = 'token';
  static const String _keyOutletId = 'outlet_id';
  static const String _keyCashierName = 'cashier_name';

  // --- 1. FUNGSI TOKEN (PENTING UNTUK API) ---
  
  // Simpan Token
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
  }

  // Ambil Token (Ini yang tadi menyebabkan error)
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
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

  // --- 4. LOGOUT (HAPUS SEMUA DATA) ---
  static Future<void> logoutKasir() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}