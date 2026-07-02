import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sistem_pos/features/orders/models/order_model.dart';
import 'package:sistem_pos/features/home/models/product_model.dart';
import 'package:sistem_pos/core/models/discount_model.dart';

class CartProvider extends ChangeNotifier {
  final Map<int, OrderItem> _cart = {};
  final List<Map<String, dynamic>> _drafts = [];
  final Map<int, Discount> _productDiscounts = {};

  CartProvider() {
    loadDraftsFromStorage();
  }

  Future<void> _saveDraftsToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> serializedDrafts = _drafts.map((draft) {
        final cartMap = draft['cart'] as Map<int, OrderItem>;
        final serializedCart = cartMap.map((key, value) => MapEntry(key.toString(), value.toDraftJson()));
        return {
          'cart': serializedCart,
          'customerName': draft['customerName'],
          'tableNumber': draft['tableNumber'],
          'tableId': draft['tableId'],
        };
      }).toList();
      
      final jsonString = jsonEncode(serializedDrafts);
      await prefs.setString('offline_draft_orders', jsonString);
    } catch (e) {
      debugPrint("Error saving drafts to storage: $e");
    }
  }

  Future<void> loadDraftsFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('offline_draft_orders');
      if (jsonString != null && jsonString.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(jsonString);
        _drafts.clear();
        for (var item in decoded) {
          final Map<String, dynamic> draftMap = item as Map<String, dynamic>;
          final serializedCart = draftMap['cart'] as Map<String, dynamic>;
          final Map<int, OrderItem> cartMap = {};
          
          serializedCart.forEach((key, value) {
            final productId = int.tryParse(key);
            if (productId != null) {
              cartMap[productId] = OrderItem.fromDraftJson(value as Map<String, dynamic>);
            }
          });
          
          _drafts.add({
            'cart': cartMap,
            'customerName': draftMap['customerName'],
            'tableNumber': draftMap['tableNumber'],
            'tableId': draftMap['tableId'],
          });
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error loading drafts from storage: $e");
    }
  }

  String? _currentCustomerName;
  String? _currentTableNumber;
  int? _currentTableId;

  bool _isPendingOrderLoaded = false;
  int? _currentPendingOrderId;
  int? _currentPendingDiscountId;

  Map<int, OrderItem> get cart => _cart;
  List<Map<String, dynamic>> get drafts => _drafts;

  String? get currentCustomerName => _currentCustomerName;
  String? get currentTableNumber => _currentTableNumber;
  int? get currentTableId => _currentTableId;
  bool get isPendingOrderLoaded => _isPendingOrderLoaded;
  int? get currentPendingOrderId => _currentPendingOrderId;
  int? get currentPendingDiscountId => _currentPendingDiscountId;

  int get totalItems => _cart.values.fold(0, (sum, item) => sum + item.activeQty);

  double get subTotal => _cart.values.fold(0.0, (sum, item) {
    if (item.isVoided) return sum;
    return sum + (item.unitPrice * item.activeQty);
  });

  bool get hasDiscountedItem => _cart.values.any((item) => item.discountId != null && !item.isVoided && item.activeQty > 0);

  double get originalTotalAmount => _cart.values.fold(0.0, (sum, item) {
    if (item.isVoided) return sum;
    return sum + (item.originalPrice * item.activeQty);
  });

  void addToCart(Product p) {
    if (p.discount != null) {
      _productDiscounts[p.id] = p.discount!;
    }

    if (_cart.containsKey(p.id)) {
      _cart[p.id]!.quantity += 1;
      _recalculateDiscount(p.id);
    } else {
      double unitPrice = p.price.toDouble();

      _cart[p.id] = OrderItem(
        id: 0,
        productId: p.id,
        categoryId: p.categoryId,
        itemName: p.name,
        originalQty: 1,
        activeQty: 1,
        unitPrice: unitPrice,
        originalPrice: unitPrice,
        discountId: p.discount?.id,
        stationId: p.stationId,
        stationName: p.stationName,
      );
      _recalculateDiscount(p.id);
    }
    notifyListeners();
  }

  void _recalculateDiscount(int productId) {
    final item = _cart[productId];
    if (item == null) return;

    final discount = _productDiscounts[productId];
    
    int eligibleQty = 0;
    if (discount != null && item.activeQty > 0) {
      if (discount.minPurchase > 0) {
        double lineTotal = item.originalPrice * item.activeQty;
        if (lineTotal >= discount.minPurchase) {
          eligibleQty = item.activeQty;
        }
      } else {
        // Tidak ada syarat minPurchase
        eligibleQty = item.activeQty;
      }
    }

    if (discount != null && eligibleQty > 0) {
      double totalDiscount = 0;
      if (discount.type == 'percentage') {
        totalDiscount = (item.originalPrice * (discount.value / 100)) * eligibleQty;
      } else {
        totalDiscount = discount.value * eligibleQty;
      }

      if (discount.maxDiscount != null && totalDiscount > discount.maxDiscount!) {
        totalDiscount = discount.maxDiscount!.toDouble();
      }

      item.unitPrice = item.originalPrice - (totalDiscount / item.activeQty);
    } else {
      item.unitPrice = item.originalPrice;
    }
  }

  void increaseQty(int productId) {
    if (_cart.containsKey(productId)) {
      _cart[productId]!.quantity += 1;
      _recalculateDiscount(productId);
      notifyListeners();
    }
  }

  void decreaseQty(int productId) {
    if (_cart.containsKey(productId)) {
      if (_cart[productId]!.quantity > 1) {
        _cart[productId]!.quantity -= 1;
        _recalculateDiscount(productId);
      } else {
        _cart.remove(productId);
      }
      notifyListeners();
    }
  }

  void updateNotes(int productId, String notes) {
    if (_cart.containsKey(productId)) {
      _cart[productId]!.notes = notes;
      notifyListeners();
    }
  }

  void removeProduct(int productId) {
    _cart.remove(productId);
    notifyListeners();
  }

  void clearCart() {
    _cart.clear();
    _currentCustomerName = null;
    _currentTableNumber = null;
    _currentTableId = null;
    _isPendingOrderLoaded = false;
    _currentPendingOrderId = null;
    _currentPendingDiscountId = null;
    notifyListeners();
  }

  void saveToDraft(String customerName, String tableNumber, int? tableId) {
    if (_cart.isNotEmpty) {
      _drafts.add({
        'cart': Map<int, OrderItem>.from(_cart),
        'customerName': customerName,
        'tableNumber': tableNumber,
        'tableId': tableId,
      });
      clearCart();
      _saveDraftsToStorage();
    }
  }

  void loadFromDraft(Map<String, dynamic> draft) {
    clearCart();
    final draftCart = draft['cart'] as Map<int, OrderItem>;
    _cart.addAll(draftCart);
    _currentCustomerName = draft['customerName'];
    _currentTableNumber = draft['tableNumber'];
    _currentTableId = draft['tableId'];
    _drafts.remove(draft);
    notifyListeners();
    _saveDraftsToStorage();
  }

  void loadPendingOrderToCart(Order order, List<Product> allProducts) {
    clearCart();
    for (var item in order.items) {
      int productIndex = allProducts.indexWhere((p) => p.id == item.productId);
      double unitPrice = item.price;
      String itemName = "Menu ${item.productId}";
      Product? product;

      if (productIndex != -1) {
        product = allProducts[productIndex];
        itemName = product.name;
        unitPrice = (item.price > 0) ? item.price : product.price.toDouble();
      }

      if (product?.discount != null) {
        _productDiscounts[item.productId] = product!.discount!;
      }

      String stId = item.stationId;
      String stName = item.stationName;

      if ((stName.isEmpty || stName == 'Tanpa Nama') && product != null) {
        stId = product.stationId;
        stName = product.stationName;
      }

      _cart[item.productId] = OrderItem(
        id: item.id,
        productId: item.productId,
        categoryId: product?.categoryId,
        itemName: itemName,
        originalQty: item.quantity,
        activeQty: item.quantity,
        unitPrice: unitPrice, // _recalculateDiscount will handle this
        originalPrice: unitPrice,
        discountId: product?.discount?.id,
        stationId: stId,
        stationName: stName,
      );
      _recalculateDiscount(item.productId);
    }

    _currentCustomerName = order.customerName;
    _currentTableNumber = order.tableNumber?.toString() ?? order.tableId?.toString() ?? "-";
    _currentTableId = int.tryParse(order.tableId?.toString() ?? '0');

    _isPendingOrderLoaded = true;
    _currentPendingOrderId = order.id;
    _currentPendingDiscountId = order.discountId;

    notifyListeners();
  }

  void removeDraft(int index) {
    if (index >= 0 && index < _drafts.length) {
      _drafts.removeAt(index);
      notifyListeners();
      _saveDraftsToStorage();
    }
  }

  void clearAllDrafts() {
    _drafts.clear();
    _saveDraftsToStorage();
    notifyListeners();
  }
}
