import 'package:flutter/material.dart';
import '../models/discount_model.dart';

class DiskonPanel extends StatelessWidget {
  final Discount? selectedDiscount;
  final List<Discount> availableDiscounts;
  final List<int> cartProductIds;
  final double discountAmount;
  final double subtotal;
  final String Function(double) formatCurrency;
  final Function(Discount) onSelected;
  final VoidCallback onRemove;

  const DiskonPanel({
    super.key,
    required this.selectedDiscount,
    required this.availableDiscounts,
    required this.cartProductIds,
    required this.discountAmount,
    required this.subtotal,
    required this.formatCurrency,
    required this.onSelected,
    required this.onRemove,
  });

  void _showSideDiscountPanel(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Dismiss",
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            elevation: 20,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.45,
              height: double.infinity,
              color: const Color(0xFFF8F9FA),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(25, 50, 25, 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Voucher Diskon",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.red,
                            size: 28,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  Expanded(
                    child: availableDiscounts.isEmpty
                        ? const Center(child: Text("Tidak ada diskon tersedia"))
                        : ListView.builder(
                            padding: const EdgeInsets.all(20),
                            itemCount: availableDiscounts.length,
                            itemBuilder: (context, index) {
                              final d = availableDiscounts[index];

                              bool isMinPurchaseMet = subtotal >= d.minPurchase;

                              bool isProductEligible = true;
                              if (d.scope == 'products' &&
                                  d.productIds.isNotEmpty) {
                                isProductEligible = cartProductIds.any(
                                  (cartId) => d.productIds.contains(cartId),
                                );
                              }

                              bool isEligible =
                                  isMinPurchaseMet && isProductEligible;

                              return Opacity(
                                opacity: isEligible ? 1.0 : 0.5,
                                child: _VoucherCard(
                                  discount: d,
                                  isEligible: isEligible,
                                  formatCurrency: formatCurrency,
                                  onTap: () {
                                    if (isEligible) {
                                      onSelected(d);
                                      Navigator.pop(context);
                                    } else {
                                      String errorMsg = !isMinPurchaseMet
                                          ? "Minimal belanja belum tercapai: ${formatCurrency(d.minPurchase)}"
                                          : "Voucher ini tidak berlaku untuk menu yang dipesan.";

                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(content: Text(errorMsg)),
                                      );
                                    }
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return SlideTransition(
          position: Tween(
            begin: const Offset(1, 0),
            end: const Offset(0, 0),
          ).animate(anim1),
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool hasDiscount = selectedDiscount != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => _showSideDiscountPanel(context),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
            decoration: BoxDecoration(
              color: hasDiscount
                  ? Colors.orange.withValues(alpha: 0.08)
                  : Colors.white,
              border: Border.all(
                color: hasDiscount
                    ? Colors.orange.withValues(alpha: 0.3)
                    : Colors.black12,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      hasDiscount
                          ? Icons.confirmation_number
                          : Icons.local_offer_outlined,
                      size: 18,
                      color: hasDiscount ? Colors.orange : Colors.black45,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      hasDiscount ? selectedDiscount!.name : "Pilih Diskon",
                      style: TextStyle(
                        color: hasDiscount
                            ? Colors.orange[900]
                            : Colors.black87,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      "- ${formatCurrency(discountAmount)}",
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (hasDiscount)
                      GestureDetector(
                        onTap: onRemove,
                        child: const Icon(
                          Icons.cancel,
                          size: 20,
                          color: Colors.red,
                        ),
                      )
                    else
                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: Colors.black26,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _VoucherCard extends StatelessWidget {
  final Discount discount;
  final bool isEligible;
  final String Function(double) formatCurrency;
  final VoidCallback onTap;

  const _VoucherCard({
    required this.discount,
    required this.isEligible,
    required this.formatCurrency,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    String scopeLabel = discount.scope == 'global'
        ? "Semua Menu"
        : "Menu Tertentu";

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        height: 110,
        child: CustomPaint(
          painter: _TicketPainter(),
          child: Row(
            children: [
              Container(
                width: 70,
                alignment: Alignment.center,
                child: Icon(
                  Icons.confirmation_number_rounded,
                  color: isEligible ? Colors.blue : Colors.grey,
                  size: 30,
                ),
              ),
              _DashedLine(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              discount.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: discount.scope == 'global'
                                  ? Colors.green[50]
                                  : Colors.blue[50],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              scopeLabel,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: discount.scope == 'global'
                                    ? Colors.green[700]
                                    : Colors.blue[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        discount.type == 'percentage'
                            ? "${discount.value.toInt()}% OFF"
                            : "POTONGAN ${formatCurrency(discount.value.toDouble())}",
                        style: TextStyle(
                          color: isEligible ? Colors.blue : Colors.grey,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Min. Belanja: ${formatCurrency(discount.minPurchase)}",
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          ),
                          if (!isEligible)
                            const Text(
                              "Syarat Belum Terpenuhi",
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
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
}

class _TicketPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    Path path = Path();
    path.lineTo(0, size.height);
    path.lineTo(size.width, size.height);
    path.lineTo(size.width, 0);

    path.addOval(
      Rect.fromCircle(center: Offset(0, size.height / 2), radius: 8),
    );
    path.addOval(
      Rect.fromCircle(center: Offset(size.width, size.height / 2), radius: 8),
    );
    path.fillType = PathFillType.evenOdd;

    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.2), 3, false);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class _DashedLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        8,
        (index) => Container(
          width: 1.2,
          height: 4,
          margin: const EdgeInsets.symmetric(vertical: 2),
          color: Colors.grey.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}
