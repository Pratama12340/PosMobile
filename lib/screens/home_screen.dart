import 'package:flutter/material.dart';
import '../widgets/hover_scale.dart';
import '../widgets/checkout_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedCategoryIndex = 0;
  final Map<String, Map<String, dynamic>> _cart = {};

  // Data Produk Dummy
  final List<Map<String, dynamic>> _products = [
    {"name": "Nasi Goreng Ayam", "price": 5.0, "img": "https://images.unsplash.com/photo-1603133872878-684f208fb84b?q=80&w=400"},
    {"name": "Nasi Goreng Udang", "price": 5.0, "img": "https://images.unsplash.com/photo-1579871494447-9811cf80d66c?q=80&w=400"},
    {"name": "Nasi Goreng Jawa", "price": 5.0, "img": "https://images.unsplash.com/photo-1585032226651-759b368d7246?q=80&w=400"},
    {"name": "Nasi Goreng Ayam", "price": 5.0, "img": "https://images.unsplash.com/photo-1603133872878-684f208fb84b?q=80&w=400"},
  ];

  void _addToCart(Map<String, dynamic> p) {
    setState(() {
      if (_cart.containsKey(p['name'])) {
        _cart[p['name']]!['qty']++;
      } else {
        _cart[p['name']] = {'price': p['price'], 'qty': 1, 'notes': ''};
      }
    });
  }

  void _updateQty(String name, int delta) {
    setState(() {
      _cart[name]!['qty'] += delta;
      if (_cart[name]!['qty'] <= 0) _cart.remove(name);
    });
  }

  double _calculateTotal() {
    double total = 0;
    _cart.forEach((k, v) => total += v['price'] * v['qty']);
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Row(
        children: [
          // ==========================================
          // SISI KIRI: MENU & CATEGORIES
          // ==========================================
          Expanded(
            // Jika keranjang kosong, flex akan mengambil seluruh layar
            flex: 1, 
            child: Padding(
              padding: const EdgeInsets.all(25.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Categories", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  _buildCategoryList(),
                  const SizedBox(height: 30),
                  Expanded(
                    child: GridView.builder(
                      itemCount: 12, // Contoh jumlah item
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        // Jika sidebar muncul (keranjang isi), kolom jadi 4. Jika tutup, jadi 6.
                        crossAxisCount: _cart.isNotEmpty ? 4 : 6,
                        childAspectRatio: 0.75,
                        crossAxisSpacing: 15,
                        mainAxisSpacing: 15,
                      ),
                      itemBuilder: (context, index) => _buildProductCard(_products[index % 3]),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ==========================================
          // SISI KANAN: SIDEBAR CHECKOUT (Hanya muncul jika ada pesanan)
          // ==========================================
          if (_cart.isNotEmpty) // <--- KUNCI PERUBAHAN DI SINI
            Container(
              width: 380,
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)], // Tambah shadow agar tegas
                border: Border(left: BorderSide(color: Color(0xFFEEEEEE))),
              ),
              child: Column(
                children: [
                  _buildCartHeader(),
                  Expanded(child: _buildCartList()),
                  _buildCartFooter(),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // --- WIDGET HELPER SISI KIRI ---
  Widget _buildCategoryList() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: ["All Menu", "Sushi", "Fried Rice", "Noodle", "Steak"].map((cat) {
          bool isSelected = cat == "All Menu";
          return Container(
            margin: const EdgeInsets.only(right: 10),
            child: FilterChip(
              label: Text(cat),
              selected: isSelected,
              onSelected: (v) {},
              backgroundColor: Colors.white,
              selectedColor: const Color(0xFF4285F4).withOpacity(0.1),
              labelStyle: TextStyle(color: isSelected ? Colors.blue : Colors.black),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> p) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: Image.network(p['img'], fit: BoxFit.cover, width: double.infinity),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const Text("Comes with a Vegetable Sauce", style: TextStyle(color: Colors.grey, fontSize: 10)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("\$${p['price']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                    GestureDetector(
                      onTap: () => _addToCart(p),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                        child: const Icon(Icons.add, color: Colors.white, size: 18),
                      ),
                    )
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  // --- WIDGET HELPER SIDEBAR KERANJANG ---
  Widget _buildCartHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("#ORD-001", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text("Cashier : Siti Fatimah", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              Text("27 Maret 2025, 14:12", style: TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
          const Text("No. Table :", style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildCartList() {
    return ListView.builder(
      itemCount: _cart.length,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemBuilder: (context, index) {
        String name = _cart.keys.elementAt(index);
        var item = _cart[name]!;
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Text("\$${item['price']}", style: const TextStyle(color: Colors.grey, fontSize: 11)),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(onPressed: () => _updateQty(name, -1), icon: const Icon(Icons.remove_circle, color: Colors.blue)),
                      Text("${item['qty']}"),
                      IconButton(onPressed: () => _updateQty(name, 1), icon: const Icon(Icons.add_circle, color: Colors.blue)),
                    ],
                  )
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: "Notes",
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      ),
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(onPressed: () => setState(() => _cart.remove(name)), icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCartFooter() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey[200]!))),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Total", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              Text("\$${_calculateTotal().toStringAsFixed(1)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                // Panggil Dialog Pembayaran yang lama di sini
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4285F4), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text("Checkout", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }
}