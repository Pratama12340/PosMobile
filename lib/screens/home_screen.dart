import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../style.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart';
import '../models/product_models.dart';
import '../models/order_model.dart';
import '../widgets/cart_panel.dart';
import 'SuccessPaymentPage.dart';

class HomeScreen extends StatefulWidget {
  final TextEditingController searchController;
  const HomeScreen({super.key, required this.searchController});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Map<int, OrderItem> _cart = {};
  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];
  List<dynamic> _categories = [];
  bool _isLoading = true;
  String _selectedCategory = "All Menu";

  String formatHarga(double price) => NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(price);

  @override
  void initState() {
    super.initState();
    widget.searchController.addListener(_applyFilters);
    _loadInitialData();
  }

  @override
  void dispose() {
    widget.searchController.removeListener(_applyFilters);
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final results = await Future.wait([ApiService.getCategories(), ApiService.getProducts()]);
      if (mounted) {
        setState(() {
          _categories = results[0] as List;
          _allProducts = results[1] as List<Product>;
          _isLoading = false;
        });
        _applyFilters();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    String query = widget.searchController.text.toLowerCase();
    setState(() {
      _filteredProducts = _allProducts.where((p) {
        bool matchCategory = _selectedCategory == "All Menu" || p.category.toLowerCase().contains(_selectedCategory.toLowerCase());
        bool matchQuery = query.isEmpty || p.name.toLowerCase().contains(query);
        return matchCategory && matchQuery;
      }).toList();
      _filteredProducts.sort((a, b) => (a.stock <= 0 && b.stock > 0) ? 1 : (a.stock > 0 && b.stock <= 0) ? -1 : 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyle.bgLightBlue,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        _buildCategoryChips(),
                        const SizedBox(height: 15),
                        Expanded(
                          child: LayoutBuilder(builder: (context, constraints) {
                            double spacing = 18.0;
                            double itemHeight = (constraints.maxHeight - spacing) / 2;
                            double itemWidth = (constraints.maxWidth - (spacing * 3)) / 4;
                            return GridView.builder(
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 4,
                                childAspectRatio: itemWidth / itemHeight,
                                crossAxisSpacing: spacing,
                                mainAxisSpacing: spacing,
                              ),
                              itemCount: _filteredProducts.length,
                              itemBuilder: (context, index) => _buildProductCard(_filteredProducts[index]),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_cart.isNotEmpty)
                  CartPanel(
                    cart: _cart,
                    cashierName: "", 
                    formatCurrency: formatHarga,
                    onIncrease: (item) => setState(() => item.quantity++),
                    onDecrease: (id) => setState(() {
                      if (_cart[id]!.quantity > 1) _cart[id]!.quantity--;
                      else _cart.remove(id);
                    }),
                    onDelete: (id) => setState(() => _cart.remove(id)),
                    onCheckoutSuccess: (res) => setState(() => _cart.clear()), 
                  ),
              ],
            ),
    );
  }

  Widget _buildCategoryChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildChip("All Menu"),
          ..._categories.map((cat) => _buildChip(cat['name'].toString())),
        ],
      ),
    );
  }

  Widget _buildChip(String label) {
    bool isSelected = _selectedCategory == label;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (val) {
          setState(() { _selectedCategory = label; _applyFilters(); });
        },
        selectedColor: const Color(0xFFE8F0FE),
        backgroundColor: Colors.white,
        labelStyle: TextStyle(color: isSelected ? AppStyle.primaryBlue : AppStyle.textMain, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50), side: BorderSide(color: isSelected ? AppStyle.primaryBlue : const Color(0xFFEEEEEE))),
        showCheckmark: false,
      ),
    );
  }

  Widget _buildProductCard(Product p) {
    bool isOutOfStock = p.stock <= 0;
    
    // Logika gambar fleksibel
    String imageUrl = p.image.trim();
    if (imageUrl.isNotEmpty && !imageUrl.startsWith('http')) {
      imageUrl = "https://api.etres.my.id/storage/${imageUrl.startsWith('/') ? imageUrl.substring(1) : imageUrl}";
    } else if (imageUrl.isEmpty) {
      imageUrl = "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?q=80&w=1000&auto=format&fit=crop";
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(25), 
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))]
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: Stack(
          children: [
            // 1. GAMBAR PRODUK (Full Card agar Proposional)
            Positioned.fill(
              child: Image.network(
                imageUrl, 
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => Container(color: Colors.grey.shade100, child: const Icon(Icons.fastfood, color: Colors.grey, size: 50)),
              ),
            ),

            // 2. GRADASI (Transparan ke Gelap)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withOpacity(0.1),
                      Colors.black.withOpacity(0.85), // Gelap di bawah
                    ],
                  ),
                ),
              ),
            ),

            // 3. LABEL STOK (Dibuat Lebih Terlihat & Tegas)
            Positioned(
              top: 15,
              right: 15,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isOutOfStock ? Colors.red : AppStyle.primaryBlue,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8)],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.inventory_2_rounded, color: Colors.white, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      isOutOfStock ? "HABIS" : "STOK: ${p.stock}",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),

            // 4. INFO PRODUK (Nama & Harga di Atas Gradasi)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.all(18.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            p.name,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20, shadows: [Shadow(color: Colors.black, blurRadius: 10)]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formatHarga(p.price.toDouble()),
                            style: const TextStyle(color: Color.fromARGB(255, 66, 133, 244), fontWeight: FontWeight.w900, fontSize: 18, shadows: [Shadow(color: Colors.black, blurRadius: 10)]),
                          ),
                        ],
                      ),
                    ),
                    
                    // TOMBOL TAMBAH (+)
                    GestureDetector(
                      onTap: isOutOfStock ? null : () => setState(() {
                        if (_cart.containsKey(p.id)) _cart[p.id]!.quantity++;
                        else _cart[p.id] = OrderItem(itemName: p.name, quantity: 1, unitPrice: p.price.toDouble());
                      }),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isOutOfStock ? Colors.grey : AppStyle.primaryBlue,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: const Color.fromRGBO(66, 133, 244, 1).withOpacity(0.4), blurRadius: 10, spreadRadius: 1)],
                        ),
                        child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
                      ),
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