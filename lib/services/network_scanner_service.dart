import 'dart:async';
import 'dart:io';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// Hasil scan berisi IP dan port yang terbuka
class ScanResult {
  final String ip;
  final int port;
  final String? hostname;
  ScanResult({required this.ip, required this.port, this.hostname});

  @override
  String toString() => '$ip:$port';
}

class NetworkScannerService {
  // Port yang umum digunakan printer thermal jaringan
  static const List<int> printerPorts = [9100, 515, 631];

  /// Mendapatkan IP lokal perangkat (IPv4 non-loopback, prefer WiFi/eth)
  ///
  /// Android kadang mengembalikan IP dari interface virtual (VPN, hotspot, dll).
  /// Fungsi ini memprioritaskan interface bernama wlan*/eth*/en*/ap* untuk
  /// memastikan kita mendapatkan IP WiFi yang sesungguhnya.
  static Future<String?> getLocalIp() async {
    try {
      // 1. Meminta izin lokasi secara dinamis (Wajib di Android untuk akses WiFi IP)
      if (Platform.isAndroid || Platform.isIOS) {
        var status = await Permission.location.status;
        if (!status.isGranted) {
          status = await Permission.location.request();
        }

        // 2. Jika diizinkan, gunakan plugin network_info_plus untuk mendapatkan IP asli WiFi
        if (status.isGranted) {
          final info = NetworkInfo();
          final wifiIp = await info.getWifiIP();
          if (wifiIp != null && wifiIp.isNotEmpty && wifiIp != '0.0.0.0') {
            return wifiIp;
          }
        }
      }

      // Fallback: Jika tidak diizinkan atau network_info_plus gagal, gunakan NetworkInterface bawaan Dart
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        includeLinkLocal: false,
        type: InternetAddressType.IPv4,
      );

      // Prioritas 1: cari interface wlan/wifi/eth/en (interface fisik)
      final preferredPrefixes = ['wlan', 'eth', 'en', 'ap'];
      for (final prefix in preferredPrefixes) {
        for (var interface in interfaces) {
          if (interface.name.toLowerCase().startsWith(prefix)) {
            for (var addr in interface.addresses) {
              if (!addr.isLoopback) {
                return addr.address;
              }
            }
          }
        }
      }

      // Fallback: ambil IP pertama yang valid dan bukan 127.x.x.x
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (!addr.isLoopback && !addr.address.startsWith('127.')) {
            return addr.address;
          }
        }
      }
    } catch (e) {
      // ignore
    }
    return null;
  }

  /// Scan subnet lokal untuk mencari perangkat yang membuka salah satu port printer.
  ///
  /// Mengembalikan list [ScanResult] yang berisi IP dan port yang merespons.
  /// Timeout dinaikkan menjadi 1200ms agar printer thermal yang lambat dapat terdeteksi.
  static Future<List<ScanResult>> scanLocalNetwork({
    List<int> ports = printerPorts,
    Duration timeout = const Duration(milliseconds: 1200),
    int concurrencyLimit = 20, // lebih konservatif agar stabil di Android
    void Function(int scanned, int total)? onProgress,
  }) async {
    final String? localIp = await getLocalIp();
    if (localIp == null) return [];

    final List<String> parts = localIp.split('.');
    if (parts.length != 4) return [];

    final String subnet = '${parts[0]}.${parts[1]}.${parts[2]}.';
    final List<ScanResult> results = [];

    // Buat daftar semua task: 254 host × N port
    final List<({String ip, int port})> tasks = [
      for (int host = 1; host <= 254; host++)
        for (final port in ports)
          (ip: '$subnet$host', port: port),
    ];

    // Skip IP perangkat itu sendiri
    final filteredTasks = tasks.where((t) => t.ip != localIp).toList();
    final total = filteredTasks.length;
    int scanned = 0;

    // Proses dalam batch untuk membatasi koneksi serentak
    for (int i = 0; i < filteredTasks.length; i += concurrencyLimit) {
      final end = (i + concurrencyLimit < filteredTasks.length)
          ? i + concurrencyLimit
          : filteredTasks.length;
      final batch = filteredTasks.sublist(i, end);

      final futures = batch.map((task) async {
        try {
          final socket = await Socket.connect(
            task.ip,
            task.port,
            timeout: timeout,
          );
          socket.destroy();
          // Printer ditemukan — tambahkan ke hasil jika IP belum ada
          // (prioritaskan port 9100 tapi jangan duplikat IP dengan port berbeda)
          final alreadyFound = results.any((r) => r.ip == task.ip);
          if (!alreadyFound) {
            String? hostname;
            try {
              // Coba deteksi nama printer dari network hostname
              final address = await InternetAddress(task.ip)
                  .reverse()
                  .timeout(const Duration(milliseconds: 500));
              hostname = address.host;
              if (hostname == task.ip) hostname = null; // Jika tidak ada nama aslinya
            } catch (_) {}

            results.add(ScanResult(ip: task.ip, port: task.port, hostname: hostname));
          }
        } catch (_) {
          // Host tidak merespons — normal
        } finally {
          scanned++;
          onProgress?.call(scanned, total);
        }
      }).toList();

      await Future.wait(futures);
    }

    // Urutkan berdasarkan oktet terakhir IP secara numerik
    results.sort((a, b) {
      final aLast = int.tryParse(a.ip.split('.').last) ?? 0;
      final bLast = int.tryParse(b.ip.split('.').last) ?? 0;
      return aLast.compareTo(bLast);
    });

    return results;
  }

  /// Cek apakah sebuah printer (IP + port) masih bisa dihubungi.
  /// Digunakan untuk pengecekan status Online/Offline pada daftar printer.
  static Future<bool> isPrinterOnline(String ip, int port) async {
    try {
      final socket = await Socket.connect(
        ip,
        port,
        timeout: const Duration(milliseconds: 2000),
      );
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Melakukan PING ICMP menggunakan command bawaan OS (Android/Linux).
  /// Ini mendeteksi *semua* perangkat yang aktif di jaringan, bukan hanya printer.
  static Future<bool> pingDevice(String ip) async {
    if (!Platform.isAndroid && !Platform.isLinux && !Platform.isMacOS) {
      // Windows menggunakan syntax ping yang berbeda, tapi karena request khusus Android,
      // kita fokus ke argumen command Unix.
      return false; 
    }
    try {
      // -c 1 : kirim 1 paket
      // -W 1 : timeout 1 detik
      final result = await Process.run('ping', ['-c', '1', '-W', '1', ip]);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  /// Memindai seluruh subnet dengan metode PING ICMP (hanya berfungsi baik di OS berbasis Unix/Android).
  /// Mengembalikan daftar IP dari semua perangkat yang terkoneksi ke WiFi.
  static Future<List<String>> scanAllDevicesPing({
    int concurrencyLimit = 40,
    void Function(int scanned, int total)? onProgress,
  }) async {
    final String? localIp = await getLocalIp();
    if (localIp == null) return [];

    final List<String> parts = localIp.split('.');
    if (parts.length != 4) return [];

    final String subnet = '${parts[0]}.${parts[1]}.${parts[2]}.';
    final List<String> results = [];
    final List<String> tasks = [
      for (int host = 1; host <= 254; host++) '$subnet$host',
    ];

    final total = tasks.length;
    int scanned = 0;

    for (int i = 0; i < tasks.length; i += concurrencyLimit) {
      final end = (i + concurrencyLimit < tasks.length) ? i + concurrencyLimit : tasks.length;
      final batch = tasks.sublist(i, end);

      final futures = batch.map((ip) async {
        final isAlive = await pingDevice(ip);
        if (isAlive && ip != localIp) {
          results.add(ip);
        }
        scanned++;
        onProgress?.call(scanned, total);
      }).toList();

      await Future.wait(futures);
    }

    results.sort((a, b) {
      final aLast = int.tryParse(a.split('.').last) ?? 0;
      final bLast = int.tryParse(b.split('.').last) ?? 0;
      return aLast.compareTo(bLast);
    });

    return results;
  }
}
