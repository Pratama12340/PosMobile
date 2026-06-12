import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sistem_pos/features/printer/models/printer_profile_model.dart';
import 'package:sistem_pos/features/printer/models/printer_device.dart';

class StorageService {
  static const String _keyToken = 'token';
  static const String _keyOutletId = 'outlet_id';
  static const String _keyCashierName = 'cashier_name';
  static const String _keyOutletName = 'outlet_name';
  static const String _keyUserRole = 'user_role';
  static const String _keyProfilePhoto = 'profile_photo';
  static const String _keyLoginTime = 'login_time';
  static const String _keyOpeningCash = 'opening_cash';
  static const String _keyIsShiftActive = 'is_shift_active';
  static const String _keyCurrentShiftId = 'current_shift_id';
  static const String _keyShiftName = 'shift_name';
  static const String _keyShiftSchedule = 'shift_schedule';
  static const String _keyLastShiftUserId = 'last_shift_user_id';
  static const String _keyPrinterIp = 'printer_ip';
  static const String _keyPort = 'printer_port';
  static const String _keyPadding = 'printer_padding';
  static const String _keyCardWidth = 'printer_card_width';

  // --- 1. FUNGSI TOKEN ---
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }

  static Future<void> removeToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
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
    final Object? val = prefs.get(_keyOpeningCash);

    if (val == null) return 0;

    if (val is int) return val;
    if (val is double) return val.toInt();
    if (val is String) {
      return int.tryParse(val.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    }

    return 0;
  }

  static Future<void> clearOpeningBalance() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyOpeningCash);
  }

  // Alias fungsi lama agar tidak error di bagian code lain (Bekerja dengan Int)
  static Future<void> saveOpeningCash(double amount) async =>
      saveOpeningBalance(amount.toInt());
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

  static Future<void> logoutKasir() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyCashierName);
    await prefs.remove(_keyUserRole);
    await prefs.remove(_keyProfilePhoto);
  }

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

  // --- 7. LOGIKA PRINTER PROFILES ---
  static const String _keyPrinters = 'printers_config';

  static Future<void> savePrinters(List<PrinterProfile> printers) async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> jsonList = printers.map((p) => p.toJson()).toList();
    await prefs.setString(_keyPrinters, jsonEncode(jsonList));
  }

  static Future<List<PrinterProfile>> getPrinters() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_keyPrinters);
    if (data == null) return [];
    try {
      final decoded = jsonDecode(data);
      if (decoded is List) {
        return decoded.map((e) => PrinterProfile.fromJson(Map<String, dynamic>.from(e))).toList();
      }
    } catch (_) {}
    return [];
  }

  // ---  FUNGSI PRINTER LIST ---
  static const String _keyPrinterList = 'printer_list';

  static Future<void> savePrinterList(List<PrinterDevice> printers) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPrinterList, PrinterDevice.encodeList(printers));
  }

  static Future<List<PrinterDevice>> getPrinterList() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyPrinterList);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    return PrinterDevice.decodeList(jsonStr);
  }

  // --- FUNGSI PRINTER SETTINGS INDIVIDUAL ---
  static Future<void> savePrinterIp(String ip) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPrinterIp, ip);
  }

  static Future<String?> getPrinterIp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPrinterIp);
  }

  static Future<void> savePrinterPort(int port) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyPort, port);
  }
  
  static Future<int> getPrinterPort() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyPort) ?? 9100;
  }

  static Future<void> savePaddingSize(double size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyPadding, size);
  }
  
  static Future<double> getPaddingSize() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyPadding) ?? 32.0;
  }

  static Future<void> saveCardWidth(double width) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyCardWidth, width);
  }
  
  static Future<double> getCardWidth() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyCardWidth) ?? 320.0;
  }
}
