import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'package:intl/intl.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:sistem_pos/features/orders/models/order_model.dart';
import 'package:sistem_pos/core/models/discount_model.dart';
import 'package:sistem_pos/core/constants/style.dart';
import 'package:sistem_pos/features/auth/services/auth_api_service.dart';
import 'package:sistem_pos/core/network/master_api_service.dart';
import 'package:sistem_pos/features/orders/services/order_api_service.dart';
import 'package:sistem_pos/features/cart_checkout/widgets/checkout_calculator.dart';
import 'package:sistem_pos/features/cart_checkout/widgets/discount_panel.dart';
import 'package:sistem_pos/features/cart_checkout/widgets/payment_selector.dart';
import 'package:sistem_pos/features/cart_checkout/widgets/checkout_summary.dart';
import 'package:sistem_pos/features/cart_checkout/screens/success_payment_screen.dart';
import 'package:sistem_pos/core/services/storage_service.dart';
import 'package:sistem_pos/features/orders/widgets/order_notification_overlay.dart';
import 'dart:async';

class CheckoutDialog extends StatefulWidget {
  final Map<int, OrderItem> cart;
  final bool hasDiscountedItem;
  final double totalAmount;
  final String orderId;
  final int? tableId;
  final String tableNumber;
  final String customerName;
  final String cashierName;
  final String Function(double) formatCurrency;
  final int? pendingDiscountId;

  final bool isUpdatingOrder;
  final double originalTotalAmount;

  const CheckoutDialog({
    super.key,
    required this.cart,
    required this.hasDiscountedItem,
    required this.totalAmount,
    required this.originalTotalAmount,
    required this.orderId,
    this.tableId,
    this.pendingDiscountId,
    required this.tableNumber,
    required this.customerName,
    required this.cashierName,
    required this.formatCurrency,
    this.isUpdatingOrder = false,
  });

  @override
  State<CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<CheckoutDialog>
    with SingleTickerProviderStateMixin {
  String _paymentMethod = 'Cash';
  double _amountTendered = 0;
  final TextEditingController _manualTenderController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _isExactChange = false;
  double? _selectedQuickAmount;
  bool _needsExactUpdate = false; // flag: update bayar pas di render berikutnya

  bool _isLoadingPayment = false;

  bool _showDiscountList = false;

  // ??? MULTI-DISCOUNT: list pengganti single _selectedDiscount ??????????????
  List<Discount> _selectedDiscounts = [];
  List<Discount> _availableDiscounts = [];

  // ??? Helper getters ????????????????????????????????????????????????????????
  bool _isDiscountSelected(Discount d) =>
      _selectedDiscounts.any((s) => s.id == d.id);

  bool get _hasGlobalDiscount =>
      _selectedDiscounts.any((d) => d.scope == 'global');

  bool get _hasProductDiscount =>
      _selectedDiscounts.any((d) => d.scope == 'products');

  void _resetPaymentState() {
    _qrUrl = null;
    _webViewController = null;
    _redirectUrl = null;
    _currentInvoiceNumber = null;
    OrderNotificationController().activeQrisInvoice = null;
    _isLoadingPayment = false;
  }

  /// Toggle diskon dengan aturan:
  /// - Diskon PRODUK/KATEGORI: maksimal 2 aktif, otomatis hapus diskon tertua jika memilih diskon ke-3 (FIFO), otomatis hapus diskon global
  /// - Diskon TRANSAKSI (global): hapus semua diskon produk, hanya 1 aktif
  void _toggleDiscount(Discount d) {
    setState(() {
      _resetPaymentState();

      // Jika Bayar Pas aktif, set flag untuk auto-update ke grand total baru
      if (_isExactChange) {
        _needsExactUpdate = true;
      }

      if (_isDiscountSelected(d)) {
        _selectedDiscounts.removeWhere((s) => s.id == d.id);
      } else {
        if (d.scope == 'global') {
          _selectedDiscounts = [d];
        } else {
          // Hapus semua diskon global
          _selectedDiscounts.removeWhere((s) => s.scope == 'global');

          // Pastikan tidak ada duplikat sebelum tambah
          _selectedDiscounts.removeWhere((s) => s.id == d.id);

          // Batasi maksimal 2 diskon produk/kategori
          final prodCatDiscounts = _selectedDiscounts
              .where((s) => s.scope == 'products' || s.scope == 'categories')
              .toList();

          if (prodCatDiscounts.length >= 2) {
            // Hapus yang tertua (indeks 0) dari daftar terpilih
            final oldest = prodCatDiscounts.first;
            _selectedDiscounts.removeWhere((s) => s.id == oldest.id);
          }

          _selectedDiscounts.add(d);
        }
      }
    });
  }

  List<dynamic> _availableTaxes = [];

  WebViewController? _webViewController;
  String? _qrUrl;
  String? _redirectUrl;

  StreamSubscription? _notifSub;
  String? _currentInvoiceNumber;
  Map<String, dynamic>? _successPaymentData;

  late AnimationController _slideController;
  late Animation<Offset> _slideOutAnimation;
  late Animation<Offset> _slideInAnimation;
  late Animation<double> _fadeAnimation;

  String _currentOutletName = "Outlet";
  String _currentOutletAddress = "-";

  @override
  void initState() {
    super.initState();
    _loadDiscounts();
    _loadTaxes();
    _loadOutletInfo();

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _slideOutAnimation =
        Tween<Offset>(begin: Offset.zero, end: const Offset(-1.0, 0)).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeInOut),
        );

