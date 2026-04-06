import 'package:flutter/material.dart';
import '../widgets/hover_scale.dart';
import '../widgets/checkout_dialog.dart'; // Pastikan path ini benar

// --- 1. MODEL DATA ---
class CategoryModel {
  final String name;
  final IconData icon;
  CategoryModel(this.name, this.icon);
}

class ProductModel {
  final String name;
  final String desc;
  final int price; // Gunakan int agar sinkron dengan CheckoutDialog
  final String imageUrl;
  ProductModel({
    required this.name,
    required this.desc,
    required this.price,
    required this.imageUrl,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedCategoryIndex = 0;

  // --- 2. STATE KERANJANG (CART) ---
  final Map<String, Map<String, dynamic>> _cart = {};

  final List<CategoryModel> _categories = [
    CategoryModel("All Menu", Icons.restaurant_menu),
    CategoryModel("Sushi", Icons.view_module),
    CategoryModel("Fried Rice", Icons.rice_bowl),
    CategoryModel("Noodle", Icons.ramen_dining),
    CategoryModel("Steak", Icons.kebab_dining),
  ];

  final List<ProductModel> _products = [
    ProductModel(
      name: "Nasi Goreng Ayam",
      desc: "Special fried rice",
      price: 50000,
      imageUrl:
          "https://images.unsplash.com/photo-1603133872878-684f208fb84b?q=80&w=400",
    ),
    ProductModel(
      name: "Salmon Sushi",
      desc: "Fresh salmon roll",
      price: 85000,
      imageUrl:
          "https://images.unsplash.com/photo-1579871494447-9811cf80d66c?q=80&w=400",
    ),
    ProductModel(
      name: "Mie Goreng Jawa",
      desc: "Spicy egg noodle",
      price: 45000,
      imageUrl:
          "https://images.unsplash.com/photo-1585032226651-759b368d7246?q=80&w=400",
    ),
    ProductModel(
      name: "Beef Sirloin",
      desc: "Juicy steak 200gr",
      price: 150000,
      imageUrl:
          "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?q=80&w=400",
    ),
    ProductModel(
      name: "French Fries",
      desc: "Crispy fries",
      price: 30000,
      imageUrl:
          "https://images.unsplash.com/photo-1518013034841-59b1b10d0508?q=80&w=400",
    ),
    ProductModel(
      name: "Iga Bakar",
      desc: "Sweet honey ribs",
      price: 120000,
      imageUrl:
          "https://images.unsplash.com/photo-1544025162-d76694265947?q=80&w=400",
    ),
  ];

  // --- 3. LOGIKA KERANJANG & CHECKOUT ---
  void _addToCart(ProductModel product) {
    setState(() {
      if (_cart.containsKey(product.name)) {
        _cart[product.name]!['qty']++;
      } else {
        _cart[product.name] = {'price': product.price, 'qty': 1};
      }
    });
  }

  int _calculateTotal() {
    int total = 0;
    _cart.forEach(
      (key, value) => total += (value['price'] as int) * (value['qty'] as int),
    );
    return total;
  }

  String _formatCurrency(int value) {
    return "Rp ${value.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}";
  }

  void _showCheckout() {
    if (_cart.isEmpty) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CheckoutDialog(
        cart: _cart,
        totalAmount: _calculateTotal(),
        orderId:
            "ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}",
        tableNumber: "Table 05",
        formatCurrency: _formatCurrency,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Responsivitas: Jika layar lebar (navbar tutup), pakai 6 kolom. Jika sempit, 5 kolom.
    double width = MediaQuery.of(context).size.width;
    int columns = width > 1150 ? 6 : 5;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      floatingActionButton: _cart.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _showCheckout,
              backgroundColor: Colors.blue,
              icon: const Icon(
                Icons.shopping_cart_checkout,
                color: Colors.white,
              ),
              label: Text(
                "Pay Bill (${_formatCurrency(_calculateTotal())})",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Categories",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 15),
            _buildCategoryList(),
            const SizedBox(height: 25),
            Expanded(
              child: GridView.builder(
                itemCount: _products.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  childAspectRatio: 0.85,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemBuilder: (context, index) =>
                    _buildProductCard(_products[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryList() {
    return SizedBox(
      height: 45,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          bool isActive = _selectedCategoryIndex == index;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: HoverScale(
              child: GestureDetector(
                onTap: () => setState(() => _selectedCategoryIndex = index),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.blue : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isActive ? Colors.blue : Colors.grey.shade200,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      _categories[index].name,
                      style: TextStyle(
                        color: isActive ? Colors.white : Colors.black87,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductCard(ProductModel product) {
    int qty = _cart[product.name]?['qty'] ?? 0;

    return HoverScale(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5),
          ],
        ),
        child: Column(
          children: [
            // GAMBAR KONSISTEN
            Expanded(
              flex: 5,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: double.infinity,
                      child: Image.network(product.imageUrl, fit: BoxFit.cover),
                    ),
                  ),
                  if (qty > 0)
                    Positioned(
                      top: 5,
                      right: 5,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          "$qty",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // INFO PRODUK
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          product.desc,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 9,
                          ),
                          maxLines: 1,
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatCurrency(product.price),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                            color: Colors.blue,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _addToCart(product),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
