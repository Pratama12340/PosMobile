import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:pusher_client_fixed/pusher_client_fixed.dart';
import 'storage_service.dart';

class ReverbService {
  static final ReverbService _instance = ReverbService._internal();
  factory ReverbService() => _instance;
  ReverbService._internal();

  PusherClient? _pusher;
  final Map<String, Channel> _channels = {};
  bool _isConnected = false;
  bool _isInitializing = false; // ✅ Mencegah pemanggilan ganda
  Completer<void>? _connectionCompleter;

  final String reverbAppKey = "r3gcjhwwanzthldyihry";
  final String reverbHost   = "pos.etres.my.id"; 
  final int reverbPort      = 8443;
  final String authUrl      = "https://api.etres.my.id/api/v1/broadcasting/auth";

  Future<void> initConnection({
    required String channelName,
    required String eventName,
    required Function(dynamic) onEventReceived,
  }) async {
    try {
      final String? token = await StorageService.getToken();
      if (token == null || token.isEmpty) {
        debugPrint("🔴 [REVERB] Token tidak ditemukan.");
        return;
      }

      // ✅ Mencegah proses koneksi berjalan dua kali bersamaan
      if (_isInitializing) {
        debugPrint("⏳ [REVERB] Sedang proses inisialisasi, tunggu sebentar...");
        if (_connectionCompleter != null) {
          await _connectionCompleter!.future;
        }
      } 
      // ✅ Inisialisasi Pusher hanya sekali
      else if (_pusher == null) {
        _isInitializing = true;
        await _initPusher(token);
        _isInitializing = false;
      }

      // ✅ Tunggu koneksi benar-benar siap sebelum subscribe
      if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
        await _connectionCompleter!.future.timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            debugPrint("⏰ [REVERB] Timeout menunggu koneksi.");
          },
        );
      }

      if (!_isConnected) {
        debugPrint("🔴 [REVERB] Tidak bisa subscribe, koneksi gagal.");
        return;
      }

      // ✅ Cek channel sudah di-subscribe atau belum
      if (_channels.containsKey(channelName)) {
        debugPrint("⚠️ [REVERB] Sudah subscribe ke: $channelName, skip.");
        return;
      }

      // ✅ Subscribe channel
      _subscribeChannel(channelName, eventName, onEventReceived);

    } catch (e) {
      _isInitializing = false; // Buka kunci jika terjadi error
      debugPrint("💥 [REVERB ERROR]: $e");
    }
  }

  Future<void> _initPusher(String token) async {
    _connectionCompleter = Completer<void>(); 

    PusherOptions options = PusherOptions(
      host: reverbHost,
      wsPort: reverbPort, // 8443
      wssPort: reverbPort, // ✅ TAMBAHKAN INI (8443)
      encrypted: true, // ✅ WAJIB TRUE karena REVERB_SCHEME=https
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

    _pusher!.onConnectionStateChange((state) {
      final current = state?.currentState;
      debugPrint("🔵 [REVERB] ${state?.previousState} -> $current");

      if (current == 'CONNECTED') {
        _isConnected = true;
        if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
          _connectionCompleter!.complete();
        }
      } else if (current == 'DISCONNECTED') {
        _isConnected = false;
      }
    });

    _pusher!.onConnectionError((error) {
      debugPrint("🔴 [REVERB ERROR] ${error?.message}");
      if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
        _connectionCompleter!.completeError(error?.message ?? 'Connection error');
      }
    });

    await _pusher!.connect();
  }

  void _subscribeChannel(
    String channelName,
    String eventName,
    Function(dynamic) onEventReceived,
  ) {
    final channel = _pusher!.subscribe(channelName);
    _channels[channelName] = channel;

    channel.bind(eventName, (PusherEvent? event) {
      debugPrint("⚡ [REVERB EVENT]: ${event?.eventName}");
      if (event?.data != null) {
        try {
          final data = jsonDecode(event!.data.toString());
          onEventReceived(data);
        } catch (e) {
          debugPrint("💥 [REVERB] Gagal parse data: $e");
        }
      }
    });

    debugPrint("✅ [REVERB] Terhubung ke: $channelName");
  }

  Future<void> disconnect() async {
    try {
      for (var channel in _channels.values) {
        await _pusher?.unsubscribe(channel.name);
      }
      _channels.clear();
      _isConnected = false;
      
      // ✅ Memutus koneksi terlebih dahulu
      if (_pusher != null) {
        await _pusher!.disconnect();
      }
      
      // ✅ Variabel dikosongkan setelah bersih
      _pusher = null; 
      _connectionCompleter = null;
      
      debugPrint("⏹️ [REVERB] Koneksi ditutup bersih.");
    } catch (e) {
      debugPrint("💥 [REVERB] Gagal disconnect: $e");
    }
  }
}