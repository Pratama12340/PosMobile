import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:pusher_client_fixed/pusher_client_fixed.dart';
import 'package:sistem_pos/core/services/storage_service.dart';

class ReverbService {
  static final ReverbService _instance = ReverbService._internal();
  factory ReverbService() => _instance;
  ReverbService._internal();

  PusherClient? _pusher;
  final Map<String, Channel> _channels = {};
  
  bool _isConnected = false;
  bool _isConnecting = false;

  final List<Map<String, dynamic>> _pendingSubscriptions = [];

  final String reverbAppKey = "r3gcjhwwanzthldyihry";
  final String reverbHost   = "ws.etres.my.id";
  final int reverbPort      = 443;
  final String authUrl      = "https://api.etres.my.id/api/v1/broadcasting/auth";

  List<String> get activeChannels => _channels.keys.toList();

  Future<void> initConnection({
    required String channelName,
    required String eventName,
    required Function(dynamic) onEventReceived,
  }) async {
    try {
      final String? token = await StorageService.getToken();
      if (token == null || token.isEmpty) {
// debugPrint("🔴 [REVERB] Token tidak ditemukan.");
        return;
      }

      _pendingSubscriptions.add({
        'channelName': channelName,
        'eventName': eventName,
        'onEventReceived': onEventReceived,
      });

      if (_isConnected) {
        _processPendingSubscriptions();
        return;
      }

      if (_isConnecting) {
// debugPrint("⏳ [REVERB] Sedang proses koneksi, harap tunggu...");
        return; 
      }

      _isConnecting = true;

      if (_pusher != null) {
// debugPrint("🔄 [REVERB] Reset pusher lama...");
        try { await _pusher!.disconnect(); } catch (_) {}
        _pusher = null;
        _channels.clear();
      }

      await _initPusher(token);

    } catch (e) {
// debugPrint("💥 [REVERB ERROR]: $e");
      _isConnecting = false;
    }
  }

  Future<void> _initPusher(String token) async {
    PusherOptions options = PusherOptions(
      host: reverbHost,
      wsPort: 443,
      wssPort: 443,
      encrypted: true,
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
// debugPrint("🔵 [REVERB] ${state?.previousState} -> $current");

      if (current == 'CONNECTED') {
        _isConnected = true;
        _isConnecting = false;
        _processPendingSubscriptions();
      } else if (current == 'DISCONNECTED') {
        _isConnected = false;
        _isConnecting = false;
      }
    });

    _pusher!.onConnectionError((error) {
// debugPrint("🔴 [REVERB ERROR] message  : ${error?.message}");
// debugPrint("🔴 [REVERB ERROR] exception: ${error?.exception}");
      _isConnected = false;
      _isConnecting = false;
    });

// debugPrint("🔌 [REVERB] Konek ke: $reverbHost:$reverbPort");
    await _pusher!.connect();
  }

  void _processPendingSubscriptions() {
    if (_pendingSubscriptions.isEmpty) return;
    final toProcess = List<Map<String, dynamic>>.from(_pendingSubscriptions);
    _pendingSubscriptions.clear();

    for (final sub in toProcess) {
      final channelName = sub['channelName'] as String;
      final eventName = sub['eventName'] as String;
      final onEventReceived = sub['onEventReceived'] as Function(dynamic);

      if (!_channels.containsKey(channelName)) {
        _subscribeChannel(channelName, eventName, onEventReceived);
      } else {
        _bindToChannel(channelName, eventName, onEventReceived);
      }
    }
  }

  void _subscribeChannel(String channelName, String eventName, Function(dynamic) onEventReceived) {
    final channel = _pusher!.subscribe(channelName);
    _channels[channelName] = channel;
    _bindToChannel(channelName, eventName, onEventReceived);
// debugPrint("✅ [REVERB] Subscribe ke: $channelName");
  }

void _bindToChannel(String channelName, String eventName, Function(dynamic) onEventReceived) {
    final channel = _channels[channelName];
    if (channel == null) return;

    // 🛠️ HAPUS ATAU KOMENTARI BAGIAN INI
    // String realEventName = eventName;
    // if (!realEventName.startsWith('.')) {
    //   realEventName = '.$realEventName';
    // }

    // Gunakan eventName langsung dari parameter
    channel.bind(eventName, (PusherEvent? event) {
// debugPrint("⚡ [REVERB EVENT RECEIVED]: ${event?.eventName}");
      if (event?.data != null) {
        try {
          final decodedData = jsonDecode(event!.data.toString());
          
          if (decodedData is Map && decodedData.containsKey('order')) {
            onEventReceived(decodedData['order']);
          } else {
            onEventReceived(decodedData);
          }
        } catch (e) {
// debugPrint("💥 [REVERB] Gagal parse data: $e");
        }
      }
    });
// debugPrint("✅ [REVERB] Bind kustom event $eventName di $channelName");
  }

  void bindEvent(String channelName, String eventName, Function(dynamic) onEventReceived) {
    if (_isConnected && _channels.containsKey(channelName)) {
      _bindToChannel(channelName, eventName, onEventReceived);
    } else {
      _pendingSubscriptions.add({
        'channelName': channelName,
        'eventName': eventName,
        'onEventReceived': onEventReceived,
      });
// debugPrint("🕐 [REVERB] bindEvent ditunda sampai connected: $eventName");
    }
  }

  Future<void> disconnect() async {
    try {
      for (var channel in _channels.values) {
        await _pusher?.unsubscribe(channel.name);
      }
      _channels.clear();
      _pendingSubscriptions.clear();
      _isConnected = false;
      _isConnecting = false;
      if (_pusher != null) await _pusher!.disconnect();
      _pusher = null;
// debugPrint("⏹️ [REVERB] Koneksi ditutup bersih.");
    } catch (e) {
// debugPrint("💥 [REVERB] Gagal disconnect: $e");
      _pusher = null;
      _channels.clear();
      _pendingSubscriptions.clear();
      _isConnected = false;
      _isConnecting = false;
    }
  }
}