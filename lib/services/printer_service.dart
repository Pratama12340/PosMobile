import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import 'package:flutter/foundation.dart';

class TerminalPrinterService {
  String _fMoney(double val) {
    return NumberFormat.decimalPattern('id').format(val.toInt());
  }

  void printToTerminal(TransactionModel transaction) {
    final now = DateTime.now();
    final fullDate = DateFormat('dd-MM-yyyy HH:mm:ss').format(now);
    StringBuffer receipt = StringBuffer();

    receipt.writeln(
      "\n${_centerText(transaction.outletName.toUpperCase(), 32)}",
    );
    receipt.writeln(_centerText(transaction.outletAddress, 32));
    receipt.writeln(_centerText("INV: ${transaction.orderId}", 32));
    receipt.writeln("-" * 32);

    receipt.writeln("tgl      : $fullDate");
    receipt.writeln(
      "table    : ${transaction.tableNumber.isEmpty ? "-" : transaction.tableNumber}",
    );
    receipt.writeln("kasir    : ${transaction.cashierName}");
    receipt.writeln(
      "customer : ${transaction.customerName.isEmpty ? "-" : transaction.customerName}",
    );
    receipt.writeln("-" * 32);

    for (var item in transaction.items) {
      receipt.writeln(item.itemName);

      String qtyPrice = "${item.quantity} x ${_fMoney(item.unitPrice)}";
      String totalItem = "Rp ${_fMoney(item.quantity * item.unitPrice)}";
      receipt.writeln(_formatRow(qtyPrice, totalItem));

      if (item.notes.trim().isNotEmpty) {
        receipt.writeln("  *${item.notes}");
      }
    }
    receipt.writeln("-" * 32);

    receipt.writeln(
      _formatRow("Sub Total", "Rp ${_fMoney(transaction.subtotal)}"),
    );
    if (transaction.discountAmount > 0) {
      receipt.writeln(
        _formatRow("Diskon", "-Rp ${_fMoney(transaction.discountAmount)}"),
      );
    }
    for (var tax in transaction.taxBreakdown) {
      String taxName = tax['name'] ?? "Pajak";
      double taxAmt =
          double.tryParse(tax['calculated_amount']?.toString() ?? '0') ?? 0;
      if (taxAmt > 0) {
        receipt.writeln(_formatRow(taxName, "Rp ${_fMoney(taxAmt)}"));
      }
    }
    receipt.writeln("-" * 32);
    receipt.writeln(
      _formatRow("TOTAL", "Rp ${_fMoney(transaction.totalDariHalaman)}"),
    );
    receipt.writeln("-" * 32);
    receipt.writeln('${_centerText("Terima Kasih", 32)}\n');

    debugPrint(receipt.toString());
  }

  void printKitchenToTerminal(TransactionModel transaction) {
    final now = DateTime.now();
    final fullDate = DateFormat('dd-MM-yyyy HH:mm:ss').format(now);
    StringBuffer kitchen = StringBuffer();

    kitchen.writeln("\n======= PESANAN DAPUR =======");
    kitchen.writeln("INV   : ${transaction.orderId}");
    kitchen.writeln("Tgl   : $fullDate");
    kitchen.writeln(
      "Meja  : ${transaction.tableNumber.isEmpty ? "-" : transaction.tableNumber}",
    );
    kitchen.writeln(
      "Cust  : ${transaction.customerName.isEmpty ? "-" : transaction.customerName}",
    );
    kitchen.writeln("-" * 30);

    for (var item in transaction.items) {
      kitchen.writeln(
        _formatRow(item.itemName.toUpperCase(), "x${item.quantity}", width: 30),
      );

      if (item.notes.trim().isNotEmpty) {
        kitchen.writeln("*${item.notes}");
      }
      kitchen.writeln("");
    }

    kitchen.writeln("-" * 30);
    kitchen.writeln(_centerText("ARANUS POS - KITCHEN", 30));
    kitchen.writeln("==============================\n");

    debugPrint(kitchen.toString());
  }

  String _centerText(String text, int width) {
    if (text.length >= width) return text;
    int sideSpace = (width - text.length) ~/ 2;
    return " " * sideSpace + text;
  }

  String _formatRow(String left, String right, {int width = 32}) {
    int totalWidth = width;
    int spaces = totalWidth - left.length - right.length;
    return "$left${" " * (spaces > 0 ? spaces : 1)}$right";
  }
}
