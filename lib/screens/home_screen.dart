import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/style.dart';
import '../services/api_service.dart';
import '../models/product_model.dart';
import '../models/order_model.dart';
import '../models/discount_model.dart';
import '../widgets/cart_panel.dart';
import '../services/reverb_service.dart';
import '../services/storage_service.dart';

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
  final ReverbService _reverbService = ReverbService();

  String? _currentCustomerName;
  String? _currentTableNumber;
  int? _currentTableId;

  List<Order> _pendingOrders = [];
  bool _isPendingOrderLoaded = false;
  int? _currentPendingOrderId;
  int? _currentPendingDiscountId;

  bool _isPendingPanelVisible = false;
  bool _isLoadingPendingOrders = false;

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
        if (!_isPendingOrderLoaded) {
          _drafts.add({
            'cart': Map<int, OrderItem>.from(_cart),
            'customerName': _currentCustomerName ?? "",
            'tableNumber': _currentTableNumber ?? "",
            'tableId': _currentTableId,
          });
        }

        _cart.clear();
        _currentCustomerName = null;
        _currentTableNumber = null;
        _currentTableId = null;

        _isPendingOrderLoaded = false;
        _currentPendingOrderId = null;
        _currentPendingDiscountId = null;

        widget.onCartToggled?.call(false);
      }

      _isCartVisible = false;
      _isPendingPanelVisible = false;
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
    _connectReverb();
  }

  @override
  void dispose() {
    widget.searchController.removeListener(_applyFilters);
    _reverbService.disconnect();
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
        ApiService.getPendingOrders().catchError((e) => <Order>[]),
      ]);

      if (mounted) {
        final List categoriesData = results[0];
        final List<Product> productsData = results[1] as List<Product>;
        final List<Discount> discountsData = results[2] as List<Discount>;
        final List reportsData = results[3];
        final List<Order> historyData = results[4] as List<Order>;
        final List<Order> pendingData = results[5] as List<Order>;

        List<Order> loadedPendingOrders = pendingData.isNotEmpty
            ? pendingData
            : [];
        Map<int, int> productSales = {};

        for (var order in historyData) {
          if (order.status == 'paid') {
            for (var item in order.items) {
              productSales[item.productId] =
                  (productSales[item.productId] ?? 0) + item.quantity;
            }
          }
          if (pendingData.isEmpty &&
              (order.status == 'pending' || order.status == 'unpaid')) {
            loadedPendingOrders.add(order);
          }
        }

        void findSales(dynamic data) {
          if (data is List) {
            for (var item in data) {
              findSales(item);
            }
          } else if (data is Map) {
            if (data.containsKey('product_id')) {
              int pId =
                  int.tryParse(data['product_id']?.toString() ?? '0') ?? 0;
              int qty =
                  int.tryParse(
                    data['qty']?.toString() ??
                        data['total_qty']?.toString() ??
                        data['sold']?.toString() ??
                        '0',
                  ) ??
                  0;
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
                productSales[item.productId] =
                    (productSales[item.productId] ?? 0) + item.quantity;
              }
            }
          }
        }

        Set<int> calculatedBestsellers = {};

        for (var product in productsData) {
          final specificDiscount = discountsData
              .where(
                (d) =>
                    d.scope == 'products' && d.productIds.contains(product.id),
              )
              .toList();

          product.discount = specificDiscount.isNotEmpty
              ? specificDiscount.first
              : null;
        }

        final sortedBySales = List<Product>.from(productsData)
          ..sort((a, b) {
            int salesA = productSales[a.id] ?? 0;
            int salesB = productSales[b.id] ?? 0;
            return salesB.compareTo(salesA);
          });

        final top5 = sortedBySales
            .where((p) => (productSales[p.id] ?? 0) > 0)
            .take(5)
            .toList();

        for (var product in top5) {
          calculatedBestsellers.add(product.id);
        }

        setState(() {
          _categories = categoriesData;
          _allProducts = productsData;
          _bestsellerProductIds = calculatedBestsellers;
          _pendingOrders = loadedPendingOrders;
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

  void _saveToDraft(String customerName, String tableNumber, int? tableId) {
    setState(() {
      if (_cart.isNotEmpty) {
        _drafts.add({
          'cart': Map<int, OrderItem>.from(_cart),
          'customerName': customerName,
          'tableNumber': tableNumber,
          'tableId': tableId,
        });

        _cart.clear();
        _currentCustomerName = null;
        _currentTableNumber = null;
        _currentTableId = null;

        _isPendingOrderLoaded = false;
        _currentPendingOrderId = null;
        _currentPendingDiscountId = null;

        _isCartVisible = false;
        widget.onCartToggled?.call(false);
      }
    });
  }

  void _loadPendingOrderToCart(Order order) {
    setState(() {
      _cart.clear();

      for (var item in order.items) {
        int productIndex = _allProducts.indexWhere(
          (p) => p.id == item.productId,
        );
        double unitPrice = item.price;
        String itemName = "Menu ${item.productId}";

        if (productIndex != -1) {
          final product = _allProducts[productIndex];
          itemName = product.name;
          unitPrice = (item.price > 0) ? item.price : product.price.toDouble();
        }
        _cart[item.productId] = OrderItem(
          id: item.id,
          productId: item.productId,
          itemName: itemName,
          originalQty: item.quantity,
          activeQty: item.quantity,
          unitPrice: unitPrice,
        );
      }

      _currentCustomerName = order.customerName;
      _currentTableNumber =
          order.tableNumber?.toString() ?? order.tableId?.toString() ?? "-";
      _currentTableId = int.tryParse(order.tableId?.toString() ?? '0');

      _isPendingOrderLoaded = true;
      _currentPendingOrderId = order.id;
      _currentPendingDiscountId = order.discountId;

      _isPendingPanelVisible = false;
      _isCartVisible = true;
      widget.onCartToggled?.call(true);
    });
  }

  void _togglePendingPanel() async {
    setState(() {
      if (_isPendingPanelVisible) {
        _isPendingPanelVisible = false;
      } else {
        _isCartVisible = false;
        widget.onCartToggled?.call(false);

        _isPendingPanelVisible = true;
        _isLoadingPendingOrders = true;
      }
    });

    if (_isPendingPanelVisible) {
      try {
        final freshPendingOrders = await ApiService.getPendingOrders();

        if (mounted) {
          setState(() {
            _pendingOrders = freshPendingOrders;
            _isLoadingPendingOrders = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoadingPendingOrders = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool hasDiscountedItem = _isPendingOrderLoaded
        ? false
        : _cart.values.any((cartItem) {
            int index = _allProducts.indexWhere(
              (p) => p.id == cartItem.productId,
            );
            return index != -1 && _allProducts[index].discount != null;
          });

    double originalTotalAmount = _isPendingOrderLoaded
        ? 0.0
        : _cart.values.fold(0.0, (sum, cartItem) {
            return sum + (cartItem.unitPrice * cartItem.quantity);
          });

    return Scaffold(
      backgroundColor: AppStyle.bgLightBlue,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (_isPendingPanelVisible) {
                        setState(() {
                          _isPendingPanelVisible = false;
                        });
                      } else if (_isCartVisible) {
                        closeCart();
                      }
                    },
                    behavior: HitTestBehavior.translucent,
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

                              if (_pendingOrders.isNotEmpty &&
                                  !_isPendingPanelVisible &&
                                  !_isPendingOrderLoaded) ...[
                                const SizedBox(width: 15),
                                Badge(
                                  label: Text(
                                    '${_pendingOrders.length}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  backgroundColor: Colors.redAccent,
                                  child: InkWell(
                                    onTap: _togglePendingPanel,
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      width: 45,
                                      height: 45,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.05,
                                            ),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.receipt_long,
                                        color: Colors.orange,
                                        size: 26,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 15),
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                double spacing = 18.0;
                                double itemHeight =
                                    (constraints.maxHeight - spacing) / 2;
                                double itemWidth =
                                    (constraints.maxWidth - (spacing * 3)) / 4;
                                return GridView.builder(
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 4,
                                        childAspectRatio:
                                            itemWidth / itemHeight,
                                        crossAxisSpacing: spacing,
                                        mainAxisSpacing: spacing,
                                      ),
                                  itemCount: _filteredProducts.length,
                                  itemBuilder: (context, index) =>
                                      _buildProductCard(
                                        _filteredProducts[index],
                                      ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                if (_isPendingPanelVisible)
                  _buildPendingOrderPanel()
                else if (_isCartVisible &&
                    (_cart.isNotEmpty ||
                        _currentCustomerName != null ||
                        _currentTableNumber != null))
                  CartPanel(
                    cart: _cart,
                    hasDiscountedItem: hasDiscountedItem,
                    originalTotalAmount: originalTotalAmount,
                    formatCurrency: formatHarga,
                    initialCustomerName: _currentCustomerName,
                    initialTableNumber: _currentTableNumber,
                    initialTableId: _currentTableId,

                    isPendingMode: _isPendingOrderLoaded,
                    pendingOrderId: _currentPendingOrderId,
                    pendingDiscountId: _currentPendingDiscountId,

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
                              _currentTableId = null;

                              _isPendingOrderLoaded = false;
                              _currentPendingOrderId = null;

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
                          _currentTableId = null;

                          _isPendingOrderLoaded = false;
                          _currentPendingOrderId = null;

                          _isCartVisible = false;
                          widget.onCartToggled?.call(false);
                        }
                      });
                    },
                    onCheckoutSuccess: (res) {
                      setState(() {
                        _cart.forEach((productId, cartItem) {
                          int productIndex = _allProducts.indexWhere(
                            (p) => p.id == productId,
                          );
                          if (productIndex != -1) {
                            _allProducts[productIndex].stock -=
                                cartItem.quantity;
                            if (_allProducts[productIndex].stock < 0) {
                              _allProducts[productIndex].stock = 0;
                            }
                          }
                        });

                        _cart.clear();
                        _currentCustomerName = null;
                        _currentTableNumber = null;
                        _currentTableId = null;

                        _isPendingOrderLoaded = false;
                        _currentPendingOrderId = null;
                        _currentPendingDiscountId = null;

                        _isCartVisible = false;
                        widget.onCartToggled?.call(false);
                        _loadInitialData();
                      });
                    },
                    onSaveDraft: (name, table, id) =>
                        _saveToDraft(name, table, id),
                  ),
              ],
            ),
    );
  }

  Future<void> _connectReverb() async {
    final int? outletId = await StorageService.getOutletId();

    if (outletId == null) {
      debugPrint('🔴 [REVERB HOME] outlet_id tidak ditemukan');
      return;
    }

    await _reverbService.initConnection(
      channelName: 'private-orders.outlet.$outletId',
      eventName: '.order.created',
      onEventReceived: (data) {
        debugPrint('⚡ [HOME] Event Reverb diterima: $data');
        _refreshPendingOrdersSilently();

        if (mounted) {
          final customerName = data['order']?['customer_name'] ?? 'Pelanggan';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.notifications_active, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Pesanan baru dari $customerName masuk!'),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      },
    );
  }

  Future<void> refreshPendingOrdersSilently() async {
    try {
      final freshOrders = await ApiService.getPendingOrders();
      if (mounted) {
        setState(() => _pendingOrders = freshOrders);
      }
    } catch (e) {
      debugPrint('⚠️ Gagal refresh pending orders: $e');
    }
  }

  Future<void> _refreshPendingOrdersSilently() async {
    try {
      final freshOrders = await ApiService.getPendingOrders();
      if (mounted) {
        setState(() {
          _pendingOrders = freshOrders;
        });
      }
    } catch (e) {
      debugPrint('⚠️ Gagal refresh pending orders: $e');
    }
  }

  Widget _buildPendingOrderPanel() {
    return Container(
      width: 360,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: Colors.grey.shade200, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(-5, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppStyle.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.receipt_long,
                    color: AppStyle.primaryBlue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    "Pesanan Tertunda",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.black54),
                  onPressed: () {
                    setState(() {
                      _isPendingPanelVisible = false;
                    });
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF5F5F5)),

          Expanded(
            child: _isLoadingPendingOrders
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppStyle.primaryBlue,
                    ),
                  )
                : _pendingOrders.isEmpty
                ? const Center(
                    child: Text(
                      "Tidak ada pesanan tertunda.",
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(15),
                    itemCount: _pendingOrders.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final order = _pendingOrders[index];

                      String custName = order.customerName;
                      String tableNo = order.tableId?.toString() ?? '-';
                      double total = (order.totalPrice).toDouble();

                      return InkWell(
                        onTap: () {
                          _loadPendingOrderToCart(order);
                        },
                        borderRadius: BorderRadius.circular(15),
                        child: Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(15),
                            color: Colors.white,
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: AppStyle.primaryBlue
                                    .withValues(alpha: 0.1),
                                radius: 20,
                                child: Text(
                                  tableNo,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppStyle.primaryBlue,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      custName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Total: ${formatHarga(total)}",
                                      style: const TextStyle(
                                        color: AppStyle.primaryBlue,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_ios,
                                size: 14,
                                color: Colors.grey,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraftDropdownButton() {
    return PopupMenuButton<int>(
      tooltip: "Pilih Draft",
      offset: const Offset(0, 50),
      constraints: const BoxConstraints(minWidth: 280, maxWidth: 280),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      onSelected: (int index) {
        setState(() {
          final selectedDraft = _drafts[index];
          _cart.addAll(selectedDraft['cart'] as Map<int, OrderItem>);
          _currentCustomerName = selectedDraft['customerName'];
          _currentTableNumber = selectedDraft['tableNumber'];
          _currentTableId = selectedDraft['tableId'];

          _isPendingOrderLoaded = false;
          _currentPendingOrderId = null;

          _drafts.removeAt(index);

          _isPendingPanelVisible = false;
          _isCartVisible = true;
          widget.onCartToggled?.call(true);
        });
      },
      itemBuilder: (context) => List.generate(_drafts.length, (index) {
        final draft = _drafts[index];
        String customerName = draft['customerName']?.toString().trim() ?? "";
        String label = customerName.isEmpty
            ? "Draft ${index + 1}"
            : customerName;

        return PopupMenuItem<int>(
          value: index,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.person_outline,
                    size: 18,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
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
                child: const Icon(Icons.close, size: 18, color: Colors.red),
              ),
            ],
          ),
        );
      }),
      child: Container(
        width: 45,
        height: 45,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            const Icon(
              Icons.shopping_cart_outlined,
              color: AppStyle.primaryBlue,
              size: 28,
            ),
            if (_drafts.isNotEmpty)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Text(
                    '${_drafts.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
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
    bool isBestseller =
        _bestsellerProductIds.contains(p.id) || p.isBestseller == true;
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
      imageUrl =
          "https://api.etres.my.id/storage/${imageUrl.startsWith('/') ? imageUrl.substring(1) : imageUrl}";
    }

    Widget imagePlaceholder = Container(
      color: const Color(0xFFEEEEEE),
      alignment: Alignment.center,
      child: Text(
        _getInitials(p.name),
        style: TextStyle(
          fontSize: 80,
          fontWeight: FontWeight.bold,
          color: Colors.grey[400],
        ),
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned.fill(
              child: imageUrl.isEmpty
                  ? imagePlaceholder
                  : Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => imagePlaceholder,
                    ),
            ),
            Positioned.fill(
              child: Container(color: Colors.black.withValues(alpha: 0.3)),
            ),

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
                        padding: const EdgeInsets.only(
                          left: 8,
                          right: 22,
                          top: 4,
                          bottom: 4,
                        ),
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

                  if (isBestseller && isDiskon) const SizedBox(height: 4),

                  if (isDiskon)
                    ClipPath(
                      clipper: TagClipper(),
                      child: Container(
                        color: const Color(0xFF24707A),
                        padding: const EdgeInsets.only(
                          left: 8,
                          right: 20,
                          top: 4,
                          bottom: 4,
                        ),
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
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: isOutOfStock ? Colors.red : AppStyle.primaryBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isOutOfStock ? "HABIS" : "STOK: ${p.stock}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            Positioned(
              bottom: 15,
              left: 15,
              right: 15,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          p.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                        ),
                        if (isDiskon) ...[
                          Text(
                            formatHarga(p.price.toDouble()),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          Text(
                            formatHarga(priceAfterDiscount),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ] else
                          Text(
                            formatHarga(p.price.toDouble()),
                            style: const TextStyle(color: Colors.white),
                          ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: isOutOfStock
                        ? null
                        : () => setState(() {
                            if (_isPendingOrderLoaded &&
                                !_cart.containsKey(p.id)) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text(
                                    "Tidak bisa menambah menu baru ke pesanan pending.\nHanya bisa mengubah jumlah menu yang sudah ada.",
                                  ),
                                  backgroundColor: Colors.orange,
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 3),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                              return;
                            }

                            _isPendingPanelVisible = false;
                            _isCartVisible = true;
                            widget.onCartToggled?.call(true);

                            if (_cart.containsKey(p.id)) {
                              _cart[p.id]!.quantity++;
                            } else {
                              _cart[p.id] = OrderItem(
                                id: 0,
                                productId: p.id,
                                itemName: p.name,
                                originalQty: 1,
                                activeQty: 1,
                                unitPrice: p.price.toDouble(),
                              );
                            }
                          }),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.add,
                        color: isOutOfStock
                            ? Colors.grey
                            : AppStyle.primaryBlue,
                      ),
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
      size.width,
      size.height / 2,
      size.width - (radius / 2),
      (size.height / 2) + radius,
    );
    path.lineTo(size.width - pointWidth, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