    _slideInAnimation =
        Tween<Offset>(begin: const Offset(1.0, 0), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeInOut),
        );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeIn));

    _notifSub = OrderNotificationController().stream.listen((notif) {
      if (!mounted) return;
      if (notif.isQris && _currentInvoiceNumber != null && _successPaymentData != null) {
        if (notif.subtitle.contains(_currentInvoiceNumber!)) {
          // Pembayaran berhasil dari Reverb!
          Navigator.of(context).pop({'status': 'success'});
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (c) => SuccessPaymentPage(
                orderId: _successPaymentData!['orderId'],
                outletName: _successPaymentData!['outletName'],
                outletAddress: _successPaymentData!['outletAddress'],
                paymentMethod: _successPaymentData!['paymentMethod'],
                grandTotal: _successPaymentData!['grandTotal'],
                amountPaid: _successPaymentData!['amountPaid'],
                change: _successPaymentData!['change'],
                cart: _successPaymentData!['cart'],
                tableNumber: _successPaymentData!['tableNumber'],
                customerName: _successPaymentData!['customerName'],
                cashierName: _successPaymentData!['cashierName'],
                formatCurrency: widget.formatCurrency,
                discountAmount: _successPaymentData!['discountAmount'],
                taxBreakdown: _successPaymentData!['taxBreakdown'],
              ),
            ),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    if (_currentInvoiceNumber != null &&
        OrderNotificationController().activeQrisInvoice == _currentInvoiceNumber) {
      OrderNotificationController().activeQrisInvoice = null;
    }
    _notifSub?.cancel();
    _manualTenderController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _loadOutletInfo() async {
    final outletData = await AuthApiService.fetchOutletInfoLive();
    if (!mounted) return;
    setState(() {
      _currentOutletName = outletData['name'] ?? "Outlet";
      _currentOutletAddress = outletData['address_outlet'] ?? "-";
    });
  }

  void _openDiscountList() {
    setState(() => _showDiscountList = true);
    _slideController.forward();
  }

  void _closeDiscountList() {
    _slideController.reverse().then((_) {
      if (mounted) setState(() => _showDiscountList = false);
    });
  }

  void _loadDiscounts() async {
  final discounts = await MasterApiService.getDiscounts();
  if (!mounted) return;

    if (kDebugMode) {
      for (var d in discounts) {
        print("=== DISKON: ${d.name}");
        print("    scope: ${d.scope}");
        print("    type: ${d.type}");
        print("    value: ${d.value}");
        print("    productIds: ${d.productIds}");
        print("    categoryIds: ${d.categoryIds}");
        print("    minPurchase: ${d.minPurchase}");
      }
    }
    setState(() {
      _availableDiscounts = discounts;

      // Kasus 1: pending order   restore discount lama
      if (widget.pendingDiscountId != null) {
        final found = discounts.firstWhere(
          (d) => d.id == widget.pendingDiscountId,
          orElse: () => discounts.isEmpty
              ? Discount(
                  id: 0,
                  name: '',
                  scope: 'global',
                  type: 'percentage',
                  value: 0,
                  minPurchase: 0,
                )
              : discounts.first,
        );
        if (found.id != 0) _selectedDiscounts = [found];
        return;
      }

      // Kasus 2: ada diskon per-item/kategori di keranjang ? auto-select
      if (widget.hasDiscountedItem) {
        // Kumpulkan semua discountId unik dari item di keranjang
        final Set<int> cartDiscountIds = widget.cart.values
            .where((item) => item.discountId != null)
            .map((item) => item.discountId!)
            .toSet();

        // Cari objek Discount yang match, ambil maks 2 (untuk scope products/categories)
        final List<Discount> autoSelected = discounts
            .where(
              (d) =>
                  cartDiscountIds.contains(d.id) &&
                  widget.totalAmount >= d.minPurchase,
            )
            .take(2)
            .toList();
        _selectedDiscounts = autoSelected;
      }
    });
  }

  void _loadTaxes() async {
    final taxes = await MasterApiService.getTaxes();
    if (!mounted) return;
    setState(() {
      _availableTaxes = taxes;
    });
  }

  // _calculateDiscountValue dan _calculateTaxesAndGrandTotal dipindah ke CheckoutCalculator


  @override
  Widget build(BuildContext context) {
    // subTotal: pakai originalTotalAmount jika ada diskon produk aktif
    double subTotal = widget.originalTotalAmount > 0
        ? widget.originalTotalAmount
        : widget.totalAmount;

    if (kDebugMode) {
      for (var item in widget.cart.values) {
        print("=== CART ITEM: ${item.itemName}");
        print("    productId: ${item.productId}");
        print("    categoryId: ${item.categoryId}");
        print("    discountId: ${item.discountId}");
      }
    }

    double discountAmount = CheckoutCalculator.calculateDiscountValue(subTotal, _selectedDiscounts, widget.cart);
    double baseAmount = subTotal - discountAmount;
    if (baseAmount < 0) baseAmount = 0;

    var taxData = CheckoutCalculator.calculateTaxesAndGrandTotal(baseAmount, _availableTaxes);
    List<Map<String, dynamic>> taxBreakdown = taxData['tax_breakdown'];
    double grandTotal = taxData['grand_total'];
    if (grandTotal < 0) grandTotal = 0;

    int tagihanInt = grandTotal.toInt();

    // Auto-update tender jika Bayar Pas aktif dan diskon baru dipilih
    if (_needsExactUpdate) {
      _needsExactUpdate = false;
      _amountTendered = grandTotal;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _manualTenderController.text = NumberFormat.decimalPattern('id').format(grandTotal.toInt());
          });
        }
      });
    }

    int uangMasukInt = _isExactChange ? tagihanInt : _amountTendered.toInt();
    int change = uangMasukInt - tagihanInt;

    String currentTime = DateFormat('HH:mm').format(DateTime.now());
    String currentDate = DateFormat('dd MMM yyyy').format(DateTime.now());

    double screenWidth = MediaQuery.of(context).size.width;
    double dialogWidth = screenWidth < 1000 ? screenWidth * 0.95 : 1000;
    bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: dialogWidth,
        constraints: const BoxConstraints(maxHeight: 680),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            colors: [Colors.white, Color(0xFFFBFBFB)],
            stops: [5 / 9, 5 / 9],
          ),
        ),
        child: Stack(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ??? LEFT PANEL ????????????????????????????????????????????
                Expanded(
                  flex: 5,
                  child: ClipRect(
                    child: AnimatedBuilder(
                      animation: _slideController,
                      builder: (context, child) {
                        return Stack(
                          children: [
                            SlideTransition(
                              position: _slideOutAnimation,
                              child: PaymentSelector(
                                isUpdatingOrder: widget.isUpdatingOrder,
                                paymentMethod: _paymentMethod,
                                manualTenderController: _manualTenderController,
                                isLoading: _isLoading,
                                isLoadingPayment: _isLoadingPayment,
                                isKeyboardOpen: isKeyboardOpen,
                                errorMessage: _errorMessage,
                                isExactChange: _isExactChange,
                                selectedQuickAmount: _selectedQuickAmount,
                                grandTotal: grandTotal,
                                tagihanInt: tagihanInt,
                                uangMasukInt: uangMasukInt,
                                change: change,
                                qrUrl: _qrUrl,
                                redirectUrl: _redirectUrl,
                                webViewController: _webViewController,
                                formatCurrency: widget.formatCurrency,
                                onPaymentMethodChanged: (method) {
                                  setState(() {
                                    if (_errorMessage != null) _errorMessage = null;
                                    _paymentMethod = method;
                                    _webViewController = null;
                                    _qrUrl = null;
                                    _redirectUrl = null;
                                  });
                                },
                                onManualAmountChanged: (v) {
                                  if (_errorMessage != null) {
                                    setState(() => _errorMessage = null);
                                  }
                                  setState(() {
                                    _isExactChange = false;
                                    _selectedQuickAmount = null;
                                    _amountTendered = v.isEmpty
                                        ? 0
                                        : double.tryParse(v.replaceAll('.', '')) ?? 0;
                                  });
                                },
                                onQuickAmountSelected: (v, isExact) {
                                  setState(() {
                                    if (_errorMessage != null) _errorMessage = null;
                                    _isExactChange = isExact;
                                    _selectedQuickAmount = v;
                                    _amountTendered = v;
                                    _manualTenderController.text = NumberFormat.decimalPattern(
                                      'id',
                                    ).format(v.toInt());
                                  });
                                },
                                onProcessPayment: (method) async {
                                  await _processPayment();
                                },
                              ),
                            ),
                            if (_showDiscountList)
                              SlideTransition(
                                position: _slideInAnimation,
                                child: FadeTransition(
                                  opacity: _fadeAnimation,
                                  child: DiscountPanel(
                                      subTotal: subTotal,
                                      cartProductIds: widget.cart.values.map((item) => item.productId).toList(),
                                      cartCategoryIds: widget.cart.values.where((item) => item.categoryId != null).map((item) => item.categoryId!).toList(),
                                      availableDiscounts: _availableDiscounts,
                                      selectedDiscounts: _selectedDiscounts,
                                      hasGlobalDiscount: _hasGlobalDiscount,
                                      hasProductDiscount: _hasProductDiscount,
                                      selectedProductCount: _selectedDiscounts.where((d) => d.scope == 'products' || d.scope == 'categories').length,
                                      onToggleDiscount: _toggleDiscount,
                                      onClose: _closeDiscountList,
                                      formatCurrency: widget.formatCurrency,
                                    ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Container(
                    decoration: const BoxDecoration(color: Colors.transparent),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(30, 25, 30, 25),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                          if (!isKeyboardOpen)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Kasir: ${widget.cashierName}",
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    "$currentDate | $currentTime WIB",
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    widget.customerName.isEmpty
                                        ? "Cust: -"
                                        : "Cust: ${widget.customerName}",
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    widget.tableNumber.isEmpty
                                        ? "Meja: -"
                                        : "Meja: ${widget.tableNumber}",
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (!isKeyboardOpen)
                            const Divider(height: 30),
                          if (!isKeyboardOpen)
                            Expanded(
                              child: ListView.builder(
                                itemCount: widget.cart.length,
                              itemBuilder: (context, index) {
                                var item = widget.cart.values.elementAt(index);
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.itemName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                            Text(
                                              "${item.quantity} x ${widget.formatCurrency(item.originalPrice)}",
                                              style: const TextStyle(
                                                color: Colors.black45,
                                                fontSize: 11,
                                              ),
                                            ),
                                            if (item.notes.trim().isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 2,
                                                ),
                                                child: Text(
                                                  "Note: ${item.notes}",
                                                  style: const TextStyle(
                                                    color: Colors.grey,
                                                    fontSize: 10,
                                                    fontStyle: FontStyle.italic,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        widget.formatCurrency(
                                          item.originalPrice * item.activeQty,
                                        ),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          if (!isKeyboardOpen)
                            const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: const Color(0xFFEEEEEE),
                              ),
                            ),
                            child: CheckoutSummary(
                              subTotal: subTotal,
                              discountAmount: discountAmount,
                              grandTotal: grandTotal,
                              taxBreakdown: taxBreakdown,
                              selectedDiscounts: _selectedDiscounts,
                              cart: widget.cart,
                              hasDiscountedItem: widget.hasDiscountedItem,
                              formatCurrency: widget.formatCurrency,
                              onOpenDiscountList: _openDiscountList,
                              onClearDiscounts: () => setState(() {
                                _selectedDiscounts.clear();
                                _resetPaymentState();
                              }),
                            ),
                          ),
                          const SizedBox(height: 20),

                          if (_paymentMethod == 'Cash')
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppStyle.primaryBlue,
                                minimumSize: const Size(double.infinity, 60),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              onPressed: _isLoading
                                  ? null
                                  : (uangMasukInt < tagihanInt
                                        ? null
                                        : _processPayment),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      "PROSES PEMBAYARAN",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                            ),
                        ],      // tutup children: [] Column
                      ),        // tutup Column
                    ),          // tutup Padding
                  ),            // tutup Container
                ),              // tutup Expanded
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 20,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.red.shade200,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.red.shade700,
                          size: 20,
                        ),
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
      final String currentOutletName = _currentOutletName;
      final String currentOutletAddress = _currentOutletAddress;

      final savedOutletId = await StorageService.getOutletId();
      if (savedOutletId == null || savedOutletId == 0) {
        throw Exception("ID Outlet tidak ditemukan.");
      }

      double subTotal = widget.originalTotalAmount > 0
          ? widget.originalTotalAmount
          : widget.totalAmount;

      if (kDebugMode) {
        for (var item in widget.cart.values) {
          print("=== CART ITEM: ${item.itemName}");
          print("    productId: ${item.productId}");
          print("    categoryId: ${item.categoryId}");
          print("    discountId: ${item.discountId}");
        }
      }
      double discountAmount = CheckoutCalculator.calculateDiscountValue(subTotal, _selectedDiscounts, widget.cart);
      double baseAmount = subTotal - discountAmount;

      var taxData = CheckoutCalculator.calculateTaxesAndGrandTotal(baseAmount, _availableTaxes);
      double taxAmountFinal = taxData['tax_amount'];
      double grandTotal = taxData['grand_total'];

      List<Map<String, dynamic>> simplifiedTaxBreakdown =
          List<Map<String, dynamic>>.from(taxData['tax_breakdown']).map((tax) {
            return {
              'id': tax['id'],
              'name': tax['name'],
              'calculated_amount': tax['calculated_amount'],
            };
          }).toList();

      int tagihanInt = grandTotal.toInt();
      int uangMasukInt = _isExactChange ? tagihanInt : _amountTendered.toInt();
      int change = uangMasukInt - tagihanInt;

      var existingItems = widget.cart.values
          .where((item) => item.id > 0)
          .map(
            (item) => {
              'product_id': item.productId,
              'qty': item.quantity,
              'price': item.originalPrice.toInt(), // ? harga asli
              'notes': item.notes,
              'id': item.id,
            },
          )
          .toList();

      var newItems = widget.cart.values
          .where((item) => item.id == 0)
          .map(
            (item) => {
              'product_id': item.productId,
              'qty': item.quantity,
              'price': item.originalPrice.toInt(), // ? harga asli
              'notes': item.notes,
            },
          )
          .toList();

      var mappedItems = [...existingItems, ...newItems];

      final String payloadMethod = _paymentMethod == 'Qris' ? 'Midtrans' : _paymentMethod;

      // payload tetap sama, hanya harga item yang berubah ke originalPrice
      Map<String, dynamic> payload = {
        'outlet_id': savedOutletId,
        'customer_name': widget.customerName,
        'table_id': widget.tableId,
        'subtotal_price': subTotal.toInt(), // ? originalTotalAmount
        'discount_amount': discountAmount.toInt(),
        'total_price': grandTotal.toInt(),
        'tax_amount': taxAmountFinal.toInt(),
        'tax_breakdown': simplifiedTaxBreakdown,
        'payment_method': payloadMethod.toLowerCase(),
        'paid_amount': _paymentMethod == 'Cash' ? uangMasukInt : tagihanInt,
        'items': mappedItems,
        if (_selectedDiscounts.length == 1)
          'discount_id': _selectedDiscounts.first.id,
      };

      if (kDebugMode) {
        print("=== DEBUG CHECKOUT ===");
        print("isUpdatingOrder: ${widget.isUpdatingOrder}");
        print("pendingDiscountId: ${widget.pendingDiscountId}");
        print(
          "selectedDiscounts: ${_selectedDiscounts.map((d) => '${d.name}(${d.scope})').join(', ')}",
        );
        print("subTotal: $subTotal");
        print("discountAmount: $discountAmount");
        print("grandTotal: $grandTotal");
        print("======================");
        print("[API REQUEST] --> CHECKOUT ORDER. Payload: $payload");
      }
      dynamic res;
      if (widget.isUpdatingOrder) {
        res = await OrderApiService.updatePendingOrder(widget.orderId, payload);
      } else {
        res = await OrderApiService.submitOrder(payload);
      }

      if (!mounted) return;

      if (res['success']) {
        String realOrderId =
            res['data']?['order']?['invoice_number'] ?? widget.orderId;
        final cartSnapshot = Map<int, OrderItem>.from(widget.cart);

        String? redirectUrl = res['data']?['redirect_url'];
        String? qrUrl = res['data']?['qr_url'];
        
        if (kDebugMode) {
          print("=== DEBUG PAYMENT RESPONSE ===");
          print("res['data']: ${res['data']}");
          print("redirectUrl: $redirectUrl");
          print("qrUrl: $qrUrl");
        }

        bool hasOnlinePaymentUrl = (redirectUrl != null && redirectUrl.isNotEmpty) || 
                                   (qrUrl != null && qrUrl.isNotEmpty);

        _currentInvoiceNumber = realOrderId;
        OrderNotificationController().activeQrisInvoice = realOrderId;
        _successPaymentData = {
          'orderId': realOrderId,
          'outletName': currentOutletName,
          'outletAddress': currentOutletAddress,
          'paymentMethod': _paymentMethod,
          'grandTotal': grandTotal,
          'amountPaid': _amountTendered,
          'change': change.toDouble(),
          'cart': cartSnapshot,
          'tableNumber': widget.tableNumber,
          'customerName': widget.customerName,
          'cashierName': widget.cashierName,
          'discountAmount': discountAmount,
          'taxBreakdown': simplifiedTaxBreakdown,
        };

        if (_paymentMethod != 'Cash' && !hasOnlinePaymentUrl) {
          // Pembayaran non-tunai tapi server tidak mengembalikan URL/QR pembayaran.
          // Jangan menggantung loading — tampilkan error agar kasir bisa mencoba lagi.
          if (mounted) {
            setState(() {
              _resetPaymentState();
              _errorMessage =
                  "Gagal memuat halaman pembayaran. Silakan coba lagi.";
            });
          }
          return;
        }

        if (!hasOnlinePaymentUrl || _paymentMethod == 'Cash') {
          if (!mounted) return;
          Navigator.of(context).pop({'status': 'success'});
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (c) => SuccessPaymentPage(
                orderId: realOrderId,
                outletName: currentOutletName,
                outletAddress: currentOutletAddress,
                paymentMethod: _paymentMethod,
                grandTotal: grandTotal,
                amountPaid: _amountTendered,
                change: change.toDouble(),
                cart: cartSnapshot,
                tableNumber: widget.tableNumber,
                customerName: widget.customerName,
                cashierName: widget.cashierName,
                formatCurrency: widget.formatCurrency,
                discountAmount: discountAmount,
                taxBreakdown: simplifiedTaxBreakdown,
              ),
            ),
          );
        } else {
          if (hasOnlinePaymentUrl) {
debugPrint("[REDIRECT URL] --> $redirectUrl");
debugPrint("[QR URL] --> $qrUrl");
debugPrint("[FULL RESPONSE] --> ${res['data']}");
            setState(() {
                _isLoadingPayment = false;
                _qrUrl = qrUrl;
                _redirectUrl = redirectUrl;
                
                if (redirectUrl != null && redirectUrl.isNotEmpty && _paymentMethod != 'Qris') {
                  _webViewController = WebViewController()
                    ..setUserAgent(
                      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
                    )
                    ..setJavaScriptMode(JavaScriptMode.unrestricted)
                    ..setBackgroundColor(const Color(0x00000000))
                    ..setNavigationDelegate(
                      NavigationDelegate(
                        onPageFinished: (_) =>
                            _webViewController
                            ?.runJavaScript("document.body.style.zoom = '0.85';"),
                        onNavigationRequest: (request) {
                          if (!request.url.startsWith('http')) {
                            return NavigationDecision.prevent;
                          }

                          if (request.url.contains('status_code=200') ||
                              request.url.contains(
                                'transaction_status=settlement',
                              )) {
                            Navigator.pop(context, {'status': 'success'});
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (c) => SuccessPaymentPage(
                                  orderId: realOrderId,
                                  outletName: currentOutletName,
                                  outletAddress: currentOutletAddress,
                                  paymentMethod: _paymentMethod,
                                  grandTotal: grandTotal,
                                  amountPaid: grandTotal,
                                  change: 0,
                                  cart: cartSnapshot,
                                  tableNumber: widget.tableNumber,
                                  customerName: widget.customerName,
                                  cashierName: widget.cashierName,
                                  formatCurrency: widget.formatCurrency,
                                  discountAmount: discountAmount,
                                  taxBreakdown: simplifiedTaxBreakdown,
                                ),
                              ),
                            );
                            return NavigationDecision.prevent;
                          }
                          return NavigationDecision.navigate;
                        },
                      ),
                    )
                    ..loadRequest(Uri.parse(redirectUrl));
                } else {
                  _webViewController = null;
                }
              });

          }
        }
      } else {
        throw Exception(res['message'] ?? "Gagal memproses pesanan");
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _errorMessage = e.toString().replaceAll('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

}
