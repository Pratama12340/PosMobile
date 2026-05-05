import 'package:intl/intl.dart';
import '../models/transaction_model.dart';

class TerminalPrinterService {
  // Fungsi untuk memformat angka menjadi titik ribuan (1.000)
  String _fMoney(double val) {
    return NumberFormat.decimalPattern('id').format(val.toInt());
  }

  void printToTerminal(TransactionModel transaction) {
    final now = DateTime.now();
    final fullDate = DateFormat('dd-MM-yyyy HH:mm:ss').format(now);
    
    StringBuffer receipt = StringBuffer();

    // --- HEADER ---
    receipt.writeln("\n        Caramel Cafe        ");
    receipt.writeln("  jln situ kamojing desa penari  ");
    receipt.writeln("   INV: ${transaction.orderId}   "); 
    receipt.writeln("-" * 32);

    // --- INFO SECTION (Sejajar Kiri) ---
    receipt.writeln("tgl      : $fullDate");
    receipt.writeln("table    : ${transaction.tableNumber.isEmpty ? "-" : transaction.tableNumber}");
    receipt.writeln("kasir    : ${transaction.cashierName}");
    receipt.writeln("customer : ${transaction.customerName.isEmpty ? "-" : transaction.customerName}");
    receipt.writeln("-" * 32);

    // --- DAFTAR BARANG ---
    if (transaction.items.isEmpty) {
      receipt.writeln("      (Tidak ada item)      ");
    } else {
      for (var item in transaction.items) {
        receipt.writeln(item.itemName);
        String qtyPrice = "${item.quantity} x ${_fMoney(item.unitPrice)}";
        String totalItem = "Rp ${_fMoney(item.quantity * item.unitPrice)}";
        receipt.writeln(_formatRow(qtyPrice, totalItem));
      }
    }
    receipt.writeln("-" * 32);

    // --- RINGKASAN (Data Database) ---
    receipt.writeln(_formatRow("Sub Total", "Rp ${_fMoney(transaction.subtotal)}"));
    
    if (transaction.discountAmount > 0) {
      receipt.writeln(_formatRow("Diskon", "-Rp ${_fMoney(transaction.discountAmount)}"));
    }
    
    receipt.writeln(_formatRow("Pajak", "Rp ${_fMoney(transaction.taxAmount)}"));
    receipt.writeln("-" * 32);
    
    // Menggunakan totalDariHalaman agar angka murni sama dengan layar
    receipt.writeln(_formatRow("TOTAL", "Rp ${_fMoney(transaction.totalDariHalaman)}"));
    receipt.writeln("-" * 32);
    
    receipt.writeln("        Terima Kasih        \n");

    print(receipt.toString());
  }

  String _formatRow(String left, String right) {
    int totalWidth = 32;
    int spaces = totalWidth - left.length - right.length;
    return "$left${" " * (spaces > 0 ? spaces : 1)}$right";
  }
}