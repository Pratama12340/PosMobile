import 'package:flutter/material.dart';
import '../widgets/hover_scale.dart';
import '../widgets/checkout_dialog.dart';
import '../style.dart'; 

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedCategoryIndex = 0;
  final Map<String, Map<String, dynamic>> _cart = {};
  
  // 1. TAMBAHKAN CONTROLLER DAN LIST HASIL FILTER
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredProducts = [];

  // Data Produk Dummy
  final List<Map<String, dynamic>> _products = [
    {"name": "Nasi Goreng Ayam", "price": 25000.0, "img": "https://images.unsplash.com/photo-1603133872878-684f208fb84b?q=80&w=400"},
    {"name": "Nasi Goreng Udang", "price": 30000.0, "img": "https://images.unsplash.com/photo-1579871494447-9811cf80d66c?q=80&w=400"},
    {"name": "Nasi Goreng Jawa", "price": 22000.0, "img": "https://images.unsplash.com/photo-1585032226651-759b368d7246?q=80&w=400"},
    {"name": "Mie Goreng Spesial", "price": 20000.0, "img": "https://images.unsplash.com/photo-1585032226651-759b368d7246?q=80&w=400"},
    {"name": "Es Teh Manis", "price": 5000.0, "img": "https://images.unsplash.com/photo-1556679343-c7306c1976bc?q=80&w=400"},
  ];

  @override
  void initState() {
    super.initState();
    // Set awal: tampilkan semua produk
    _filteredProducts = _products;
  }

  // 2. FUNGSI LOGIKA PENCARIAN
  void _filterSearch(String query) {
    setState(() {
      _filteredProducts = _products
          .where((product) => product['name'].toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

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
      backgroundColor: AppStyle.bgLightBlue,
      body: Row(
        children: [
          Expanded(
            flex: 1, 
            child: Padding(
              padding: const EdgeInsets.all(25.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 3. UI SEARCH BAR
                  _buildSearchBar(),
                  const SizedBox(height: 20),
                  _buildCategoryList(),
                  const SizedBox(height: 30),
                  
                  // TAMPILKAN PRODUK HASIL FILTER
                  Expanded(
                    child: _filteredProducts.isEmpty 
                    ? _buildEmptySearch()
                    : GridView.builder(
                        itemCount: _filteredProducts.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: _cart.isNotEmpty ? 4 : 5,
                          childAspectRatio: 0.72,
                          crossAxisSpacing: 15,
                          mainAxisSpacing: 15,
                        ),
                        itemBuilder: (context, index) => _buildProductCard(_filteredProducts[index]),
                      ),
                  ),
                ],
              ),
            ),
          ),

          if (_cart.isNotEmpty) 
            Container(
              width: 380,
              decoration: BoxDecoration(
                color: AppStyle.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                border: const Border(left: BorderSide(color: Color(0xFFEEEEEE))),
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

  // --- WIDGET SEARCH BAR ---
  Widget _buildSearchBar() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: AppStyle.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _filterSearch, // PANGGIL FUNGSI FILTER SAAT MENGETIK
        style: AppStyle.menuText,
        decoration: InputDecoration(
          hintText: "Cari menu makanan atau minuman...",
          hintStyle: AppStyle.subTitleText,
          prefixIcon: const Icon(Icons.search, color: AppStyle.primaryBlue),
          suffixIcon: _searchController.text.isNotEmpty 
            ? IconButton(
                icon: const Icon(Icons.clear, size: 20), 
                onPressed: () {
                  _searchController.clear();
                  _filterSearch('');
                }
              ) 
            : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }

  Widget _buildEmptySearch() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 10),
          Text("Menu tidak ditemukan", style: AppStyle.subTitleText),
        ],
      ),
    );
  }

  // (Widget helper lainnya seperti _buildCategoryList, _buildProductCard, dll tetap sama)
  // Pastikan di _buildProductCard menggunakan data p['name'] dan p['price']
  Widget _buildProductCard(Map<String, dynamic> p) {
    return Container(
      decoration: BoxDecoration(
        color: AppStyle.white,
        borderRadius: BorderRadius.circular(20),
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
                Text(p['name'], style: AppStyle.menuText.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Rp ${p['price'].toInt()}", style: AppStyle.priceText.copyWith(fontSize: 14)),
                    GestureDetector(
                      onTap: () => _addToCart(p),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: AppStyle.primaryBlue, shape: BoxShape.circle),
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

  // (Sisa widget _buildCartHeader, _buildCartList, _buildCartFooter tetap sama seperti sebelumnya)
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
              backgroundColor: AppStyle.white,
              selectedColor: AppStyle.primaryBlue.withOpacity(0.1),
              labelStyle: TextStyle(
                color: isSelected ? AppStyle.primaryBlue : AppStyle.textMain, 
                fontFamily: AppStyle.fontPoppins,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isSelected ? AppStyle.primaryBlue : Colors.grey.shade300)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCartHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("#ORD-001", style: AppStyle.subTitleText.copyWith(fontWeight: FontWeight.bold, color: AppStyle.primaryBlue)),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Cashier : Siti Fatimah", style: AppStyle.menuText.copyWith(fontSize: 12, fontWeight: FontWeight.bold)),
              Text("06 April 2026", style: AppStyle.subTitleText.copyWith(fontSize: 10)),
            ],
          ),
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
                        Text(name, style: AppStyle.menuText.copyWith(fontWeight: FontWeight.bold, fontSize: 13)),
                        Text("Rp ${item['price'].toInt()}", style: AppStyle.priceText.copyWith(fontSize: 11, color: AppStyle.textGrey)),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(onPressed: () => _updateQty(name, -1), icon: const Icon(Icons.remove_circle, color: AppStyle.primaryBlue)),
                      Text("${item['qty']}", style: AppStyle.numPadText.copyWith(fontSize: 16)),
                      IconButton(onPressed: () => _updateQty(name, 1), icon: const Icon(Icons.add_circle, color: AppStyle.primaryBlue)),
                    ],
                  )
                ],
              ),
              TextField(
                decoration: InputDecoration(
                  hintText: "Notes",
                  hintStyle: AppStyle.subTitleText,
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                ),
                style: AppStyle.menuText.copyWith(fontSize: 11),
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
      decoration: BoxDecoration(color: AppStyle.white, border: Border(top: BorderSide(color: Colors.grey[200]!))),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Total", style: AppStyle.menuText.copyWith(color: AppStyle.textGrey)),
              Text("Rp ${_calculateTotal().toInt()}", style: AppStyle.priceText.copyWith(fontSize: 22)),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(backgroundColor: AppStyle.primaryBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text("Checkout", style: AppStyle.buttonText),
            ),
          )
        ],
      ),
    );
  }
}