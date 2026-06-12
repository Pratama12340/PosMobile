import 'package:sistem_pos/features/orders/models/order_model.dart';
import 'package:sistem_pos/features/printer/models/print_model.dart';
import 'package:sistem_pos/features/printer/models/printer_device.dart';
import 'package:sistem_pos/features/printer/services/printer_service.dart';
import 'package:sistem_pos/core/services/storage_service.dart';

class PrintHelper {
  static List<CartItem> orderItemsToCartItems(List<dynamic> items, {bool filterVoided = true}) {
    return items.where((item) {
      if (filterVoided && item is OrderItem && item.isVoided) return false;
      return true;
    }).map((item) {
      return CartItem(
        itemName: item.itemName,
        quantity: item is OrderItem ? item.activeQty : item.quantity,
        unitPrice: item.unitPrice,
        notes: item.notes,
        stationId: item.stationId,
        stationName: item.stationName,
      );
    }).toList();
  }

  static TransactionModel buildTransaction({
    required String orderId,
    required String outletName,
    required String outletAddress,
    required String cashierName,
    required String? customerName,
    required String? tableNumber,
    required List<CartItem> items,
    required List<Map<String, dynamic>> taxBreakdown,
    required double discountAmount,
    required double totalPrice,
  }) {
    return TransactionModel(
      orderId: orderId,
      outletName: outletName,
      outletAddress: outletAddress,
      cashierName: cashierName,
      customerName: customerName ?? 'Pelanggan',
      tableNumber: tableNumber ?? '-',
      items: items,
      taxBreakdown: taxBreakdown,
      discountAmount: discountAmount,
      totalDariHalaman: totalPrice,
    );
  }

  static Future<void> printToAllPrinters({
    required TransactionModel transaction,
    Function(String name)? onSuccess,
    Function(String name, dynamic error)? onError,
    Function()? onNoPrinter,
    bool isDoublePrint = false,
  }) async {
    final List<PrinterDevice> allPrinters = await StorageService.getPrinterList();
    final List<PrinterDevice> activePrinters = allPrinters.where((p) => p.isActive).toList();

    if (activePrinters.isEmpty) {
      onNoPrinter?.call();
      return;
    }

    final printerService = NetworkPrinterService();

    Map<String, List<CartItem>> groupedByStation = {};
    for (var item in transaction.items) {
      String sName = item.stationName.isNotEmpty ? item.stationName : 'Kasir (Semua Item)';
      groupedByStation.putIfAbsent(sName, () => []).add(item);
    }

    for (final printer in activePrinters) {
      if (printer.conn != 'Network Printer') continue;

      try {
        bool isConnected = await printerService.checkPrinterConnection(printer.ip, printer.port);

        if (!isConnected) {
          onError?.call(printer.name, "Tidak terjangkau");
          continue;
        }

        if (printer.stationName.toLowerCase().contains('kasir') ||
            printer.stationName.toLowerCase().contains('semua')) {
          await printerService.printReceipt(
            ipAddress: printer.ip,
            transaction: transaction,
            port: printer.port,
          );
        } else {
          final stationItems = groupedByStation[printer.stationName] ?? [];
          if (stationItems.isEmpty) continue;

          final stationTransaction = TransactionModel(
            orderId: transaction.orderId,
            outletName: transaction.outletName,
            outletAddress: transaction.outletAddress,
            cashierName: transaction.cashierName,
            customerName: transaction.customerName,
            tableNumber: transaction.tableNumber,
            items: stationItems,
            taxBreakdown: transaction.taxBreakdown,
            discountAmount: transaction.discountAmount,
            totalDariHalaman: transaction.totalDariHalaman,
          );

          await printerService.printKitchenReceipt(
            ipAddress: printer.ip,
            transaction: stationTransaction,
            port: printer.port,
          );
        }

        onSuccess?.call(printer.name);
      } catch (e) {
        onError?.call(printer.name, e);
      }
    }
  }
}
