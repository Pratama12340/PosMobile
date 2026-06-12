import 'package:flutter/material.dart';
import 'package:sistem_pos/features/shift/services/shift_api_service.dart';

class ShiftProvider extends ChangeNotifier {
  bool _isShiftOpen = false;
  int? _shiftId;
  String _openTime = '';

  bool get isShiftOpen => _isShiftOpen;
  int? get shiftId => _shiftId;
  String get openTime => _openTime;

  Future<void> checkShiftStatus(int outletId) async {
    try {
      final res = await ShiftApiService.checkShiftStatus(outletId);
      if (res['success'] == true && res['data'] != null) {
        final shiftData = res['data'];
        _isShiftOpen = shiftData['status'] == 'open';
        _shiftId = shiftData['id'];
        _openTime = shiftData['start_time'] ?? '';
      } else {
        _isShiftOpen = false;
        _shiftId = null;
        _openTime = '';
      }
      notifyListeners();
    } catch (e) {
// debugPrint("Error checking shift status: $e");
    }
  }

  void updateShiftStatus(bool isOpen, int? id, String time) {
    _isShiftOpen = isOpen;
    _shiftId = id;
    _openTime = time;
    notifyListeners();
  }
}
