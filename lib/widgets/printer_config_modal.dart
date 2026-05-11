import 'package:flutter/material.dart';
import '../constants/style.dart';

class PrinterConfigModal extends StatefulWidget {
  const PrinterConfigModal({super.key});

  @override
  State<PrinterConfigModal> createState() => _PrinterConfigModalState();
}

class _PrinterConfigModalState extends State<PrinterConfigModal> {
  // States
  String selectedType = "Thermal Printer";
  String selectedMode = "Standard Printing";
  String selectedConn = "Network Printer";
  bool isAutoCut = true;
  bool isActive = true;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Center(
        child: Container(
          width: 550, // Optimal untuk tablet
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
              // Header Modern
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
                      // Toggle Status Printer (Paling Atas agar mudah dilihat)
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

                      // Dinamis berdasarkan koneksi
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: selectedConn == "Network Printer"
                            ? _buildNetworkFields()
                            : _buildBluetoothPicker(),
                      ),

                      _buildModernTextField(
                        "Nama Printer",
                        "Contoh: Kasir Lantai 1",
                      ),

                      Row(
                        children: [
                          Expanded(
                            child: _buildModernTextField(
                              "Chars. per line",
                              "32",
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: _buildModernTextField(
                              "Port Printer",
                              "9100",
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
        children: [
          const Icon(Icons.print_rounded, color: Colors.white, size: 28),
          const SizedBox(width: 16),
          Text(
            "Pengaturan Perangkat",
            style: AppStyle.menuText.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
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
                onChanged: isActive
                    ? onChanged
                    : null, // Disable dropdown jika printer nonaktif
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

  Widget _buildModernTextField(String label, String hint) {
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
            enabled: isActive, // Disable input jika printer nonaktif
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              filled: true,
              fillColor: isActive
                  ? Colors.grey.shade50
                  : Colors.grey.shade200, // Warna berubah jika disable
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
    return Column(
      key: const ValueKey('network'),
      children: [_buildModernTextField("IP Address Printer", "192.168.1.100")],
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
              onPressed: () {},
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
