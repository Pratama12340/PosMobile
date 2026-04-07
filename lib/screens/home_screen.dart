import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; 
import '../style.dart'; 
import '../services/storage_service.dart';
import '../services/api_service.dart';
import '../models/product_models.dart'; 
import '../models/order_model.dart'; 
import '../widgets/cart_panel.dart';
import 'SuccessPaymentPage.dart'; // Pastikan import ini tidak hilang

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

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
  String _cashierName = "Cashier";

  String formatHarga(double price) {
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(price);
  }

  @override
  void initState() {
    super.initState();
    _loadInitialData(); 
  }

  Future<void> _loadInitialData() async {
    try {
      final results = await Future.wait([
        ApiService.getCategories(),
        ApiService.getProducts(),
        StorageService.getCashierName(),
      ]);
      setState(() {
        _categories = results[0] as List;
        _allProducts = results[1] as List<Product>;
        _cashierName = results[2] as String;
        _filteredProducts = _allProducts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // --- PERBAIKAN: FUNGSI INI HARUS LENGKAP AGAR TIDAK TERPUTUS ---
  void _handleCheckoutSuccess(Map<String, dynamic> result) {
    // 1. Simpan snapshot keranjang sebelum dihapus
    final cartSnapshot = Map<int, OrderItem>.from(_cart);
    final String currentCashier = _cashierName;

    // 2. Bersihkan keranjang di HomeScreen
    setState(() => _cart.clear());

    // 3. Pindah ke halaman sukses dengan data lengkap
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SuccessPaymentPage(
          orderId: result['orderId'],
          paymentMethod: result['paymentMethod'],
          grandTotal: (result['grandTotal'] as num).toDouble(),
          amountPaid: (result['amountPaid'] as num).toDouble(),
          change: (result['change'] as num).toDouble(),
          cart: cartSnapshot,
          tableNumber: result['tableNumber'] ?? "-",
          cashierName: currentCashier,
          formatCurrency: formatHarga,
        ),
      ),
    );
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
                  padding: const EdgeInsets.all(25.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTopSection(),
                      const SizedBox(height: 25),
                      Expanded(
                        child: GridView.builder(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: _cart.isNotEmpty ? 4 : 5, 
                            childAspectRatio: 0.72,
                            crossAxisSpacing: 15,
                            mainAxisSpacing: 15,
                          ),
                          itemCount: _filteredProducts.length,
                          itemBuilder: (context, index) => _buildProductCard(_filteredProducts[index]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Cart Panel hanya muncul jika ada item
              if (_cart.isNotEmpty)
                CartPanel(
                  cart: _cart,
                  cashierName: _cashierName, // Gunakan variabel state
                  formatCurrency: formatHarga,
                  onIncrease: (item) => setState(() => item.quantity++),
                  onDecrease: (id) => setState(() {
                    if (_cart[id]!.quantity > 1) _cart[id]!.quantity--;
                    else _cart.remove(id);
                  }),
                  onDelete: (id) => setState(() => _cart.remove(id)),
                  onCheckoutSuccess: _handleCheckoutSuccess, // Hubungkan ke fungsi di atas
                ),
            ],
          ),
    );
  }

  // ... (Widget _buildTopSection, _buildCategoryChip, dan _buildProductCard tetap sama seperti desain sebelumnya)
  
  Widget _buildTopSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 55,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
          ),
          child: const TextField(
            decoration: InputDecoration(
              hintText: "Cari menu makanan atau minuman...",
              prefixIcon: Icon(Icons.search, color: AppStyle.primaryBlue),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 18),
            ),
          ),
        ),
        const SizedBox(height: 20),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildCategoryChip("All Menu"),
              ..._categories.map((cat) => _buildCategoryChip(cat['name'].toString())).toList(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryChip(String label) {
    bool isSelected = _selectedCategory == label;
    return Container(
      margin: const EdgeInsets.only(right: 10),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (val) {
          setState(() {
            _selectedCategory = label;
            _filteredProducts = label == "All Menu" 
                ? _allProducts 
                : _allProducts.where((p) => p.category == label).toList();
          });
        },
        selectedColor: const Color(0xFFE8F0FE),
        backgroundColor: Colors.white,
        labelStyle: TextStyle(
          color: isSelected ? AppStyle.primaryBlue : AppStyle.textMain,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(50),
          side: BorderSide(color: isSelected ? AppStyle.primaryBlue : const Color(0xFFEEEEEE)),
        ),
        showCheckmark: false,
      ),
    );
  }

  Widget _buildProductCard(Product p) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: Image.network(p.image, fit: BoxFit.cover, width: double.infinity, 
                errorBuilder: (c, e, s) => const Center(child: Icon(Icons.broken_image))),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1),
                const Text("Varian special menu", style: TextStyle(color: Colors.grey, fontSize: 10)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(formatHarga(p.price.toDouble()), style: const TextStyle(color: AppStyle.primaryBlue, fontWeight: FontWeight.bold)),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          if (_cart.containsKey(p.id)) _cart[p.id]!.quantity++;
                          else _cart[p.id] = OrderItem(itemName: p.name, quantity: 1, unitPrice: p.price.toDouble());
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(color: AppStyle.primaryBlue, shape: BoxShape.circle),
                        child: const Icon(Icons.add, color: Colors.white, size: 16),
                      ),
                    ),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}