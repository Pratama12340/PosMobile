import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:pusher_client_fixed/pusher_client_fixed.dart';
import 'storage_service.dart';

class ReverbService {
  static final ReverbService _instance = ReverbService._internal();
  factory ReverbService() => _instance;
  ReverbService._internal();

  PusherClient? _pusher;
  Channel? _channel;

  final String reverbAppKey = "r3gcjhwwanzthldyihry";
  final String reverbHost = "192.168.1.29";
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

      PusherOptions options = PusherOptions(
        host: reverbHost,
        wsPort: reverbPort,
        encrypted: false,
        cluster: 'mt1',
        auth: PusherAuth(
          authUrl,
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );

      _pusher = PusherClient(
        reverbAppKey,
        options,
        autoConnect: false,
        enableLogging: true,
      );

      await _pusher!.connect();

      _pusher!.onConnectionStateChange((state) {
        debugPrint(
          "🔵 [REVERB STATUS] ${state?.previousState} -> ${state?.currentState}",
        );
      });

      _pusher!.onConnectionError((error) {
        debugPrint("🔴 [REVERB ERROR] ${error?.message}");
      });

      _channel = _pusher!.subscribe(channelName);

      _channel!.bind(eventName, (PusherEvent? event) {
        debugPrint("⚡ [REVERB EVENT MASUK]: ${event?.eventName}");
        if (event?.data != null) {
          final data = jsonDecode(event!.data.toString());
          onEventReceived(data);
        }
      });

      debugPrint(
        "✅ [REVERB SUCCESS] Terhubung dan listen ke channel: $channelName",
      );
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
