import 'package:flutter/material.dart';

class HomeScreenContent extends StatefulWidget {
  const HomeScreenContent({super.key});

  @override
  State<HomeScreenContent> createState() => _HomeScreenContentState();
}

class _HomeScreenContentState extends State<HomeScreenContent> {
  // Indeks kategori yang sedang aktif (All Menu = 0)
  int _selectedCategoryIndex = 0;

  // Data dummy Kategori: [Nama, Ikon]
  final List<List<dynamic>> categories = [
    ['All Menu', Icons.restaurant_menu],
    ['Sushi', Icons.bento_outlined],
    ['Fried Rice', Icons.rice_bowl_outlined],
    ['Noodle', Icons.ramen_dining_outlined],
    ['Steak', Icons.set_meal_outlined],
    ['Snack', Icons.fastfood_outlined],
  ];

  // Data dummy Produk: [Nama, Deskripsi, Harga, Ikon]
  final List<List<dynamic>> products = [
    ['Nasi Goreng Ayam', 'Dengan telur mata sapi...', 25000, Icons.rice_bowl],
    ['Sushi Roll Salmon', 'Fresh salmon & nori...', 45000, Icons.bento],
    ['Mie Goreng Spesial', 'Porsi besar topping lengkap...', 22000, Icons.ramen_dining],
    ['Beef Steak BBQ', 'Daging sapi sirloin 200g...', 85000, Icons.set_meal],
    ['Kentang Goreng', 'Renyah dengan bumbu peri-peri...', 15000, Icons.fastfood],
    ['Ayam Bakar Madu', 'Ayam kampung bakar bumbu...', 35000, Icons.outdoor_grill],
  ];

  // Fungsi pembantu format rupiah
  String formatRupiah(int price) {
    return "Rp ${price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // Latar belakang abu-abu sangat muda (seperti desain dashboard)
      color: const Color(0xFFF8F9FA), 
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER HALAMAN ---
            const Text(
              'Categories',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),

            // --- LIST KATEGORI (HORIZONTAL) ---
            SizedBox(
              height: 45,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  bool isActive = _selectedCategoryIndex == index;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategoryIndex = index),
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: isActive ? Colors.blue : Colors.white,
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: isActive ? Colors.blue : Colors.grey.shade300,
                        ),
                        boxShadow: isActive ? [
                          BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))
                        ] : [],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            categories[index][1],
                            color: isActive ? Colors.white : Colors.grey.shade600,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            categories[index][0],
                            style: TextStyle(
                              color: isActive ? Colors.white : Colors.black87,
                              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                              fontFamily: 'Poppins',
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 30),

            // --- GRID PRODUK ---
            Expanded(
              child: GridView.builder(
                // MaxCrossAxisExtent membuat grid adaptif (bisa menyesuaikan lebar layar)
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 250, 
                  childAspectRatio: 0.75,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                ),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  return _buildProductCard(
                    name: products[index][0],
                    desc: products[index][1],
                    price: products[index][2],
                    icon: products[index][3],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGET KARTU PRODUK (MINIMALIS & ELEGANT) ---
  Widget _buildProductCard({
    required String name,
    required String desc,
    required int price,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bagian Atas (Ilustrasi Produk)
          Expanded(
            flex: 5,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Center(
                child: Icon(icon, size: 60, color: Colors.blue.shade300),
              ),
            ),
          ),
          
          // Bagian Bawah (Info & Tombol)
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        desc,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                          fontFamily: 'Poppins',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        formatRupiah(price),
                        style: const TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      Container(
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(6.0),
                          child: Icon(Icons.add, color: Colors.white, size: 18),
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
    );
  }
}