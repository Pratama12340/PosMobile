import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../style.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart';
import '../models/product_models.dart';
import '../models/order_model.dart';
import '../widgets/cart_panel.dart';
import 'SuccessPaymentPage.dart';
import 'package:sistem_pos/widgets/opening_cash_dialog.dart'; // Import file dialog kas awal

class HomeScreen extends StatefulWidget {
  final TextEditingController searchController;
  const HomeScreen({super.key, required this.searchController});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Map<int, OrderItem> _cart = {};
  final List<Map<int, OrderItem>> _drafts = [];

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
    
    // PEMICU POP-UP KAS AWAL: Muncul setelah frame pertama selesai dirender
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowOpeningCash();
    });
  }

  // Fungsi untuk mengecek dan menampilkan dialog kas awal
  Future<void> _checkAndShowOpeningCash() async {
    final existingCash = await StorageService.getOpeningCash();
    if (existingCash == 0) {
      if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (context) => const OpeningCashDialog(),
    );
    
    setState(() {}); 
    }
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

  void _saveToDraft() {
    setState(() {
      if (_cart.isNotEmpty) {
        _drafts.add(Map.from(_cart));
        _cart.clear(); 
      }
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
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(child: _buildCategoryChips()), 
                          const SizedBox(width: 15),
                          if (_cart.isEmpty && _drafts.isNotEmpty)
                            _buildDraftDropdownButton(),
                        ],
                      ),
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
                  formatCurrency: formatHarga,
                  onIncrease: (item) => setState(() => item.quantity++),
                  onDecrease: (id) => setState(() {
                    if (_cart[id]!.quantity > 1) {
                      _cart[id]!.quantity--;
                    } else {
                      _cart.remove(id);
                    }
                  }),
                  onDelete: (id) => setState(() => _cart.remove(id)),
                  onCheckoutSuccess: (res) {
                    setState(() {
                      _cart.forEach((productId, cartItem) {
                        int productIndex = _allProducts.indexWhere((p) => p.id == productId);
                        if (productIndex != -1) {
                          _allProducts[productIndex].stock -= cartItem.quantity;
                          if (_allProducts[productIndex].stock < 0) _allProducts[productIndex].stock = 0;
                        }
                      });
                      _cart.clear();
                      _applyFilters();
                    });
                  },
                  onSaveDraft: _saveToDraft, 
                ),
            ],
          ),
    );
  }

  // --- WIDGET HELPERS ---

  Widget _buildDraftDropdownButton() {
    return PopupMenuButton<int>(
      tooltip: "Pilih Draft",
      offset: const Offset(0, 50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      onSelected: (int index) {
        setState(() {
          _cart.addAll(_drafts[index]);
          _drafts.removeAt(index);
        });
      },
      itemBuilder: (context) => List.generate(_drafts.length, (index) {
        int totalItems = _drafts[index].values.fold(0, (sum, item) => sum + item.quantity);
        return PopupMenuItem<int>(
          value: index,
          child: Text("Draft ${index + 1} ($totalItems Item)"),
        );
      }),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppStyle.primaryBlue, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
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
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (val) {
          setState(() { _selectedCategory = label; _applyFilters(); });
        },
        selectedColor: const Color(0xFFE8F0FE),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        showCheckmark: false,
      ),
    );
  }

  Widget _buildProductCard(Product p) {
    bool isOutOfStock = p.stock <= 0;
    String imageUrl = p.image.trim();
    if (imageUrl.isNotEmpty && !imageUrl.startsWith('http')) {
      imageUrl = "https://api.etres.my.id/storage/${imageUrl.startsWith('/') ? imageUrl.substring(1) : imageUrl}";
    }

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.network(
                imageUrl, 
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => const Icon(Icons.fastfood, size: 50, color: Colors.grey),
              ),
            ),
            Positioned.fill(child: Container(color: Colors.black.withOpacity(0.3))),
            Positioned(
              top: 10, right: 10,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: isOutOfStock ? Colors.red : AppStyle.primaryBlue, borderRadius: BorderRadius.circular(8)),
                child: Text(isOutOfStock ? "HABIS" : "STOK: ${p.stock}", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ),
            Positioned(
              bottom: 15, left: 15, right: 15,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(p.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), maxLines: 1),
                        Text(formatHarga(p.price.toDouble()), style: const TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: isOutOfStock ? null : () => setState(() {
                      if (_cart.containsKey(p.id)) {
                        _cart[p.id]!.quantity++;
                      } else {
                        _cart[p.id] = OrderItem(
                          id: p.id,
                          itemName: p.name, 
                          quantity: 1, 
                          unitPrice: p.price.toDouble()
                        );
                      }
                    }),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: Icon(Icons.add, color: isOutOfStock ? Colors.grey : AppStyle.primaryBlue),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}