import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  // --- KUMPULAN KEY (Agar rapi dan tidak typo) ---
  static const String _keyToken = 'token';
  static const String _keyOutletId = 'outlet_id';
  static const String _keyCashierName = 'cashier_name';
  static const String _keyOutletName = 'outlet_name';
  static const String _keyUserRole = 'user_role';
  static const String _keyProfilePhoto = 'profile_photo';
  static const String _keyLoginTime = 'login_time';
  static const String _keyOpeningCash = 'opening_cash';
  // Tambahan Key untuk Shift
  static const String _keyShiftName = 'shift_name';
  static const String _keyShiftSchedule = 'shift_schedule';

  // --- 1. FUNGSI TOKEN ---
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
  }

  static Future<String> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken) ?? '';
  }

  // --- 2. FUNGSI OUTLET DATA (Tetap Ada Saat Logout) ---
  static Future<void> saveOutletId(int id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyOutletId, id);
  }

  static Future<int?> getOutletId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyOutletId);
  }

  static Future<void> saveOutletName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyOutletName, name);
  }

  static Future<String> getOutletName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyOutletName) ?? "Aranus PoS R&B";
  }

  // --- 3. FUNGSI DATA KARYAWAN (Dihapus Saat Logout) ---
  
  // Nama Kasir
  static Future<void> saveCashierName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCashierName, name);
  }

  static Future<String> getCashierName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyCashierName) ?? "Cashier";
  }

  static Future<void> saveLoginTime(String time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLoginTime, time);
  }

  static Future<String?> getLoginTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLoginTime);
  }

  // Role User
  static Future<void> saveUserRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserRole, role);
  }

  static Future<String> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserRole) ?? "Cashier";
  }

  // Foto Profil (HANYA SATU FUNGSI)
  static Future<void> saveProfilePhoto(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyProfilePhoto, url);
  }

  static Future<String> getProfilePhoto() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyProfilePhoto) ?? "";
  }

  static Future<void> saveOpeningCash(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyOpeningCash, amount);
  }

  static Future<int> getOpeningCash() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyOpeningCash) ?? 0;
  }

  // --- 5. FUNGSI SHIFT (TAMBAHAN BARU) ---
  static Future<void> saveShiftInfo(String name, String schedule) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyShiftName, name);
    await prefs.setString(_keyShiftSchedule, schedule);
  }

  static Future<String> getShiftName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyShiftName) ?? "Shift -";
  }

  static Future<String> getShiftSchedule() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyShiftSchedule) ?? "00:00 - 00:00";
  }

  // --- 4. PROSES LOGOUT KASIR ---
  static Future<void> logoutKasir() async {
    final prefs = await SharedPreferences.getInstance();

    // Menghapus SEMUA data yang berkaitan dengan personil/karyawan
    await prefs.remove(_keyToken);
    await prefs.remove(_keyCashierName);
    await prefs.remove(_keyUserRole);
    await prefs.remove(_keyProfilePhoto);

    // Menggunakan variable key agar lebih aman dari typo
    await prefs.remove(_keyOpeningCash); 
    await prefs.remove(_keyLoginTime);
    
    // Menghapus data shift saat logout
    await prefs.remove(_keyShiftName);
    await prefs.remove(_keyShiftSchedule);

    // Data Outlet ID & Name TIDAK DIHAPUS agar HP tetap terkunci ke cabang tsb
    print("Logout Berhasil: Sesi karyawan dibersihkan, Identitas Outlet dipertahankan.");
  }
}