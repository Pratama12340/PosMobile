import 'dart:io';
import 'package:flutter/material.dart';
import '../constants/style.dart';
import '../models/printer_profile_model.dart';
import '../widgets/printer_config_modal.dart';
import '../services/storage_service.dart';
import '../services/printer_service.dart';
import '../models/print_model.dart';
import '../models/printer_device.dart';
import '../services/network_scanner_service.dart';

class PrinterScreen extends StatefulWidget {
  const PrinterScreen({super.key});

  @override
  State<PrinterScreen> createState() => _PrinterScreenState();
}

class _PrinterScreenState extends State<PrinterScreen> {
  List<PrinterDevice> _printers = [];
  bool _isLoadingPrinters = true;

  // States baru untuk scan otomatis
  List<ScanResult> _discoveredPrinters = [];
  bool _isScanningNetwork = false;
  int _scanProgress = 0;
  int _scanTotal = 0;
  String? _localIp;

  @override
  void initState() {
    super.initState();
    _loadPrinterList(); // Bagian 4c — load printer list
    _autoScanNetwork(); // Memulai scan otomatis di latar belakang
  }

  Future<void> _autoScanNetwork() async {
    final ip = await NetworkScannerService.getLocalIp();
    if (mounted) {
      setState(() {
        _localIp = ip;
        _isScanningNetwork = true;
        _discoveredPrinters = [];
        _scanProgress = 0;
        _scanTotal = 0;
      });
    }

    if (ip == null) {
      if (mounted) {
        setState(() {
          _isScanningNetwork = false;
        });
      }
      return;
    }

    try {
      final results = await NetworkScannerService.scanLocalNetwork(
        ports: [9100],
        onProgress: (scanned, total) {
          if (mounted) {
            setState(() {
              _scanProgress = scanned;
              _scanTotal = total;
            });
          }
        },
      );
      
      if (mounted) {
        setState(() {
          _discoveredPrinters = results;
          _isScanningNetwork = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanningNetwork = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal scan otomatis jaringan: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _scanAllNetworkDevicesPing() async {
    if (mounted) {
      setState(() {
        _isScanningNetwork = true;
        _scanProgress = 0;
        _scanTotal = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Memulai PING scan... mendeteksi SEMUA perangkat aktif.")),
      );
    }

    try {
      final results = await NetworkScannerService.scanAllDevicesPing(
        onProgress: (scanned, total) {
          if (mounted) {
            setState(() {
              _scanProgress = scanned;
              _scanTotal = total;
            });
          }
        },
      );
      if (mounted) {
        setState(() {
          _isScanningNetwork = false;
        });
        
        if (results.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Tidak ada perangkat yang membalas ping.")),
          );
        } else {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text("Perangkat Aktif (Ping) - Total: ${results.length}"),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: results.length,
                  itemBuilder: (ctx, i) {
                    return ListTile(
                      leading: Icon(Icons.devices, color: Colors.purple.shade500),
                      title: Text(results[i], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text("Ping sukses"),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppStyle.primaryBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text("TAMBAH"),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showConfigModal(defaultIp: results[i], defaultPort: 9100);
                        },
                      ),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("TUTUP"))
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanningNetwork = false;
        });
      }
    }
  }

  // Status check — ping setiap printer untuk menentukan Online/Offline
  Future<void> _checkPrinterStatuses() async {
    if (_printers.isEmpty) return;
    for (int i = 0; i < _printers.length; i++) {
      final p = _printers[i];
      if (p.conn != 'Network Printer') continue;
      final online = await NetworkScannerService.isPrinterOnline(p.ip, p.port);
      if (mounted) {
        setState(() {
          _printers[i] = PrinterDevice(
            name: p.name,
            status: online ? 'Online' : 'Offline',
            type: p.type,
            conn: p.conn,
            ip: p.ip,
            port: p.port,
            stationName: p.stationName,
            isAutoCut: p.isAutoCut,
            isActive: p.isActive,
          );
        });
      }
    }
  }

  // Bagian 4c — Load daftar printer dari storage dan ping status awal
  Future<void> _loadPrinterList() async {
    final list = await StorageService.getPrinterList();
    setState(() {
      _printers = list;
      _isLoadingPrinters = false;
    });
    // Setelah load, langsung ping semua printer untuk status awal
    _checkPrinterStatuses();
  }

  // Bagian 4d — Modifikasi _showConfigModal untuk mendukung mode edit dan tambah
  void _showConfigModal({PrinterDevice? existing, int? editIndex, String? defaultIp, int? defaultPort}) async {
    final result = await showDialog<PrinterDevice>(
      context: context,
      barrierDismissible: true,
      builder: (context) => PrinterConfigModal(
        existingPrinter: existing,
        defaultIp: defaultIp,
        defaultPort: defaultPort,
      ),
    );

    if (result != null) {
      final updatedList = await StorageService.getPrinterList();

      if (result.name == '__DELETE__') {
        if (editIndex != null) {
          updatedList.removeAt(editIndex);
        }
      } else {
        if (editIndex != null) {
          // Mode edit: replace data lama di index yang sama
          updatedList[editIndex] = result;
        } else {
          // Mode tambah baru: append ke list
          updatedList.add(result);
        }
      }

      await StorageService.savePrinterList(updatedList);
      _loadPrinterList();
      // Jalankan scan ulang jika ada printer baru didaftarkan, agar list terdeteksi ter-filter
      _autoScanNetwork();
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

  Future<void> _executeTestPrint(PrinterDevice printer) async {
    // Tampilkan info printer yang akan diuji
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Mengirim tes cetak ke ${printer.name}..."), duration: const Duration(seconds: 2)),
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

    try {
      // Skip printer Bluetooth untuk sementara (belum diimplementasi)
      if (printer.conn != 'Network Printer') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("${printer.name}: Bluetooth belum didukung, tidak dapat tes cetak.")),
          );
        }
        return;
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
        return;
      }

      await printerService.printReceipt(
        ipAddress: printer.ip,
        transaction: testData,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✓ ${printer.name} (${printer.ip}) berhasil mencetak."),
            backgroundColor: Colors.green,
          ),
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

  @override
  Widget build(BuildContext context) {
    // Bagian 4g — List hardcode 'printers' SUDAH DIHAPUS TOTAL dari sini.
    final newDiscovered = _discoveredPrinters.where((scanned) {
      return !_printers.any((p) => p.conn == 'Network Printer' && p.ip == scanned.ip);
    }).toList();

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
            const SizedBox(height: 10),

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

            // Section Printer Terdeteksi di Jaringan WiFi
            _buildDiscoveredSection(newDiscovered),
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
                  _buildInfoRow("Station", data.stationName),
                  const SizedBox(height: 8),
                  _buildInfoRow("Koneksi", data.conn),
                  _buildInfoRow("Koneksi", data.conn),
                  const SizedBox(height: 8),
                  _buildInfoRow("Address", "${data.ip}:${data.port}"),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  // Tombol Periksa Koneksi
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        if (data.conn != 'Network Printer') return;
                        final online = await NetworkScannerService.isPrinterOnline(
                            data.ip, data.port);
                        final updatedList = await StorageService.getPrinterList();
                        if (index < updatedList.length) {
                          updatedList[index] = PrinterDevice(
                            name: data.name,
                            status: online ? 'Online' : 'Offline',
                            type: data.type,
                            conn: data.conn,
                            ip: data.ip,
                            port: data.port,
                            stationName: data.stationName,
                            isAutoCut: data.isAutoCut,
                            isActive: data.isActive,
                          );
                          await StorageService.savePrinterList(updatedList);
                          _loadPrinterList();
                        }
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(
                              online
                                  ? "✓ ${data.name} Online (${data.ip})"
                                  : "✗ ${data.name} tidak dapat dijangkau.",
                            ),
                            backgroundColor:
                                online ? Colors.green : Colors.red,
                          ));
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: isOnline
                              ? Colors.green.shade300
                              : Colors.grey.shade300,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Icon(Icons.wifi_tethering_rounded,
                          size: 18,
                          color: isOnline
                              ? Colors.green.shade700
                              : Colors.grey.shade600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Tombol Tes Cetak
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _executeTestPrint(data),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade50,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Icon(
                        Icons.print_outlined,
                        size: 18,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Tombol Pengaturan
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () =>
                          _showConfigModal(existing: data, editIndex: index),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade50,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "EDIT",
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.settings_rounded,
                            size: 14,
                            color: Colors.blue.shade700,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
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
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
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

  Widget _buildDiscoveredSection(List<ScanResult> newDiscovered) {
    final double progress = _scanTotal > 0 ? _scanProgress / _scanTotal : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 40),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Printer Terdeteksi di Jaringan WiFi",
                  style: AppStyle.menuText.copyWith(
                    fontSize: 16,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_localIp != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    "IP Tablet: $_localIp | Subnet: ${_localIp!.split('.').take(3).join('.')}.x",
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ],
            ),
            IconButton(
              icon: _isScanningNetwork
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded, color: AppStyle.primaryBlue),
              tooltip: "Pindai Ulang Jaringan",
              onPressed: _isScanningNetwork ? null : _autoScanNetwork,
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_isScanningNetwork) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.blue.shade100,
                          color: Colors.blue.shade600,
                          minHeight: 6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      "$_scanProgress/$_scanTotal",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  "Sedang memindai printer di jaringan WiFi lokal...",
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.blue),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (!_isScanningNetwork && newDiscovered.isEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: Colors.grey.shade500),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _localIp == null
                        ? "Tablet tidak terhubung ke WiFi. Pastikan WiFi aktif untuk memindai."
                        : "Tidak ada printer baru terdeteksi dalam jaringan WiFi saat ini.",
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ] else if (newDiscovered.isNotEmpty) ...[
          Wrap(
            spacing: 20,
            runSpacing: 20,
            children: newDiscovered.map((scanned) {
              return _buildDiscoveredCard(scanned);
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildDiscoveredCard(ScanResult scanned) {
    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade100, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.print_rounded, color: Colors.blue.shade700, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Printer Terdeteksi",
                        style: AppStyle.menuText.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        scanned.hostname ?? "Printer Thermal (Port ${scanned.port})",
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  scanned.ip,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.blue.shade900,
                    fontFamily: 'monospace',
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    // Buka modal config modal dengan data pre-filled
                    _showConfigModal(
                      defaultIp: scanned.ip,
                      defaultPort: scanned.port,
                    );
                  },
                  icon: const Icon(Icons.add_rounded, size: 14, color: Colors.white),
                  label: const Text(
                    "TAMBAH",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}