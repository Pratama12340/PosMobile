class Product {
  final int id;
  final String name;
  final String? description;
  final int price;
  final String image;

  Product({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    required this.image,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      name: json['name'] ?? 'No Name',
      description: json['description'] ?? '',
      // Mengonversi harga dari API (yang mungkin string/double) ke int
      price: double.parse(json['price'].toString()).toInt(),
      image: json['image'] ?? '',
    );
  }
}
