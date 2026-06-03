import 'dart:io';
import 'package:intl/intl.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/foundation.dart';
import '../models/print_model.dart'; // Pastikan path model Anda sudah benar

class NetworkPrinterService {

  // =========================================================================
  // LOGIKA UTAMA CEK JARINGAN (ANTI CRASH / TIMEOUT PROTECTION)
  // =========================================================================
  Future<bool> checkPrinterConnection(String ip, int port) async {
    try {
      final socket = await Socket.connect(ip, port, timeout: const Duration(seconds: 2));
      socket.destroy(); 
      return true; 
    } catch (e) {
      debugPrint("🚨 [POS NETWORK CHECK] Printer tidak terjangkau di IP $ip:$port - Error: $e");
      return false;
    }
  }

  // Helper format mata uang tanpa simbol Rp
  String _fMoney(double val) {
    return NumberFormat.decimalPattern('id').format(val.toInt());
  }

  // =========================================================================
  // 1. STRUK BELANJA UTAMA (KASIR / CUSTOMER)
  // =========================================================================
  Future<void> printReceipt({
    required String ipAddress,
    required TransactionModel transaction,
    int port = 9100,
  }) async {
    try {
      // Validasi koneksi jaringan lokal sebelum melakukan build bytes struk
      bool isPrinterReady = await checkPrinterConnection(ipAddress, port);
      if (!isPrinterReady) {
        throw Exception("Printer offline atau tidak berada di jaringan Wi-Fi yang sama.");
      }

      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);
      List<int> bytes = [];

      final now = DateTime.now();
      final fullDate = DateFormat('dd-MM-yyyy HH:mm:ss').format(now);

      // --- HEADER ---
      bytes += generator.text(
        transaction.outletName.toUpperCase(),
        styles: const PosStyles(
          align: PosAlign.center, 
          bold: true, 
          height: PosTextSize.size2, 
          width: PosTextSize.size2
        ),
      );
      bytes += generator.text(transaction.outletAddress, styles: const PosStyles(align: PosAlign.center));
      bytes += generator.text("INV: ${transaction.orderId}", styles: const PosStyles(align: PosAlign.center));
      bytes += generator.hr();

      // --- INFO TRANSAKSI ---
      bytes += generator.text("Tgl   : $fullDate");
      bytes += generator.text("Meja  : ${transaction.tableNumber.isEmpty ? "-" : transaction.tableNumber}");
      bytes += generator.text("Kasir : ${transaction.cashierName}");
      bytes += generator.hr();

      // --- DAFTAR ITEM BELANJA ---
      for (var item in transaction.items) {
        bytes += generator.text(item.itemName, styles: const PosStyles(bold: true));
        
        String qtyPrice = "  ${item.quantity} x ${_fMoney(item.unitPrice)}";
        String totalItem = _fMoney(item.quantity * item.unitPrice);
        
        bytes += generator.row([
          PosColumn(text: qtyPrice, width: 7),
          PosColumn(text: totalItem, width: 5, styles: const PosStyles(align: PosAlign.right)),
        ]);

        // Catatan item ('notes')
        if (item.notes.trim().isNotEmpty) {
          bytes += generator.text("  * ${item.notes}", styles: const PosStyles(fontType: PosFontType.fontB));
        }
      }
      bytes += generator.hr();

      // --- PERHITUNGAN FINANSIAL ---
      bytes += generator.row([
        PosColumn(text: "Sub Total", width: 6),
        PosColumn(text: _fMoney(transaction.items.fold(0, (sum, item) => sum + (item.quantity * item.unitPrice.toInt()))), width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);

      if (transaction.discountAmount > 0) {
        bytes += generator.row([
          PosColumn(text: "Diskon", width: 6),
          PosColumn(text: "-${_fMoney(transaction.discountAmount)}", width: 6, styles: const PosStyles(align: PosAlign.right)),
        ]);
      }

      // Loop Pajak secara dinamis
      for (var tax in transaction.taxBreakdown) {
        String taxName = tax['name'] ?? "Pajak";
        double taxAmt = double.tryParse(tax['calculated_amount']?.toString() ?? 
                        tax['amount']?.toString() ?? '0') ?? 0;
        
        if (taxAmt > 0) {
          bytes += generator.row([
            PosColumn(text: taxName, width: 6),
            PosColumn(text: _fMoney(taxAmt), width: 6, styles: const PosStyles(align: PosAlign.right)),
          ]);
        }
      }
      bytes += generator.hr();

      // --- GRAND TOTAL ---
      bytes += generator.row([
        PosColumn(text: "TOTAL", width: 6, styles: const PosStyles(bold: true, height: PosTextSize.size2, width: PosTextSize.size2)),
        PosColumn(text: _fMoney(transaction.totalDariHalaman), width: 6, styles: const PosStyles(align: PosAlign.right, bold: true, height: PosTextSize.size2, width: PosTextSize.size2)),
      ]);
      bytes += generator.hr();

      // --- FOOTER ---
      bytes += generator.text("Terima Kasih", styles: const PosStyles(align: PosAlign.center, fontType: PosFontType.fontB));
      bytes += generator.feed(3);
      bytes += generator.cut();

      // --- PROSES KIRIM KE PRINTER VIA TCP SOCKET ---
      await _sendToPrinter(ipAddress, port, bytes);

    } catch (e) {
      debugPrint("💥 [PRINTER ERROR] Gagal cetak struk utama: $e");
      rethrow;
    }
  }

  // =========================================================================
  // 2. STRUK KHUSUS DAPUR (KITCHEN BILL)
  // =========================================================================
  Future<void> printKitchenReceipt({
    required String ipAddress,
    required TransactionModel transaction,
    int port = 9100,
  }) async {
    try {
      // Validasi koneksi jaringan lokal sebelum memproses menu dapur
      bool isPrinterReady = await checkPrinterConnection(ipAddress, port);
      if (!isPrinterReady) {
        throw Exception("Printer dapur offline atau tidak berada di jaringan Wi-Fi yang sama.");
      }

      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);
      List<int> bytes = [];

      final now = DateTime.now();
      final fullDate = DateFormat('dd-MM-yyyy HH:mm:ss').format(now);

      bytes += generator.text("======= PESANAN DAPUR =======", styles: const PosStyles(align: PosAlign.center, bold: true));
      bytes += generator.text("INV   : ${transaction.orderId}");
      bytes += generator.text("Tgl   : $fullDate");
      bytes += generator.text("Meja  : ${transaction.tableNumber.isEmpty ? "-" : transaction.tableNumber}");
      bytes += generator.hr();

      for (var item in transaction.items) {
        bytes += generator.row([
          PosColumn(text: item.itemName.toUpperCase(), width: 9, styles: const PosStyles(bold: true, height: PosTextSize.size2, width: PosTextSize.size2)),
          PosColumn(text: "x${item.quantity}", width: 3, styles: const PosStyles(align: PosAlign.right, bold: true, height: PosTextSize.size2, width: PosTextSize.size2)),
        ]);

        if (item.notes.trim().isNotEmpty) {
          bytes += generator.text("  * Catatan: ${item.notes}", styles: const PosStyles(bold: true, fontType: PosFontType.fontB));
        }
        bytes += generator.feed(1);
      }
      bytes += generator.hr();
      bytes += generator.text("ARANUS POS - KITCHEN", styles: const PosStyles(align: PosAlign.center));
      
      bytes += generator.feed(3);
      bytes += generator.cut();

      await _sendToPrinter(ipAddress, port, bytes);

    } catch (e) {
      debugPrint("💥 [PRINTER ERROR] Gagal cetak ke Dapur: $e");
      rethrow;
    }
  }

  // =========================================================================
  // BRIDGE UTAMA: PENGIRIM BYTE DATA KE SOCKET PRINTER
  // =========================================================================
  Future<void> _sendToPrinter(String ipAddress, int port, List<int> bytes) async {
    Socket? socket;
    try {
      socket = await Socket.connect(ipAddress, port, timeout: const Duration(seconds: 4));
      socket.add(bytes);
      await socket.flush();
    } finally {
      if (socket != null) {
        await socket.close();
      }
    }
  }
}