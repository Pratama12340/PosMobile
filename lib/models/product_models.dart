class Product {
  final int id;
  final String name;
  final String? description;
  final int price;
  final String image;
  final String category; 
  Product({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    required this.image,
    required this.category,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      name: json['name'] ?? 'No Name',
      description: json['description'] ?? '',
      price: double.parse(json['price'].toString()).toInt(),
      image: json['image'] ?? '',
      category: (json['category_name'] ?? 
                 json['category'] ?? 
                 json['category_id'] ?? 
                 'Uncategorized').toString(),
    );
  }
}