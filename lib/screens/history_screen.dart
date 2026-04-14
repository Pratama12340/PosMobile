import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../models/order_model.dart';
import '../widgets/receipt_dialog.dart';
import '../style.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  // Formatter menggunakan id_ID yang sudah diinisialisasi di main.dart
  final NumberFormat _priceFormatter = NumberFormat.currency(
    locale: 'id_ID', 
    symbol: 'Rp ', 
    decimalDigits: 0
  );
  
  List<Order> _allOrders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistoryData();
  }

  Future<void> _loadHistoryData() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.fetchHistory();
      setState(() {
        _allOrders = data;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar("Gagal memuat riwayat: $e");
      }
    }
  }

  // Fungsi untuk memanggil detail transaksi
  Future<void> _viewDetail(int id) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppStyle.primaryBlue)
      ),
    );

    try {
      final detailOrder = await ApiService.fetchHistoryDetail(id);
      
      if (mounted) {
        Navigator.pop(context); // Tutup loading

        if (detailOrder != null) {
          showDialog(
            context: context,
            builder: (context) => ReceiptDialog(order: detailOrder),
          );
        } else {
          _showErrorSnackBar("Gagal memuat detail: Data tidak ditemukan");
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showErrorSnackBar("Error parsing data: $e");
      }
    }
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
      // AppBar ditambahkan sebagai pengganti Search Bar agar UI tetap seimbang
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: AppStyle.primaryBlue))
            : _allOrders.isEmpty
              ? const Center(child: Text("Tidak ada transaksi"))
              : _buildDataTable(),
        ),
      ),
    );
  }

  Widget _buildDataTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.grey.shade100),
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(Colors.grey.shade50),
          columnSpacing: 24,
          columns: const [
            DataColumn(label: Text('INVOICE', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('TANGGAL', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('MEJA', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('METODE', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('AKSI', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: _allOrders.map((order) {
            return DataRow(cells: [
              DataCell(Text(order.invoiceNo, 
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)
              )),
              DataCell(Text(order.date, // Sudah bersih dari '000000Z'
                style: const TextStyle(fontSize: 12)
              )),
              DataCell(Text(order.tableNo, 
                style: const TextStyle(fontSize: 12)
              )),
              DataCell(Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(order.paymentMethod, 
                  style: const TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold)
                ),
              )),
              DataCell(Text(_priceFormatter.format(order.totalAmount),
                style: const TextStyle(
                  fontFamily: 'JetBrains Mono', // Font khusus angka
                  fontWeight: FontWeight.bold,
                  fontSize: 13
                ),
              )),
              DataCell(IconButton(
                icon: const Icon(Icons.receipt_long_rounded, color: AppStyle.primaryBlue),
                onPressed: () => _viewDetail(order.id),
              )),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}