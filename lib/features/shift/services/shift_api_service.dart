import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sistem_pos/core/models/rekap_model.dart';
import 'package:sistem_pos/core/services/storage_service.dart';
import 'package:sistem_pos/core/network/api_client.dart';

class ShiftApiService {
  static Future<Map<String, dynamic>> checkShiftStatus(int outletId) async {
    try {
      final headers = await ApiClient.getHeaders();
      final response = await http.get(
        Uri.parse('${ApiClient.baseUrl}/shift-karyawans/check-status?outlet_id=$outletId'),
        headers: headers,
      );
      final data = jsonDecode(response.body);
      return response.statusCode == 200
          ? {'success': data['success'] ?? true, 'message': data['message'], 'data': data['data']}
          : {'success': false, 'message': data['message'] ?? 'Gagal'};
    } catch (e) {
      return {'success': false, 'message': 'Koneksi error: $e'};
    }
  }

  static Future<Map<String, dynamic>> startShift(int nominal, int outletId) async {
    try {
      final headers = await ApiClient.getHeaders();
      final response = await http.post(
        Uri.parse('${ApiClient.baseUrl}/shift-karyawans/start'),
        headers: headers,
        body: jsonEncode({'outlet_id': outletId, 'opening_balance': nominal}),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final int balance =
            int.tryParse(data['data']['opening_balance'].toString()) ?? nominal;
        await StorageService.saveOpeningBalance(balance);
        await StorageService.saveShiftStatus(true);
        return {'success': true, 'data': data};
      }
      return {'success': false, 'message': data['message'] ?? 'Gagal memulai shift'};
    } catch (e) {
      return {'success': false, 'message': 'Koneksi error: $e'};
    }
  }

  static Future<Map<String, dynamic>> endShift(int totalFisik, String notes) async {
    try {
      final headers = await ApiClient.getHeaders();
      final response = await http.post(
        Uri.parse('${ApiClient.baseUrl}/shift-karyawans/end'),
        headers: headers,
        body: jsonEncode({'actual_closing_balance': totalFisik, 'notes': notes}),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        await StorageService.clearOpeningBalance();
        await StorageService.saveShiftStatus(false);
        return {'success': true, 'data': data};
      } else if (response.statusCode == 404) {
        await StorageService.clearOpeningBalance();
        await StorageService.saveShiftStatus(false);
        return {'success': true, 'message': 'Shift sinkron.', 'is_forced_sync': true};
      }
      return {'success': false, 'message': data['message'] ?? 'Gagal'};
    } catch (e) {
      return {'success': false, 'message': 'Koneksi error: $e'};
    }
  }

  static Future<List<RekapShift>> getShiftHistory() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiClient.baseUrl}/shift-karyawans'),
        headers: await ApiClient.getHeaders(),
      );
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        List data = result['data'] is List ? result['data'] : result['data']['data'] ?? [];
        return data.map((json) => RekapShift.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<List<ShiftMaster>> getMasterShifts() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiClient.baseUrl}/shifts'),
        headers: await ApiClient.getHeaders(),
      );
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        List data = result['data'] is List ? result['data'] : result['data']['data'] ?? [];
        return data.map((json) => ShiftMaster.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}
