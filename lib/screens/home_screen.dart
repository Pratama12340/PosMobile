import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../style.dart';
import '../services/api_service.dart';
import '../models/product_models.dart';
import '../models/order_model.dart';
import '../models/discount_model.dart'; 
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
  
  Set<int> _bestsellerProductIds = {}; 
  
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
      final results = await Future.wait([
        ApiService.getCategories().catchError((e) => []),
        ApiService.getProducts().catchError((e) => <Product>[]),
        ApiService.getDiscounts().catchError((e) => <Discount>[]),
        ApiService.getReports().catchError((e) => []), 
        ApiService.fetchHistory().catchError((e) => <Order>[]), 
      ]);

      if (mounted) {
        final List categoriesData = results[0];
        final List<Product> productsData = results[1] as List<Product>;
        final List<Discount> discountsData = results[2] as List<Discount>;
        final List reportsData = results[3];
        final List<Order> historyData = results[4] as List<Order>;

        Map<int, int> productSales = {};

        void findSales(dynamic data) {
          if (data is List) {
            for (var item in data) {
              findSales(item);
            }
          } else if (data is Map) {
            if (data.containsKey('product_id')) {
              int pId = int.tryParse(data['product_id']?.toString() ?? '0') ?? 0;
              int qty = int.tryParse(data['qty']?.toString() ?? data['total_qty']?.toString() ?? data['sold']?.toString() ?? '0') ?? 0;
              if (pId != 0 && qty > 0) {
                productSales[pId] = (productSales[pId] ?? 0) + qty;
              }
            }
            for (var value in data.values) {
              if (value is List || value is Map) {
                findSales(value);
              }
            }
          }
        }

        findSales(reportsData);

        if (productSales.isEmpty) {
          for (var order in historyData) {
            if (order.status == 'paid') {
              for (var item in order.items) {
                productSales[item.productId] = (productSales[item.productId] ?? 0) + item.quantity;
              }
            }
          }
        }

        Set<int> calculatedBestsellers = {};

        for (var product in productsData) {
          final specificDiscount = discountsData.where((d) => 
            d.scope == 'products' && d.productIds.contains(product.id)
          ).toList();

          if (specificDiscount.isNotEmpty) {
            product.discount = specificDiscount.first;
          } else {
            product.discount = null;
          }

          int soldCount = productSales[product.id] ?? 0;
          String catName = product.category.toLowerCase();
          
          bool isBest = false;
          int target = 20; 
          
          if (catName.contains('makan')) {
             target = 10;
          } else if (catName.contains('minum')) {
             target = 5;
          }
          
          isBest = soldCount >= target;
          if (isBest) calculatedBestsellers.add(product.id);
        }

        setState(() {
          _categories = categoriesData;
          _allProducts = productsData;
          _bestsellerProductIds = calculatedBestsellers; 
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
    bool hasDiscountedItem = _cart.values.any((cartItem) {
      int index = _allProducts.indexWhere((p) => p.id == cartItem.productId);
      return index != -1 && _allProducts[index].discount != null;
    });

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
                    hasDiscountedItem: hasDiscountedItem, 
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
                        _loadInitialData(); 
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
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
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
    bool isBestseller = _bestsellerProductIds.contains(p.id) || p.isBestseller == true; 
    bool isDiskon = p.discount != null; 
    
    double priceAfterDiscount = p.price.toDouble();
    if (isDiskon) {
      if (p.discount!.type == 'percentage') {
        priceAfterDiscount = p.price * (1 - (p.discount!.value / 100));
      } else {
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
            Positioned.fill(
              child: imageUrl.isEmpty ? imagePlaceholder : Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (c, e, s) => imagePlaceholder),
            ),
            Positioned.fill(child: Container(color: Colors.black.withValues(alpha: 0.3))),
            
            Positioned(
              top: 10,
              left: 0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isBestseller)
                    ClipPath(
                      clipper: TagClipper(),
                      child: Container(
                        color: const Color(0xFFD32F2F),
                        padding: const EdgeInsets.only(left: 8, right: 22, top: 4, bottom: 4),
                        child: const Text(
                          "BESTSELLER",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  
                  if (isBestseller && isDiskon)
                    const SizedBox(height: 4),
                    
                  if (isDiskon)
                    ClipPath(
                      clipper: TagClipper(),
                      child: Container(
                        color: const Color(0xFF24707A),
                        padding: const EdgeInsets.only(left: 8, right: 20, top: 4, bottom: 4),
                        child: const Text(
                          "DISKON",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            Positioned(
              top: 10, right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(color: isOutOfStock ? Colors.red : AppStyle.primaryBlue, borderRadius: BorderRadius.circular(8)),
                child: Text(isOutOfStock ? "HABIS" : "STOK: ${p.stock}", style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
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
                        if (isDiskon) ...[
                          Text(
                            formatHarga(p.price.toDouble()),
                            style: const TextStyle(
                              color: Colors.white70, 
                              fontSize: 10, 
                              decoration: TextDecoration.lineThrough
                            ),
                          ),
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

class TagClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final double pointWidth = 12.0;
    final double radius = 4.0;
    path.moveTo(0, 0);
    path.lineTo(size.width - pointWidth, 0); 
    path.lineTo(size.width - (radius / 2), (size.height / 2) - radius);
    path.quadraticBezierTo(
      size.width, size.height / 2,
      size.width - (radius / 2), (size.height / 2) + radius
    );
    path.lineTo(size.width - pointWidth, size.height);
    path.lineTo(0, size.height); 
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}