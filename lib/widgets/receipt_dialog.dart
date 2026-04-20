import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../style.dart'; // Pastikan path ini sesuai dengan project Anda
import '../models/order_model.dart';
import '../services/api_service.dart';

// --- WIDGET DIALOG UTAMA ---

class ReceiptDialog extends StatefulWidget {
  final int orderId;
  const ReceiptDialog({super.key, required this.orderId});

  @override
  State<ReceiptDialog> createState() => _ReceiptDialogState();
}

class _ReceiptDialogState extends State<ReceiptDialog> {
  late Future<Order?> _detailFuture;
  Order? localOrder; // Data lokal untuk handle perubahan UI (Qty/Note)
  bool isEditMode = false;
  final TextEditingController _noteController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _detailFuture = ApiService.fetchHistoryDetail(widget.orderId);
  }

  // Fungsi hitung total tagihan secara dinamis berdasarkan perubahan qty
  double get currentTotal {
    if (localOrder == null) return 0;
    double subtotal = 0;
    for (var item in localOrder!.items) {
      subtotal += item.subtotal;
    }
    // Total = Subtotal + Pajak - Diskon
    return subtotal + localOrder!.taxAmount - localOrder!.discountAmount;
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
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
              }
              if (snapshot.hasError || snapshot.data == null) {
                return const Center(child: Text("Gagal memuat rincian pesanan"));
              }

              // Inisialisasi data lokal hanya saat pertama kali data datang
              localOrder ??= snapshot.data;

              return Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // --- HEADER ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(localOrder!.invoiceNo,
                                style: AppStyle.priceText.copyWith(fontSize: 20, color: AppStyle.primaryBlue)),
                            Text(localOrder!.date, style: AppStyle.subTitleText),
                          ],
                        ),
                        IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                      ],
                    ),
                    const Divider(height: 30),

                    // --- INFO KASIR & MEJA ---
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppStyle.bgLightBlue, borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildInfoCol("KASIR", localOrder!.cashierName),
                          _buildInfoCol("TIPE", localOrder!.tableNo),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // --- TOMBOL EDIT / VOID ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Rincian Pesanan", style: TextStyle(fontWeight: FontWeight.bold)),
                        _buildEditToggleButton(),
                      ],
                    ),
                    const Divider(),

                    // --- LIST ITEMS ---
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: localOrder!.items.length,
                        itemBuilder: (context, i) {
                          final item = localOrder!.items[i];
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
                                          color: item.quantity == 0 ? Colors.red : Colors.black
                                        )
                                      ),
                                      Text("${item.quantity} x ${style.formatHarga(item.unitPrice)}",
                                          style: AppStyle.subTitleText.copyWith(fontSize: 11)),
                                    ],
                                  ),
                                ),
                                if (isEditMode) _buildQtyController(i),
                                const SizedBox(width: 15),
                                Text(style.formatHarga(item.subtotal), 
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    const Divider(height: 30),

                    // --- INPUT NOTE (WAJIB JIKA EDIT) ---
                    if (isEditMode)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: TextFormField(
                          controller: _noteController,
                          decoration: InputDecoration(
                            labelText: "Catatan Perubahan (Wajib Diisi)",
                            labelStyle: const TextStyle(color: Colors.redAccent, fontSize: 13),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Colors.redAccent),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) return "Tulis alasan perubahan/void item";
                            return null;
                          },
                        ),
                      ),

                    // --- TOTAL HARGA ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Total Tagihan", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(style.formatHarga(currentTotal),
                                style: const TextStyle(fontSize: 24, color: Colors.green, fontWeight: FontWeight.w900)),
                            Text("Metode: ${localOrder!.paymentMethod}", style: AppStyle.subTitleText),
                          ],
                        )
                      ],
                    ),

                    // --- TOMBOL SIMPAN (FIXED ERROR) ---
                    if (isEditMode)
                      Padding(
                        padding: const EdgeInsets.only(top: 20), // PERBAIKAN DI SINI
                        child: SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: _handleSaveUpdate,
                            child: const Text("Simpan Perubahan", 
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // --- WIDGET HELPER ---

  Widget _buildEditToggleButton() {
    return OutlinedButton.icon(
      onPressed: () => setState(() => isEditMode = !isEditMode),
      icon: Icon(isEditMode ? Icons.close : Icons.edit_note, size: 18, color: Colors.redAccent),
      label: Text(isEditMode ? "Batal" : "Edit / Void Item",
          style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Colors.redAccent),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  Widget _buildQtyController(int index) {
    return Row(
      children: [
        _qtyIconBtn(Icons.remove, () {
          if (localOrder!.items[index].quantity > 0) {
            setState(() => localOrder!.items[index].quantity--);
          }
        }),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text("${localOrder!.items[index].quantity}", 
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        _qtyIconBtn(Icons.add, () {
          setState(() => localOrder!.items[index].quantity++);
        }),
      ],
    );
  }

  Widget _qtyIconBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle, 
          border: Border.all(color: Colors.redAccent.withOpacity(0.5))
        ),
        child: Icon(icon, size: 16, color: Colors.redAccent),
      ),
    );
  }

  Widget _buildInfoCol(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: AppStyle.primaryBlue)),
      ],
    );
  }

  // --- LOGIKA SIMPAN ---

  void _handleSaveUpdate() async {
    if (_formKey.currentState!.validate()) {
      // Tampilkan indikator loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      try {
        // Kirim data ke API (Sesuaikan dengan ApiService Anda)
        // await ApiService.updateOrder(localOrder!.id, localOrder!.items, _noteController.text);
        
        await Future.delayed(const Duration(seconds: 1)); // Simulasi proses API

        if (mounted) {
          Navigator.pop(context); // Tutup Loading
          Navigator.pop(context); // Tutup Dialog Receipt
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(backgroundColor: Colors.green, content: Text("Data Berhasil Diperbarui"))
          );
        }
      } catch (e) {
        Navigator.pop(context); // Tutup Loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text("Gagal memperbarui: $e"))
        );
      }
    }
  }
}