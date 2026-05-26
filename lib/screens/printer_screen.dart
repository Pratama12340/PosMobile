import 'package:flutter/material.dart';
import '../constants/style.dart';
import '../widgets/printer_config_modal.dart';
import '../services/storage_service.dart';
import '../services/printer_service.dart';
import '../models/print_model.dart';

class PrinterScreen extends StatefulWidget {
  const PrinterScreen({super.key});

  @override
  State<PrinterScreen> createState() => _PrinterScreenState();
}

class _PrinterScreenState extends State<PrinterScreen> {
  // Variabel penampung IP dinamis
  String currentPrinterIp = "192.168.1.87";

  @override
  void initState() {
    super.initState();
    _loadCurrentPrinterIp();
  }

  // Mengambil IP terbaru dari SharedPreferences lokal
  Future<void> _loadCurrentPrinterIp() async {
    final savedIp = await StorageService.getPrinterIp();
    if (savedIp != null && savedIp.isNotEmpty) {
      setState(() {
        currentPrinterIp = savedIp;
      });
    }
  }

  // Mengatur modal agar meng-update halaman utama ketika tombol simpan ditekan
  void _showConfigModal() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => const PrinterConfigModal(),
    );

    if (result == true) {
      _loadCurrentPrinterIp(); // Refresh IP di UI card
    }
  }

  // Fungsi memicu tes cetak fisik ke printer
  Future<void> _executeTestPrint() async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(" Mengirim data tes cetak ke $currentPrinterIp...")),
    );

    try {
      final printerService = NetworkPrinterService();

      // Struktur dummy data transaksi audit untuk melakukan test print out
      final testData = TransactionModel(
        orderId: "TEST-PRINT-ARANUS",
        outletName: "ARANUS POS",
        outletAddress: "Testing Jaringan Printer OK",
        cashierName: "Developer Mode",
        customerName: "", 
        tableNumber: "99",
        items: [
          CartItem(itemName: "Es Kelapa Segar", quantity: 2, unitPrice: 15000, notes: "Es dikit", stationId: "1"),
          CartItem(itemName: "Teh Manis Hangat", quantity: 1, unitPrice: 10000, notes: "", stationId: "1")
        ],
        discountAmount: 5000,
        taxBreakdown: [
          {"name": "PPN 11%", "calculated_amount": 3850}
        ],
        totalDariHalaman: 38850
      );

      await printerService.printReceipt(
        ipAddress: currentPrinterIp, 
        transaction: testData
      );

    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Koneksi Printer Gagal"),
            content: Text("Gagal mengirim data ke printer fisik ($currentPrinterIp).\n\nDetail Error: $e"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx), 
                child: const Text("OK")
              )
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> printers = [
      {
        'name': 'Kasir Utama',
        'status': 'Online',
        'type': 'Thermal',
        'conn': 'LAN',
        'ip': currentPrinterIp, // Data IP berubah secara reaktif mengikuti storage lokal
        'color': Colors.green,
        'station_name': 'Kasir (Semua Item)', 
      },
      {
        'name': 'Printer Dapur',
        'status': 'Offline',
        'type': 'Thermal',
        'conn': 'Bluetooth',
        'ip': 'BT:00:11:22',
        'color': Colors.red,
        'station_name': 'Dapur',
      },
    ];

    return Scaffold(
      backgroundColor: AppStyle.bgLightBlue,
      appBar: AppBar(
        title: Text(
          "Koneksi Printer",
          style: AppStyle.menuText.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppStyle.primaryBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildSoftTopButton(
                  label: "Buka Drawer",
                  icon: Icons.key_outlined,
                  bgColor: Colors.blue.shade50,
                  textColor: Colors.blue.shade700,
                  onTap: () {},
                ),
                const SizedBox(width: 16),
                _buildSoftTopButton(
                  label: "Tes Cetak",
                  icon: Icons.print_outlined,
                  bgColor: Colors.orange.shade50,
                  textColor: Colors.orange.shade800,
                  onTap: _executeTestPrint, // Terhubung ke fungsi tes cetak fisik
                ),
              ],
            ),
            const SizedBox(height: 40),

            Text(
              "Daftar Perangkat Terhubung",
              style: AppStyle.menuText.copyWith(
                fontSize: 16,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 20),

            Wrap(
              spacing: 20,
              runSpacing: 20,
              children: printers.map((p) => _buildPrinterCard(p)).toList(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showConfigModal,
        backgroundColor: AppStyle.primaryBlue,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          "Printer Baru",
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildSoftTopButton({
    required String label,
    required IconData icon,
    required Color bgColor,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: textColor, size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrinterCard(Map<String, dynamic> data) {
    bool isOnline = data['status'] == 'Online';

    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    data['name'],
                    style: AppStyle.menuText.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isOnline
                          ? Colors.green.shade50
                          : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isOnline
                            ? Colors.green.shade200
                            : Colors.red.shade200,
                      ),
                    ),
                    child: Text(
                      data['status'],
                      style: TextStyle(
                        color: isOnline
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildInfoRow("Station", data['station_name'] ?? "Semua Item"),
                  const SizedBox(height: 8),
                  _buildInfoRow("Koneksi", data['conn']),
                  const SizedBox(height: 8),
                  _buildInfoRow("Address", data['ip']),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _showConfigModal,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade50,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "PENGATURAN",
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: Colors.blue.shade700,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(height: 6, color: data['color']),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        ),
      ],
    );
  }
}