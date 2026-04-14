import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/order_model.dart';
import '../style.dart';

class ReceiptDialog extends StatelessWidget {
  final Order order;

  const ReceiptDialog({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final priceFormatter = NumberFormat.currency(
      locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0,
    );

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.45,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.invoiceNo, style: AppStyle.titleText.copyWith(fontSize: 18, color: AppStyle.primaryBlue)),
                    Text("${order.date} • Outlet 1", style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.print, size: 16, color: Colors.white),
                      label: const Text("Cetak", style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppStyle.primaryBlue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                  ],
                )
              ],
            ),
            const SizedBox(height: 20),

            // INFO BOX: KASIR & TIPE (MEJA)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppStyle.bgLightBlue.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildInfoColumn("KASIR", order.cashierName),
                  _buildInfoColumn("TIPE", order.tableNo),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // RINCIAN PESANAN & TOMBOL EDIT
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Rincian Pesanan", style: AppStyle.menuText.copyWith(fontWeight: FontWeight.bold)),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.edit_note, size: 18, color: Colors.redAccent),
                  label: const Text("Edit / Void Item", style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.redAccent),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
            const Divider(),
            
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.3),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: order.items.length,
                itemBuilder: (context, index) {
                  final item = order.items[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.itemName, style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text("${item.quantity}x @ ${priceFormatter.format(item.unitPrice)}", 
                                style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                        Text(priceFormatter.format(item.subtotal), 
                            style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'JetBrains Mono')),
                      ],
                    ),
                  );
                },
              ),
            ),
            
            const Divider(thickness: 1, height: 32),

            // TOTAL
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Total Tagihan", style: AppStyle.titleText.copyWith(fontSize: 16)),
                Text(priceFormatter.format(order.totalAmount), 
                    style: AppStyle.titleText.copyWith(
                      fontSize: 22, color: const Color(0xFF2E7D32), 
                      fontFamily: 'JetBrains Mono', fontWeight: FontWeight.bold,
                    )),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Text("Metode: ${order.paymentMethod}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoColumn(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: AppStyle.primaryBlue)),
      ],
    );
  }
}