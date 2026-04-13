import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../models/order_model.dart';
import '../style.dart';

class HistoryScreenContent extends StatefulWidget {
  const HistoryScreenContent({super.key});

  @override
  State<HistoryScreenContent> createState() => _HistoryScreenContentState();
}

class _HistoryScreenContentState extends State<HistoryScreenContent> {
  final TextEditingController _searchController = TextEditingController();
  final NumberFormat _formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  
  List<Order> _allOrders = [];
  List<Order> _filteredOrders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistoryData();
  }

  // REFRESH DATA
  Future<void> _loadHistoryData() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.fetchHistory();
      if (mounted) {
        setState(() {
          _allOrders = data;
          _filteredOrders = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal memuat riwayat: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _filteredOrders = _allOrders.where((order) {
        final orderNo = order.orderNo.toLowerCase();
        final cashier = order.cashierName.toLowerCase();
        final searchLower = query.toLowerCase();
        return orderNo.contains(searchLower) || cashier.contains(searchLower);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppStyle.bgLightBlue,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSearchBar(),
            const SizedBox(height: 20),
            
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadHistoryData,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
                  ),
                  child: _isLoading 
                      ? const Center(child: CircularProgressIndicator())
                      : _filteredOrders.isEmpty
                          ? _buildEmptyState()
                          : _buildDataTable(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        decoration: const InputDecoration(
          icon: Icon(Icons.search, color: AppStyle.primaryBlue),
          hintText: "Cari No. Pesanan atau Nama Kasir...",
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildDataTable() {
    return ListView( // Gunakan ListView agar bisa discroll jika data banyak
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 40,
            horizontalMargin: 24,
            headingRowColor: WidgetStateProperty.all(AppStyle.bgLightBlue.withOpacity(0.5)),
            columns: [
              _headerCell('TANGGAL & NO. ORDER'),
              _headerCell('KASIR'),
              _headerCell('MEJA'),
              _headerCell('METODE'),
              _headerCell('TOTAL'),
              _headerCell('STATUS'),
              _headerCell('AKSI'),
            ],
            rows: _filteredOrders.map((order) {
              return DataRow(
                cells: [
                  DataCell(Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(order.orderNo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text(order.date, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  )),
                  DataCell(Text(order.cashierName)),
                  DataCell(Text(order.tableNo.isEmpty ? "-" : order.tableNo)),
                  DataCell(Text(order.paymentMethod)),
                  DataCell(Text(_formatter.format(order.totalAmount), style: const TextStyle(fontWeight: FontWeight.bold, color: AppStyle.primaryBlue))),
                  DataCell(_buildStatusBadge(order.status)),
                  DataCell(
                    IconButton(
                      icon: const Icon(Icons.receipt_long, color: AppStyle.primaryBlue),
                      onPressed: () => _showReceiptDialog(order),
                      tooltip: "Detail Struk",
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  DataColumn _headerCell(String label) {
    return DataColumn(
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _buildStatusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: Text(
        status.toUpperCase(), 
        style: const TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: Colors.grey.shade200),
          const SizedBox(height: 16),
          const Text('Belum ada riwayat pesanan', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  void _showReceiptDialog(Order order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Detail Transaksi", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _receiptInfoRow("No. Order", order.orderNo),
              _receiptInfoRow("Waktu", order.date),
              _receiptInfoRow("Kasir", order.cashierName),
              _receiptInfoRow("Meja", order.tableNo.isEmpty ? "-" : order.tableNo),
              const Divider(height: 30),
              
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: order.items.length,
                  itemBuilder: (context, index) {
                    final item = order.items[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Text("${item.quantity}x", style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 10),
                          Expanded(child: Text(item.itemName)),
                          Text(_formatter.format(item.subtotal)),
                        ],
                      ),
                    );
                  },
                ),
              ),
              
              const Divider(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("TOTAL BAYAR", style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(_formatter.format(order.totalAmount), 
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppStyle.primaryBlue)),
                ],
              ),
            ],
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppStyle.primaryBlue),
              onPressed: () => Navigator.pop(context),
              child: const Text("Tutup", style: TextStyle(color: Colors.white)),
            ),
          )
        ],
      ),
    );
  }

  Widget _receiptInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }
}