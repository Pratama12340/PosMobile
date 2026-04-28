import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../style.dart';
import '../services/api_service.dart';
import '../models/product_models.dart';
import '../models/order_model.dart';
import '../models/discount_model.dart'; // Pastikan model diskon diimport
import '../widgets/cart_panel.dart';

class HomeScreen extends StatefulWidget {
  final TextEditingController searchController;
  final Function(bool)? onCartToggled;

  const HomeScreen({
    super.key,
    required this.searchController,
    this.onCartToggled,
  });

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final Map<int, OrderItem> _cart = {};
  final List<Map<String, dynamic>> _drafts = [];

  String? _currentCustomerName;
  String? _currentTableNumber;

  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];
  List<dynamic> _categories = [];
  bool _isLoading = true;
  String _selectedCategory = "All Menu";
  
  bool _isCartVisible = false;

  void closeCart() {
    setState(() {
      if (_cart.isNotEmpty) {
        _drafts.add({
          'cart': Map<int, OrderItem>.from(_cart),
          'customerName': _currentCustomerName ?? "",
          'tableNumber': _currentTableNumber ?? "",
        });
        
        _cart.clear();
        _currentCustomerName = null;
        _currentTableNumber = null;
        widget.onCartToggled?.call(false);
      }
      _isCartVisible = false;
    });
  }

  String formatHarga(double price) => NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      ).format(price);

  String _getInitials(String name) {
    if (name.isEmpty) return "";
    List<String> words = name.trim().split(RegExp(r'\s+'));
    if (words.length >= 2) {
      return (words[0][0] + words[1][0]).toUpperCase();
    }
    return words[0][0].toUpperCase();
  }

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
      // 1. Ambil Kategori, Produk, dan Diskon secara paralel dari API masing-masing
      final results = await Future.wait([
        ApiService.getCategories(),
        ApiService.getProducts(),
        ApiService.getDiscounts(), // Memanggil API Diskon terpisah
      ]);

      if (mounted) {
        List<dynamic> categoriesData = results[0] as List;
        List<Product> productsData = results[1] as List<Product>;
        List<Discount> discountsData = results[2] as List<Discount>;

        // 👇 TAMBAHKAN PRINT DI SINI 👇
        print("--- CEK DATA API ---");
        print("Jumlah Produk: ${productsData.length}");
        print("Jumlah Diskon: ${discountsData.length}");

        // 2. MAPPING: Pasangkan data diskon ke produk berdasarkan productId
        for (var product in productsData) {
          try {
            // Mencari diskon yang memiliki productId yang sama dengan id produk
            product.discount = discountsData.firstWhere(
              (d) => d.productId == product.id,
            );

            // 👇 TAMBAHKAN PRINT UNTUK MELIHAT YANG BERHASIL DI-MAP 👇
            print("✅ Mapping Berhasil: ${product.name} (ID: ${product.id}) -> Diskon: ${product.discount?.name}");

          } catch (e) {
            product.discount = null; // Tidak ada diskon yang cocok
          }
        }

        setState(() {
          _categories = categoriesData;
          _allProducts = productsData;
          _isLoading = false;
        });

        // Debug untuk verifikasi mapping di terminal
        print("--- DEBUG MAPPING DISKON ---");
        for (var p in _allProducts) {
          if (p.discount != null) {
            print("Produk: ${p.name} | Diskon: ${p.discount!.name} (${p.discount!.value})");
          }
        }

        _applyFilters();
      }
    } catch (e) {
      print("Error Loading Data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    String query = widget.searchController.text.toLowerCase();
    setState(() {
      _filteredProducts = _allProducts.where((p) {
        bool matchCategory =
            _selectedCategory == "All Menu" ||
            p.category.toLowerCase().contains(_selectedCategory.toLowerCase());
        bool matchQuery = query.isEmpty || p.name.toLowerCase().contains(query);
        return matchCategory && matchQuery;
      }).toList();
      _filteredProducts.sort(
        (a, b) => (a.stock <= 0 && b.stock > 0)
            ? 1
            : (a.stock > 0 && b.stock <= 0)
            ? -1
            : 0,
      );
    });
  }

  void _saveToDraft(String customerName, String tableNumber) {
    setState(() {
      if (_cart.isNotEmpty) {
        _drafts.add({
          'cart': Map<int, OrderItem>.from(_cart),
          'customerName': customerName,
          'tableNumber': tableNumber,
        });
        
        _cart.clear();
        _currentCustomerName = null;
        _currentTableNumber = null;
        _isCartVisible = false;
        widget.onCartToggled?.call(false);
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
                          child: LayoutBuilder(
                            builder: (context, constraints) {
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
                                itemBuilder: (context, index) =>
                                    _buildProductCard(_filteredProducts[index]),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_isCartVisible && (_cart.isNotEmpty || _currentCustomerName != null || _currentTableNumber != null))
                  CartPanel(
                    cart: _cart,
                    formatCurrency: formatHarga,
                    initialCustomerName: _currentCustomerName,
                    initialTableNumber: _currentTableNumber,
                    onIncrease: (id) {
                      setState(() {
                        if (_cart.containsKey(id)) {
                          _cart.update(id, (item) {
                            item.quantity += 1;
                            return item; 
                          });
                        }
                      });
                    },
                    onDecrease: (id) {
                      setState(() {
                        if (_cart.containsKey(id)) {
                          if (_cart[id]!.quantity > 1) {
                            _cart.update(id, (item) {
                              item.quantity -= 1;
                              return item;
                            });
                          } else {
                            _cart.remove(id);
                            if (_cart.isEmpty) {
                              _currentCustomerName = null;
                              _currentTableNumber = null;
                              _isCartVisible = false;
                              widget.onCartToggled?.call(false);
                            }
                          }
                        }
                      });
                    },
                    onDelete: (id) {
                      setState(() {
                        _cart.remove(id);
                        if (_cart.isEmpty) {
                          _currentCustomerName = null;
                          _currentTableNumber = null;
                          _isCartVisible = false;
                          widget.onCartToggled?.call(false);
                        }
                      });
                    },
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
                        _currentCustomerName = null;
                        _currentTableNumber = null;
                        _isCartVisible = false;
                        widget.onCartToggled?.call(false);
                        _applyFilters(); 
                      });
                    },
                    onSaveDraft: _saveToDraft,
                  ),
              ],
            ),
    );
  }

  Widget _buildDraftDropdownButton() {
    return PopupMenuButton<int>(
      tooltip: "Pilih Draft",
      offset: const Offset(0, 50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      onSelected: (int index) {
        setState(() {
          final selectedDraft = _drafts[index];
          _cart.addAll(selectedDraft['cart'] as Map<int, OrderItem>);
          _currentCustomerName = selectedDraft['customerName'];
          _currentTableNumber = selectedDraft['tableNumber'];
          _drafts.removeAt(index);
          _isCartVisible = true;
          widget.onCartToggled?.call(true);
        });
      },
      itemBuilder: (context) => List.generate(_drafts.length, (index) {
        final draft = _drafts[index];
        String customerName = draft['customerName']?.toString().trim() ?? "";
        String label = customerName.isEmpty ? "Draft ${index + 1}" : customerName;

        return PopupMenuItem<int>(
          value: index,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person_outline, size: 18, color: Colors.grey),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _drafts.removeAt(index);
                  });
                  Navigator.pop(context);
                },
                child: const Icon(
                  Icons.close, 
                  size: 18, 
                  color: Colors.red,
                ),
              ),
            ],
          ),
        );
      }),
      child: Container(
        width: 45, height: 45,
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.shopping_cart_outlined, color: AppStyle.primaryBlue, size: 28),
            if (_drafts.isNotEmpty)
              Positioned(
                right: -2, top: -2,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  child: Text('${_drafts.length}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                ),
              ),
          ],
        ),
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
          setState(() {
            _selectedCategory = label;
            _applyFilters();
          });
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
    
    // 1. Logika Bestseller (Sesuai instruksi: Nanti dulu, jadi kita biarkan false jika tidak ada data)
    bool isBestseller = p.isBestseller == true; 
    
    // 2. Logika Diskon (Fokus Utama saat ini)
    bool isDiskon = p.discount != null; 
    
    double priceAfterDiscount = p.price.toDouble();
    if (isDiskon) {
      if (p.discount!.type == 'percentage') {
        priceAfterDiscount = p.price * (1 - (p.discount!.value / 100));
      } else {
        // Tipe Nominal
        priceAfterDiscount = (p.price - p.discount!.value).toDouble();
      }
    }

    String imageUrl = p.image.trim();
    if (imageUrl.isNotEmpty && !imageUrl.startsWith('http')) {
      imageUrl = "https://api.etres.my.id/storage/${imageUrl.startsWith('/') ? imageUrl.substring(1) : imageUrl}";
    }

    Widget imagePlaceholder = Container(
      color: const Color(0xFFEEEEEE),
      alignment: Alignment.center,
      child: Text(_getInitials(p.name), style: TextStyle(fontSize: 80, fontWeight: FontWeight.bold, color: Colors.grey[400])),
    );

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // GAMBAR PRODUK
            Positioned.fill(
              child: imageUrl.isEmpty ? imagePlaceholder : Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (c, e, s) => imagePlaceholder),
            ),
            // OVERLAY GELAP
            Positioned.fill(child: Container(color: Colors.black.withOpacity(0.3))),
            
            // PITA DIAGONAL (DISKON / TERLARIS)
            if (isDiskon || isBestseller)
              Positioned(
                top: 12,
                left: -28,
                child: Transform.rotate(
                  angle: -0.785398, // -45 derajat
                  child: Container(
                    width: 110,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      // Warna Teal untuk Diskon, Coral untuk Bestseller
                      color: isDiskon ? const Color(0xFF2E7D8A) : const Color(0xFFE57373),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))
                      ],
                    ),
                    child: Text(
                      isDiskon ? "DISKON" : "TERLARIS",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),

            // BADGE STOK (POJOK KANAN ATAS)
            Positioned(
              top: 10, right: 10,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: isOutOfStock ? Colors.red : AppStyle.primaryBlue, borderRadius: BorderRadius.circular(8)),
                child: Text(isOutOfStock ? "HABIS" : "STOK: ${p.stock}", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ),

            // INFORMASI NAMA & HARGA (BAWAH)
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
                        if (isDiskon) ...[
                          // Tampilkan Harga Asli dengan Garis Coret
                          Text(
                            formatHarga(p.price.toDouble()),
                            style: const TextStyle(
                              color: Colors.white70, 
                              fontSize: 10, 
                              decoration: TextDecoration.lineThrough
                            ),
                          ),
                          // Tampilkan Harga Diskon
                          Text(formatHarga(priceAfterDiscount), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ] else
                          Text(formatHarga(p.price.toDouble()), style: const TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: isOutOfStock ? null : () => setState(() {
                      _isCartVisible = true;
                      widget.onCartToggled?.call(true);

                      if (_cart.containsKey(p.id)) {
                        _cart[p.id]!.quantity++;
                      } else {
                        _cart[p.id] = OrderItem(
                          id: p.id, 
                          productId: p.id, 
                          itemName: p.name, 
                          originalQty: 1, 
                          activeQty: 1, 
                          // Pastikan harga yang masuk ke keranjang adalah harga setelah diskon
                          unitPrice: isDiskon ? priceAfterDiscount : p.price.toDouble()
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