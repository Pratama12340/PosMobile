import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  // --- KUMPULAN KEY ---
  static const String _keyToken = 'token';
  static const String _keyOutletId = 'outlet_id';
  static const String _keyCashierName = 'cashier_name';
  static const String _keyOutletName = 'outlet_name';
  static const String _keyUserRole = 'user_role';
  static const String _keyProfilePhoto = 'profile_photo';
  static const String _keyLoginTime = 'login_time';
  static const String _keyOpeningCash = 'opening_cash'; // Key untuk Kas Awal
  
  // Key Shift (Data operasional yang dipertahankan saat logout)
  static const String _keyIsShiftActive = 'is_shift_active'; 
  static const String _keyCurrentShiftId = 'current_shift_id';
  static const String _keyShiftName = 'shift_name';
  static const String _keyShiftSchedule = 'shift_schedule';
  static const String _keyLastShiftUserId = 'last_shift_user_id'; 

  // --- 1. FUNGSI TOKEN ---
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
  }

  static Future<String> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken) ?? '';
  }

  // --- 2. FUNGSI OUTLET DATA ---
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

  // --- 3. FUNGSI DATA KARYAWAN ---
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

  static Future<void> saveUserRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserRole, role);
  }

  static Future<String> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserRole) ?? "Cashier";
  }

  static Future<void> saveProfilePhoto(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyProfilePhoto, url);
  }

  static Future<String> getProfilePhoto() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyProfilePhoto) ?? "";
  }

  // --- 4. FUNGSI KAS AWAL (LOGIKA ROBUST) ---
  static Future<void> saveOpeningBalance(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyOpeningCash, amount);
  }

  static Future<int> getOpeningBalance() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.get(_keyOpeningCash); 
    
    if (val == null) return 0;
    
    // Proteksi Multi-Type: Menangani jika tersimpan sebagai int, double, atau String
    if (val is int) return val;
    if (val is double) return val.toInt(); 
    if (val is String) {
      // Jika tersimpan sebagai String (misal dari input text), bersihkan karakter non-angka
      return int.tryParse(val.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    }
    
    return 0;
  }

  static Future<void> clearOpeningBalance() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyOpeningCash);
  }

  // Alias fungsi lama agar tidak error di bagian code lain
  static Future<void> saveOpeningCash(double amount) async => saveOpeningBalance(amount.toInt());
  static Future<double> getOpeningCash() async {
    final val = await getOpeningBalance();
    return val.toDouble();
  }

  // --- 5. FUNGSI LOGIKA SHIFT ---
  static Future<void> saveShiftStatus(bool isActive) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsShiftActive, isActive);
  }

  static Future<bool?> getShiftStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsShiftActive);
  }

  static Future<bool> isShiftActive() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsShiftActive) ?? false;
  }

  static Future<void> saveCurrentShiftId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCurrentShiftId, id);
  }

  static Future<String?> getCurrentShiftId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyCurrentShiftId);
  }

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

  static Future<void> saveLastShiftUserId(int id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLastShiftUserId, id);
  }

  static Future<int> getLastShiftUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyLastShiftUserId) ?? 0;
  }

  // --- 6. LOGIKA LOGOUT VS TUTUP KASIR ---

  // Logout hanya menghapus sesi user, data shift tetap aman
  static Future<void> logoutKasir() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyCashierName);
    await prefs.remove(_keyUserRole);
    await prefs.remove(_keyProfilePhoto);
  }

  // Menghapus data operasional saat shift benar-benar selesai
  static Future<void> tutupKasir() async {
    final prefs = await SharedPreferences.getInstance();
    await clearOpeningBalance(); 
    await prefs.remove(_keyLoginTime);
    await prefs.remove(_keyIsShiftActive);
    await prefs.remove(_keyCurrentShiftId);
    await prefs.remove(_keyShiftName);
    await prefs.remove(_keyShiftSchedule);
    await prefs.remove(_keyLastShiftUserId); 
  }
}