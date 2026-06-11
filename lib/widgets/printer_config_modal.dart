import 'package:flutter/material.dart';
import '../constants/style.dart';
import '../models/printer_device.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart';
import '../services/network_scanner_service.dart';

class PrinterConfigModal extends StatefulWidget {
  final PrinterDevice? existingPrinter;
  final String? defaultIp;
  final int? defaultPort;
  const PrinterConfigModal({
    super.key,
    this.existingPrinter,
    this.defaultIp,
    this.defaultPort,
  });

  @override
  State<PrinterConfigModal> createState() => _PrinterConfigModalState();
}

class _PrinterConfigModalState extends State<PrinterConfigModal> {
  // Controllers
  late final TextEditingController nameController;
  late final TextEditingController ipController;
  late final TextEditingController portController;
  late final TextEditingController charsController;

  // States
  String selectedType = "Thermal Printer";
  String selectedMode = "Esc/Pos Mode";
  String selectedConn = "Network Printer";
  bool isAutoCut = true;
  bool isActive = true;

  // Stations List & Selection
  List<String> stations = ["Kasir (Semua Item)"];
  String selectedStationName = "Kasir (Semua Item)";
  bool isLoadingStations = false;

  // Scanning States
  bool isScanning = false;
  List<ScanResult> scannedResults = [];
  int _scanProgress = 0;
  int _scanTotal = 0;
  String? _localIp;

  @override
  void initState() {
    super.initState();

    final p = widget.existingPrinter;
    nameController = TextEditingController(text: p?.name ?? "Printer Baru");
    ipController = TextEditingController(text: p?.ip ?? widget.defaultIp ?? "192.168.1.");
    portController = TextEditingController(text: p?.port.toString() ?? widget.defaultPort?.toString() ?? "9100");
    charsController = TextEditingController(text: "48"); // Default 48 for Panda PRJ-80USE

    if (p != null) {
      selectedType = p.type;
      selectedConn = p.conn;
      isAutoCut = p.isAutoCut;
      isActive = p.isActive;
      selectedStationName = p.stationName;
      if (!stations.contains(selectedStationName)) {
        stations.add(selectedStationName);
      }
    } else {
      _loadSavedPrinterData();
    }

    _fetchStations();
  }

