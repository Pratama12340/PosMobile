import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/order_model.dart';
import '../style.dart';
import '../screens/SuccessPaymentPage.dart';
import '../services/api_service.dart'; // Pastikan import ini benar

class CheckoutDialog extends StatefulWidget {
  final Map<int, OrderItem> cart;
  final double totalAmount;
  final String orderId;
  final String tableNumber;
  final String cashierName;
  final String Function(double) formatCurrency;

  const CheckoutDialog({
    super.key,
    required this.cart,
    required this.totalAmount,
    required this.orderId,
    required this.tableNumber,
    required this.cashierName,
    required this.formatCurrency,
  });

  @override
  State<CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<CheckoutDialog> {
  String _paymentMethod = 'Cash';
  double _amountTendered = 0;
  final TextEditingController _manualTenderController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _amountTendered = 0;
    _manualTenderController.text = "";
  }

  @override
  Widget build(BuildContext context) {
    double subTotal = widget.totalAmount;
    double tax = 0;
    double grandTotal = subTotal + tax;
    double change = _amountTendered - grandTotal;

    String currentTime = DateFormat('HH:mm').format(DateTime.now());
    String currentDate = DateFormat('dd MMM yyyy').format(DateTime.now());

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 1000,
        height: 680,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Row(
          children: [
            // SISI KIRI: PEMBAYARAN
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    const Center(child: Text("Payment Method", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Poppins'))),
                    const SizedBox(height: 30),
                    Row(
                      children: [
                        _payBtn('Cash', Icons.payments_outlined),
                        const SizedBox(width: 15),
                        _payBtn('Card', Icons.credit_card_outlined),
                        const SizedBox(width: 15),
                        _payBtn('Qris', Icons.qr_code_scanner),
                      ],
                    ),
                    const SizedBox(height: 50),
                    if (_paymentMethod == 'Cash') ...[
                      TextField(
                        controller: _manualTenderController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly, CurrencyInputFormatter()],
                        style: AppStyle.numPadText.copyWith(fontSize: 35, color: AppStyle.primaryBlue),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          hintText: "0",
                          labelText: "Isi Uang Manual",
                          prefixIcon: const Icon(Icons.edit_note, size: 30),
                          filled: true,
                          fillColor: const Color(0xFFF8F9FA),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                        ),
                        onChanged: (v) => setState(() => _amountTendered = v.isEmpty ? 0 : double.tryParse(v.replaceAll('.', '')) ?? 0),
                      ),
                      const SizedBox(height: 30),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        children: [20000, 50000, 100000, 150000, 200000].map((v) => _quickBtn(v.toDouble())).toList(),
                      ),
                      const Spacer(),
                      if (change > 0) _buildChangeDisplay(change),
                    ] else ...[
                      const Spacer(),
                      Icon(_paymentMethod == 'Card' ? Icons.credit_card : Icons.qr_code_2, size: 120, color: Colors.grey.shade300),
                      const SizedBox(height: 20),
                      Text(_paymentMethod == 'Card' ? "Silahkan Swipe atau Insert Kartu" : "SCAN QRIS UNTUK MEMBAYAR", style: const TextStyle(fontFamily: 'Poppins', color: Colors.grey)),
                      const Spacer(),
                    ]
                  ],
                ),
              ),
            ),

            // SISI KANAN: RINGKASAN STRUK
            Expanded(
              flex: 4,
              child: Container(
                padding: const EdgeInsets.all(35),
                color: const Color(0xFFFBFBFB),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(widget.orderId, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppStyle.primaryBlue)),
                        GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, color: Colors.grey, size: 28)),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(children: [const Icon(Icons.calendar_today_rounded, size: 12, color: Colors.black45), const SizedBox(width: 8), Text("$currentDate | $currentTime WIB", style: const TextStyle(fontSize: 12, color: Colors.black54))]),
                    const SizedBox(height: 8),
                    Row(children: [const Icon(Icons.person_outline_rounded, size: 14, color: Colors.black45), const SizedBox(width: 8), const Text("Cashier: ", style: TextStyle(fontSize: 12, color: Colors.black45)), Text(widget.cashierName, style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w600))]),
                    const SizedBox(height: 8),
                    Row(children: [const Icon(Icons.table_bar_rounded, size: 14, color: Colors.black45), const SizedBox(width: 8), const Text("Table: ", style: TextStyle(fontSize: 12, color: Colors.black45)), Text(widget.tableNumber.isEmpty ? '-' : widget.tableNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppStyle.primaryBlue))]),
                    const Divider(height: 40, thickness: 1),
                    Expanded(
                      child: ListView.builder(
                        itemCount: widget.cart.length,
                        itemBuilder: (context, index) {
                          var item = widget.cart.values.elementAt(index);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.itemName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), Text("${item.quantity} x ${widget.formatCurrency(item.unitPrice)}", style: const TextStyle(color: Colors.black45, fontSize: 12))])),
                                    Text(widget.formatCurrency(item.subtotal), style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                if (item.notes != null && item.notes!.isNotEmpty)
                                  Container(margin: const EdgeInsets.only(top: 4), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.08), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.orange.withOpacity(0.1))), child: Text("Note: ${item.notes}", style: const TextStyle(fontSize: 11, color: Colors.orange, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600))),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const Divider(height: 30, thickness: 1),
                    _rowInf("Sub Total", subTotal),
                    _rowInf("Tax (0%)", tax),
                    const SizedBox(height: 15),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Total", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)), Text(widget.formatCurrency(grandTotal), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppStyle.primaryBlue))]),
                    const SizedBox(height: 25),

                    // TOMBOL PROSES PEMBAYARAN
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppStyle.primaryBlue,
                          minimumSize: const Size(double.infinity, 60),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                      onPressed: (_paymentMethod == 'Cash' && _amountTendered < grandTotal) || _isLoading
                          ? null
                          : () async {
                              setState(() {
                                _isLoading = true;
                              });

                              try {
                                Map<String, dynamic> payloadData = {
                                'table_id': widget.tableNumber.isEmpty ? '1' : widget.tableNumber, 
                                'total_price': grandTotal,
                                'payment_method': _paymentMethod, // Wajib ada
                                'amount_paid': _amountTendered,   // Wajib ada
                                'items': widget.cart.values.map((item) => {
                                  'product_id': item.id,
                                  'qty': item.quantity, 
                                  'price': item.unitPrice,
                                }).toList(),
                              };

                                final result = await ApiService.submitOrder(payloadData);

                                if (result['success']) {
                                  if (context.mounted) {
                                    Navigator.pop(context, {'status': 'success'});
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => SuccessPaymentPage(
                                          orderId: widget.orderId,
                                          paymentMethod: _paymentMethod,
                                          grandTotal: grandTotal,
                                          amountPaid: _amountTendered,
                                          change: change,
                                          cart: widget.cart,
                                          tableNumber: widget.tableNumber,
                                          cashierName: widget.cashierName,
                                          outletName: "ARANUS POS",
                                          formatCurrency: widget.formatCurrency,
                                        ),
                                      ),
                                    );
                                  }
                                } else {
                                  throw Exception(result['message']);
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("Gagal Simpan: $e"), backgroundColor: Colors.red),
                                  );
                                }
                              } finally {
                                if (mounted) setState(() { _isLoading = false; });
                              }
                            },
                      child: _isLoading
                          ? const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                          : const Text("PROSES PEMBAYARAN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rowInf(String l, double v) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(l, style: const TextStyle(color: Colors.black45, fontSize: 13)),
          Text(widget.formatCurrency(v), style: const TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.bold))
        ]));
  }

  Widget _payBtn(String l, IconData i) {
    bool isSel = _paymentMethod == l;
    return Expanded(
        child: GestureDetector(
            onTap: () => setState(() => _paymentMethod = l),
            child: Container(
                height: 100,
                decoration: BoxDecoration(
                    color: isSel ? AppStyle.primaryBlue : Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: isSel ? AppStyle.primaryBlue : const Color(0xFFEEEEEE))),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(i, color: isSel ? Colors.white : AppStyle.textMain, size: 32),
                  const SizedBox(height: 8),
                  Text(l, style: TextStyle(color: isSel ? Colors.white : AppStyle.textMain, fontWeight: isSel ? FontWeight.bold : FontWeight.normal))
                ]))));
  }

  Widget _quickBtn(double v) {
    return GestureDetector(
        onTap: () => setState(() {
              _amountTendered = v;
              _manualTenderController.text = NumberFormat.decimalPattern('id').format(v.toInt());
            }),
        child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFEEEEEE))),
            child: Text(widget.formatCurrency(v), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold))));
  }

  Widget _buildChangeDisplay(double change) {
    return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.green.shade100)),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text("Kembalian", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
          Text(widget.formatCurrency(change), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 22))
        ]));
  }
}

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue.copyWith(text: '');
    double value = double.parse(newValue.text.replaceAll('.', ''));
    String newText = NumberFormat.decimalPattern('id').format(value);
    return newValue.copyWith(text: newText, selection: TextSelection.collapsed(offset: newText.length));
  }
}