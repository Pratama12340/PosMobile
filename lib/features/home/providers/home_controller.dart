import 'package:flutter/material.dart';

class HomeController extends ChangeNotifier {
  bool _isPendingPanelVisible = false;
  bool _isDraftPanelVisible = false;

  bool get isPendingPanelVisible => _isPendingPanelVisible;
  bool get isDraftPanelVisible => _isDraftPanelVisible;

  void togglePendingPanel() {
    _isPendingPanelVisible = !_isPendingPanelVisible;
    if (_isPendingPanelVisible) _isDraftPanelVisible = false;
    notifyListeners();
  }

  void toggleDraftPanel() {
    _isDraftPanelVisible = !_isDraftPanelVisible;
    if (_isDraftPanelVisible) _isPendingPanelVisible = false;
    notifyListeners();
  }

  void hideAllPanels() {
    _isPendingPanelVisible = false;
    _isDraftPanelVisible = false;
    notifyListeners();
  }
}
