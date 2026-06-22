import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dart_pusher_channels/dart_pusher_channels.dart';
import 'package:sistem_pos/core/services/storage_service.dart';
import 'package:sistem_pos/core/network/api_client.dart';

class ReverbService {
  static final ReverbService _instance = ReverbService._internal();
  factory ReverbService() => _instance;
  ReverbService._internal();

  PusherChannelsClient? _pusher;
  final Map<String, Channel> _channels = {};
  
  bool _isConnected = false;
  bool _isConnecting = false;

  StreamSubscription? _connectionSubscription;
  StreamSubscription? _disconnectionSubscription;
  final Map<String, StreamSubscription> _eventSubscriptions = {};

  // Registry PERMANEN semua langganan yang diminta (keyed by 'channel_event').
  // Tidak ikut dikosongkan saat disconnect, agar channel & event bisa
  // dipasang ulang otomatis setiap kali koneksi pulih (reconnect).
  final Map<String, Map<String, dynamic>> _subscriptionRegistry = {};

  final String reverbAppKey = const String.fromEnvironment('REVERB_APP_KEY', defaultValue: 'r3gcjhwwanzthldyihry');
  final String reverbHost   = const String.fromEnvironment('REVERB_HOST', defaultValue: 'ws.etres.my.id');
  final int reverbPort      = const int.fromEnvironment('REVERB_PORT', defaultValue: 443);
  String get authUrl      => "${ApiClient.baseUrl}/broadcasting/auth";

  List<String> get activeChannels => _channels.keys.toList();

  Future<void> initConnection({
    required String channelName,
    required String eventName,
    required Function(dynamic) onEventReceived,
  }) async {
    try {
      final String? token = await StorageService.getToken();
      if (token == null || token.isEmpty) {
        if (kDebugMode) print("🔴 [REVERB] Token tidak ditemukan.");
        return;
      }

      _subscriptionRegistry['${channelName}_$eventName'] = {
        'channelName': channelName,
        'eventName': eventName,
        'onEventReceived': onEventReceived,
      };

      if (_isConnected) {
        _establishAllSubscriptions(token);
        return;
      }

      if (_isConnecting) {
        if (kDebugMode) print("⏳ [REVERB] Sedang proses koneksi, harap tunggu...");
        return; 
      }

      _isConnecting = true;
      Future.delayed(const Duration(seconds: 10), () {
        if (_isConnecting && !_isConnected) {
          if (kDebugMode) print("⏳ [REVERB] Timeout connecting, resetting state.");
          _isConnecting = false;
        }
      });

      if (_pusher != null) {
        if (kDebugMode) print("🔄 [REVERB] Reset pusher lama...");
        try { _pusher!.disconnect(); } catch (_) {}
        await _clearSubscriptions();
        _pusher = null;
      }

      await _initPusher(token);

    } catch (e) {
      if (kDebugMode) print("💥 [REVERB ERROR]: $e");
      _isConnecting = false;
    }
  }

  Future<void> _initPusher(String token) async {
    final options = PusherChannelsOptions.fromHost(
      scheme: reverbPort == 443 ? 'wss' : 'ws',
      host: reverbHost,
      port: reverbPort,
      key: reverbAppKey,
    );

    _pusher = PusherChannelsClient.websocket(
      options: options,
      connectionErrorHandler: (exception, trace, refresh) {
        if (kDebugMode) print("🔴 [REVERB ERROR] $exception");
        refresh();
      },
    );

    _connectionSubscription = _pusher!.onConnectionEstablished.listen((_) {
      if (kDebugMode) print("🔵 [REVERB] CONNECTED");
      _isConnected = true;
      _isConnecting = false;
      // Pasang ulang SEMUA langganan dari registry. Penting agar setelah
      // reconnect channel & event di-bind kembali (bukan hanya saat pertama).
      _establishAllSubscriptions(token);
    });

    _disconnectionSubscription = _pusher!.lifecycleStream.listen((state) {
      if (state == PusherChannelsClientLifeCycleState.disconnected ||
          state == PusherChannelsClientLifeCycleState.inactive) {
        if (kDebugMode) print("🔵 [REVERB] DISCONNECTED / INACTIVE");
        _isConnected = false;
        _isConnecting = false;
        // Channel & event lama sudah mati setelah koneksi putus. Buang agar
        // dibuat ulang dari registry saat reconnect (registry tetap disimpan).
        _invalidateChannels();
      }
    });

    if (kDebugMode) print("🔌 [REVERB] Konek ke: $reverbHost:$reverbPort");
    await _pusher!.connect();
  }

