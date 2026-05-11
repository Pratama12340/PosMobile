import 'package:flutter/material.dart';
import '../constants/style.dart';
import '../widgets/printer_config_modal.dart';

class PrinterScreen extends StatefulWidget {
  const PrinterScreen({super.key});

  @override
  State<PrinterScreen> createState() => _PrinterScreenState();
}

class _PrinterScreenState extends State<PrinterScreen> {
  final List<Map<String, dynamic>> printers = [
    {
      'name': 'Kasir Utama',
      'status': 'Online',
      'type': 'Thermal',
      'conn': 'LAN',
      'ip': '192.168.1.100',
      'color': Colors.green,
    },
    {
      'name': 'Printer Dapur',
      'status': 'Offline',
      'type': 'Thermal',
      'conn': 'Bluetooth',
      'ip': 'BT:00:11:22',
      'color': Colors.red,
    },
  ];

  void _showConfigModal() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const PrinterConfigModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
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
        actions: [],
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
                  onTap: () {},
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
                  _buildInfoRow("Jenis", data['type']),
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
