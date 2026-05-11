import 'discount_model.dart';

class Product {
  final int id;
  final String name;
  final String? description;
  final int price;
  final String image;
  final String category;
  int stock;
  Discount? discount;
  bool? isBestseller;

  Product({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    required this.image,
    required this.category,
    required this.stock,
    this.discount,
    this.isBestseller,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      name: json['name'] ?? 'No Name',
      description: json['description'] ?? '',
      price: double.parse(json['price'].toString()).toInt(),
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
