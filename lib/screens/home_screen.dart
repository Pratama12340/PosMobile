import 'package:flutter/material.dart';
import '../services/api_service.dart'; 
import '../widgets/cart_panel.dart';    
import '../widgets/hover_scale.dart'; 
import '../widgets/opening_cash_dialog.dart';  

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // --- STATE UNTUK KERANJANG ---
  final Map<String, Map<String, dynamic>> _cart = {};

  // --- STATE UNTUK KATEGORI & PRODUK (DARI API) ---
  int _selectedCategoryIndex = 0;
  
  List<dynamic> _apiCategories = [];
  bool _isLoadingCategories = true;

  List<dynamic> _apiProducts = [];
  bool _isLoadingProducts = true;

  @override
  void initState() {
    super.initState();
    _loadDataKategori();
    _loadDataProduk();

    // TAMBAHKAN INI: Panggil popup setelah build selesai
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showOpeningCashDialog();
    });
  }

  // ==========================================
  // FUNGSI MENGAMBIL DATA API
  // ==========================================
  Future<void> _loadDataKategori() async {
    try {
      final data = await ApiService.fetchCategories();
      setState(() {
        _apiCategories = data;
        _isLoadingCategories = false;
      });
    } catch (e) {
      debugPrint("Kategori Error: $e");
      setState(() => _isLoadingCategories = false);
    }
  }

  Future<void> _loadDataProduk() async {
    try {
      final data = await ApiService.fetchProducts();
      setState(() {
        _apiProducts = data;
        _isLoadingProducts = false;
      });
    } catch (e) {
      debugPrint("Produk Error: $e");
      setState(() => _isLoadingProducts = false);
    }
  }

  // ==========================================
  // FUNGSI FILTER & FORMAT
  // ==========================================
  List<dynamic> get _filteredProducts {
    if (_selectedCategoryIndex == 0) return _apiProducts;
    final selectedCategoryId = _apiCategories[_selectedCategoryIndex - 1]['id'];
    return _apiProducts.where((product) {
      return product['category_id'].toString() == selectedCategoryId.toString();
    }).toList();
  }

  // Format Mata Uang untuk Tampilan
  String _formatRupiah(int price) {
    return "Rp ${price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}";
  }

  // ==========================================
  // FUNGSI UPDATE KERANJANG
  // ==========================================
  void _updateCart(String name, int price, bool add) {
    setState(() {
      if (add) {
        if (_cart.containsKey(name)) {
          _cart[name]!['qty']++;
        } else {
          _cart[name] = {'qty': 1, 'price': price};
        }
      } else {
        if (_cart.containsKey(name) && _cart[name]!['qty'] > 1) {
          _cart[name]!['qty']--;
        } else {
          _cart.remove(name);
        }
      }
    });
  }

  // ==========================================
  // BUILD UTAMA
  // ==========================================
  @override
  Widget build(BuildContext context) {
    // Tentukan Base URL Gambar dari API
    const String baseUrl = "https://api.etres.my.id/storage/products/";

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: LayoutBuilder(builder: (context, constraints) {
        bool isWide = constraints.maxWidth > 900;
        return Row(
          children: [
            // BAGIAN KIRI: KONTEN UTAMA
            Expanded(
              child: _buildMainContent(isWide, baseUrl),
            ),
            
            // BAGIAN KANAN: PANEL KERANJANG (FIX ERROR DI SINI)
            if (isWide && _cart.isNotEmpty)
              CartPanel(
                cart: _cart,
                onAdd: (name, price) => _updateCart(name, price, true),
                onRemove: (name) => _updateCart(name, 0, false), 
                onDelete: (name) => setState(() => _cart.remove(name)),
                formatCurrency: (p) => _formatRupiah(p),
              ),
          ],
        );
      }),
      // TOMBOL MENGAMBANG JIKA LAYAR KECIL (MOBILE)
      floatingActionButton: (MediaQuery.of(context).size.width <= 900 && _cart.isNotEmpty)
          ? FloatingActionButton.extended(
              onPressed: () => _showMobileCart(),
              label: Text("Orders (${_cart.length})", style: const TextStyle(fontFamily: 'Poppins')),
              icon: const Icon(Icons.shopping_basket),
            )
          : null,
    );
  }

  // ==========================================
  // KONTEN KIRI (KATEGORI & GRID PRODUK)
  // ==========================================
  Widget _buildMainContent(bool isWide, String baseUrl) {
    return Padding(
      padding: EdgeInsets.all(isWide ? 30.0 : 15.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Categories', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
          const SizedBox(height: 20),
          _buildCategoryList(),
          const SizedBox(height: 30),
          
          Expanded(
            child: _isLoadingProducts 
              ? const Center(child: CircularProgressIndicator())
              : _filteredProducts.isEmpty
                ? const Center(child: Text('Belum ada menu di kategori ini', style: TextStyle(fontFamily: 'Poppins')))
                : GridView.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 250,
                      childAspectRatio: 0.7,
                      crossAxisSpacing: 20,
                      mainAxisSpacing: 20,
                    ),
                    itemCount: _filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = _filteredProducts[index];
                      
                      return _buildItemCard(
                        name: product['name'] ?? 'Tanpa Nama',
                        desc: product['description'] ?? '-',
                        price: int.tryParse(product['price'].toString()) ?? 0,
                        imageUrl: baseUrl + (product['image'] ?? ''),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryList() {
    return SizedBox(
      height: 45,
      child: _isLoadingCategories
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _apiCategories.length + 1,
            itemBuilder: (context, index) {
              bool active = _selectedCategoryIndex == index;
              String name = index == 0 ? "All Menu" : _apiCategories[index - 1]['name'];

              return GestureDetector(
                onTap: () => setState(() => _selectedCategoryIndex = index),
                child: HoverScale(
                  child: Container(
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: active ? Colors.blue : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: active ? Colors.blue : Colors.grey.shade300)
                    ),
                    child: Center(
                      child: Text(name, style: TextStyle(color: active ? Colors.white : Colors.black, fontFamily: 'Poppins', fontWeight: active ? FontWeight.bold : FontWeight.normal)),
                    ),
                  ),
                ),
              );
            },
          ),
    );
  }

  Widget _buildItemCard({required String name, required String desc, required int price, required String imageUrl}) {
    return HoverScale(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white, 
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]
        ),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (context, error, stackTrace) => Container(color: Colors.blue.shade50, child: const Icon(Icons.fastfood, size: 40, color: Colors.blue)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins'), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(desc, style: const TextStyle(fontSize: 10, color: Colors.grey, fontFamily: 'Poppins'), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_formatRupiah(price), style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                      IconButton.filled(
                        onPressed: () => _updateCart(name, price, true), 
                        icon: const Icon(Icons.add, size: 18)
                      ),
                    ],
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  void _showMobileCart() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: CartPanel(
          cart: _cart,
          onAdd: (n, p) => _updateCart(n, p, true),
          onRemove: (n) => _updateCart(n, 0, false),
          onDelete: (n) => setState(() => _cart.remove(n)),
          formatCurrency: (p) => _formatRupiah(p),
        ),
      ),
    );
  }
  // Fungsi untuk memunculkan popup kas awal
  void _showOpeningCashDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // User tidak bisa menutup popup tanpa isi data
      builder: (context) => const CashInitialDialog(),
    );
  }
}