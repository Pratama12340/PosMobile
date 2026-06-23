import 'package:flutter/material.dart';
import 'package:sistem_pos/core/models/discount_model.dart';
import 'package:sistem_pos/core/utils/discount_eligibility_helper.dart';

class DiscountPanel extends StatelessWidget {
  final double subTotal;
  final List<int> cartProductIds;
  final List<int> cartCategoryIds;
  final List<Discount> availableDiscounts;
  final List<Discount> selectedDiscounts;
  final bool hasGlobalDiscount;
  final bool hasProductDiscount;
  final int selectedProductCount;
  final Function(Discount) onToggleDiscount;
  final VoidCallback onClose;
  final String Function(double) formatCurrency;

  const DiscountPanel({
    super.key,
    required this.subTotal,
    required this.cartProductIds,
    required this.cartCategoryIds,
    required this.availableDiscounts,
    required this.selectedDiscounts,
    required this.hasGlobalDiscount,
    required this.hasProductDiscount,
    required this.selectedProductCount,
    required this.onToggleDiscount,
    required this.onClose,
    required this.formatCurrency,
  });

  static const Color _softBlue = Color(0xFFE8F0FE);
  static const Color _primaryBlue = Color(0xFF4285F4);
  static const Color _panelBg = Color(0xFFF4F7F9);

  bool _isDiscountSelected(Discount d) =>
      selectedDiscounts.any((s) => s.id == d.id);

  @override
  Widget build(BuildContext context) {
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
                _BackButton(onTap: onClose),
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
                // Badge info multi-diskon produk dihilangkan sesuai request
              ],
            ),
          ),

          // Info banner: aturan multi-diskon
          Container(height: 1, color: const Color(0xFFDDE3ED)),

          // Discount list
          Expanded(
            child: availableDiscounts.isEmpty
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
                    itemCount: availableDiscounts.length,
                    itemBuilder: (context, index) {
                      var d = availableDiscounts[index];

                      bool isSelected = _isDiscountSelected(d);
                      
                      bool eligible = DiscountEligibilityHelper.isEligible(
                        discount: d,
                        subTotal: subTotal,
                        cartProductIds: cartProductIds,
                        cartCategoryIds: cartCategoryIds,
                        hasGlobalDiscount: hasGlobalDiscount,
                        selectedProductCount: selectedProductCount,
                        isSelected: isSelected,
                      );

                      bool canTap = DiscountEligibilityHelper.canTap(
                        discount: d,
                        subTotal: subTotal,
                        cartProductIds: cartProductIds,
                        cartCategoryIds: cartCategoryIds,
                        selectedProductCount: selectedProductCount,
                        isSelected: isSelected,
                      );

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

    String? blockedReason = DiscountEligibilityHelper.getBlockedReason(
      discount: d,
      isSelected: isSelected,
      hasGlobalDiscount: hasGlobalDiscount,
      selectedProductCount: selectedProductCount,
    );

    return GestureDetector(
      onTap: (canTap || isSelected) ? () => onToggleDiscount(d) : null,
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
                          : "Hemat ${formatCurrency(d.value.toDouble())}",
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
                          "Min. ${formatCurrency(d.minPurchase.toDouble())}",
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
                              "Terpilih ✓",
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
