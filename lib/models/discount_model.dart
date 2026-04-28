class Discount {
  final int id;
  final int? productId; // 👈 Tambahkan ini untuk mapping
  final String name;
  final String type; // 'percentage' atau 'nominal'
  final int value;
  final int minPurchase;

  Discount({
    required this.id,
    this.productId, // 👈 Tambahkan ke constructor
    required this.name,
    required this.type,
    required this.value,
    required this.minPurchase,
  });

  factory Discount.fromJson(Map<String, dynamic> json) {
    return Discount(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      // 👇 Tangkap product_id dari API diskon Anda 👇
      productId: json['product_id'] != null ? _toInt(json['product_id']) : null,
      name: json['name'] ?? 'Diskon Tanpa Nama',
      type: json['type'] ?? 'nominal',
      value: _toInt(json['value']), 
      minPurchase: _toInt(json['min_purchase']),
    );
  }

  static int _toInt(dynamic val) {
    if (val == null) return 0;
    if (val is int) return val;
    if (val is double) return val.toInt();
    return int.tryParse(val.toString()) ?? 0;
  }
}