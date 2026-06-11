import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/order_model.dart';
import '../models/discount_model.dart';
import '../constants/style.dart';
import '../services/api_service.dart';
import '../screens/success_payment_screen.dart';
import '../services/storage_service.dart';

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

  /// Toggle diskon dengan aturan:
  /// - Diskon PRODUK: bisa 2 sekaligus, otomatis hapus diskon global
  /// - Diskon TRANSAKSI (global): hapus semua diskon produk, hanya 1 aktif
  void _toggleDiscount(Discount d) {
    setState(() {
      // Reset exact change saat diskon berubah agar user konfirmasi ulang
      //if (_isExactChange) {
      //_isExactChange = false;
      //_selectedQuickAmount = null;
      //_amountTendered = 0;
      //_manualTenderController.clear();
      //}

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

          if (_selectedDiscounts.length < 2) {
            _selectedDiscounts.add(d);
          }
        }
      }
    });
  }

  List<dynamic> _availableTaxes = [];

  WebViewController? _webViewController;

  late AnimationController _slideController;
  late Animation<Offset> _slideOutAnimation;
  late Animation<Offset> _slideInAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _loadDiscounts();
    _loadTaxes();

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
  }

  @override
  void dispose() {
    _manualTenderController.dispose();
    _slideController.dispose();
    super.dispose();
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
  final discounts = await ApiService.getDiscounts();
  if (!mounted) return;

  for (var d in discounts) {
    debugPrint("=== DISKON: ${d.name}");
    debugPrint("    scope: ${d.scope}");
    debugPrint("    type: ${d.type}");
    debugPrint("    value: ${d.value}");
    debugPrint("    productIds: ${d.productIds}");
    debugPrint("    categoryIds: ${d.categoryIds}");
    debugPrint("    minPurchase: ${d.minPurchase}");
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
    final taxes = await ApiService.getTaxes();
    if (!mounted) return;
    setState(() {
      _availableTaxes = taxes;
    });
  }

  // ??? Hitung total diskon dari semua diskon yang dipilih ???????????????????
  double _calculateDiscountValue(double subTotal) {
    if (_selectedDiscounts.isEmpty) return 0;

    double total = 0;

    for (var d in _selectedDiscounts) {
      double dAmt = 0;

      // Jika punya productIds atau categoryIds ? hitung per item   qty
      // (berlaku untuk scope apapun: global, products, categories)
      if (d.productIds.isNotEmpty || d.categoryIds.isNotEmpty) {
        for (var item in widget.cart.values) {
          if (item.isVoided || item.activeQty == 0) continue;

          bool matched = false;
          if (d.productIds.isNotEmpty) {
            matched = d.productIds.contains(item.productId);
          } else if (d.categoryIds.isNotEmpty) {
            matched =
                item.categoryId != null &&
                d.categoryIds.contains(item.categoryId);
          }

          if (!matched) continue;

          double discPerItem = d.type == 'percentage'
              ? (item.originalPrice * d.value / 100)
              : d.value;

          dAmt += discPerItem * item.activeQty;
        }
      } else {
        // Tidak ada filter produk/kategori ? berlaku seluruh transaksi
        dAmt = d.type == 'percentage' ? (subTotal * d.value / 100) : d.value;
      }

      if (d.maxDiscount != null && dAmt > d.maxDiscount!) {
        dAmt = d.maxDiscount!;
      }

      total += dAmt;
    }

    return total;
  }

  Map<String, dynamic> _calculateTaxesAndGrandTotal(double baseAmount) {
    double serviceAmount = 0;

    for (var tax in _availableTaxes) {
      String taxName = (tax['name'] ?? '').toString().toLowerCase();
      if (taxName.contains('service')) {
        double rate = double.tryParse(tax['rate']?.toString() ?? '0') ?? 0;
        double exactAmt = (tax['type'] == 'percentage')
            ? (baseAmount * (rate / 100))
            : rate;
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
        amt = (tax['type'] == 'percentage')
            ? (baseAmount * (rate / 100))
            : rate;
      } else {
        double baseForOtherTax = baseAmount + serviceAmount;
        amt = (tax['type'] == 'percentage')
            ? (baseForOtherTax * (rate / 100))
            : rate;
      }

      amt = amt.floorToDouble();
      totalTaxAmount += amt;

      Map<String, dynamic> taxData = Map<String, dynamic>.from(tax);
      taxData['calculated_amount'] = amt;
      taxBreakdown.add(taxData);
    }

    return {
      'tax_amount': totalTaxAmount,
      'tax_breakdown': taxBreakdown,
      'grand_total': (baseAmount + totalTaxAmount).floorToDouble(),
    };
  }

  // ??? LEFT PANEL: DISCOUNT LIST ?????????????????????????????????????????????
  static const Color _softBlue = Color(0xFFE8F0FE);
  static const Color _primaryBlue = Color(0xFF4285F4);
  static const Color _panelBg = Color(0xFFF4F7F9);

  Widget _buildLeftDiscountPanel(double sub) {
    List<int> cartProductIds = widget.cart.values
        .map((item) => item.productId)
        .toList();

    List<int> cartCategoryIds = widget.cart.values
      .where((item) => item.categoryId != null)
      .map((item) => item.categoryId!)
      .toList();
    // Jumlah diskon produk yang sudah dipilih
    int selectedProductCount = _selectedDiscounts
        .where((d) => d.scope == 'products')
        .length;

    return Container(
      color: _panelBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 28, 20, 18),
            color: _panelBg,
            child: Row(
              children: [
                _BackButton(onTap: _closeDiscountList),
                const SizedBox(width: 10),
                const Text(
                  "Pilih Voucher",
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Poppins',
                    letterSpacing: -0.3,
                  ),
                ),
                const Spacer(),
                // Badge info multi-diskon produk
                if (selectedProductCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _primaryBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "$selectedProductCount/2 Produk",
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _primaryBlue,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Info banner: aturan multi-diskon
          Container(height: 1, color: const Color(0xFFDDE3ED)),

          // Discount list
          Expanded(
            child: _availableDiscounts.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.local_offer_outlined,
                          size: 48,
                          color: Colors.black26,
                        ),
                        SizedBox(height: 12),
                        Text(
                          "Tidak ada diskon aktif",
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 18,
                    ),
                    itemCount: _availableDiscounts.length,
                    itemBuilder: (context, index) {
                      var d = _availableDiscounts[index];

                      bool isMinPurchaseMet = sub >= d.minPurchase;
bool isProductEligible = true;

if (d.scope == 'products' && d.productIds.isNotEmpty) {
  isProductEligible = cartProductIds.any(
    (cartId) => d.productIds.contains(cartId),
  );
} else if (d.scope == 'categories' && d.categoryIds.isNotEmpty) {
  // ← TAMBAH INI
  isProductEligible = cartCategoryIds.any(
    (catId) => d.categoryIds.contains(catId),
  );
}

                      // Diskon produk max 2: disabled jika sudah 2 dan ini belum dipilih
                      bool isMaxProductReached =
                          d.scope == 'products' &&
                          selectedProductCount >= 2 &&
                          !_isDiscountSelected(d);

                      // Diskon produk disabled jika ada global aktif, dan sebaliknya
                      bool isBlockedByGlobal =
                          d.scope == 'products' && _hasGlobalDiscount;
                      bool isBlockedByProduct =
                          d.scope == 'global' && _hasProductDiscount;

                      bool eligible =
                          isMinPurchaseMet &&
                          isProductEligible &&
                          !isMaxProductReached &&
                          !isBlockedByGlobal;

                      bool canTap =
                          _isDiscountSelected(d) ||
                          (isMinPurchaseMet &&
                              isProductEligible &&
                              !isMaxProductReached) ||
                          d.scope == 'global'; // transaksi selalu bisa diklik

                      return Opacity(
                        opacity: canTap ? 1.0 : 0.45,
                        child: _buildVoucherCard(
                          d,
                          eligible: eligible,
                          canTap: canTap,
                          selectedProductCount: selectedProductCount,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoucherCard(
    Discount d, {
    required bool eligible,
    required bool canTap,
    required int selectedProductCount,
  }) {
    final bool isProduct = d.scope == 'products';
    final bool isSelected = _isDiscountSelected(d);

    // Label khusus untuk kondisi terblokir
    String? blockedReason;
    if (!isSelected) {
      if (isProduct && _hasGlobalDiscount) {
        blockedReason = "Hapus diskon transaksi dulu";
      } else if (isProduct && selectedProductCount >= 2) {
        blockedReason = "Maks. 2 diskon produk";
      }
    }

    return GestureDetector(
      onTap: (canTap || isSelected) ? () => _toggleDiscount(d) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 14),
        height: blockedReason != null ? 118 : 108,
        decoration: BoxDecoration(
          color: isSelected ? _softBlue : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? _primaryBlue.withValues(alpha: 0.45)
                : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? _primaryBlue.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: isSelected ? 12 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Left accent strip
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 5,
              decoration: BoxDecoration(
                color: isSelected
                    ? _primaryBlue
                    : (eligible ? const Color(0xFFDDE3ED) : Colors.grey[300]),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
              ),
            ),

            // Icon zone
            Container(
              width: 58,
              alignment: Alignment.center,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: isSelected
                    ? const Icon(
                        Icons.check_circle_rounded,
                        key: ValueKey('check'),
                        color: _primaryBlue,
                        size: 26,
                      )
                    : Icon(
                        isProduct
                            ? Icons.shopping_bag_outlined
                            : Icons.receipt_long_outlined,
                        key: const ValueKey('offer'),
                        color: eligible
                            ? const Color(0xFF8FAEE0)
                            : Colors.grey[400],
                        size: 24,
                      ),
              ),
            ),

            // Dashed divider
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  7,
                  (_) => Container(
                    width: 1,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 2.5),
                    color: isSelected
                        ? _primaryBlue.withValues(alpha: 0.25)
                        : Colors.grey.withValues(alpha: 0.25),
                  ),
                ),
              ),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Scope chip + name row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isProduct
                                ? const Color(0xFFEDE7FD)
                                : const Color(0xFFE6F4EA),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isProduct
                                    ? Icons.inventory_2_outlined
                                    : Icons.receipt_outlined,
                                size: 9,
                                color: isProduct
                                    ? const Color(0xFF7C3AED)
                                    : const Color(0xFF16A34A),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                isProduct ? "Per Produk" : "Transaksi",
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: isProduct
                                      ? const Color(0xFF7C3AED)
                                      : const Color(0xFF16A34A),
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            d.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: isSelected
                                  ? _primaryBlue
                                  : const Color(0xFF1A1A2E),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    Text(
                      d.type == 'percentage'
                          ? "${d.value.toInt()}% OFF"
                          : "Hemat ${widget.formatCurrency(d.value.toDouble())}",
                      style: TextStyle(
                        color: isSelected
                            ? _primaryBlue
                            : (eligible
                                  ? const Color(0xFF2563EB)
                                  : Colors.grey),
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        letterSpacing: -0.5,
                      ),
                    ),

                    const SizedBox(height: 5),

                    // Footer row
                    Row(
                      children: [
                        const Icon(
                          Icons.payments_outlined,
                          size: 10,
                          color: Colors.black38,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "Min. ${widget.formatCurrency(d.minPurchase.toDouble())}",
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.black38,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (blockedReason != null) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber[50],
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                blockedReason,
                                style: TextStyle(
                                  fontSize: 8.5,
                                  color: Colors.orange[800],
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ] else if (!eligible && !isSelected) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              "Belum memenuhi syarat",
                              style: TextStyle(
                                fontSize: 8.5,
                                color: Colors.red[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                        if (isSelected) ...[
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _primaryBlue.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              "Terpilih ?",
                              style: TextStyle(
                                fontSize: 9,
                                color: _primaryBlue,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
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

  // ??? DISCOUNT BUTTON (on right panel summary) ??????????????????????????????
  Widget _buildDiscountButton(double discAmount) {
    bool isProductDiscountActive = widget.hasDiscountedItem;
    bool hasAnyDiscount = _selectedDiscounts.isNotEmpty;

    // Label dinamis berdasarkan jumlah diskon terpilih
    String btnText;
    if (_selectedDiscounts.isEmpty) {
      btnText = "Pilih diskon tambahan";
    } else if (_selectedDiscounts.length == 1) {
      btnText = _selectedDiscounts.first.name;
    } else {
      btnText =
          "${_selectedDiscounts.length} Diskon: "
          "${_selectedDiscounts.map((d) => d.name).join(', ')}";
    }

    bool isHighlighted = isProductDiscountActive || hasAnyDiscount;

    return InkWell(
      onTap: _openDiscountList,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isHighlighted
              ? Colors.orange.withValues(alpha: 0.08)
              : Colors.grey.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isHighlighted
                ? Colors.orange.withValues(alpha: 0.3)
                : Colors.black12,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left: icon + label
            Expanded(
              child: Row(
                children: [
                  Icon(
                    isProductDiscountActive
                        ? Icons.verified_rounded
                        : (hasAnyDiscount
                              ? Icons.confirmation_number_rounded
                              : Icons.local_offer_outlined),
                    size: 18,
                    color: isHighlighted ? Colors.orange : Colors.black45,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      btnText,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isHighlighted
                            ? Colors.orange[900]
                            : Colors.black54,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            // Right: amount / status
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isProductDiscountActive && _selectedDiscounts.isEmpty) ...[
                  const Text(
                    "Aktif",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.swap_horiz_rounded,
                    size: 16,
                    color: Colors.orange,
                  ),
                ] else if (hasAnyDiscount) ...[
                  Text(
                    "- ${widget.formatCurrency(discAmount)}",
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Tombol hapus semua diskon
                  GestureDetector(
                    onTap: () => setState(() => _selectedDiscounts.clear()),
                    child: const Icon(
                      Icons.cancel,
                      size: 18,
                      color: Colors.red,
                    ),
                  ),
                ] else ...[
                  const Text(
  "Tambah",
  style: TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.bold,
    color: AppStyle.primaryBlue,
  ),
),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ??? RECEIPT SUMMARY ???????????????????????????????????????????????????????
  Widget _buildReceiptSummary(
    double sub,
    double disc,
    double grand,
    List<Map<String, dynamic>> taxBreakdown,
  ) {
    return Column(
      children: [
        _rowInf("Sub Total", sub),
        const SizedBox(height: 10),
        _buildDiscountButton(disc),

        // Detail per diskon jika lebih dari 1
        if (_selectedDiscounts.length > 1) ...[
          const SizedBox(height: 6),
          ...(_selectedDiscounts.map((d) {
            double dAmt = 0;
            if (d.productIds.isNotEmpty || d.categoryIds.isNotEmpty) {
              for (var item in widget.cart.values) {
                if (item.isVoided || item.activeQty == 0) continue;
                bool matched = false;
                if (d.productIds.isNotEmpty) {
                  matched = d.productIds.contains(item.productId);
                } else if (d.categoryIds.isNotEmpty) {
                  matched =
                      item.categoryId != null &&
                      d.categoryIds.contains(item.categoryId);
                }
                if (!matched) continue;
                double discPerItem = d.type == 'percentage'
                    ? (item.originalPrice * d.value / 100)
                    : d.value;
                dAmt += discPerItem * item.activeQty;
              }
            } else {
              dAmt = d.type == 'percentage'
                  ? (sub * d.value / 100)
                  : d.value.toDouble();
            }
            if (d.maxDiscount != null && dAmt > d.maxDiscount!) {
              dAmt = d.maxDiscount!;
            }

            return Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.subdirectory_arrow_right_rounded,
                        size: 12,
                        color: Colors.black26,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        d.name,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.black45,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    "- ${widget.formatCurrency(dAmt)}",
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          })),
        ],

        const SizedBox(height: 10),
        const Divider(color: Color(0xFFEEEEEE), height: 1),
        const SizedBox(height: 10),
        ...taxBreakdown.map((tax) {
          double rate = double.tryParse(tax['rate']?.toString() ?? '0') ?? 0;
          double amt = tax['calculated_amount'] ?? 0.0;
          String label = tax['name'] ?? "Pajak";
          if (tax['type'] == 'percentage') {
            label += " (${rate.toString().replaceAll('.0', '')}%)";
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _rowInf(label, amt),
          );
        }),
        const Divider(height: 24, thickness: 1),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Total",
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                fontFamily: 'Poppins',
              ),
            ),
            Text(
              widget.formatCurrency(grand),
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: AppStyle.primaryBlue,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ??? LEFT PANEL: PAYMENT METHOD ???????????????????????????????????????????
  Widget _buildPaymentMethodPanel(
    double grandTotal,
    int tagihanInt,
    int uangMasukInt,
    int change,
  ) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Text(
            widget.isUpdatingOrder
                ? "Bayar Pesanan (Update)"
                : "Payment Method",
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              fontFamily: 'Poppins',
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
          const SizedBox(height: 40),

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
                color: AppStyle.primaryBlue,
              ),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                labelText: "Isi Uang Manual",
                filled: true,
                fillColor: const Color(0xFFF8F9FA),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) {
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
            ),
            const SizedBox(height: 25),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                _quickBtn(grandTotal, label: "Bayar Pas", isExact: true),
                ...[
                  20000.0,
                  50000.0,
                  100000.0,
                  150000.0,
                  200000.0,
                ].map((v) => _quickBtn(v)),
              ],
            ),
            const Spacer(),
            if (change >= 0) _buildChangeDisplay(change.toDouble()),
          ] else if (_paymentMethod == 'Card' || _paymentMethod == 'Qris') ...[
            Expanded(
              child: _webViewController != null
                  ? Container(
                      margin: const EdgeInsets.only(top: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: AppStyle.primaryBlue.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: WebViewWidget(controller: _webViewController!),
                    )
                  : Center(
                      // ← HAPUS const
                      child: Column(
                        // ← GANTI jadi Column
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(
                            color: AppStyle.primaryBlue,
                          ),
                          const SizedBox(height: 16),
                          if (_errorMessage != null) // ← TAMBAH error message
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 13,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            )
                          else
                            const Text(
                              // ← TAMBAH loading text
                              "Memuat halaman pembayaran...",
                              style: TextStyle(
                                color: Colors.black45,
                                fontSize: 13,
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // subTotal: pakai originalTotalAmount jika ada diskon produk aktif
    double subTotal = widget.originalTotalAmount > 0
        ? widget.originalTotalAmount
        : widget.totalAmount;

        for (var item in widget.cart.values) {
    debugPrint("=== CART ITEM: ${item.itemName}");
    debugPrint("    productId: ${item.productId}");
    debugPrint("    categoryId: ${item.categoryId}");
    debugPrint("    discountId: ${item.discountId}");
  }

    double discountAmount = _calculateDiscountValue(subTotal);
    double baseAmount = subTotal - discountAmount;
    if (baseAmount < 0) baseAmount = 0;

    var taxData = _calculateTaxesAndGrandTotal(baseAmount);
    List<Map<String, dynamic>> taxBreakdown = taxData['tax_breakdown'];
    double grandTotal = taxData['grand_total'];
    if (grandTotal < 0) grandTotal = 0;

    if (_isExactChange) {
      final formatted = NumberFormat.decimalPattern(
        'id',
      ).format(grandTotal.toInt());
      if (_manualTenderController.text != formatted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _manualTenderController.text = formatted;
          // Update _amountTendered tanpa setState agar tidak rebuild loop
          _amountTendered = grandTotal;
        });
      }
    }

    int tagihanInt = grandTotal.toInt();
    int uangMasukInt = _amountTendered.toInt();
    int change = uangMasukInt - tagihanInt;

    String currentTime = DateFormat('HH:mm').format(DateTime.now());
    String currentDate = DateFormat('dd MMM yyyy').format(DateTime.now());

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(viewInsets: EdgeInsets.zero),
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        insetPadding: const EdgeInsets.all(24),
        child: Container(
          width: 1000,
          constraints: const BoxConstraints(maxHeight: 680),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Stack(
          children: [
            Row(
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
                              child: _buildPaymentMethodPanel(
                                grandTotal,
                                tagihanInt,
                                uangMasukInt,
                                change,
                              ),
                            ),
                            if (_showDiscountList)
                              SlideTransition(
                                position: _slideInAnimation,
                                child: FadeTransition(
                                  opacity: _fadeAnimation,
                                  child: _buildLeftDiscountPanel(subTotal),
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
                    decoration: const BoxDecoration(color: Color(0xFFFBFBFB)),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(30, 25, 30, 25),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                          const Divider(height: 30),
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
                            child: _buildReceiptSummary(
                              subTotal,
                              discountAmount,
                              grandTotal,
                              taxBreakdown,
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
                        ],
                      ),
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
      ),
    );
  }

  Future<void> _processPayment() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final outletData = await ApiService.fetchOutletInfoLive();
      final String currentOutletName = outletData['name']!;
      final String currentOutletAddress = outletData['address_outlet'] ?? "-";

      final savedOutletId = await StorageService.getOutletId();
      if (savedOutletId == null || savedOutletId == 0) {
        throw Exception("ID Outlet tidak ditemukan.");
      }

      double subTotal = widget.originalTotalAmount > 0
          ? widget.originalTotalAmount
          : widget.totalAmount;

          for (var item in widget.cart.values) {
    debugPrint("=== CART ITEM: ${item.itemName}");
    debugPrint("    productId: ${item.productId}");
    debugPrint("    categoryId: ${item.categoryId}");
    debugPrint("    discountId: ${item.discountId}");
  }
      double discountAmount = _calculateDiscountValue(subTotal);
      double baseAmount = subTotal - discountAmount;

      var taxData = _calculateTaxesAndGrandTotal(baseAmount);
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
        'payment_method': _paymentMethod.toLowerCase(),
        'paid_amount': _paymentMethod == 'Cash' ? uangMasukInt : tagihanInt,
        'items': mappedItems,
        if (_selectedDiscounts.length == 1)
          'discount_id': _selectedDiscounts.first.id,
      };

      debugPrint("=== DEBUG CHECKOUT ===");
      debugPrint("isUpdatingOrder: ${widget.isUpdatingOrder}");
      debugPrint("pendingDiscountId: ${widget.pendingDiscountId}");
      debugPrint(
        "selectedDiscounts: ${_selectedDiscounts.map((d) => '${d.name}(${d.scope})').join(', ')}",
      );
      debugPrint("subTotal: $subTotal");
      debugPrint("discountAmount: $discountAmount");
      debugPrint("grandTotal: $grandTotal");
      debugPrint("======================");

      debugPrint("[API REQUEST] --> CHECKOUT ORDER. Payload: $payload");
      dynamic res;
      if (widget.isUpdatingOrder) {
        res = await ApiService.updatePendingOrder(widget.orderId, payload);
      } else {
        res = await ApiService.submitOrder(payload);
      }

      if (!mounted) return;

      if (res['success']) {
        String realOrderId =
            res['data']?['order']?['invoice_number'] ?? widget.orderId;
        final cartSnapshot = Map<int, OrderItem>.from(widget.cart);

        if (_paymentMethod == 'Cash') {
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
          String? redirectUrl = res['data']?['redirect_url'];
          if (redirectUrl != null && redirectUrl.isNotEmpty) {
            debugPrint("[REDIRECT URL] --> ${res['data']?['redirect_url']}");
            debugPrint("[FULL RESPONSE] --> ${res['data']}");

            if (redirectUrl != null && redirectUrl.isNotEmpty) {
              setState(() {
                _isLoadingPayment = false;
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
                          // Sedikit memperkecil zoom jika QR code terpotong di layar POS Anda
                          ?.runJavaScript("document.body.style.zoom = '0.85';"),
                      onNavigationRequest: (request) {
                        // 2. Cegah error jika WebView mencoba membuka deeplink aplikasi (gojek://, shopeeid://, intent://)
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
                                amountPaid:
                                    grandTotal, // Karena cashless, uang masuk = tagihan
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
              });
            }
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

  Widget _rowInf(String l, double v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(l, style: const TextStyle(color: Colors.black45, fontSize: 11)),
        Text(
          widget.formatCurrency(v),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
        ),
      ],
    ),
  );

  Widget _payBtn(String l, IconData i, {bool isEnabled = true}) {
    bool s = _paymentMethod == l;
    return Expanded(
      child: GestureDetector(
        onTap: (isEnabled && !_isLoading)
    ? () async {
        setState(() {
          if (_errorMessage != null) _errorMessage = null;
          _paymentMethod = l;
          _webViewController = null; // reset dulu, lalu proses
        });
        if (l != 'Cash') await _processPayment();
      }
    : null,
        child: Opacity(
          opacity: isEnabled ? 1.0 : 0.4,
          child: Container(
            height: 100,
            decoration: BoxDecoration(
              color: s ? AppStyle.primaryBlue : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: s ? AppStyle.primaryBlue : const Color(0xFFEEEEEE),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isLoading && s)
                  const SizedBox(
                    height: 28,
                    width: 28,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                else
                  Icon(
                    i,
                    color: s ? Colors.white : AppStyle.textMain,
                    size: 28,
                  ),
                const SizedBox(height: 8),
                Text(
                  l,
                  style: TextStyle(
                    color: s ? Colors.white : AppStyle.textMain,
                    fontWeight: s ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _quickBtn(double v, {String? label, bool isExact = false}) {
    bool isSelected =
        _selectedQuickAmount == v &&
        (label == null || _isExactChange == isExact);

    if (label == "Bayar Pas") {
      isSelected = _isExactChange;
    }

    return GestureDetector(
      onTap: () => setState(() {
        if (_errorMessage != null) _errorMessage = null;
        _isExactChange = isExact;
        _selectedQuickAmount = v;
        _amountTendered = v;
        _manualTenderController.text = NumberFormat.decimalPattern(
          'id',
        ).format(v.toInt());
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppStyle.primaryBlue : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppStyle.primaryBlue : const Color(0xFFEEEEEE),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppStyle.primaryBlue.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Text(
          label ?? widget.formatCurrency(v),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : AppStyle.textMain,
          ),
        ),
      ),
    );
  }

  Widget _buildChangeDisplay(double c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
    decoration: BoxDecoration(
      color: Colors.green.shade50,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: Colors.green.withValues(alpha: 0.1)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          "Kembalian",
          style: TextStyle(
            color: Colors.green,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        Text(
          widget.formatCurrency(c),
          style: const TextStyle(
            color: Colors.green,
            fontWeight: FontWeight.w900,
            fontSize: 24,
          ),
        ),
      ],
    ),
  );
}

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFDDE3ED)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 15,
          color: Color(0xFF4285F4),
        ),
      ),
    );
  }
}

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue o, TextEditingValue n) {
    if (n.text.isEmpty) return n.copyWith(text: '');
    String t = NumberFormat.decimalPattern(
      'id',
    ).format(double.parse(n.text.replaceAll('.', '')));
    return n.copyWith(
      text: t,
      selection: TextSelection.collapsed(offset: t.length),
    );
  }
}
