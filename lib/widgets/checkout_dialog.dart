import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart'; 
import '../models/order_model.dart';
import '../models/discount_model.dart';
import '../style.dart';
import '../services/api_service.dart';
import '../screens/SuccessPaymentPage.dart';
import '../services/storage_service.dart';

// =======================================================
// CARA MENGAKTIFKAN MIDTRANS KEMBALI NANTI:
// 1. Hapus tanda comment (//) pada import di bawah ini
// =======================================================
// import 'package:midtrans_sdk/midtrans_sdk.dart';

class CheckoutDialog extends StatefulWidget {
  final Map<int, OrderItem> cart;
  final bool hasDiscountedItem; 
  final double totalAmount;
  final String orderId;
  final String tableNumber;
  final String customerName; 
  final String cashierName;
  final String Function(double) formatCurrency;

  const CheckoutDialog({
    super.key,
    required this.cart,
    required this.hasDiscountedItem, 
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
  String? _errorMessage;

  String? _qrisStringFromApi;
  
  // 🔥 STATE BARU UNTUK PILIHAN BRAND KARTU
  String _selectedCardBrand = 'BCA'; // Default terpilih
  final List<String> _cardBrands = ['BCA', 'Mandiri', 'BNI', 'BRI', 'Visa/Master'];
  final TextEditingController _approvalCodeController = TextEditingController();

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

  @override
  void dispose() {
    _manualTenderController.dispose();
    _approvalCodeController.dispose();
    super.dispose();
  }

  void _loadDiscounts() async {
    final discounts = await ApiService.getDiscounts();
    if (mounted) {
      setState(() {
        _availableDiscounts = discounts;
        
        if (widget.hasDiscountedItem) {
          List<int> cartProductIds = widget.cart.values.map((item) => item.productId).toList();
          for (var d in discounts) {
            if (d.scope == 'products' && d.productIds.any((id) => cartProductIds.contains(id))) {
              _selectedDiscount = d; 
              break;
            }
          }
        }
      });
    }
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
    if (widget.hasDiscountedItem) return 0;

    if (_selectedDiscount == null) return 0;
    return _selectedDiscount!.type == 'percentage'
        ? (subtotal * _selectedDiscount!.value) / 100
        : _selectedDiscount!.value.toDouble();
  }

  Map<String, dynamic> _calculateTaxesAndGrandTotal(double baseAmount) {
    double serviceAmount = 0;
    
    for (var tax in _availableTaxes) {
      String taxName = (tax['name'] ?? '').toString().toLowerCase();
      if (taxName.contains('service')) {
        double rate = double.tryParse(tax['rate']?.toString() ?? '0') ?? 0;
        double exactAmt = (tax['type'] == 'percentage') ? (baseAmount * (rate / 100)) : rate;
        serviceAmount += exactAmt.ceilToDouble(); 
      }
    }

    double totalTaxAmount = 0;
    List<Map<String, dynamic>> taxBreakdown = [];

    for (var tax in _availableTaxes) {
      String taxName = (tax['name'] ?? '').toString().toLowerCase();
      double rate = double.tryParse(tax['rate']?.toString() ?? '0') ?? 0;
      bool isService = taxName.contains('service');
      
      double amt = 0;
      if (isService) {
        amt = (tax['type'] == 'percentage') ? (baseAmount * (rate / 100)) : rate;
      } else {
        double baseForOtherTax = baseAmount + serviceAmount;
        amt = (tax['type'] == 'percentage') ? (baseForOtherTax * (rate / 100)) : rate;
      }

      amt = amt.ceilToDouble(); 
      totalTaxAmount += amt;
      
      Map<String, dynamic> taxData = Map<String, dynamic>.from(tax);
      taxData['calculated_amount'] = amt; 
      taxBreakdown.add(taxData);
    }

    return {
      'tax_amount': totalTaxAmount,
      'tax_breakdown': taxBreakdown,
      'grand_total': (baseAmount + totalTaxAmount).ceilToDouble(), 
    };
  }

  Widget _buildSideDiscountPanel(double sub) {
    List<int> cartProductIds = widget.cart.values.map((item) => item.productId).toList();

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
                      
                      bool isMinPurchaseMet = sub >= d.minPurchase;
                      bool isProductEligible = true;
                      
                      if (d.scope == 'products' && d.productIds.isNotEmpty) {
                        isProductEligible = cartProductIds.any((cartId) => d.productIds.contains(cartId));
                      }
                      
                      bool eligible = isMinPurchaseMet && isProductEligible;

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
    bool isProductDiscountActive = widget.hasDiscountedItem;
    bool hasGlobalDiscount = _selectedDiscount != null && !isProductDiscountActive;

    String btnText = "Pilih Diskon Tambahan";
    if (isProductDiscountActive) {
      if (_availableDiscounts.isEmpty) {
        btnText = "Mengecek Promo...";
      } else if (_selectedDiscount != null) {
        btnText = _selectedDiscount!.name;
      } else {
        btnText = "Promo Produk Aktif";
      }
    } else if (hasGlobalDiscount) {
      btnText = _selectedDiscount!.name;
    }

    bool isHighlighted = isProductDiscountActive || hasGlobalDiscount;

    return InkWell(
      onTap: isProductDiscountActive ? null : () => setState(() => _showDiscountList = true),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isHighlighted ? Colors.orange.withOpacity(0.08) : Colors.grey.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isHighlighted ? Colors.orange.withOpacity(0.3) : Colors.black12
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  isProductDiscountActive ? Icons.verified_rounded : (hasGlobalDiscount ? Icons.confirmation_number_rounded : Icons.local_offer_outlined), 
                  size: 18, 
                  color: isHighlighted ? Colors.orange : Colors.black45
                ),
                const SizedBox(width: 10),
                Text(
                  btnText, 
                  style: TextStyle(
                    fontSize: 13, 
                    fontWeight: FontWeight.bold, 
                    color: isHighlighted ? Colors.orange[900] : Colors.black54
                  )
                ),
              ],
            ),
            Row(
              children: [
                if (isProductDiscountActive) ...[
                  const Text("Otomatis Aktif", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.orange)),
                  const SizedBox(width: 6),
                  const Icon(Icons.lock_outline, size: 16, color: Colors.orange),
                ] else ...[
                  Text(
                    hasGlobalDiscount ? "- ${widget.formatCurrency(discAmount)}" : "Tambah", 
                    style: TextStyle(
                      fontSize: 13, 
                      fontWeight: FontWeight.bold, 
                      color: hasGlobalDiscount ? Colors.red : AppStyle.primaryBlue
                    )
                  ),
                  if (hasGlobalDiscount) ...[
                    const SizedBox(width: 8),
                    GestureDetector(onTap: () => setState(() => _selectedDiscount = null), child: const Icon(Icons.cancel, size: 18, color: Colors.red)),
                  ]
                ]
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptSummary(double sub, double disc, double grand, List<Map<String, dynamic>> taxBreakdown) {
    return Column(
      children: [
        _rowInf("Sub Total", sub),
        const SizedBox(height: 10),
        
        _buildDiscountButton(disc),
        
        const SizedBox(height: 10),
        const Divider(color: Color(0xFFEEEEEE), height: 1),
        const SizedBox(height: 10),
        ...taxBreakdown.map((tax) {
          double rate = double.tryParse(tax['rate']?.toString() ?? '0') ?? 0;
          double amt = tax['calculated_amount'] ?? 0.0;
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
    
    var taxData = _calculateTaxesAndGrandTotal(baseAmount);
    List<Map<String, dynamic>> taxBreakdown = taxData['tax_breakdown'];
    double grandTotal = taxData['grand_total'];

    if (grandTotal < 0) grandTotal = 0;
    
    int tagihanInt = grandTotal.toInt();
    int uangMasukInt = _amountTendered.toInt();
    int change = uangMasukInt - tagihanInt;

    String currentTime = DateFormat('HH:mm').format(DateTime.now());
    String currentDate = DateFormat('dd MMM yyyy').format(DateTime.now());

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Container(
        width: 1000,
        height: 680,
        clipBehavior: Clip.antiAlias, 
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
        child: Stack(
          children: [
            Row(
              children: [
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
                            onChanged: (v) {
                              if (_errorMessage != null) setState(() => _errorMessage = null);
                              setState(() => _amountTendered = v.isEmpty ? 0 : double.tryParse(v.replaceAll('.', '')) ?? 0);
                            },
                          ),
                          const SizedBox(height: 25),
                          Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.center,
                              children: [20000, 50000, 100000, 150000, 200000].map((v) => _quickBtn(v.toDouble())).toList()),
                          const Spacer(),
                          if (change >= 0) _buildChangeDisplay(change.toDouble()), 
                        ] 
                        // 🔥 TAMPILAN PILIHAN BRAND KARTU MENGGUNAKAN WRAP
                        else if (_paymentMethod == 'Card') ...[
                          const Spacer(),
                          const Text("Pilih EDC / Brand Kartu", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
                          const SizedBox(height: 20),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              alignment: WrapAlignment.center,
                              children: _cardBrands.map((brand) => _cardBrandBtn(brand)).toList(),
                            ),
                          ),
                          const SizedBox(height: 35),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: TextField(
                              controller: _approvalCodeController,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2),
                              textAlign: TextAlign.center,
                              decoration: InputDecoration(
                                labelText: "Kode Approval EDC (Opsional)",
                                labelStyle: const TextStyle(letterSpacing: 0, fontSize: 14, color: Colors.black54),
                                floatingLabelAlignment: FloatingLabelAlignment.center,
                                filled: true,
                                fillColor: const Color(0xFFF8F9FA),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15), 
                                  borderSide: BorderSide(color: Colors.grey.shade300)
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15), 
                                  borderSide: const BorderSide(color: AppStyle.primaryBlue, width: 2)
                                ),
                              ),
                            ),
                          ),
                          const Spacer(),
                        ] 
                        else if (_paymentMethod == 'Qris') ...[
                          const Spacer(),
                          if (_qrisStringFromApi != null)
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16), 
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20), 
                                    border: Border.all(color: AppStyle.primaryBlue.withOpacity(0.3), width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 10,
                                        offset: const Offset(0, 5),
                                      )
                                    ]
                                  ),
                                  child: QrImageView(
                                    data: _qrisStringFromApi!,
                                    version: QrVersions.auto,
                                    size: 260.0,
                                  ),
                                ),
                                const SizedBox(height: 25),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: const Text(
                                    "Silakan Scan QRIS", 
                                    style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 18)
                                  ),
                                ),
                              ],
                            ),
                          const Spacer(),
                        ]
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFFFBFBFB),
                    ),
                    child: Stack(
                      children: [
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
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start, 
                                                children: [
                                                  Text(item.itemName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                                  Text("${item.quantity} x ${widget.formatCurrency(item.unitPrice)}", style: const TextStyle(color: Colors.black45, fontSize: 11)),
                                                  if (item.notes != null && item.notes!.trim().isNotEmpty)
                                                    Padding(
                                                      padding: const EdgeInsets.only(top: 2),
                                                      child: Text(
                                                        "Note: ${item.notes}", 
                                                        style: const TextStyle(color: Colors.grey, fontSize: 10, fontStyle: FontStyle.italic)
                                                      ),
                                                    ),
                                                ]
                                              )
                                            ),
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
                                child: _buildReceiptSummary(subTotal, discountAmount, grandTotal, taxBreakdown),
                              ),
                              const SizedBox(height: 20),

                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: AppStyle.primaryBlue, minimumSize: const Size(double.infinity, 60), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                                onPressed: (_paymentMethod == 'Cash' && uangMasukInt < tagihanInt) || _isLoading ? null : _processPayment,
                                child: _isLoading
                                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Text("PROSES PEMBAYARAN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                              ),
                            ],
                          ),
                        ),
                        if (_showDiscountList) _buildSideDiscountPanel(subTotal),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            if (_errorMessage != null)
              Positioned(
                top: 24, 
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 450), 
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(16), 
                      border: Border.all(color: Colors.red.shade200, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min, 
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.red.shade800,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
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
    setState(() {
      _isLoading = true;
      _errorMessage = null; 
    });
    try {
      final savedOutletId = await StorageService.getOutletId();
      if (savedOutletId == null || savedOutletId == 0) throw Exception("ID Outlet tidak ditemukan.");

      double subTotal = widget.totalAmount;
      double discountAmount = _calculateDiscountValue(subTotal);
      double baseAmount = subTotal - discountAmount;
      
      var taxData = _calculateTaxesAndGrandTotal(baseAmount);
      double taxAmountFinal = taxData['tax_amount'];
      double grandTotal = taxData['grand_total'];
      List<Map<String, dynamic>> taxBreakdown = taxData['tax_breakdown'];

      int tagihanInt = grandTotal.toInt();
      int uangMasukInt = _amountTendered.toInt();
      int change = uangMasukInt - tagihanInt;

      var mappedItems = widget.cart.values.map((item) {
        return {
          'product_id': item.productId, 
          'qty': item.quantity, 
          'price': item.unitPrice.toInt(),
          'notes': item.notes ?? '' 
        };
      }).toList();

      int finalPaidAmount = _paymentMethod == 'Cash' ? uangMasukInt : tagihanInt;
      int finalChangeAmount = _paymentMethod == 'Cash' ? change : 0;

      int? finalDiscountId = _selectedDiscount?.id;

      // Sisipkan tipe kartu dan kode approval ke dalam notes backend bila metode adalah Card
      String additionalNotes = '';
      if (_paymentMethod == 'Card') {
        additionalNotes = "EDC/Brand: $_selectedCardBrand. Kode Approval: ${_approvalCodeController.text.isNotEmpty ? _approvalCodeController.text : '-'}";
      }

      Map<String, dynamic> payload = {
        'outlet_id': savedOutletId,
        'invoice_number': "INV-${DateTime.now().millisecondsSinceEpoch}",
        'customer_name': widget.customerName, 
        'table_id': widget.tableNumber.isEmpty ? null : widget.tableNumber,
        'subtotal_price': subTotal.toInt(),
        'total_price': tagihanInt,
        'discount_amount': discountAmount.toInt(),
        'tax_amount': taxAmountFinal.toInt(),
        'tax_breakdown': taxBreakdown, 
        'payment_method': _paymentMethod.toLowerCase(), 
        'paid_amount': finalPaidAmount,     
        'change_amount': finalChangeAmount, 
        'discount_id': finalDiscountId, 
        'items': mappedItems,
        'status': 'paid',
        // Jika backend Anda memiliki field untuk notes order, tambahkan di sini:
        // 'order_notes': additionalNotes,
      };

      final res = await ApiService.submitOrder(payload);

      if (res['success'] && context.mounted) {
        String realOrderId = res['data']?['order']?['invoice_number'] ?? widget.orderId;

        if (_paymentMethod == 'Cash') {
          Navigator.pop(context, {'status': 'success'});
          Navigator.push(context, MaterialPageRoute(builder: (c) => SuccessPaymentPage(
            orderId: realOrderId,
            paymentMethod: _paymentMethod,
            grandTotal: grandTotal,
            amountPaid: _amountTendered,
            change: change.toDouble(),
            cart: widget.cart,
            tableNumber: widget.tableNumber,
            customerName: widget.customerName, 
            cashierName: widget.cashierName,
            outletName: "ARANUS POS",
            formatCurrency: widget.formatCurrency,
          )));
        } else {
          Navigator.pop(context, {'status': 'success'});
          Navigator.push(context, MaterialPageRoute(builder: (c) => SuccessPaymentPage(
            orderId: realOrderId,
            paymentMethod: _paymentMethod,
            grandTotal: grandTotal,
            amountPaid: grandTotal, 
            change: 0,
            cart: widget.cart,
            tableNumber: widget.tableNumber,
            customerName: widget.customerName, 
            cashierName: widget.cashierName,
            outletName: "ARANUS POS",
            formatCurrency: widget.formatCurrency,
          )));
        }
      } else {
        throw Exception(res['message'] ?? "Gagal memproses pesanan");
      }
    } catch (e) {
      if (context.mounted) {
        String errorText = e.toString().replaceAll('Exception: ', '');
        setState(() => _errorMessage = errorText);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _rowInf(String l, double v) => Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: const TextStyle(color: Colors.black45, fontSize: 11)), Text(widget.formatCurrency(v), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))]));
  
  Widget _payBtn(String l, IconData i, {bool isEnabled = true}) { 
    bool s = _paymentMethod == l; 
    return Expanded(
      child: GestureDetector(
        onTap: isEnabled ? () => setState(() {
          if (_errorMessage != null) _errorMessage = null;
          _paymentMethod = l;
          
          if (l == 'Qris') {
            _qrisStringFromApi = "00020101021138540016ID.CO.TELKOMSEL.WWW01189360091100142DUMMYQRCODE123456789";
          } else {
            _qrisStringFromApi = null;
          }
          
        }) : null, 
        child: Opacity(
          opacity: isEnabled ? 1.0 : 0.4,
          child: Container(
            height: 100, 
            decoration: BoxDecoration(color: s ? AppStyle.primaryBlue : Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: s ? AppStyle.primaryBlue : const Color(0xFFEEEEEE))), 
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(i, color: s ? Colors.white : AppStyle.textMain, size: 28), const SizedBox(height: 8), Text(l, style: TextStyle(color: s ? Colors.white : AppStyle.textMain, fontWeight: s ? FontWeight.bold : FontWeight.normal))])
          )
        )
      )
    ); 
  }

  // 🔥 WIDGET BARU UNTUK CHIP BRAND KARTU
  Widget _cardBrandBtn(String brand) {
    bool selected = _selectedCardBrand == brand;
    return GestureDetector(
      onTap: () => setState(() => _selectedCardBrand = brand),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppStyle.primaryBlue : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: selected ? AppStyle.primaryBlue : Colors.grey.shade300, width: 1.5),
        ),
        child: Text(
          brand, 
          style: TextStyle(
            color: selected ? Colors.white : Colors.black87, 
            fontWeight: FontWeight.bold, 
            fontSize: 15
          )
        ),
      ),
    );
  }
  
  Widget _quickBtn(double v) => GestureDetector(
    onTap: () => setState(() { 
      if (_errorMessage != null) _errorMessage = null;
      _amountTendered = v; 
      _manualTenderController.text = NumberFormat.decimalPattern('id').format(v.toInt()); 
    }), 
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10), 
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFEEEEEE))), 
      child: Text(widget.formatCurrency(v), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold))
    )
  );
  
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