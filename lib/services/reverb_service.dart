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
  bool _isInitializing = false;
  Completer<void>? _connectionCompleter;

  final String reverbAppKey = "r3gcjhwwanzthldyihry";
  final String reverbHost   = "ws.etres.my.id";
  final int reverbPort      = 443;
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

      if (_isInitializing) {
        debugPrint("⏳ [REVERB] Sedang proses inisialisasi, tunggu sebentar...");
        if (_connectionCompleter != null) {
          await _connectionCompleter!.future;
        }
      } else if (_pusher == null) {
        _isInitializing = true;
        await _initPusher(token);
        _isInitializing = false;
      }

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

      if (_channels.containsKey(channelName)) {
        debugPrint("⚠️ [REVERB] Sudah subscribe ke: $channelName, skip.");
        return;
      }

      _subscribeChannel(channelName, eventName, onEventReceived);

    } catch (e) {
      _isInitializing = false;
      debugPrint("💥 [REVERB ERROR]: $e");
    }
  }

  Future<void> _initPusher(String token) async {
    _connectionCompleter = Completer<void>();

    PusherOptions options = PusherOptions(
      host: reverbHost,
      wsPort: reverbPort,
      wssPort: reverbPort,
      encrypted: true,
      //cluster: 'mt1',
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
      debugPrint("🔴 [REVERB ERROR] code: ${error?.code}");
      debugPrint("🔴 [REVERB ERROR] exception: ${error?.exception}");
      if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
        _connectionCompleter!.completeError(error?.message ?? 'Connection error');
      }
    });

    // Taruh tepat sebelum await _pusher!.connect();
    debugPrint("🔌 [REVERB] Konek ke: $reverbHost:$reverbPort encrypted:${options.encrypted}");
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

  // ✅ BARU — bind event tambahan ke channel yang sudah ada
  void bindEvent(
    String channelName,
    String eventName,
    Function(dynamic) onEventReceived,
  ) {
    final channel = _channels[channelName];
    if (channel == null) {
      debugPrint('⚠️ [REVERB] Channel $channelName belum ada, tidak bisa bind.');
      return;
    }

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

    debugPrint("✅ [REVERB] Event $eventName terikat ke channel $channelName");
  }

  Future<void> disconnect() async {
    try {
      for (var channel in _channels.values) {
        await _pusher?.unsubscribe(channel.name);
      }
      _channels.clear();
      _isConnected = false;

      if (_pusher != null) {
        await _pusher!.disconnect();
      }

      _pusher = null;
      _connectionCompleter = null;

      debugPrint("⏹️ [REVERB] Koneksi ditutup bersih.");
    } catch (e) {
      debugPrint("💥 [REVERB] Gagal disconnect: $e");
    }
  }
}