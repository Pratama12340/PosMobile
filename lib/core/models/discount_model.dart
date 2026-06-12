class Discount {
  final int id;
  final String name;
  final String scope;
  final String type;
  final double value;
  final List<int> productIds;
  final List<int> categoryIds;
  final double minPurchase;
  final double? maxDiscount;
  final int? maxUsage;

  Discount({
    required this.id,
    required this.name,
    required this.scope,
    required this.type,
    required this.value,
    this.productIds = const [],
    this.categoryIds = const [],
    required this.minPurchase,
    this.maxDiscount,
    this.maxUsage,
  });

  factory Discount.fromJson(Map<String, dynamic> json) {
    return Discount(
      id: _toInt(json['id']),
      name: json['name']?.toString() ?? '',
      scope: json['scope']?.toString() ?? 'global',
      type: json['type']?.toString() ?? 'percentage',
      value: _toDouble(json['value']),
      productIds: _parseIds(json['product_ids']),
      categoryIds: _parseIds(json['category_ids']),
      minPurchase: _toDouble(json['min_purchase']),
      maxDiscount: json['max_discount'] != null
          ? _toDouble(json['max_discount'])
          : null,
      maxUsage: json['max_usage'] != null ? _toInt(json['max_usage']) : null,
    );
  }

  static List<int> _parseIds(dynamic raw) {
    if (raw == null ||
        raw.toString().toUpperCase() == 'NULL' ||
        raw.toString().trim().isEmpty) {
      return [];
    }

    try {
      if (raw is List) {
        return raw
            .map((e) => int.tryParse(e.toString()) ?? 0)
            .where((e) => e != 0)
            .toList();
      }

      String clean = raw
          .toString()
          .replaceAll('[', '')
          .replaceAll(']', '')
          .replaceAll('"', '')
          .trim();

      if (clean.isEmpty) return [];

      return clean
          .split(',')
          .map((e) => int.tryParse(e.trim()) ?? 0)
          .where((e) => e != 0)
          .toList();
    } catch (e) {
      return [];
    }
  }

  static int _toInt(dynamic val) {
    if (val == null) return 0;
    if (val is int) return val;
    return int.tryParse(val.toString()) ?? 0;
  }

  static double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is double) return val;
    if (val is int) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }
}
