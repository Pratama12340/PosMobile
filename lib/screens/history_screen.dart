import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/order_model.dart';

class HistoryScreenContent extends StatefulWidget {
  const HistoryScreenContent({super.key});

  @override
  State<HistoryScreenContent> createState() => _HistoryScreenContentState();
}

class _HistoryScreenContentState extends State<HistoryScreenContent> {
  List<Order> _apiOrders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistoryData();
  }

  Future<void> _loadHistoryData() async {
    try {
      final data = await ApiService.fetchHistory();
      setState(() {
        _apiOrders = data.map<Order>((json) => Order.fromJson(json)).toList();
        _isLoading = false;
      });
    } catch (e) {
      print("History Error: $e");
      setState(() => _isLoading = false);
    }
  }

  String formatRupiah(double amount) {
    return "Rp ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8F9FA),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Judul 'History' telah dihapus dari sini
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const TextField(
                decoration: InputDecoration(
                  icon: Icon(Icons.search, color: Colors.grey),
                  hintText: "No Pesanan / Nama Kasir",
                  hintStyle: TextStyle(fontFamily: 'Poppins'),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: _isLoading 
                    ? const Center(child: CircularProgressIndicator())
                    : _apiOrders.isEmpty
                        ? const Center(child: Text('Belum ada riwayat pesanan', style: TextStyle(fontFamily: 'Poppins')))
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              return SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                                  child: DataTable(
                                    columnSpacing: 30,
                                    horizontalMargin: 24,
                                    headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                                    columns: const [
                                      DataColumn(label: Text('TANGGAL & NO.ORDER', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins'))),
                                      DataColumn(label: Text('KASIR', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins'))),
                                      DataColumn(label: Text('MEJA', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins'))),
                                      DataColumn(label: Text('METODE', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins'))),
                                      DataColumn(label: Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins'))),
                                      DataColumn(label: Text('STATUS', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins'))),
                                      DataColumn(label: Text('AKSI', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins'))),
                                    ],
                                    rows: _apiOrders.map((order) {
                                      return DataRow(
                                        cells: [
                                          DataCell(Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text("#${order.orderNo}", style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                                              Text(order.date, style: const TextStyle(color: Colors.grey, fontSize: 11, fontFamily: 'Poppins')),
                                            ],
                                          )),
                                          DataCell(Text(order.cashierName, style: const TextStyle(fontFamily: 'Poppins'))),
                                          DataCell(Text(order.tableNo, style: const TextStyle(fontFamily: 'Poppins'))),
                                          DataCell(Text(order.paymentMethod, style: const TextStyle(fontFamily: 'Poppins'))),
                                          DataCell(Text(formatRupiah(order.totalAmount), style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins'))),
                                          DataCell(
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(20)),
                                              child: Text(order.status, style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                                            ),
                                          ),
                                          DataCell(
                                            TextButton(
                                              onPressed: () => _showReceiptDialog(order),
                                              child: const Text('Detail struk', style: TextStyle(color: Colors.blue, fontFamily: 'Poppins')),
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                              );
                            }
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Fungsi _showReceiptDialog tetap sama seperti sebelumnya
  void _showReceiptDialog(Order order) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: 450,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Detail Rincian", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, fontFamily: 'Poppins')),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Name : ${order.cashierName}", style: const TextStyle(fontWeight: FontWeight.w500, fontFamily: 'Poppins')),
                        const SizedBox(height: 4),
                        Text("No. Table : ${order.tableNo}", style: const TextStyle(fontWeight: FontWeight.w500, fontFamily: 'Poppins')),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text("Order #${order.orderNo}", style: const TextStyle(fontWeight: FontWeight.w900, fontFamily: 'Poppins')),
                        const SizedBox(height: 4),
                        Text(order.date, style: const TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'Poppins')),
                      ],
                    ),
                  ],
                ),
                const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Divider(thickness: 1, color: Color(0xFFEEEEEE))),
                const Text("Items", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Poppins')),
                const SizedBox(height: 16),
                if (order.items.isEmpty) 
                   const Text("Tidak ada detail item", style: TextStyle(color: Colors.grey, fontFamily: 'Poppins', fontStyle: FontStyle.italic)),
                ...order.items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 30, child: Text("${item.quantity}x", style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins'))),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.itemName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, fontFamily: 'Poppins')),
                            if (item.notes.isNotEmpty && item.notes != "-")
                              Text(item.notes, style: const TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic, fontFamily: 'Poppins')),
                          ],
                        ),
                      ),
                      Text(formatRupiah(item.subtotal), style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                    ],
                  ),
                )),
                const Divider(thickness: 1, color: Color(0xFFEEEEEE), height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Sub Total", style: TextStyle(color: Colors.grey, fontFamily: 'Poppins')),
                    Text(formatRupiah(order.totalAmount), style: const TextStyle(fontWeight: FontWeight.w500, fontFamily: 'Poppins')),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Total", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'Poppins')),
                    Text(formatRupiah(order.totalAmount), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.blue, fontFamily: 'Poppins')),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }
}