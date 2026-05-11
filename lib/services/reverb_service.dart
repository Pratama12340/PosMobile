import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:pusher_client_fixed/pusher_client_fixed.dart';

// Sesuaikan path import ini dengan lokasi StorageService Anda
import 'storage_service.dart'; 

class ReverbService {
  // Singleton pattern
  static final ReverbService _instance = ReverbService._internal();
  factory ReverbService() => _instance;
  ReverbService._internal();

  PusherClient? _pusher;
  Channel? _channel;

  // ========================================================
  // KONFIGURASI SERVER REVERB (Sesuai .env Anda)
  // ========================================================
  final String reverbAppKey = "r3gcjhwwanzthldyihry"; 
  final String reverbHost = "192.168.1.29"; // IP Lokal
  final int reverbPort = 8080;
  final String authUrl = "https://api.etres.my.id/api/broadcasting/auth";

  Future<void> initConnection({
    required String channelName,
    required String eventName,
    required Function(dynamic) onEventReceived,
  }) async {
    try {
      final String? token = await StorageService.getToken();

      if (token == null || token.isEmpty) {
        debugPrint("🔴 [REVERB] Batal koneksi: Token Kasir tidak ditemukan.");
        return;
      }

      // 1. Konfigurasi PusherOptions untuk Custom Host (Reverb)
      PusherOptions options = PusherOptions(
        host: reverbHost,
        wsPort: reverbPort,
        encrypted: false, // Set false karena pakai HTTP (ws://), bukan HTTPS (wss://)
        cluster: 'mt1', // Wajib diisi meskipun Reverb tidak memakainya
        auth: PusherAuth(
          authUrl,
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );

      // 2. Inisialisasi PusherClient
      _pusher = PusherClient(
        reverbAppKey,
        options,
        autoConnect: false,
        enableLogging: true, // Akan mencetak log koneksi di console Anda
      );

      // 3. Connect ke Server Reverb
      await _pusher!.connect();

      _pusher!.onConnectionStateChange((state) {
        debugPrint("🔵 [REVERB STATUS] ${state?.previousState} -> ${state?.currentState}");
      });

      _pusher!.onConnectionError((error) {
        debugPrint("🔴 [REVERB ERROR] ${error?.message}");
      });

      // 4. Subscribe ke Private Channel
      _channel = _pusher!.subscribe(channelName);

      // 5. Bind / Dengarkan Event Masuk
      // CATATAN: Terkadang Laravel menambahkan awalan titik (.). 
      // Jika event tidak merespon, coba panggil dengan ".$eventName" (misal: ".order.updated")
      _channel!.bind(eventName, (PusherEvent? event) {
        debugPrint("⚡ [REVERB EVENT MASUK]: ${event?.eventName}");
        if (event?.data != null) {
          final data = jsonDecode(event!.data.toString());
          onEventReceived(data);
        }
      });

      debugPrint("✅ [REVERB SUCCESS] Terhubung dan listen ke channel: $channelName");

    } catch (e) {
      debugPrint("💥 [REVERB FATAL ERROR]: $e");
    }
  }

  Future<void> disconnect() async {
    try {
      if (_channel != null) {
        await _pusher?.unsubscribe(_channel!.name);
      }
      await _pusher?.disconnect();
      debugPrint("⏹️ [REVERB] Koneksi ditutup.");
    } catch (e) {
      debugPrint("💥 [REVERB] Gagal menutup koneksi: $e");
    }
  }
}