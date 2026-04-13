import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../models/order_model.dart';
import '../style.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
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

  // --- LOGIKA API ---
  Future<void> _loadHistoryData() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.fetchHistory();
      setState(() {
        _allOrders = data;
        _filteredOrders = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar("Gagal memuat riwayat: $e");
    }
  }

  Future<void> _viewDetail(int id) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: AppStyle.primaryBlue)),
    );

    try {
      final detailOrder = await ApiService.fetchHistoryDetail(id);
      Navigator.pop(context); 
      _showReceiptDialog(detailOrder);
    } catch (e) {
      Navigator.pop(context); 
      _showErrorSnackBar("Gagal memuat detail: $e");
    }
  }

  // --- LOGIKA UI ---
  void _onSearchChanged(String query) {
    setState(() {
      _filteredOrders = _allOrders.where((order) {
        final orderNo = order.orderNo.toLowerCase();
        final cashier = order.cashierName.toLowerCase();
        return orderNo.contains(query.toLowerCase()) || 
               cashier.contains(query.toLowerCase());
      }).toList();
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppStyle.errorRed),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyle.bgLightBlue,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSearchBar(),
            const SizedBox(height: 20),
            
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppStyle.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02), 
                      blurRadius: 10, 
                      offset: const Offset(0, 4)
                    )
                  ],
                ),
                child: _isLoading 
                    ? const Center(child: CircularProgressIndicator(color: AppStyle.primaryBlue))
                    : _filteredOrders.isEmpty
                        ? _buildEmptyState()
                        : _buildDataTable(), // Memanggil fungsi tabel
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
        style: AppStyle.menuText,
        decoration: const InputDecoration(
          icon: Icon(Icons.search, color: AppStyle.primaryBlue),
          hintText: "Cari No. Pesanan atau Nama Kasir...",
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildDataTable() {
    // LayoutBuilder ditambahkan di sini untuk mendapatkan variabel 'constraints'
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.vertical, // Scroll atas bawah
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal, // Scroll kiri kanan
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                columnSpacing: 30,
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
                          Text(order.orderNo, style: AppStyle.menuText.copyWith(fontWeight: FontWeight.bold)),
                          Text(order.date, style: AppStyle.subTitleText.copyWith(fontSize: 10)),
                        ],
                      )),
                      DataCell(Text(order.cashierName, style: AppStyle.menuText)),
                      DataCell(Text(order.tableNo, style: AppStyle.menuText)),
                      DataCell(Text(order.paymentMethod, style: AppStyle.menuText)),
                      DataCell(Text(_formatter.format(order.totalAmount), style: AppStyle.priceText.copyWith(fontSize: 14))),
                      DataCell(_buildStatusBadge(order.status)),
                      DataCell(
                        TextButton(
                          onPressed: () => _viewDetail(order.id),
                          child: const Text('Detail struk', style: TextStyle(color: AppStyle.primaryBlue, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  DataColumn _headerCell(String label) {
    return DataColumn(
      label: Text(label, style: AppStyle.subTitleText.copyWith(fontWeight: FontWeight.bold, color: AppStyle.textMain))
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
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Detail Transaksi", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const Divider(height: 30),
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
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppStyle.primaryBlue, 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 16)
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text("Tutup", style: AppStyle.buttonText),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _receiptInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}