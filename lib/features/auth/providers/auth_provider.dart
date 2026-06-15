import 'package:flutter/material.dart';

class AuthProvider extends ChangeNotifier {
  String _cashierName = '';
  String _outletName = '';
  int? _outletId;

  String get cashierName => _cashierName;
  String get outletName => _outletName;
  int? get outletId => _outletId;

  void setAuthData({
    required String cashierName,
    required String outletName,
    int? outletId,
  }) {
    _cashierName = cashierName;
    _outletName = outletName;
    _outletId = outletId;
    notifyListeners();
  }
}
