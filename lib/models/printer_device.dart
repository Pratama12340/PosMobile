import 'dart:convert';

class PrinterDevice {
  final String name;
  final String status;
  final String type;
  final String conn;
  final String ip;
  final int port;
  final String stationName;
  final bool isAutoCut;
  final bool isActive;

  PrinterDevice({
    required this.name,
    required this.status,
    required this.type,
    required this.conn,
    required this.ip,
    required this.port,
    required this.stationName,
    this.isAutoCut = true,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'status': status,
    'type': type,
    'conn': conn,
    'ip': ip,
    'port': port,
    'stationName': stationName,
    'isAutoCut': isAutoCut,
    'isActive': isActive,
  };

  factory PrinterDevice.fromJson(Map<String, dynamic> json) => PrinterDevice(
    name: json['name'] ?? 'Printer Baru',
    status: json['status'] ?? 'Offline',
    type: json['type'] ?? 'Thermal Printer',
    conn: json['conn'] ?? 'Network Printer',
    ip: json['ip'] ?? '192.168.1.1',
    port: json['port'] ?? 9100,
    stationName: json['stationName'] ?? 'Semua Item',
    isAutoCut: json['isAutoCut'] ?? true,
    isActive: json['isActive'] ?? true,
  );

  static String encodeList(List<PrinterDevice> list) =>
      jsonEncode(list.map((e) => e.toJson()).toList());

  static List<PrinterDevice> decodeList(String jsonStr) {
    final List<dynamic> decoded = jsonDecode(jsonStr);
    return decoded.map((e) => PrinterDevice.fromJson(e)).toList();
  }
}