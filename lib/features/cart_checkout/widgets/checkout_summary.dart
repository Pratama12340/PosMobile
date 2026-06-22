import 'package:flutter/material.dart';
import 'package:sistem_pos/features/orders/models/order_model.dart';
import 'package:sistem_pos/core/models/discount_model.dart';
import 'package:sistem_pos/core/constants/style.dart';

class CheckoutSummary extends StatelessWidget {
  final double subTotal;
  final double discountAmount;
  final double grandTotal;
  final List<Map<String, dynamic>> taxBreakdown;
  final List<Discount> selectedDiscounts;
  final Map<int, OrderItem> cart;
  final bool hasDiscountedItem;
  final String Function(double) formatCurrency;
  final VoidCallback onOpenDiscountList;
  final VoidCallback onClearDiscounts;

  const CheckoutSummary({
    super.key,
    required this.subTotal,
    required this.discountAmount,
    required this.grandTotal,
    required this.taxBreakdown,
    required this.selectedDiscounts,
    required this.cart,
    required this.hasDiscountedItem,
    required this.formatCurrency,
    required this.onOpenDiscountList,
    required this.onClearDiscounts,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _rowInf("Sub Total", subTotal),
        const SizedBox(height: 10),
        _buildDiscountButton(),

        // Detail per diskon jika lebih dari 1
        if (selectedDiscounts.length > 1) ...[
          const SizedBox(height: 6),
          ...selectedDiscounts.map((d) {
            double dAmt = 0;
            if (d.productIds.isNotEmpty || d.categoryIds.isNotEmpty) {
              for (var item in cart.values) {
                if (item.isVoided || item.activeQty == 0) continue;
                bool matched = false;
                if (d.productIds.isNotEmpty) {
                  matched = d.productIds.contains(item.productId);
                } else if (d.categoryIds.isNotEmpty) {
                  matched = item.categoryId != null && d.categoryIds.contains(item.categoryId);
                }
                if (!matched) continue;
                double discPerItem = d.type == 'percentage'
                    ? (item.originalPrice * d.value / 100)
                    : d.value;
                dAmt += discPerItem * item.activeQty;
              }
            } else {
              dAmt = d.type == 'percentage'
                  ? (subTotal * d.value / 100)
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
                    "- ${formatCurrency(dAmt)}",
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }),
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
              formatCurrency(grandTotal),
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

  Widget _rowInf(String l, double v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l, style: const TextStyle(color: Colors.black45, fontSize: 11)),
            Text(
              formatCurrency(v),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ],
        ),
      );

  Widget _buildDiscountButton() {
    bool isProductDiscountActive = hasDiscountedItem;
    bool hasAnyDiscount = selectedDiscounts.isNotEmpty;

    String btnText;
    if (selectedDiscounts.isEmpty) {
      btnText = "Pilih diskon tambahan";
    } else if (selectedDiscounts.length == 1) {
      btnText = selectedDiscounts.first.name;
    } else {
      btnText =
          "${selectedDiscounts.length} Diskon: "
          "${selectedDiscounts.map((d) => d.name).join(', ')}";
    }

    bool isHighlighted = isProductDiscountActive || hasAnyDiscount;

    return InkWell(
      onTap: onOpenDiscountList,
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
                if (isProductDiscountActive && selectedDiscounts.isEmpty) ...[
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
                    "- ${formatCurrency(discountAmount)}",
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Tombol hapus semua diskon
                  IconButton(
                    onPressed: onClearDiscounts,
                    icon: const Icon(Icons.cancel, color: Colors.red, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    style: IconButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
}
