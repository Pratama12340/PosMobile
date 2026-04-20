import 'dart:convert';

// Model untuk data Master Shift (Jadwal Kerja)
class ShiftMaster {
  final int id;
  final String name;
  final String startTime; 
  final String endTime;   

  ShiftMaster({required this.id, required this.name, required this.startTime, required this.endTime});

  factory ShiftMaster.fromJson(Map<String, dynamic> json) {
    return ShiftMaster(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'Unknown',
      startTime: json['start_time'] ?? '00:00:00',
      endTime: json['end_time'] ?? '00:00:00',
    );
  }
}

// Model untuk data Transaksi/Riwayat Shift (Tabel shift_karyawans)
class RekapShift {
  final int? id;
  final int? outletId;
  final int? userId;
  final int? shiftId;
  final int? uangAwal;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final String? status;
  
  // Objek pendukung untuk menampung info jadwal dari tabel shifts
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

  // LOGIC: Cek apakah user telat saat mulai shift (startedAt)
  bool get isLate {
    if (startedAt == null || masterInfo == null) return false;

    // Memecah jam jadwal (Contoh: "08:30:00" -> hour: 8, min: 30)
    List<String> timeParts = masterInfo!.startTime.split(':');
    int scheduledHour = int.parse(timeParts[0]);
    int scheduledMinute = int.parse(timeParts[1]);

    // Bandingkan jam login aktual dengan jadwal
    if (startedAt!.hour > scheduledHour) {
      return true;
    } else if (startedAt!.hour == scheduledHour && startedAt!.minute > scheduledMinute) {
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
      uangAwal: json['uang_awal'] != null ? int.tryParse(json['uang_awal'].toString()) : 0,
      startedAt: json['started_at'] != null ? DateTime.parse(json['started_at']).toLocal() : null,
      endedAt: json['ended_at'] != null ? DateTime.parse(json['ended_at']).toLocal() : null,
      status: json['status'],
    );
  }
}