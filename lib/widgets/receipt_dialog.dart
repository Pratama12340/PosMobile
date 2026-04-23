import 'package:flutter/material.dart';
import '../style.dart';
import '../models/order_model.dart';
import '../services/api_service.dart';

class ReceiptDialog extends StatefulWidget {
  final int orderId;
  const ReceiptDialog({super.key, required this.orderId});

  @override
  State<ReceiptDialog> createState() => _ReceiptDialogState();
}

class _ReceiptDialogState extends State<ReceiptDialog> {
  late Future<Order?> _detailFuture;
  Order? localOrder;
  bool isEditMode = false;
  final TextEditingController _noteController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  double _taxRate = 0;

  @override
  void initState() {
    super.initState();
    _detailFuture = ApiService.fetchHistoryDetail(widget.orderId);
  }

  void _triggerRefresh() {
    setState(() {
      localOrder = null;
      _detailFuture = ApiService.fetchHistoryDetail(widget.orderId);
    });
  }

  double get calculatedSubtotal {
    if (localOrder == null) return 0;
    double total = 0;
    for (var item in localOrder!.items) {
      total += (item.quantity * item.unitPrice);
    }
    return total;
  }

  double get dynamicTax {
    if (localOrder == null) return 0;
    return calculatedSubtotal * _taxRate;
  }

  @override
  Widget build(BuildContext context) {
    final style = AppStyle();
    return FutureBuilder<Order?>(
      future: _detailFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && localOrder == null) {
          return const Dialog(child: SizedBox(height: 300, child: Center(child: CircularProgressIndicator())));
        }
        if (snapshot.hasData && localOrder == null) {
          localOrder = snapshot.data;
          double initialSubtotal = 0;
          for (var item in localOrder!.items) {
            initialSubtotal += item.subtotal;
          }
          if (initialSubtotal > 0) {
            _taxRate = localOrder!.taxAmount / initialSubtotal;
          }
        }
        if (localOrder == null) return const Dialog(child: Center(child: Text("Data tidak ditemukan")));

        bool showRightSide = localOrder!.logs.isNotEmpty || isEditMode;

        return Dialog(
          backgroundColor: const Color(0xFFF8FAFC),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * (showRightSide ? 0.85 : 0.5),
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            child: Form(
              key: _formKey,
              child: Row(
                children: [
                  // --- SISI KIRI: RINCIAN PESANAN ---
                  Expanded(
                    flex: 4,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: showRightSide 
                          ? const BorderRadius.horizontal(left: Radius.circular(24))
                          : BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeaderCustom(), // Perbaikan Overflow di sini
                          const SizedBox(height: 24),
                          _buildCashierInfoBox(),
                          const SizedBox(height: 32),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Rincian Pesanan", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
                              _buildEditToggleButton(),
                            ],
                          ),
                          const Divider(height: 32, thickness: 1),
                          Expanded(
                            child: ListView(
                              children: localOrder!.items.map((item) => _buildItemRowCustom(item, style)).toList(),
                            ),
                          ),
                          const Divider(height: 24, thickness: 1),
                          _buildSummaryRow("Subtotal", style.formatHarga(calculatedSubtotal)),
                          if (localOrder!.discountAmount > 0)
                            _buildSummaryRow("Diskon", "-${style.formatHarga(localOrder!.discountAmount)}", color: Colors.red),
                          if (dynamicTax > 0 || _taxRate > 0)
                            _buildSummaryRow("Pajak", style.formatHarga(dynamicTax)),
                          const Divider(height: 32, thickness: 1),
                          _buildTotalSectionCustom(style),
                        ],
                      ),
                    ),
                  ),

