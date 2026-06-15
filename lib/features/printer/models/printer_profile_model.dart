class PrinterProfile {
  final String id;
  final String name;
  final String type; // e.g., "Thermal Printer", "Impact Printer"
  final String mode; // e.g., "Standard Printing", "Esc/Pos Mode"
  final String conn; // e.g., "Network Printer", "Bluetooth Printer"
  final String ip; // e.g., "192.168.1.45"
  final int port; // e.g., 9100
  final int charsPerLine; // e.g., 48 or 32
  final bool isAutoCut;
  final bool isActive;
  final String stationId; // "all" for cashier/all items, or specific stationId from API
  final String stationName; // e.g., "Kasir (Semua Item)", "Dapur", "Bar"

  PrinterProfile({
    required this.id,
    required this.name,
    required this.type,
    required this.mode,
    required this.conn,
    required this.ip,
    required this.port,
    required this.charsPerLine,
    required this.isAutoCut,
    required this.isActive,
    required this.stationId,
    required this.stationName,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'mode': mode,
      'conn': conn,
      'ip': ip,
      'port': port,
      'charsPerLine': charsPerLine,
      'isAutoCut': isAutoCut,
      'isActive': isActive,
      'stationId': stationId,
      'stationName': stationName,
    };
  }

  factory PrinterProfile.fromJson(Map<String, dynamic> json) {
    return PrinterProfile(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString() ?? 'Thermal Printer',
      mode: json['mode']?.toString() ?? 'Esc/Pos Mode',
      conn: json['conn']?.toString() ?? 'Network Printer',
      ip: json['ip']?.toString() ?? '',
      port: int.tryParse(json['port']?.toString() ?? '9100') ?? 9100,
      charsPerLine: int.tryParse(json['charsPerLine']?.toString() ?? '48') ?? 48,
      isAutoCut: json['isAutoCut'] == true || json['isAutoCut'] == 'true',
      isActive: json['isActive'] == true || json['isActive'] == 'true',
      stationId: json['stationId']?.toString() ?? 'all',
      stationName: json['stationName']?.toString() ?? 'Kasir (Semua Item)',
    );
  }
}
