class Discount {
  final int id;
  final String name;
  final String type; // 'percentage' atau 'nominal'
  final int value;
  final int minPurchase;

  Discount({
    required this.id,
    required this.name,
    required this.type,
    required this.value,
    required this.minPurchase,
  });

  factory Discount.fromJson(Map<String, dynamic> json) {
    return Discount(
      // Menggunakan tryParse atau .toInt() untuk jaga-jaga jika API kirim String
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      name: json['name'] ?? 'Diskon Tanpa Nama',
      type: json['type'] ?? 'nominal',
      // Laravel integer terkadang dikirim sebagai String oleh driver DB tertentu
      value: _toInt(json['value']), 
      minPurchase: _toInt(json['min_purchase']),
    );
  }

  // Helper function untuk konversi tipe data yang bandel
  static int _toInt(dynamic val) {
    if (val == null) return 0;
    if (val is int) return val;
    if (val is double) return val.toInt();
    return int.tryParse(val.toString()) ?? 0;
  }
}