  @override
  void dispose() {
    nameController.dispose();
    ipController.dispose();
    portController.dispose();
    charsController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedPrinterData() async {
    final savedIp = await StorageService.getPrinterIp();
    final savedPort = await StorageService.getPrinterPort();
    final savedPadding = await StorageService.getPaddingSize();

    setState(() {
      if (savedIp != null && savedIp.isNotEmpty) {
        ipController.text = savedIp;
      }
      portController.text = savedPort.toString();
      charsController.text = savedPadding.toInt().toString();
    });
  }

  Future<void> _fetchStations() async {
    setState(() => isLoadingStations = true);
    try {
      final list = await ApiService.getStations();
      final List<String> fetchedStations = ["Kasir (Semua Item)"];

      for (var item in list) {
        if (item is Map) {
          final sName = item['name']?.toString() ?? '';
          if (sName.isNotEmpty && !fetchedStations.contains(sName)) {
            fetchedStations.add(sName);
          }
        }
      }

      setState(() {
        stations = fetchedStations;
        if (!stations.contains(selectedStationName)) {
          if (widget.existingPrinter != null) {
            stations.add(selectedStationName);
          } else {
            selectedStationName = "Kasir (Semua Item)";
          }
        }
      });
    } catch (_) {}
    setState(() => isLoadingStations = false);
  }

  Future<void> _startNetworkScan() async {
    // Tampilkan local IP untuk debugging
    final ip = await NetworkScannerService.getLocalIp();
    setState(() {
      isScanning = true;
      scannedResults = [];
      _scanProgress = 0;
      _scanTotal = 0;
      _localIp = ip;
    });

    if (ip == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Gagal mendapatkan IP WiFi perangkat. Pastikan sudah terhubung ke WiFi.",
            ),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => isScanning = false);
      }
      return;
    }

    try {
      final results = await NetworkScannerService.scanLocalNetwork(
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
          scannedResults = results;
        });
        if (results.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Tidak ada printer terdeteksi di subnet ${ip.split('.').take(3).join('.')}.x"
                " pada port 9100/515/631.",
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal scan network: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isScanning = false);
      }
    }
  }

  Future<void> _savePrinterSettings() async {
    final name = nameController.text.trim();
    final ip = ipController.text.trim();
    final portStr = portController.text.trim();
    final charsStr = charsController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Nama printer tidak boleh kosong")),
      );
      return;
    }

    if (selectedConn == 'Network Printer' && ip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("IP Address tidak boleh kosong untuk printer jaringan")),
      );
      return;
    }

    final port = int.tryParse(portStr) ?? 9100;
    final chars = double.tryParse(charsStr) ?? 48.0;

    final newPrinter = PrinterDevice(
      name: name,
      status: isActive ? 'Online' : 'Offline',
      type: selectedType,
      conn: selectedConn,
      ip: selectedConn == 'Network Printer' ? ip : 'BT:00:11:22',
      port: port,
      stationName: selectedStationName,
      isAutoCut: isAutoCut,
      isActive: isActive,
    );

    // Simpan data kustom ke StorageService
    await StorageService.savePrinterIp(ip);
    await StorageService.savePrinterPort(port);
    await StorageService.savePaddingSize(chars);

    if (mounted) {
      Navigator.pop(context, newPrinter);
    }
  }

  Future<void> _deletePrinter() async {
    if (widget.existingPrinter == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hapus Perangkat"),
        content: const Text(
          "Apakah Anda yakin ingin menghapus printer ini dari pengaturan?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("BATAL"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("HAPUS"),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      // Kembalikan objek khusus dengan penanda hapus
      final deleteSignal = PrinterDevice(
        name: '__DELETE__',
        status: 'Offline',
        type: selectedType,
        conn: selectedConn,
        ip: '',
        port: 0,
        stationName: '',
        isAutoCut: false,
        isActive: false,
      );
      Navigator.pop(context, deleteSignal);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(viewInsets: EdgeInsets.zero),
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Center(
          child: Container(
            width: 550,
            constraints: const BoxConstraints(maxHeight: 700),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 30,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Modern Header
              _buildModalHeader(),

              // Form Body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 24,
                  ),
                  child: Column(
                    children: [
                      // Status switch
                      // Status switch
                      _buildStatusSwitch(),
                      const Divider(
                        height: 40,
                        thickness: 1,
                        color: Colors.black12,
                      ),

                      _buildModernDropdown(
                        label: "Jenis Printer",
                        value: selectedType,
                        items: ["Thermal Printer", "Impact Printer"],
                        onChanged: (v) => setState(() => selectedType = v!),
                      ),
                      _buildModernDropdown(
                        label: "Mode Printer",
                        value: selectedMode,
                        items: [
                          "Standard Printing",
                          "Esc/Pos Mode",
                          "Star Mode",
                        ],
                        onChanged: (v) => setState(() => selectedMode = v!),
                      ),
                      _buildModernDropdown(
                        label: "Koneksi Printer",
                        value: selectedConn,
                        items: ["Network Printer", "Bluetooth Printer"],
                        onChanged: (v) => setState(() => selectedConn = v!),
                      ),

                      // Station Dropdown selection
                      _buildStationDropdown(),

                      // Dynamic network scan / fields
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: selectedConn == "Network Printer"
                            ? _buildNetworkFields()
                            : _buildBluetoothPicker(),
                      ),

                      _buildModernTextField(
                        "Nama Printer",
                        nameController,
                        hint: "Contoh: Kasir Lantai 1",
                      ),

                      Row(
                        children: [
                          Expanded(
                            child: _buildModernTextField(
                              "Chars. per line",
                              charsController,
                              hint: "48",
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: _buildModernTextField(
                              "Port Printer",
                              portController,
                              hint: "9100",
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),

                      // UX Switch Auto Cut
                      _buildAutoCutSwitch(),
                    ],
                  ),
                ),
              ),

              // Footer Actions
              _buildFooterActions(),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildModalHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppStyle.primaryBlue,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.print_rounded, color: Colors.white, size: 28),
              const SizedBox(width: 16),
              Text(
                widget.existingPrinter == null ? "Tambah Perangkat" : "Edit Perangkat",
                style: AppStyle.menuText.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          if (widget.existingPrinter != null)
            IconButton(
              icon: const Icon(Icons.delete_forever_rounded, color: Colors.white, size: 26),
              tooltip: "Hapus Printer",
              onPressed: _deletePrinter,
            ),
        ],
      ),
    );
  }

  Widget _buildStatusSwitch() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isActive ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? Colors.green.shade200 : Colors.red.shade200,
        ),
      ),
      child: SwitchListTile(
        title: Text(
          "Status Perangkat",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: isActive ? Colors.green.shade800 : Colors.red.shade800,
          ),
        ),
        subtitle: Text(
          isActive
              ? "Printer aktif dan siap menerima data cetak."
              : "Printer dinonaktifkan sementara oleh sistem.",
          style: TextStyle(
            fontSize: 12,
            color: isActive ? Colors.green.shade700 : Colors.red.shade700,
          ),
        ),
        value: isActive,
        activeThumbColor: Colors.green,
        inactiveThumbColor: Colors.red.shade400,
        inactiveTrackColor: Colors.red.shade100,
        onChanged: (v) => setState(() => isActive = v),
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildModernDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300, width: 1.5),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.black87,
                ),
                dropdownColor: Colors.white,
                borderRadius: BorderRadius.circular(12),
                elevation: 8,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                onChanged: isActive ? onChanged : null,
                items: items.map((String item) {
                  return DropdownMenuItem<String>(
                    value: item,
                    child: Text(item),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStationDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Target Cetak (Station)",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300, width: 1.5),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedStationName,
                isExpanded: true,
                icon: isLoadingStations
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.black87,
                      ),
                dropdownColor: Colors.white,
                borderRadius: BorderRadius.circular(12),
                elevation: 8,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                onChanged: isActive
                    ? (v) => setState(() => selectedStationName = v!)
                    : null,
                items: stations.map((s) {
                  return DropdownMenuItem<String>(
                    value: s,
                    child: Text(s),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernTextField(
    String label,
    TextEditingController controller, {
    required String hint,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            enabled: isActive,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              filled: true,
              fillColor: isActive ? Colors.grey.shade50 : Colors.grey.shade200,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppStyle.primaryBlue,
                  width: 2,
                ),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkFields() {
    final double progress = _scanTotal > 0 ? _scanProgress / _scanTotal : 0;
    return Column(
      key: const ValueKey('network'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // WiFi scanner UI section
        Container(
          margin: const EdgeInsets.only(bottom: 24),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isActive ? Colors.blue.shade50 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive ? Colors.blue.shade200 : Colors.grey.shade300,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: icon + label + SCAN button
              Row(
                children: [
                  Icon(Icons.wifi_find_rounded,
                      color: isActive ? Colors.blue.shade700 : Colors.grey),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Temukan Printer WiFi Otomatis",
                          style: TextStyle(
                            color: isActive
                                ? Colors.blue.shade900
                                : Colors.grey,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        if (_localIp != null)
                          Text(
                            "IP perangkat Anda: $_localIp",
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue.shade600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 36,
                    child: ElevatedButton.icon(
                      onPressed:
                          isActive && !isScanning ? _startNetworkScan : null,
                      icon: isScanning
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.search_rounded,
                              size: 16, color: Colors.white),
                      label: Text(
                        isScanning ? "SCAN..." : "SCAN",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Progress bar saat scanning
              if (isScanning && _scanTotal > 0) ...[
                const SizedBox(height: 10),
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
                    const SizedBox(width: 10),
                    Text(
                      "$_scanProgress/$_scanTotal",
                      style: TextStyle(
                          fontSize: 11, color: Colors.blue.shade700),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  "Memindai subnet ${_localIp?.split('.').take(3).join('.')}.x ...",
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: Colors.blue.shade600,
                  ),
                ),
              ] else if (isScanning) ...[
                const SizedBox(height: 8),
                Text(
                  "Menginisialisasi scan...",
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: Colors.blue.shade600,
                  ),
                ),
              ],

              // Hasil scan — chip per perangkat ditemukan
              if (scannedResults.isNotEmpty && !isScanning) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.check_circle_rounded,
                        size: 15, color: Colors.green.shade700),
                    const SizedBox(width: 6),
                    Text(
                      "${scannedResults.length} perangkat ditemukan — tap untuk pilih:",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: scannedResults.map((result) {
                    final isSelected = ipController.text == result.ip;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          ipController.text = result.ip;
                          // Auto-isi port jika kosong atau default
                          portController.text = result.port.toString();
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.blue.shade700
                              : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? Colors.blue.shade700
                                : Colors.blue.shade200,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withValues(alpha: 0.08),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.print_rounded,
                                  size: 14,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.blue.shade700,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  result.ip,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.blue.shade900,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              "port: ${result.port}",
                              style: TextStyle(
                                fontSize: 10,
                                color: isSelected
                                    ? Colors.white.withValues(alpha: 0.8)
                                    : Colors.blue.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ] else if (!isScanning && scannedResults.isEmpty && _scanTotal > 0) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 15, color: Colors.orange.shade700),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        "Tidak ada printer terdeteksi. Pastikan printer menyala "
                        "dan terhubung ke WiFi yang sama.",
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        _buildModernTextField(
          "IP Address Printer",
          ipController,
          hint: "192.168.1.100",
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }

  Widget _buildBluetoothPicker() {
    return Container(
      key: const ValueKey('bluetooth'),
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isActive ? Colors.blue.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? Colors.blue.shade100 : Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.bluetooth, color: isActive ? Colors.blue : Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Cari Printer Bluetooth...",
              style: TextStyle(
                color: isActive ? Colors.blue : Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: isActive ? () {} : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              elevation: 0,
            ),
            child: const Text(
              "SCAN",
              style: TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutoCutSwitch() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: SwitchListTile(
        title: const Text(
          "Potong Kertas Otomatis",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: const Text(
          "Printer akan memotong struk secara otomatis saat selesai.",
          style: TextStyle(fontSize: 12),
        ),
        value: isAutoCut,
        activeThumbColor: AppStyle.primaryBlue,
        onChanged: isActive ? (v) => setState(() => isAutoCut = v) : null,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildFooterActions() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                side: BorderSide(color: Colors.grey.shade300, width: 1.5),
              ),
              child: const Text(
                "BATALKAN",
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: ElevatedButton(
              onPressed: _savePrinterSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade800,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: const Text(
                "SIMPAN PERANGKAT",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}