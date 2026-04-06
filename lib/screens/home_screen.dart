import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; 
import '../style.dart'; 
import '../services/storage_service.dart';
import '../services/api_service.dart';
import '../models/product_models.dart'; 
import '../models/order_model.dart'; 
import '../widgets/checkout_dialog.dart'; // Pastikan import ini ada

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  
  final Map<int, OrderItem> _cart = {}; 
  List<Product> _allProducts = []; 
  List<Product> _filteredProducts = []; 
  List<dynamic> _categories = []; 
  
  bool _isLoading = true; 
  String _selectedCategory = "All Menu";
  String _cashierName = "Loading...";
  String _tableNumber = "";
  String _orderId = "";

  String formatHarga(double price) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(price);
  }

  @override
  void initState() {
    super.initState();
    _generateOrderId();
    _fetchDataDariApi(); 
  }

  void _generateOrderId() {
    String timestamp = DateFormat('yyyyMMdd-HHmm').format(DateTime.now());
    setState(() => _orderId = "ORD-$timestamp");
  }

  Future<void> _fetchDataDariApi() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        ApiService.getCategories(),
        ApiService.getProducts(),
        StorageService.getCashierName(),
      ]);

      setState(() {
        _categories       = results[0] as List<dynamic>; 
        _allProducts     = results[1] as List<Product>;
        _cashierName     = results[2] as String;
        _filteredProducts = _allProducts;
        _isLoading        = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal mengambil data: $e")),
        );
      }
    }
  }

  void _filterByCategory(String categoryName) {
    setState(() {
      _selectedCategory = categoryName;
      if (categoryName == "All Menu") {
        _filteredProducts = _allProducts;
      } else {
        _filteredProducts = _allProducts
            .where((p) => p.name.toLowerCase().contains(categoryName.toLowerCase())) 
            .toList();
      }
    });
  }

  void _filterSearch(String query) {
    setState(() {
      _filteredProducts = _allProducts
          .where((p) => p.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  void _addToCart(Product p) {
    setState(() {
      if (_cart.containsKey(p.id)) {
        _cart[p.id]!.quantity++;
      } else {
        _cart[p.id] = OrderItem(
          quantity: 1,
          itemName: p.name,
          unitPrice: p.price.toDouble(),
          notes: "",
        );
      }
    });
  }

  void _updateQty(int productId, int delta) {
    setState(() {
      if (_cart.containsKey(productId)) {
        _cart[productId]!.quantity += delta;
        if (_cart[productId]!.quantity <= 0) _cart.remove(productId);
      }
    });
  }

  double _calculateTotal() {
    double total = 0;
    _cart.forEach((id, item) => total += item.subtotal);
    return total;
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
                      _buildSearchBar(),
                      const SizedBox(height: 20),
                      _buildCategoryList(), 
                      const SizedBox(height: 30),
                      Expanded(
                        child: _filteredProducts.isEmpty
                            ? _buildEmptyState()
                            : GridView.builder(
                                itemCount: _filteredProducts.length,
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: _cart.isNotEmpty ? 4 : 5,
                                  childAspectRatio: 0.72,
                                  crossAxisSpacing: 15,
                                  mainAxisSpacing: 15,
                                ),
                                itemBuilder: (context, index) {
                                  return _buildProductCard(_filteredProducts[index]);
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_cart.isNotEmpty) _buildCheckoutSidebar(),
            ],
          ),
    );
  }

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
        onChanged: _filterSearch,
        style: AppStyle.menuText,
        decoration: InputDecoration(
          hintText: "Cari menu makanan atau minuman...",
          hintStyle: AppStyle.subTitleText,
          prefixIcon: const Icon(Icons.search, color: AppStyle.primaryBlue),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }

  Widget _buildCategoryList() {
    List<String> catNames = ["All Menu", ..._categories.map((c) => c['name'].toString())];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: catNames.map((cat) {
          bool isSelected = _selectedCategory == cat;
          return Container(
            margin: const EdgeInsets.only(right: 10),
            child: FilterChip(
              label: Text(cat),
              selected: isSelected,
              onSelected: (v) => _filterByCategory(cat),
              backgroundColor: AppStyle.white,
              selectedColor: AppStyle.primaryBlue.withOpacity(0.1),
              labelStyle: TextStyle(
                color: isSelected ? AppStyle.primaryBlue : AppStyle.textMain,
                fontFamily: AppStyle.fontPoppins,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20), 
                side: BorderSide(color: isSelected ? AppStyle.primaryBlue : Colors.grey.shade300)
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildProductCard(Product p) {
    return Container(
      decoration: BoxDecoration(
        color: AppStyle.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: Image.network(
                p.image, 
                fit: BoxFit.cover, 
                width: double.infinity,
                errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.broken_image)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name, style: AppStyle.menuText.copyWith(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text("Varian special menu", style: AppStyle.subTitleText.copyWith(fontSize: 10)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(formatHarga(p.price.toDouble()), style: AppStyle.priceText.copyWith(fontSize: 14)),
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

  Widget _buildCheckoutSidebar() {
    String formattedDate = DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now());

    return Container(
      width: 380,
      decoration: const BoxDecoration(
        color: AppStyle.white,
        border: Border(left: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: Column(
        children: [
          _buildSidebarHeader(formattedDate),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: _cart.length,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              itemBuilder: (context, index) {
                int id = _cart.keys.elementAt(index);
                OrderItem item = _cart[id]!;
                return _buildCartItem(id, item);
              },
            ),
          ),
          _buildSidebarFooter(), // Tombol Checkout sudah ada di dalam fungsi ini
        ],
      ),
    );
  }

  Widget _buildSidebarHeader(String formattedDate) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_orderId, style: AppStyle.priceText.copyWith(fontSize: 14, color: AppStyle.primaryBlue)),
              const Icon(Icons.receipt_long, color: AppStyle.primaryBlue, size: 18),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Text("Cashier : ", style: AppStyle.subTitleText.copyWith(fontSize: 12)),
              Text(_cashierName, style: AppStyle.menuText.copyWith(fontWeight: FontWeight.bold, fontSize: 12)),
              const Spacer(),
              Text(formattedDate, style: AppStyle.subTitleText.copyWith(fontSize: 10)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFEEEEEE)),
            ),
            child: Row(
              children: [
                const Icon(Icons.table_restaurant, size: 14, color: AppStyle.textGrey),
                const SizedBox(width: 8),
                Text("Table No : ", style: AppStyle.subTitleText.copyWith(fontSize: 12)),
                Expanded(
                  child: TextField(
                    onChanged: (v) => _tableNumber = v,
                    style: AppStyle.numPadText.copyWith(fontSize: 13, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(hintText: "...", border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(int productId, OrderItem item) {
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
                    Text(item.itemName, style: AppStyle.menuText.copyWith(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(formatHarga(item.unitPrice), style: AppStyle.priceText.copyWith(fontSize: 11, color: AppStyle.textGrey)),
                  ],
                ),
              ),
              Row(
                children: [
                  _qtyButton(Icons.remove, () => _updateQty(productId, -1)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text("${item.quantity}", style: AppStyle.numPadText.copyWith(fontSize: 14)),
                  ),
                  _qtyButton(Icons.add, () => _updateQty(productId, 1)),
                ],
              )
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 35,
                  child: TextField(
                    onChanged: (v) => item.notes = v,
                    decoration: InputDecoration(
                      hintText: "Notes",
                      hintStyle: AppStyle.subTitleText.copyWith(fontSize: 11),
                      filled: true,
                      fillColor: const Color(0xFFF8F9FA),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    style: AppStyle.menuText.copyWith(fontSize: 11),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _cart.remove(productId)),
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarFooter() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFEEEEEE)))),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Total", style: AppStyle.menuText.copyWith(color: AppStyle.textGrey)),
              Text(formatHarga(_calculateTotal()), style: AppStyle.priceText.copyWith(fontSize: 22)),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: _cart.isEmpty ? null : () async {
                bool? isSuccess = await showDialog<bool>(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => CheckoutDialog(
                    cart: _cart,
                    totalAmount: _calculateTotal(),
                    orderId: _orderId,
                    tableNumber: _tableNumber,
                    cashierName: _cashierName,
                    formatCurrency: formatHarga,
                  ),
                );

                if (isSuccess == true) {
                  setState(() {
                    _cart.clear();
                    _generateOrderId();
                    _tableNumber = "";
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Transaksi Berhasil!"), backgroundColor: Colors.green),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppStyle.primaryBlue, 
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                elevation: 0,
              ),
              child: Text("Checkout", style: AppStyle.buttonText.copyWith(fontSize: 18)),
            ),
          )
        ],
      ),
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(color: AppStyle.primaryBlue, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(child: Text("Menu tidak ditemukan", style: AppStyle.subTitleText));
  }
}