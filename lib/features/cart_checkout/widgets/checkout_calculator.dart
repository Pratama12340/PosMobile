import 'package:sistem_pos/features/orders/models/order_model.dart';
import 'package:sistem_pos/core/models/discount_model.dart';
import 'package:sistem_pos/core/utils/tax_calculator.dart' as tax_calc;

class CheckoutCalculator {
  static double calculateDiscountValue(
      double subTotal, List<Discount> selectedDiscounts, Map<int, OrderItem> cart) {
    if (selectedDiscounts.isEmpty) return 0;

    double totalDiscount = 0;

    for (var d in selectedDiscounts) {
      double dAmt = 0;
      double eligibleTotal = 0;
      int eligibleQty = 0;

      if (d.productIds.isNotEmpty || d.categoryIds.isNotEmpty) {
        for (var item in cart.values) {
          if (item.isVoided || item.activeQty <= 0) continue;

          bool matched = false;
          if (d.productIds.isNotEmpty) {
            matched = d.productIds.contains(item.productId);
          } else if (d.categoryIds.isNotEmpty) {
            matched = item.categoryId != null && d.categoryIds.contains(item.categoryId);
          }

          if (matched) {
            eligibleTotal += (item.originalPrice * item.activeQty);
            eligibleQty += item.activeQty;
          }
        }
      } else {
        eligibleTotal = subTotal;
        for (var item in cart.values) {
          if (!item.isVoided && item.activeQty > 0) {
            eligibleQty += item.activeQty;
          }
        }
      }

      if (eligibleTotal > 0) {
        if (d.type == 'percentage') {
          double calc = eligibleTotal * (d.value / 100);
          if (d.maxDiscount != null && d.maxDiscount! > 0 && calc > d.maxDiscount!) {
            calc = d.maxDiscount!;
          }
          dAmt = calc.floorToDouble(); // PHP uses (int) cast which truncates
        } else {
          if (d.scope == 'global' || d.scope == 'transaction' || d.scope == 'all' || d.scope == null || d.scope!.isEmpty) {
             dAmt = d.value < eligibleTotal ? d.value : eligibleTotal;
          } else {
             double calc = d.value * eligibleQty;
             dAmt = calc < eligibleTotal ? calc : eligibleTotal;
          }
          dAmt = dAmt.floorToDouble();
        }
      }

      totalDiscount += dAmt;
    }

    return totalDiscount;
  }

  static Map<String, dynamic> calculateTaxesAndGrandTotal(
      double baseAmount, List<dynamic> availableTaxes) {
    return tax_calc.calculateTaxesAndGrandTotal(baseAmount, availableTaxes);
  }
}
