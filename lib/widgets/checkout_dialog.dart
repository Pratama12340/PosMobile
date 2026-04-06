import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/order_model.dart';
import '../style.dart';

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

  @override
  void initState() {
    super.initState();
    _amountTendered = 0;
    _manualTenderController.text = "";
  }

  @override
  Widget build(BuildContext context) {
    // LOGIKA HITUNGAN PAJAK (Exclusive: Harga + Pajak)
    double subTotal = widget.totalAmount;
    double tax = subTotal * 0.1;
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
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            // --- SISI KIRI: METODE PEMBAYARAN & INPUT ---
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    const Center(
                      child: Text(
                        "Payment Method",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
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
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          CurrencyInputFormatter(),
                        ],
                        style: AppStyle.numPadText.copyWith(
                          fontSize: 35,
                          color: const Color(0xFF4285F4), // Biru ARANUS
                        ),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          hintText: "0",
                          labelText: "Isi Uang Manual",
                          labelStyle: const TextStyle(fontFamily: 'Poppins'),
                          prefixIcon: const Icon(Icons.edit_note, size: 30),
                          filled: true,
                          fillColor: const Color(0xFFF8F9FA),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (v) {
                          setState(() {
                            _amountTendered = v.isEmpty
                                ? 0
                                : double.tryParse(v.replaceAll('.', '')) ?? 0;
                          });
                        },
                      ),
                      const SizedBox(height: 30),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        children: [20000, 50000, 100000, 150000, 200000]
                            .map((v) => _quickBtn(v.toDouble()))
                            .toList(),
                      ),
                      const Spacer(),
                      if (change > 0) _buildChangeDisplay(change),
                    ] else if (_paymentMethod == 'Card') ...[
                      const Spacer(),
                      const Icon(Icons.credit_card, size: 120, color: Colors.grey),
                      const SizedBox(height: 20),
                      const Text("Silahkan Swipe atau Insert Kartu", style: TextStyle(fontFamily: 'Poppins', color: Colors.grey)),
                      const Spacer(),
                    ] else if (_paymentMethod == 'Qris') ...[
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.qr_code_2, size: 180, color: Colors.black),
                            const SizedBox(height: 10),
                            Text("SCAN QRIS DISINI", style: AppStyle.titleText.copyWith(fontSize: 14)),
                          ],
                        ),
                      ),
                      const Spacer(),
                    ]
                  ],
                ),
              ),
            ),

            // --- SISI KANAN: RINGKASAN STRUK ---
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
                        Text(widget.orderId, style: AppStyle.priceText.copyWith(fontSize: 18)),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(Icons.close, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Date : $currentDate", style: AppStyle.subTitleText.copyWith(fontSize: 12)),
                        Text("Time : $currentTime", style: AppStyle.subTitleText.copyWith(fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Cashier : ${widget.cashierName}", style: AppStyle.subTitleText.copyWith(fontSize: 12)),
                        Text("Table : ${widget.tableNumber.isEmpty ? '-' : widget.tableNumber}", 
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'Poppins')),
                      ],
                    ),
                    const Divider(height: 30),
                    Expanded(
                      child: ListView.builder(
                        itemCount: widget.cart.length,
                        itemBuilder: (context, index) {
                          var item = widget.cart.values.elementAt(index);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 15),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.itemName, style: AppStyle.menuText.copyWith(fontSize: 13, fontWeight: FontWeight.bold)),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text("${item.quantity} x ${widget.formatCurrency(item.unitPrice)}", style: AppStyle.subTitleText.copyWith(fontSize: 12)),
                                    Text(widget.formatCurrency(item.subtotal), style: AppStyle.priceText.copyWith(fontSize: 13, color: AppStyle.textMain)),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const Divider(height: 30),
                    _rowInf("Sub Total", subTotal),
                    _rowInf("Tax (10%)", tax),
                    const SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Total", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, fontFamily: 'Poppins')),
                        Text(widget.formatCurrency(grandTotal), style: AppStyle.priceText.copyWith(fontSize: 22, color: const Color(0xFF4285F4))),
                      ],
                    ),
                    const SizedBox(height: 25),
                    
                    // --- TOMBOL PROSES PEMBAYARAN ---
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4285F4),
                        disabledBackgroundColor: Colors.grey.shade300,
                        minimumSize: const Size(double.infinity, 60),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      onPressed: (_paymentMethod == 'Cash' && _amountTendered < grandTotal)
                          ? null
                          : () {
                              // MODIFIKASI: Mengirim Map Data saat Pop
                              Navigator.pop(context, {
                                'status': 'success',
                                'paymentMethod': _paymentMethod,
                                'grandTotal': grandTotal,
                                'orderId': widget.orderId,
                              });
                            },
                      child: const Text("PROSES PEMBAYARAN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Poppins')),
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget pendukung (Helper Widgets) tetap sama seperti sebelumnya...
  Widget _rowInf(String l, double v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(l, style: AppStyle.subTitleText.copyWith(fontSize: 13)),
          Text(widget.formatCurrency(v), style: AppStyle.priceText.copyWith(fontSize: 13, color: AppStyle.textGrey)),
        ],
      ),
    );
  }

  Widget _buildChangeDisplay(double change) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("Kembalian", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Poppins')),
          Text(widget.formatCurrency(change), style: AppStyle.priceText.copyWith(color: Colors.green, fontSize: 22)),
        ],
      ),
    );
  }

  Widget _payBtn(String l, IconData i) {
    bool isSelected = _paymentMethod == l;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _paymentMethod = l),
        child: Container(
          height: 100,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF4285F4) : Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: isSelected ? const Color(0xFF4285F4) : const Color(0xFFEEEEEE)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(i, color: isSelected ? Colors.white : AppStyle.textMain, size: 32),
              const SizedBox(height: 8),
              Text(l, style: AppStyle.menuText.copyWith(color: isSelected ? Colors.white : AppStyle.textMain, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickBtn(double v) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _amountTendered = v;
          _manualTenderController.text = NumberFormat.decimalPattern('id').format(v.toInt());
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFEEEEEE)),
        ),
        child: Text(widget.formatCurrency(v), style: AppStyle.priceText.copyWith(fontSize: 14, color: AppStyle.textMain)),
      ),
    );
  }
}

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue.copyWith(text: '');
    double value = double.parse(newValue.text.replaceAll('.', ''));
    final formatter = NumberFormat.decimalPattern('id');
    String newText = formatter.format(value);
    return newValue.copyWith(text: newText, selection: TextSelection.collapsed(offset: newText.length));
  }
}