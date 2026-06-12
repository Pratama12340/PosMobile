import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sistem_pos/features/orders/models/order_model.dart';
import 'package:sistem_pos/features/orders/services/order_api_service.dart';

class OrderProvider extends ChangeNotifier {
  List<Order> _pendingOrders = [];
  List<Order> _paidOrders = [];
  final Set<int> _dismissedOrderIds = {};
  bool _isLoadingPendingOrders = false;

  List<Order> get pendingOrders => _pendingOrders;
  List<Order> get paidOrders => _paidOrders;
  bool get isLoadingPendingOrders => _isLoadingPendingOrders;

  bool _isToday(Order order) {
    final String todayStr = DateFormat('yyyyMMdd').format(DateTime.now());
    return order.invoiceNo.contains(todayStr);
  }

  Future<void> fetchPendingOrders({int? currentShiftId}) async {
    _isLoadingPendingOrders = true;
    notifyListeners();

    try {
      final orders = await OrderApiService.getPendingOrders();
      _pendingOrders = orders.where((o) {
        if (_dismissedOrderIds.contains(o.id)) return false;
        if (!_isToday(o)) return false;
        if (currentShiftId != null && o.shiftId != null && o.shiftId != currentShiftId) return false;
        return true;
      }).toList();
    } catch (e) {
// debugPrint("Error fetching pending orders: $e");
    } finally {
      _isLoadingPendingOrders = false;
      notifyListeners();
    }
  }

  Future<void> fetchPaidOrders({int? currentShiftId}) async {
    try {
      final orders = await OrderApiService.getPaidOrders();
      _paidOrders = orders.where((o) {
        if (currentShiftId != null && o.shiftId != null && o.shiftId != currentShiftId) return false;
        return true;
      }).toList();
      notifyListeners();
    } catch (e) {
// debugPrint("Error fetching paid orders: $e");
    }
  }

  void dismissOrder(int orderId) {
    _dismissedOrderIds.add(orderId);
    _pendingOrders.removeWhere((o) => o.id == orderId);
    notifyListeners();
  }

  Future<bool> acceptOrder(int orderId) async {
    try {
      final res = await OrderApiService.acceptOrder(orderId);
      if (res == true) {
        dismissOrder(orderId);
        return true;
      }
      return false;
    } catch (e) {
// debugPrint("Error accepting order: $e");
      return false;
    }
  }
}
