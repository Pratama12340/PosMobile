import 'package:sistem_pos/features/orders/models/order_model.dart';
import 'package:sistem_pos/core/models/discount_model.dart';
import 'package:sistem_pos/core/utils/tax_calculator.dart' as tax_calc;

class CheckoutCalculator {
  static double calculateDiscountValue(
      double subTotal, List<Discount> selectedDiscounts, Map<int, OrderItem> cart) {
    if (selectedDiscounts.isEmpty) return 0;

    double total = 0;

    for (var d in selectedDiscounts) {
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

          double discPerItem =
              d.type == 'percentage' ? (item.originalPrice * d.value / 100) : d.value;

          dAmt += discPerItem * item.activeQty;
        }
      } else {
        dAmt = d.type == 'percentage' ? (subTotal * d.value / 100) : d.value;
      }

      if (d.maxDiscount != null && dAmt > d.maxDiscount!) {
        dAmt = d.maxDiscount!;
      }

      total += dAmt;
    }

    return total;
  }

  static Map<String, dynamic> calculateTaxesAndGrandTotal(
      double baseAmount, List<dynamic> availableTaxes) {
    return tax_calc.calculateTaxesAndGrandTotal(baseAmount, availableTaxes);
  }
}
