import 'package:flutter/material.dart';
import '../style.dart';
import '../models/order_model.dart';
import '../services/api_service.dart';

class ReceiptDialog extends StatefulWidget {
  final int orderId; // Ini id_history yang dikirim dari halaman history
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

  @override
  void initState() {
    super.initState();
    print("--- [DEBUG] MEMBUKA DIALOG HISTORY ID: ${widget.orderId} ---");
    _detailFuture = ApiService.fetchHistoryDetail(widget.orderId);
  }

  // Fungsi untuk muat ulang data secara bersih dari server
  void _triggerRefresh() {
    print("--- [DEBUG] MEMICU REFRESH DATA DARI SERVER ---");
    setState(() {
      localOrder = null; // Penting: Hapus cache lokal agar UI mengambil data baru
      _detailFuture = ApiService.fetchHistoryDetail(widget.orderId);
    });
  }

  // Hitung subtotal item secara realtime saat edit (sebelum pajak/diskon)
  double get calculatedSubtotal {
    if (localOrder == null) return 0;
    double sub = 0;
    for (var item in localOrder!.items) {
      sub += item.subtotal;
    }
    return sub;
  }

  @override
  Widget build(BuildContext context) {
    final style = AppStyle();
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.6,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: FutureBuilder<Order?>(
            future: _detailFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && localOrder == null) {
                return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
              }
              
              if (snapshot.hasData && localOrder == null) {
                localOrder = snapshot.data;
                print("--- [DEBUG] DATA DITERIMA ---");
                print("ID History: ${localOrder!.id}");
                print("ID Order Asli: ${localOrder!.orderId}"); // Ini yang dipakai buat update
              }

              if (localOrder == null) return const Center(child: Text("Data tidak ditemukan"));

              return Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // --- HEADER (Invoice, Outlet, Cetak) ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(localOrder!.invoiceNo, 
                                style: const TextStyle(fontSize: 20, color: Color(0xFF4285F4), fontWeight: FontWeight.bold)),
                            Text("${localOrder!.date} • Outlet 1", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => print("Fitur Cetak Belum Diimplementasi"), 
                              icon: const Icon(Icons.print, size: 18, color: Colors.white),
                              label: const Text("Cetak", style: TextStyle(color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4285F4),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 30),

                    // --- BOX INFO KASIR & MEJA ---
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildInfoCol("KASIR", localOrder!.cashierName),
                          _buildInfoCol("TIPE", localOrder!.tableNo),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // --- RINCIAN PESANAN ---
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Rincian Pesanan", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              _buildEditToggleButton(),
                            ],
                          ),
                          const Divider(),
                          ...localOrder!.items.map((item) => _buildItemRow(item, style)).toList(),
                          
                          const SizedBox(height: 20),
                          
                          // Timeline Log Perubahan
                          if (localOrder!.logs.isNotEmpty) _buildLogSection(localOrder!.logs),
                        ],
                      ),
                    ),

                    const Divider(height: 30),

                    // --- SUMMARY BIAYA ---
                    _buildSummaryRow("Subtotal", calculatedSubtotal, style),
                    if (localOrder!.discountAmount > 0)
                      _buildSummaryRow("Diskon", -localOrder!.discountAmount, style, isNegative: true),
                    if (localOrder!.taxAmount > 0)
                      _buildSummaryRow("Pajak", localOrder!.taxAmount, style),
                    
                    const SizedBox(height: 10),

                    // --- TOTAL TAGIHAN ---
                    _buildTotalSection(style),

                    // --- INPUT NOTES & TOMBOL SIMPAN (Hanya saat edit) ---
                    if (isEditMode) ...[
                      const SizedBox(height: 15),
                      _buildNoteInput(),
                      _buildSaveButton(),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // --- WIDGET HELPERS ---

  Widget _buildInfoCol(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4285F4), fontSize: 14)),
      ],
    );
  }

  Widget _buildItemRow(OrderItem item, AppStyle style) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.itemName, 
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      decoration: item.quantity == 0 ? TextDecoration.lineThrough : null,
                    )),
                // @ dihapus sesuai permintaan sebelumnya
                Text("${item.quantity} x ${style.formatHarga(item.unitPrice)}", 
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          if (isEditMode) _buildQtyController(item),
          const SizedBox(width: 15),
          Text(style.formatHarga(item.subtotal), style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildEditToggleButton() {
    return OutlinedButton.icon(
      onPressed: () => setState(() => isEditMode = !isEditMode),
      icon: Icon(isEditMode ? Icons.close : Icons.edit, size: 16, color: Colors.redAccent),
      label: Text(isEditMode ? "Batal" : "Edit / Void Item", style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Colors.redAccent),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  Widget _buildQtyController(OrderItem item) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
          onPressed: () => setState(() { if (item.quantity > 0) item.quantity--; }),
        ),
        Text("${item.quantity}", style: const TextStyle(fontWeight: FontWeight.bold)),
        IconButton(
          icon: const Icon(Icons.add_circle_outline, color: Color(0xFF4285F4), size: 20),
          onPressed: () => setState(() => item.quantity++),
        ),
      ],
    );
  }

  Widget _buildNoteInput() {
    return TextFormField(
      controller: _noteController,
      decoration: InputDecoration(
        hintText: "Alasan perubahan (Wajib)",
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      validator: (value) => (value == null || value.isEmpty) ? "Catatan tidak boleh kosong" : null,
    );
  }

  Widget _buildTotalSection(AppStyle style) {
    double totalDisplay = calculatedSubtotal + localOrder!.taxAmount - localOrder!.discountAmount;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text("Total Tagihan", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(style.formatHarga(totalDisplay), 
                style: const TextStyle(fontSize: 28, color: Colors.green, fontWeight: FontWeight.w900)),
            Text("Metode: ${localOrder!.paymentMethod}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, double amount, AppStyle style, {bool isNegative = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(style.formatHarga(amount), style: TextStyle(fontSize: 13, color: isNegative ? Colors.red : Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildLogSection(List<OrderLog> logs) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Row(children: const [Icon(Icons.history, size: 16), SizedBox(width: 8), Text("Log Perubahan", style: TextStyle(fontWeight: FontWeight.bold))]),
          const SizedBox(height: 10),
          ...logs.map((log) => Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.circle, size: 10, color: Color(0xFF4285F4)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(log.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                          Text(log.date, style: const TextStyle(fontSize: 9, color: Colors.grey)),
                        ],
                      ),
                      Text("Alasan: ${log.reason}", style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  // --- LOGIKA SIMPAN ---

  void _handleSaveButton() async {
    if (_formKey.currentState!.validate()) {
      showDialog(
        context: context, 
        barrierDismissible: false, 
        builder: (_) => const Center(child: CircularProgressIndicator())
      );
      
      print("--- [DEBUG] MENYIAPKAN DATA SIMPAN ---");
      print("Menggunakan OrderID Asli: ${localOrder!.orderId}");

      try {
        final success = await ApiService.updateOrder(
          orderId: localOrder!.orderId, // MENGGUNAKAN ID ORDER ASLI (ID: 4 dalam log kamu)
          items: localOrder!.items,
          reason: _noteController.text,
        );

        Navigator.pop(context); // Tutup Loading

        if (success) {
          print("--- [DEBUG] SIMPAN SUKSES, MENUNGGU SYNC SERVER ---");
          await Future.delayed(const Duration(milliseconds: 700));
          
          _triggerRefresh(); // Refresh UI dengan data baru dari server

          setState(() {
            isEditMode = false;
            _noteController.clear();
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(backgroundColor: Colors.green, content: Text("Data berhasil diperbarui"))
          );
        } else {
          print("--- [DEBUG] SIMPAN GAGAL BERDASARKAN RESPON API ---");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(backgroundColor: Colors.red, content: Text("Gagal menyimpan ke server"))
          );
        }
      } catch (e) {
        Navigator.pop(context);
        print("--- [DEBUG] ERROR SISTEM SAAT SIMPAN: $e ---");
      }
    }
  }

  Widget _buildSaveButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 15),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent, 
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
          ),
          onPressed: _handleSaveButton,
          child: const Text("Simpan Perubahan", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}