                  // --- SISI KANAN: LOG PERUBAHAN ---
                  if (showRightSide)
                    Expanded(
                      flex: 3,
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isEditMode) ...[
                              const Text("Input Perubahan", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 16),
                              _buildNoteInput(),
                              const SizedBox(height: 12),
                              _buildSaveButton(),
                              const Divider(height: 40),
                            ],
                            Row(
                              children: const [
                                Icon(Icons.history_rounded, color: Colors.blueGrey),
                                SizedBox(width: 8),
                                Text("Log Perubahan", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                              ],
                            ),
                            const SizedBox(height: 24),
                            Expanded(
                              child: localOrder!.logs.isEmpty
                                  ? const Center(child: Text("Riwayat akan muncul di sini", style: TextStyle(color: Colors.grey)))
                                  : _buildTimelineLogs(),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // --- Header Fix Overflow ---
  Widget _buildHeaderCustom() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded( // Mencegah teks INV terlalu panjang menabrak tombol
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                localOrder!.invoiceNo, 
                style: const TextStyle(fontSize: 26, color: Color(0xFF4285F4), fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis, // Jika sangat panjang, akan dipotong titik-titik
              ),
              const SizedBox(height: 4),
              Text("${localOrder!.date} • Outlet 1", style: const TextStyle(color: Colors.grey, fontSize: 14)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.print, size: 20, color: Colors.white),
              label: const Text("Cetak", style: TextStyle(color: Colors.white, fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4285F4),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildCashierInfoBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildInfoColumn("KASIR", localOrder!.cashierName),
          _buildInfoColumn("TIPE", localOrder!.tableNo, isRight: true),
        ],
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value, {bool isRight = false}) {
    return Column(
      crossAxisAlignment: isRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 16, color: Color(0xFF4285F4), fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildItemRowCustom(OrderItem item, AppStyle style) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.itemName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text("${item.quantity} x ${style.formatHarga(item.unitPrice)}", style: const TextStyle(fontSize: 14, color: Colors.grey)),
              ],
            ),
          ),
          if (isEditMode) _buildQtyController(item),
          const SizedBox(width: 20),
          Text(style.formatHarga(item.quantity * item.unitPrice), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {Color color = Colors.black87}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 16)),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _buildTotalSectionCustom(AppStyle style) {
    double totalDisplay = calculatedSubtotal + dynamicTax - localOrder!.discountAmount;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text("Total Tagihan", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(style.formatHarga(totalDisplay), style: const TextStyle(fontSize: 32, color: Color(0xFF4CAF50), fontWeight: FontWeight.bold)),
            Text("Metode: ${localOrder!.paymentMethod}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ],
    );
  }

  // --- SISI KANAN: LOG PERUBAHAN ---
  Widget _buildTimelineLogs() {
    return ListView.builder(
      itemCount: localOrder!.logs.length,
      itemBuilder: (context, index) {
        final log = localOrder!.logs[index];
        // Ubah "Void 3x Item" menjadi "- 3 Item"
        String formattedTitle = log.title.replaceAll(RegExp(r'Void (\d+)x'), '- \1');

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(width: 12, height: 12, decoration: const BoxDecoration(color: Color(0xFF4285F4), shape: BoxShape.circle)),
                if (index != localOrder!.logs.length - 1)
                  Container(width: 2, height: 110, color: Colors.blue.withOpacity(0.1)),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(localOrder!.cashierName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(log.date, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.withOpacity(0.1)),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(formattedTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF4285F4))),
                        const SizedBox(height: 6),
                        const Divider(),
                        const SizedBox(height: 4),
                        Text("Alasan: ${log.reason}", style: const TextStyle(fontSize: 12, color: Colors.black87, fontStyle: FontStyle.italic)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEditToggleButton() {
    return OutlinedButton.icon(
      onPressed: () => setState(() => isEditMode = !isEditMode),
      icon: Icon(isEditMode ? Icons.close : Icons.edit_note, color: Colors.redAccent, size: 18),
      label: Text(isEditMode ? "Batal" : "Edit Item", style: const TextStyle(color: Colors.redAccent)),
      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
    );
  }

  Widget _buildQtyController(OrderItem item) {
    return Row(
      children: [
        IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent), onPressed: () => setState(() => item.quantity > 0 ? item.quantity-- : null)),
        Text("${item.quantity}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        IconButton(icon: const Icon(Icons.add_circle_outline, color: Color(0xFF4285F4)), onPressed: () => setState(() => item.quantity++)),
      ],
    );
  }

  Widget _buildNoteInput() {
    return TextFormField(
      controller: _noteController,
      maxLines: 2,
      decoration: InputDecoration(
        hintText: "Tulis alasan perubahan secara detail...",
        filled: true,
        fillColor: const Color(0xFFF1F5F9),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
      validator: (value) => (value == null || value.isEmpty) ? "Wajib isi alasan" : null,
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 45,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        onPressed: _handleSaveButton,
        child: const Text("Simpan Perubahan", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _handleSaveButton() async {
    if (_formKey.currentState!.validate()) {
      showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
      try {
        final success = await ApiService.updateOrder(
          orderId: localOrder!.orderId,
          items: localOrder!.items,
          reason: _noteController.text,
        );
        Navigator.pop(context);
        if (success) {
          _triggerRefresh();
          setState(() {
            isEditMode = false;
            _noteController.clear();
          });
        }
      } catch (e) {
        Navigator.pop(context);
      }
    }
  }
}