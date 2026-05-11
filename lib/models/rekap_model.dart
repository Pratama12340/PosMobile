class ShiftMaster {
  final int id;
  final String name;
  final String startTime;
  final String endTime;

  ShiftMaster({
    required this.id,
    required this.name,
    required this.startTime,
    required this.endTime,
  });

  factory ShiftMaster.fromJson(Map<String, dynamic> json) {
    return ShiftMaster(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'Unknown',
      startTime: json['start_time'] ?? '00:00:00',
      endTime: json['end_time'] ?? '00:00:00',
    );
  }
}

class RekapShift {
  final int? id;
  final int? outletId;
  final int? userId;
  final int? shiftId;
  final int? uangAwal;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final String? status;

  ShiftMaster? masterInfo;

  RekapShift({
    this.id,
    this.outletId,
    this.userId,
    this.shiftId,
    this.uangAwal,
    this.startedAt,
    this.endedAt,
    this.status,
    this.masterInfo,
  });

  bool get isLate {
    if (startedAt == null || masterInfo == null) return false;

    List<String> timeParts = masterInfo!.startTime.split(':');
    int scheduledHour = int.parse(timeParts[0]);
    int scheduledMinute = int.parse(timeParts[1]);

    if (startedAt!.hour > scheduledHour) {
      return true;
    } else if (startedAt!.hour == scheduledHour &&
        startedAt!.minute > scheduledMinute) {
      return true;
    }
    return false;
  }

  String get lateStatusText => isLate ? "Telat" : "Tepat Waktu";

  factory RekapShift.fromJson(Map<String, dynamic> json) {
    return RekapShift(
      id: json['id'],
      outletId: json['outlet_id'],
      userId: json['user_id'],
      shiftId: json['shift_id'],
      uangAwal: json['uang_awal'] != null
          ? int.tryParse(json['uang_awal'].toString())
          : 0,
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at']).toLocal()
          : null,
      endedAt: json['ended_at'] != null
          ? DateTime.parse(json['ended_at']).toLocal()
          : null,
      status: json['status'],
    );
  }
}
