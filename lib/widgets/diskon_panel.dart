import 'package:flutter/material.dart';
import '../models/discount_model.dart';
import '../style.dart';

class DiskonPanel extends StatelessWidget {
  final Discount? selectedDiscount;
  final List<Discount> availableDiscounts;
  final double discountAmount;
  final String Function(double) formatCurrency;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const DiskonPanel({
    super.key,
    required this.selectedDiscount,
    required this.availableDiscounts,
    required this.discountAmount,
    required this.formatCurrency,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            decoration: BoxDecoration(
              color: selectedDiscount != null ? AppStyle.primaryBlue.withOpacity(0.05) : Colors.transparent,
              border: Border.all(color: AppStyle.primaryBlue.withOpacity(0.2)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.confirmation_number_outlined, size: 16, color: AppStyle.primaryBlue),
                    const SizedBox(width: 8),
                    Text(
                      selectedDiscount == null ? "Pilih Diskon" : selectedDiscount!.name,
                      style: const TextStyle(color: AppStyle.primaryBlue, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Text(
                  "- ${formatCurrency(discountAmount)}",
                  style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
        if (selectedDiscount != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: GestureDetector(
              onTap: onRemove,
              child: const Text("Hapus Diskon", style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ),
      ],
    );
  }
}