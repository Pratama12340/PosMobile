import 'package:flutter/material.dart';
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
  List<Order> _allOrders = [];
  List<Order> _filteredOrders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistoryData();
  }

  // LOGIKA AMBIL DATA
  Future<void> _loadHistoryData() async {
    try {
      final data = await ApiService.fetchHistory();
      setState(() {
        _allOrders = data; // Data asli
        _filteredOrders = data; // Data tampilan
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      print("History Error: $e");
    }
  }

  // LOGIKA PENCARIAN
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
            // SEARCH BAR
            _buildSearchBar(),
            const SizedBox(height: 20),
            
            // TABLE AREA
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppStyle.white,
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
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppStyle.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        style: AppStyle.menuText,
        decoration: InputDecoration(
          icon: const Icon(Icons.search, color: AppStyle.primaryBlue),
          hintText: "Cari No. Pesanan atau Nama Kasir...",
          hintStyle: AppStyle.subTitleText,
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildDataTable() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
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
                    // HARGA PAKAI JETBRAINS
                    DataCell(Text("Rp ${order.totalAmount.toInt()}", style: AppStyle.priceText.copyWith(fontSize: 14))),
                    DataCell(_buildStatusBadge(order.status)),
                    DataCell(
                      TextButton(
                        onPressed: () => _showReceiptDialog(order),
                        child: const Text('Detail struk', style: TextStyle(color: AppStyle.primaryBlue, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      }
    );
  }

  DataColumn _headerCell(String label) {
    return DataColumn(
      label: Text(label, style: AppStyle.subTitleText.copyWith(fontWeight: FontWeight.bold, color: AppStyle.textMain)),
    );
  }

  Widget _buildStatusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: Text(
        status, 
        style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Poppins')
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off, size: 60, color: Colors.grey.shade300),
          const SizedBox(height: 10),
          Text('Belum ada riwayat pesanan', style: AppStyle.subTitleText),
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
                  Text("Rincian Transaksi", style: AppStyle.titleText.copyWith(fontSize: 18)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const Divider(height: 30),
              _receiptInfoRow("No. Order", order.orderNo),
              _receiptInfoRow("Tanggal", order.date),
              _receiptInfoRow("Kasir", order.cashierName),
              _receiptInfoRow("Meja", order.tableNo),
              const Divider(height: 30),
              
              // LIST ITEMS
              ...order.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Text("${item.quantity}x", style: AppStyle.menuText.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(item.itemName, style: AppStyle.menuText)),
                    Text("Rp ${item.subtotal.toInt()}", style: AppStyle.priceText.copyWith(fontSize: 13, color: AppStyle.textMain)),
                  ],
                ),
              )),
              
              const Divider(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("TOTAL", style: AppStyle.menuText.copyWith(fontWeight: FontWeight.bold)),
                  Text("Rp ${order.totalAmount.toInt()}", style: AppStyle.priceText.copyWith(fontSize: 20)),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppStyle.primaryBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
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
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppStyle.subTitleText),
          Text(value, style: AppStyle.menuText.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}