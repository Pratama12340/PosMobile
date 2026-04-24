import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
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

  // PANEL PILIHAN DISKON (MENUTUPI SISI KANAN)
  Widget _buildSideDiscountPanel(double sub) {
    return Container(
      color: const Color(0xFFF4F7F9),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Pilih Voucher", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, fontFamily: 'Poppins')),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.red),
                onPressed: () => setState(() => _showDiscountList = false),
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 10),
          Expanded(
            child: _availableDiscounts.isEmpty
                ? const Center(child: Text("Tidak ada diskon aktif", style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: _availableDiscounts.length,
                    itemBuilder: (context, index) {
                      var d = _availableDiscounts[index];
                      bool eligible = sub >= d.minPurchase;
                      return Opacity(
                        opacity: eligible ? 1.0 : 0.5,
                        child: _buildVoucherCard(d, eligible),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // DESAIN KARTU VOUCHER (MODEL TIKET)
  Widget _buildVoucherCard(Discount d, bool eligible) {
    return GestureDetector(
      onTap: eligible ? () {
        setState(() {
          _selectedDiscount = d;
          _showDiscountList = false;
        });
      } : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        height: 100,
        child: CustomPaint(
          painter: _TicketPainter(),
          child: Row(
            children: [
              Container(
                width: 70,
                alignment: Alignment.center,
                child: Icon(Icons.local_offer_rounded, color: eligible ? AppStyle.primaryBlue : Colors.grey, size: 30),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(8, (index) => Container(width: 1, height: 4, margin: const EdgeInsets.symmetric(vertical: 2), color: Colors.grey.withOpacity(0.3))),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(d.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text(
                        d.type == 'percentage' ? "${d.value.toInt()}% OFF" : "Potongan ${widget.formatCurrency(d.value.toDouble())}",
                        style: TextStyle(color: eligible ? AppStyle.primaryBlue : Colors.grey, fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                      Text("Min. Belanja: ${widget.formatCurrency(d.minPurchase.toDouble())}", style: const TextStyle(fontSize: 10, color: Colors.black45)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDiscountButton(double discAmount) {
    bool hasDiscount = _selectedDiscount != null;
    return InkWell(
      onTap: () => setState(() => _showDiscountList = true),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: hasDiscount ? Colors.orange.withOpacity(0.08) : Colors.grey.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: hasDiscount ? Colors.orange.withOpacity(0.3) : Colors.black12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(hasDiscount ? Icons.confirmation_number_rounded : Icons.local_offer_outlined, size: 18, color: hasDiscount ? Colors.orange : Colors.black45),
                const SizedBox(width: 10),
                Text(hasDiscount ? _selectedDiscount!.name : "Pilih Diskon", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: hasDiscount ? Colors.orange[900] : Colors.black54)),
              ],
            ),
            Row(
              children: [
                Text(hasDiscount ? "- ${widget.formatCurrency(discAmount)}" : "Tambah", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: hasDiscount ? Colors.red : AppStyle.primaryBlue)),
                if (hasDiscount) ...[
                  const SizedBox(width: 8),
                  GestureDetector(onTap: () => setState(() => _selectedDiscount = null), child: const Icon(Icons.cancel, size: 18, color: Colors.red)),
                ]
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptSummary(double sub, double baseAmount, double disc, double grand) {
    return Column(
      children: [
        _rowInf("Sub Total", sub),
        const SizedBox(height: 10),
        _buildDiscountButton(disc),
        const SizedBox(height: 10),
        const Divider(color: Color(0xFFEEEEEE), height: 1),
        const SizedBox(height: 10),
        ..._availableTaxes.map((tax) {
          double rate = double.tryParse(tax['rate']?.toString() ?? '0') ?? 0;
          double amt = (tax['type'] == 'percentage') ? (baseAmount * (rate / 100)) : rate;
          String label = tax['name'] ?? "Pajak";
          if (tax['type'] == 'percentage') label += " (${rate.toString().replaceAll('.0', '')}%)";
          return Padding(padding: const EdgeInsets.only(bottom: 6), child: _rowInf(label, amt));
        }).toList(),
        const Divider(height: 24, thickness: 1),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Total", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, fontFamily: 'Poppins')),
            Text(widget.formatCurrency(grand), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppStyle.primaryBlue, fontFamily: 'Poppins')),
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
      taxAmount += (tax['type'] == 'percentage') ? (baseAmount * (rate / 100)) : rate;
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
            // SISI KIRI
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
            // SISI KANAN (DIUBAH MENJADI STACK)
            Expanded(
              flex: 4,
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFFBFBFB),
                  borderRadius: BorderRadius.only(topRight: Radius.circular(28), bottomRight: Radius.circular(28)),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(topRight: Radius.circular(28), bottomRight: Radius.circular(28)),
                  child: Stack(
                    children: [
                      // Layer Utama: Receipt
                      Padding(
                        padding: const EdgeInsets.fromLTRB(30, 25, 30, 25),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text("Kasir: ${widget.cashierName}", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                  Text("$currentDate | $currentTime WIB", style: const TextStyle(fontSize: 11, color: Colors.black54)),
                                ]),
                                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                  Text(widget.customerName.isEmpty ? "Cust: -" : "Cust: ${widget.customerName}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  Text(widget.tableNumber.isEmpty ? "Meja: -" : "Meja: ${widget.tableNumber}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                ]),
                              ],
                            ),
                            const Divider(height: 30),
                            Expanded(
                              child: ListView.builder(
                                itemCount: widget.cart.length,
                                itemBuilder: (context, index) {
                                  var item = widget.cart.values.elementAt(index);
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 14),
                                    child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                                Text(item.itemName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                                Text("${item.quantity} x ${widget.formatCurrency(item.unitPrice)}", style: const TextStyle(color: Colors.black45, fontSize: 11)),
                                              ])),
                                          Text(widget.formatCurrency(item.subtotal), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                        ]),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0xFFEEEEEE))),
                              child: _buildReceiptSummary(subTotal, baseAmount, discountAmount, grandTotal),
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
                      // Layer Pilihan Diskon (Overlay Sisi Kanan)
                      if (_showDiscountList) _buildSideDiscountPanel(subTotal),
                    ],
                  ),
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
        return {'product_id': item.productId, 'qty': item.quantity, 'price': item.unitPrice.toInt(), 'notes': item.notes ?? ''};
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

      // 1. Kirim data ke backend
      final res = await ApiService.submitOrder(payload);

      if (res['success'] && context.mounted) {
        // 2. Ambil Invoice Number asli dari response Backend
        String realOrderId = res['data']?['invoice_number'] ?? widget.orderId;

        Navigator.pop(context, {'status': 'success'});
        
        // 3. Kirim realOrderId ke SuccessPaymentPage agar saat di-print sesuai database
        Navigator.push(context, MaterialPageRoute(builder: (c) => SuccessPaymentPage(
          orderId: realOrderId,
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

  Widget _rowInf(String l, double v) => Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: const TextStyle(color: Colors.black45, fontSize: 11)), Text(widget.formatCurrency(v), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))]));
  
  Widget _payBtn(String l, IconData i) { 
    bool s = _paymentMethod == l; 
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _paymentMethod = l), 
        child: Container(
          height: 100, 
          decoration: BoxDecoration(color: s ? AppStyle.primaryBlue : Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: s ? AppStyle.primaryBlue : const Color(0xFFEEEEEE))), 
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(i, color: s ? Colors.white : AppStyle.textMain, size: 28), const SizedBox(height: 8), Text(l, style: TextStyle(color: s ? Colors.white : AppStyle.textMain, fontWeight: s ? FontWeight.bold : FontWeight.normal))])
        )
      )
    ); 
  }
  
  Widget _quickBtn(double v) => GestureDetector(onTap: () => setState(() { _amountTendered = v; _manualTenderController.text = NumberFormat.decimalPattern('id').format(v.toInt()); }), child: Container(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFEEEEEE))), child: Text(widget.formatCurrency(v), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold))));
  
  Widget _buildChangeDisplay(double c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15), 
    decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.green.withOpacity(0.1))), 
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Kembalian", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14)), Text(widget.formatCurrency(c), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w900, fontSize: 24))])
  );
}

class _TicketPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white..style = PaintingStyle.fill;
    Path path = Path();
    path.lineTo(0, size.height);
    path.lineTo(size.width, size.height);
    path.lineTo(size.width, 0);
    path.addOval(Rect.fromCircle(center: Offset(0, size.height / 2), radius: 10));
    path.addOval(Rect.fromCircle(center: Offset(size.width, size.height / 2), radius: 10));
    path.fillType = PathFillType.evenOdd;
    canvas.drawShadow(path, Colors.black.withOpacity(0.1), 4, false);
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue o, TextEditingValue n) {
    if (n.text.isEmpty) return n.copyWith(text: '');
    String t = NumberFormat.decimalPattern('id').format(double.parse(n.text.replaceAll('.', '')));
    return n.copyWith(text: t, selection: TextSelection.collapsed(offset: t.length));
  }
}