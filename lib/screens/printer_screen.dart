import 'package:flutter/material.dart';
import '../constants/style.dart';
import '../widgets/printer_config_modal.dart';
import '../services/storage_service.dart';
import '../services/printer_service.dart';
import '../models/print_model.dart';
import '../models/printer_device.dart'; 

class PrinterScreen extends StatefulWidget {
  const PrinterScreen({super.key});

  @override
  State<PrinterScreen> createState() => _PrinterScreenState();
}

class _PrinterScreenState extends State<PrinterScreen> {
  List<PrinterDevice> _printers = [];
  bool _isLoadingPrinters = true;

  @override
  void initState() {
    super.initState();
    _loadPrinterList(); // Bagian 4c — Ditambahkan ke initState
  }

  // Bagian 4c — Fungsi Baru _loadPrinterList setelah _loadPrinterSettings
  Future<void> _loadPrinterList() async {
    final list = await StorageService.getPrinterList();
    setState(() {
      _printers = list;
      _isLoadingPrinters = false;
    });
  }

  // Bagian 4d — Modifikasi _showConfigModal untuk mendukung mode edit dan tambah
  void _showConfigModal({PrinterDevice? existing, int? editIndex}) async {
    final result = await showDialog<PrinterDevice>(
      context: context,
      barrierDismissible: true,
      builder: (context) => PrinterConfigModal(existingPrinter: existing),
    );

    if (result != null) {
      final updatedList = await StorageService.getPrinterList();

      if (editIndex != null) {
        // Mode edit: replace data lama di index yang sama
        updatedList[editIndex] = result;
      } else {
        // Mode tambah baru: append ke list
        updatedList.add(result);
      }

      await StorageService.savePrinterList(updatedList);
      _loadPrinterList();
    }
  }

  // Bagian 4h — Fungsi Baru _buildEmptyState ketika list printer kosong
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Icon(Icons.print_disabled_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              "Belum ada printer terdaftar",
              style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(
              "Tap tombol \"Printer Baru\" untuk menambahkan",
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

Future<void> _executeTestPrint() async {
    // Ambil hanya printer yang aktif dari list
    final activePrinters = _printers.where((p) => p.isActive).toList();

    if (activePrinters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Tidak ada printer aktif. Aktifkan printer terlebih dahulu.")),
      );
      return;
    }

    // Tampilkan info berapa printer yang akan menerima job
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Mengirim tes cetak ke ${activePrinters.length} printer aktif...")),
    );

    // Data dummy untuk test print
    final testData = TransactionModel(
      orderId: "TEST-PRINT-ARANUS",
      outletName: "ARANUS POS",
      outletAddress: "Testing Jaringan Printer OK",
      cashierName: "Developer Mode",
      customerName: "",
      tableNumber: "99",
      items: [
        CartItem(itemName: "Es Kelapa Segar", quantity: 2, unitPrice: 15000, notes: "Es dikit", stationId: "1"),
        CartItem(itemName: "Teh Manis Hangat", quantity: 1, unitPrice: 10000, notes: "", stationId: "1"),
      ],
      discountAmount: 5000,
      taxBreakdown: [
        {"name": "PPN 11%", "calculated_amount": 3850}
      ],
      totalDariHalaman: 38850,
    );

    final printerService = NetworkPrinterService();

    // Loop setiap printer aktif — kirim job satu per satu
    for (final printer in activePrinters) {
      try {
        // Skip printer Bluetooth untuk sementara (belum diimplementasi)
        if (printer.conn != 'Network Printer') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("${printer.name}: Bluetooth belum didukung, dilewati.")),
            );
          }
          continue;
        }

        bool isConnected = await printerService.checkPrinterConnection(printer.ip, printer.port);

        if (!isConnected) {
          if (mounted) {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text("${printer.name} Gagal Terhubung"),
                content: Text(
                  "Tidak dapat menjangkau ${printer.name} di ${printer.ip}:${printer.port}.\n\n"
                  "Silakan periksa:\n"
                  "1. Apakah Tablet sudah terhubung ke Wi-Fi toko?\n"
                  "2. Apakah kabel LAN printer sudah tercolok?\n"
                  "3. Pastikan AP Isolation pada router dimatikan.",
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))
                ],
              ),
            );
          }
          continue; // lanjut ke printer berikutnya meski 1 gagal
        }

        await printerService.printReceipt(
          ipAddress: printer.ip,
          transaction: testData,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("✓ ${printer.name} (${printer.ip}) berhasil mencetak.")),
          );
        }

      } catch (e) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text("Error: ${printer.name}"),
              content: Text("Gagal mengirim data ke ${printer.name} (${printer.ip}).\n\nDetail: $e"),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))
              ],
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Bagian 4g — List hardcode 'printers' SUDAH DIHAPUS TOTAL dari sini.

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
                  onTap: _executeTestPrint,
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

            // Bagian 4e — Validasi state loading, empty list, dan mapping list dinamis via Wrap
            _isLoadingPrinters
                ? const Center(child: CircularProgressIndicator())
                : _printers.isEmpty
                    ? _buildEmptyState()
                    : Wrap(
                        spacing: 20,
                        runSpacing: 20,
                        children: List.generate(
                          _printers.length,
                          (i) => _buildPrinterCard(_printers[i], index: i),
                        ),
                      ),
          ],
        ),
      ),
      // Bagian 4f — Penyesuaian FAB ke mode tambah baru tanpa parameter existing
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showConfigModal(), 
        backgroundColor: AppStyle.primaryBlue,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          "Printer Baru",
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  // Bagian 4i — Modifikasi _buildPrinterCard menggunakan model PrinterDevice & passing data index untuk Edit Mode
  Widget _buildPrinterCard(PrinterDevice data, {required int index}) {
    bool isOnline = data.status == 'Online';
    Color statusColor = isOnline ? Colors.green : Colors.red;

    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
                    data.name, 
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
                      color: isOnline ? Colors.green.shade50 : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isOnline ? Colors.green.shade200 : Colors.red.shade200,
                      ),
                    ),
                    child: Text(
                      data.status,
                      style: TextStyle(
                        color: isOnline ? Colors.green.shade700 : Colors.red.shade700,
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
                  _buildInfoRow("Station", data.stationName),
                  const SizedBox(height: 8),
                  _buildInfoRow("Koneksi", data.conn),
                  const SizedBox(height: 8),
                  _buildInfoRow("Address", "${data.ip}:${data.port}"),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _showConfigModal(existing: data, editIndex: index),
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
            Container(height: 6, color: statusColor),
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
}