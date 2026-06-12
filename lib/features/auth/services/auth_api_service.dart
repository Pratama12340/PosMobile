import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sistem_pos/core/services/storage_service.dart';
import 'package:sistem_pos/core/network/api_client.dart';

class AuthApiService {
  static Future<Map<String, dynamic>> loginPin(String pin, int outletId) async {
// debugPrint("\n=========================================");
// debugPrint("[API REQUEST] --> LOGIN PIN");
// debugPrint("Payload: {'pin': '***', 'outlet_id': $outletId}");

    try {
      final response = await ApiClient.post(
        Uri.parse('${ApiClient.baseUrl}/login-pin'),
        body: jsonEncode({'pin': pin, 'outlet_id': outletId}),
      );

// debugPrint("[API RESPONSE] <-- STATUS: ${response.statusCode}");

      if (kDebugMode) {
        final body = Map<String, dynamic>.from(jsonDecode(response.body));
        body.remove('token');
// debugPrint('[RESPONSE BODY]: $body');
      }

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final user = data['user'];
        if (user == null) {
// debugPrint("❌ [API ERROR] Data user dari server bernilai null.");
          return {'success': false, 'message': 'Format data server tidak valid.'};
        }

        final int userOutletId = int.tryParse(user['outlet_id'].toString()) ?? 0;
// debugPrint("🔍 [API VALIDASI] Cek Cabang Karyawan: DB ($userOutletId) vs App ($outletId)");

        if (userOutletId != outletId) {
// debugPrint("❌ [API REJECTED] Karyawan terdaftar di cabang lain!");
          return {'success': false, 'message': 'Akses Ditolak: Anda terdaftar di Cabang lain.'};
        }

        final String? shiftId = data['shift_id']?.toString();
        if (shiftId == null || shiftId == 'null' || shiftId.isEmpty) {
// debugPrint("❌ [API REJECTED] Karyawan tidak memiliki jadwal shift aktif saat ini.");
          return {
            'success': false,
            'message': 'Akses Ditolak: Anda tidak memiliki jadwal shift aktif saat ini.',
          };
        }

        await StorageService.saveToken(data['token']);
        await StorageService.saveCashierName(user['name'] ?? "Kasir");
        await StorageService.saveUserRole(user['role']?.toString() ?? "Cashier");
        await StorageService.saveOutletId(outletId);
        await StorageService.saveProfilePhoto(
          user['image'] != null ? user['image'].toString() : "",
        );
        await StorageService.saveCurrentShiftId(shiftId);

        if (data['opening_balance'] != null) {
          int balance = int.tryParse(data['opening_balance'].toString()) ?? 0;
          await StorageService.saveOpeningBalance(balance);
          await StorageService.saveShiftStatus(true);
        }

        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['message'] ?? 'PIN Salah!'};
      }
    } catch (e) {
      if (kDebugMode) {
        print("💥 [API ERROR] loginPin: $e");
      }
      return {'success': false, 'message': 'Koneksi error: $e'};
    }
  }

  static Future<Map<String, dynamic>> fetchOutletInfoLive() async {
// debugPrint("[API REQUEST] --> FETCH OUTLET INFO LIVE");
    try {
      final String role = await StorageService.getUserRole();
      final outletId = await StorageService.getOutletId();

      if (outletId == null) {
        return {
          'name': "Outlet Belum Dipilih",
          'address_outlet': "-",
          'phone_number_outlet': "-",
          'image': null,
          'owner_name': "-",
          'owner_email': "-",
        };
      }

      final response = await ApiClient.get(Uri.parse('${ApiClient.baseUrl}/outlets'));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        List<dynamic> outlets = (result['data'] is List)
            ? result['data']
            : (result['data']?['data'] ?? []);

        for (var outlet in outlets) {
          if (outlet['id'].toString() == outletId.toString()) {
            String ownerName = "Belum diatur";
            String ownerEmail = "Belum diatur";

            if (role == 'owner' && outlet['owner_id'] != null) {
              try {
// debugPrint("==================================================");
// debugPrint("🚨 [DEBUG Laporan Backend] MULAI CEK AKSES /users");
// debugPrint("🚨 [DEBUG Laporan Backend] Mencari owner_id : ${outlet['owner_id']}");

                final userResponse = await ApiClient.get(Uri.parse('${ApiClient.baseUrl}/users'));

// debugPrint("🚨 [DEBUG Laporan Backend] Status HTTP   : ${userResponse.statusCode}");
// debugPrint("🚨 [DEBUG Laporan Backend] Body Response : ${userResponse.body}");
// debugPrint("==================================================");

                if (userResponse.statusCode == 200) {
                  final userResult = jsonDecode(userResponse.body);
                  List<dynamic> users = [];
                  if (userResult is List) {
                    users = userResult;
                  } else if (userResult['data'] is List) {
                    users = userResult['data'];
                  }

                  for (var user in users) {
                    if (user['id'].toString() == outlet['owner_id'].toString()) {
                      ownerName = user['name']?.toString() ?? "Belum diatur";
                      ownerEmail = user['email']?.toString() ?? "Belum diatur";
                      break;
                    }
                  }
                }
              } catch (e) {
                if (kDebugMode) {
                  print("💥 [API ERROR] Gagal fetch data user: $e");
                }
              }
            }

            return {
              'name': outlet['name']?.toString() ?? "Outlet",
              'address_outlet': outlet['address_outlet']?.toString() ?? "Alamat tidak tersedia",
              'phone_number_outlet': outlet['phone_number_outlet']?.toString() ?? "-",
              'image': outlet['image'],
              'owner_name': ownerName,
              'owner_email': ownerEmail,
            };
          }
        }
      }

      return {
        'name': "Outlet Tidak Ditemukan",
        'address_outlet': "-",
        'phone_number_outlet': "-",
        'image': null,
        'owner_name': "-",
        'owner_email': "-",
      };
    } catch (e) {
      if (kDebugMode) {
        print("💥 [API ERROR] fetchOutletInfoLive: $e");
      }
      return {
        'name': "Error Jaringan",
        'address_outlet': "-",
        'phone_number_outlet': "-",
        'image': null,
        'owner_name': "-",
        'owner_email': "-",
      };
    }
  }
}
