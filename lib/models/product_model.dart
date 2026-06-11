import 'discount_model.dart';

class Product {
  final int id;
  final int? categoryId;
  final String name;
  final String? description;
  final int price;
  final String image;
  final String category;
  final String stationId;
  String stationName;
  int stock;
  Discount? discount;
  bool? isBestseller;

  Product({
    required this.id,
    this.categoryId, 
    required this.name,
    this.description,
    required this.price,
    required this.image,
    required this.category,
    required this.stock,
    this.discount,
    this.isBestseller,
    required this.stationId,
    this.stationName = "",
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      categoryId: json['category_id'] != null
          ? int.tryParse(json['category_id'].toString())
          : null,              // ← BARU
      name: json['name'] ?? 'No Name',
      description: json['description'] ?? '',
      price: double.parse(json['price'].toString()).toInt(),
      stationId: json['station_id']?.toString() ?? "Dapur",
      stationName: "",
      image: json['image'] ?? '',
      category:
          (json['category_name'] ??
                  json['category'] ??
                  json['category_id'] ??
                  'Uncategorized')
              .toString(),
      stock: json['stock'] != null
          ? int.tryParse(json['stock'].toString()) ?? 0
          : 0,
      isBestseller: json['is_bestseller'] == 1 || json['is_bestseller'] == true,
    );
  }
}