  /// Memasang (atau memasang ulang) seluruh langganan dari [_subscriptionRegistry].
  /// Dipanggil setiap kali koneksi terbentuk / pulih.
  void _establishAllSubscriptions(String token) {
    if (_subscriptionRegistry.isEmpty) return;
    final toProcess =
        List<Map<String, dynamic>>.from(_subscriptionRegistry.values);

    for (final sub in toProcess) {
      final channelName = sub['channelName'] as String;
      final eventName = sub['eventName'] as String;
      final onEventReceived = sub['onEventReceived'] as Function(dynamic);

      if (!_channels.containsKey(channelName)) {
        _subscribeChannel(channelName, eventName, onEventReceived, token);
      } else {
        _bindToChannel(channelName, eventName, onEventReceived);
      }
    }
  }

  /// Membuang channel & binding event lama (yang sudah mati setelah koneksi
  /// putus) TANPA menghapus registry, sehingga bisa dibuat ulang saat reconnect.
  void _invalidateChannels() {
    for (final sub in _eventSubscriptions.values) {
      sub.cancel();
    }
    _eventSubscriptions.clear();
    _channels.clear();
  }

  void _subscribeChannel(String channelName, String eventName, Function(dynamic) onEventReceived, String token) {
    if (_pusher == null) return;
    
    Channel channel;
    if (channelName.startsWith('private-')) {
      channel = _pusher!.privateChannel(
        channelName,
        authorizationDelegate: EndpointAuthorizableChannelTokenAuthorizationDelegate.forPrivateChannel(
          authorizationEndpoint: Uri.parse(authUrl),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        )
      );
    } else if (channelName.startsWith('presence-')) {
      channel = _pusher!.presenceChannel(
        channelName,
        authorizationDelegate: EndpointAuthorizableChannelTokenAuthorizationDelegate.forPresenceChannel(
          authorizationEndpoint: Uri.parse(authUrl),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        )
      );
    } else {
      channel = _pusher!.publicChannel(channelName);
    }

    channel.subscribe();
    _channels[channelName] = channel;
    if (kDebugMode) print("✅ [REVERB] Subscribe ke: $channelName");

    _bindToChannel(channelName, eventName, onEventReceived);
  }

  void _bindToChannel(String channelName, String eventName, Function(dynamic) onEventReceived) {
    final channel = _channels[channelName];
    if (channel == null) return;

    final subId = '${channelName}_$eventName';
    if (_eventSubscriptions.containsKey(subId)) {
      _eventSubscriptions[subId]?.cancel();
    }

    final sub = channel.bind(eventName).listen((event) {
      if (kDebugMode) print("⚡ [REVERB EVENT RECEIVED]: ${event.name}");
      if (event.data != null) {
        try {
          final decodedData = jsonDecode(event.data);
          
          if (decodedData is Map && decodedData.containsKey('order')) {
            onEventReceived(decodedData['order']);
          } else {
            onEventReceived(decodedData);
          }
        } catch (e) {
          if (kDebugMode) print("💥 [REVERB] Gagal parse data: $e");
        }
      }
    });
    
    _eventSubscriptions[subId] = sub;
    if (kDebugMode) print("✅ [REVERB] Bind event $eventName di $channelName");
  }

  void bindEvent(String channelName, String eventName, Function(dynamic) onEventReceived) {
    // Selalu simpan ke registry agar tetap terpasang ulang setelah reconnect.
    _subscriptionRegistry['${channelName}_$eventName'] = {
      'channelName': channelName,
      'eventName': eventName,
      'onEventReceived': onEventReceived,
    };

    if (_isConnected && _channels.containsKey(channelName)) {
      _bindToChannel(channelName, eventName, onEventReceived);
    } else {
      if (kDebugMode) print("🕐 [REVERB] bindEvent ditunda sampai connected: $eventName");
    }
  }

  Future<void> _clearSubscriptions() async {
    for (var sub in _eventSubscriptions.values) {
      await sub.cancel();
    }
    _eventSubscriptions.clear();
    
    for (var channel in _channels.values) {
      channel.unsubscribe();
    }
    _channels.clear();
    // Catatan: _subscriptionRegistry sengaja TIDAK dikosongkan di sini agar
    // langganan bisa dipasang ulang saat re-init. Pembersihan total hanya
    // dilakukan di disconnect().

    await _connectionSubscription?.cancel();
    await _disconnectionSubscription?.cancel();
  }

  Future<void> disconnect() async {
    try {
      await _clearSubscriptions();
      _subscriptionRegistry.clear(); // teardown total: hapus juga registry
      _isConnected = false;
      _isConnecting = false;

      if (_pusher != null) {
        _pusher!.disconnect();
      }
      _pusher = null;
      if (kDebugMode) print("⏹️ [REVERB] Koneksi ditutup bersih.");
    } catch (e) {
      if (kDebugMode) print("💥 [REVERB] Gagal disconnect: $e");
      _pusher = null;
      _isConnected = false;
      _isConnecting = false;
    }
  }
}