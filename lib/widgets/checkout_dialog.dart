import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../models/order_model.dart';
import '../models/discount_model.dart';
import '../style.dart';
import '../services/api_service.dart';
import '../screens/SuccessPaymentPage.dart';
import '../services/storage_service.dart';

class CheckoutDialog extends StatefulWidget {
  final Map<int, OrderItem> cart;
  final double totalAmount;
  final String orderId;
  final String tableNumber;
  final String customerName; 
  final String cashierName;
  final String Function(double) formatCurrency;

  const CheckoutDialog({
    super.key,
    required this.cart,
    required this.totalAmount,
    required this.orderId,
    required this.tableNumber,
    required this.customerName, 
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

  bool _showDiscountList = false;
  Discount? _selectedDiscount;
  List<Discount> _availableDiscounts = [];

  List<dynamic> _availableTaxes = [];
  double _totalTaxPercentage = 0.0;

  @override
  void initState() {
    super.initState();
    _loadDiscounts();
    _loadTaxes(); 
  }

  void _loadDiscounts() async {
    final discounts = await ApiService.getDiscounts();
    if (mounted) setState(() => _availableDiscounts = discounts);
  }

  void _loadTaxes() async {
    final taxes = await ApiService.getTaxes();
    if (mounted) {
      setState(() {
        _availableTaxes = taxes;
        _totalTaxPercentage = taxes.fold(0.0, (sum, tax) {
          if (tax['type'] == 'percentage') {
            double val = double.tryParse(tax['rate']?.toString() ?? '0') ?? 0.0;
            return sum + val;
          }
          return sum;
        });
      });
    }
  }

  double _calculateDiscountValue(double subtotal) {
    if (_selectedDiscount == null) return 0;
    return _selectedDiscount!.type == 'percentage'
        ? (subtotal * _selectedDiscount!.value) / 100
        : _selectedDiscount!.value.toDouble();
  }

  Widget _buildDiscountPickerMenu(double sub) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Pilih Diskon", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Poppins')),
            IconButton(icon: const Icon(Icons.close, size: 18, color: Colors.red), onPressed: () => setState(() => _showDiscountList = false)),
          ],
        ),
        const Divider(),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 180),
          child: _availableDiscounts.isEmpty
              ? const Center(child: Text("Tidak ada diskon aktif", style: TextStyle(fontSize: 12, color: Colors.grey)))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _availableDiscounts.length,
                  itemBuilder: (context, index) {
                    var d = _availableDiscounts[index];
                    bool eligible = sub >= d.minPurchase;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      enabled: eligible,
                      dense: true,
                      leading: Icon(Icons.stars, size: 18, color: eligible ? Colors.orange : Colors.grey),
                      title: Text(d.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onTap: () {
                        setState(() {
                          _selectedDiscount = d;
                          _showDiscountList = false;
                        });
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildReceiptSummary(double sub, double tx, double disc, double grand) {
    return Column(
      children: [
        _rowInf("Sub Total", sub),
        const SizedBox(height: 8),
        _rowInf("Pajak ($_totalTaxPercentage%)", tx),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => setState(() => _showDiscountList = true),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text("Diskon", style: TextStyle(color: Colors.black45, fontSize: 12)),
                  if (_selectedDiscount != null) ...[
                    const SizedBox(width: 6),
                    Text("(${_selectedDiscount!.name})", style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 4),
                    GestureDetector(onTap: () => setState(() => _selectedDiscount = null), child: const Icon(Icons.cancel, size: 14, color: Colors.red)),
                  ] else ...[
                    const SizedBox(width: 6),
                    const Text("(Pilih Diskon)", style: TextStyle(color: AppStyle.primaryBlue, fontSize: 10, decoration: TextDecoration.underline)),
                  ]
                ],
              ),
              Text(disc > 0 ? "- ${widget.formatCurrency(disc)}" : widget.formatCurrency(0),
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: disc > 0 ? Colors.red : Colors.black)),
            ],
          ),
        ),
        const Divider(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Total", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, fontFamily: 'Poppins')),
            Text(widget.formatCurrency(grand), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppStyle.primaryBlue, fontFamily: 'Poppins')),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    double subTotal = widget.totalAmount;
    double discountAmount = _calculateDiscountValue(subTotal);
    double baseAmount = subTotal - discountAmount;
    
    double taxAmount = 0;
    for (var tax in _availableTaxes) {
      double rate = double.tryParse(tax['rate']?.toString() ?? '0') ?? 0;
      if (tax['type'] == 'percentage') {
        taxAmount += baseAmount * (rate / 100);
      } else {
        taxAmount += rate;
      }
    }
    
    double grandTotal = baseAmount + taxAmount;
    if (grandTotal < 0) grandTotal = 0;
    double change = _amountTendered - grandTotal;

    String currentTime = DateFormat('HH:mm').format(DateTime.now());
    String currentDate = DateFormat('dd MMM yyyy').format(DateTime.now());

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Container(
        width: 1000,
        height: 680,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
        child: Row(
          children: [
            // SISI KIRI: PEMBAYARAN
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    const Text("Payment Method", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                    const SizedBox(height: 30),
                    Row(children: [
                      _payBtn('Cash', Icons.payments_outlined),
                      const SizedBox(width: 15),
                      _payBtn('Card', Icons.credit_card_outlined),
                      const SizedBox(width: 15),
                      _payBtn('Qris', Icons.qr_code_scanner),
                    ]),
                    const SizedBox(height: 40),
                    if (_paymentMethod == 'Cash') ...[
                      TextField(
                        controller: _manualTenderController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly, CurrencyInputFormatter()],
                        style: AppStyle.numPadText.copyWith(fontSize: 35, color: AppStyle.primaryBlue),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          labelText: "Isi Uang Manual",
                          filled: true,
                          fillColor: const Color(0xFFF8F9FA),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                        ),
                        onChanged: (v) => setState(() => _amountTendered = v.isEmpty ? 0 : double.tryParse(v.replaceAll('.', '')) ?? 0),
                      ),
                      const SizedBox(height: 25),
                      Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.center,
                          children: [20000, 50000, 100000, 150000, 200000].map((v) => _quickBtn(v.toDouble())).toList()),
                      const Spacer(),
                      if (change > 0) _buildChangeDisplay(change),
                    ] else ...[
                      const Spacer(),
                      Icon(_paymentMethod == 'Card' ? Icons.credit_card : Icons.qr_code_2, size: 120, color: Colors.grey.shade300),
                      const Spacer(),
                    ]
                  ],
                ),
              ),
            ),
            // SISI KANAN: RINGKASAN PESANAN
            Expanded(
              flex: 4,
              child: Container(
                padding: const EdgeInsets.fromLTRB(30, 20, 30, 30),
                decoration: const BoxDecoration(
                  color: Color(0xFFFBFBFB),
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(28),
                    bottomRight: Radius.circular(28),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(alignment: Alignment.topRight, child: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))),
                    
                    // INFORMASI TRANSAKSI (CUSTOMER & MEJA DIMAJUKAN KE KIRI)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Informasi Kasir
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Kasir: ${widget.cashierName}", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            Text("$currentDate | $currentTime WIB", style: const TextStyle(fontSize: 11, color: Colors.black54)),
                          ],
                        ),
                        
                        // Jarak tetap untuk memajukan posisi kolom Customer
                        const SizedBox(width: 70), 

                        // Informasi Customer & Meja (Sejajar Atas-Bawah, Rata Kiri)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.customerName.isEmpty ? "Customer: -" : "Customer: ${widget.customerName}", 
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black)
                            ),
                            const SizedBox(height: 3),
                            Text(
                              widget.tableNumber.isEmpty ? "Meja: -" : "Meja: ${widget.tableNumber}", 
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black)
                            ),
                          ],
                        )
                      ],
                    ),
                    
                    const Divider(height: 30),
                    Expanded(
                      child: ListView.builder(
                        itemCount: widget.cart.length,
                        itemBuilder: (context, index) {
                          var item = widget.cart.values.elementAt(index);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Text(item.itemName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                        Text("${item.quantity} x ${widget.formatCurrency(item.unitPrice)}", style: const TextStyle(color: Colors.black45, fontSize: 11)),
                                        if (item.notes != null && item.notes.isNotEmpty)
                                          Text("Note: ${item.notes}", style: TextStyle(fontSize: 10, color: Colors.orange[800], fontStyle: FontStyle.italic)),
                                      ])),
                                  Text(widget.formatCurrency(item.subtotal), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                ]),
                          );
                        },
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0xFFEEEEEE))),
                      child: _showDiscountList ? _buildDiscountPickerMenu(subTotal) : _buildReceiptSummary(subTotal, taxAmount, discountAmount, grandTotal),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppStyle.primaryBlue, minimumSize: const Size(double.infinity, 60), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                      onPressed: (_paymentMethod == 'Cash' && _amountTendered < grandTotal) || _isLoading ? null : _processPayment,
                      child: _isLoading
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
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

  Future<void> _processPayment() async {
    setState(() => _isLoading = true);
    try {
      final savedOutletId = await StorageService.getOutletId();
      if (savedOutletId == null || savedOutletId == 0) throw Exception("ID Outlet tidak ditemukan.");

      double subTotal = widget.totalAmount;
      double discountAmount = _calculateDiscountValue(subTotal);
      double baseAmount = subTotal - discountAmount;

      double taxAmountFinal = 0;
      for (var tax in _availableTaxes) {
        double rate = double.tryParse(tax['rate']?.toString() ?? '0') ?? 0;
        taxAmountFinal += (tax['type'] == 'percentage') ? (baseAmount * (rate / 100)) : rate;
      }

      double grandTotal = baseAmount + taxAmountFinal;
      double change = _amountTendered - grandTotal;

      var mappedItems = widget.cart.values.map((item) {
        return {
          'product_id': item.productId,
          'qty': item.quantity,
          'price': item.unitPrice.toInt(),
          'notes': item.notes ?? '' 
        };
      }).toList();

      Map<String, dynamic> payload = {
        'outlet_id': savedOutletId,
        'invoice_number': "INV-${DateTime.now().millisecondsSinceEpoch}",
        'customer_name': widget.customerName, 
        'table_id': widget.tableNumber.isEmpty ? null : widget.tableNumber,
        'subtotal_price': subTotal.toInt(),
        'total_price': grandTotal.toInt(),
        'discount_amount': discountAmount.toInt(),
        'tax_amount': taxAmountFinal.toInt(),
        'tax_breakdown': _availableTaxes,
        'payment_method': _paymentMethod,
        'paid_amount': _paymentMethod == 'Cash' ? _amountTendered.toInt() : grandTotal.toInt(),
        'change_amount': _paymentMethod == 'Cash' ? change.toInt() : 0,
        'discount_id': _selectedDiscount?.id,
        'items': mappedItems,
        'status': 'paid',
      };

      final res = await ApiService.submitOrder(payload);

      if (res['success'] && context.mounted) {
        Navigator.pop(context, {'status': 'success'});
        Navigator.push(context, MaterialPageRoute(builder: (c) => SuccessPaymentPage(
          orderId: widget.orderId,
          paymentMethod: _paymentMethod,
          grandTotal: grandTotal,
          amountPaid: _paymentMethod == 'Cash' ? _amountTendered : grandTotal,
          change: _paymentMethod == 'Cash' ? change : 0,
          cart: widget.cart,
          tableNumber: widget.tableNumber,
          customerName: widget.customerName, 
          cashierName: widget.cashierName,
          outletName: "ARANUS POS",
          formatCurrency: widget.formatCurrency,
        )));
      } else {
        throw Exception(res['message'] ?? "Gagal memproses pesanan");
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _rowInf(String l, double v) => Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: const TextStyle(color: Colors.black45, fontSize: 12)), Text(widget.formatCurrency(v), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))]));
  
  Widget _payBtn(String l, IconData i) { 
    bool s = _paymentMethod == l; 
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _paymentMethod = l), 
        child: Container(
          height: 100, 
          decoration: BoxDecoration(
            color: s ? AppStyle.primaryBlue : Colors.white, 
            borderRadius: BorderRadius.circular(18), 
            border: Border.all(color: s ? AppStyle.primaryBlue : const Color(0xFFEEEEEE))
          ), 
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, 
            children: [
              Icon(i, color: s ? Colors.white : AppStyle.textMain, size: 28), 
              const SizedBox(height: 8), 
              Text(l, style: TextStyle(color: s ? Colors.white : AppStyle.textMain, fontWeight: s ? FontWeight.bold : FontWeight.normal))
            ]
          )
        )
      )
    ); 
  }
  
  Widget _quickBtn(double v) => GestureDetector(onTap: () => setState(() { _amountTendered = v; _manualTenderController.text = NumberFormat.decimalPattern('id').format(v.toInt()); }), child: Container(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFEEEEEE))), child: Text(widget.formatCurrency(v), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold))));
  
  Widget _buildChangeDisplay(double c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15), 
    decoration: BoxDecoration(
      color: Colors.green.shade50, 
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: Colors.green.withOpacity(0.1))
    ), 
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween, 
      children: [
        const Text("Kembalian", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14)), 
        Text(widget.formatCurrency(c), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w900, fontSize: 24))
      ]
    )
  );
}

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue o, TextEditingValue n) {
    if (n.text.isEmpty) return n.copyWith(text: '');
    String t = NumberFormat.decimalPattern('id').format(double.parse(n.text.replaceAll('.', '')));
    return n.copyWith(text: t, selection: TextSelection.collapsed(offset: t.length));
  }
}