import 'package:flutter/material.dart';
import 'package:sistem_pos/features/orders/models/order_model.dart';
import 'package:sistem_pos/features/home/models/product_model.dart';
import 'package:sistem_pos/core/models/discount_model.dart';

class CartProvider extends ChangeNotifier {
  final Map<int, OrderItem> _cart = {};
  final List<Map<String, dynamic>> _drafts = [];
  final Map<int, Discount> _productDiscounts = {};

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
    if (discount != null) {
      double totalDiscount = 0;
      if (discount.type == 'percentage') {
        totalDiscount = (item.originalPrice * (discount.value / 100)) * item.activeQty;
      } else {
        totalDiscount = discount.value * item.activeQty;
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
        stationId: item.stationId,
        stationName: item.stationName,
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
    }
  }
}
