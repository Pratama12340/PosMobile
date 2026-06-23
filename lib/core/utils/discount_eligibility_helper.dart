import 'package:sistem_pos/core/models/discount_model.dart';

class DiscountEligibilityHelper {
  static bool isProductEligible(Discount discount, List<int> cartProductIds, List<int> cartCategoryIds) {
    if (discount.scope == 'products' && discount.productIds.isNotEmpty) {
      return cartProductIds.any((id) => discount.productIds.contains(id));
    } else if (discount.scope == 'categories' && discount.categoryIds.isNotEmpty) {
      return cartCategoryIds.any((id) => discount.categoryIds.contains(id));
    }
    return true;
  }

  static bool isMinPurchaseMet(Discount discount, double subTotal) {
    return subTotal >= discount.minPurchase;
  }

  static bool isBlockedByGlobal(Discount discount, bool hasGlobalDiscount) {
    return discount.scope == 'products' && hasGlobalDiscount;
  }

  static bool isMaxProductReached(Discount discount, int selectedProductCount, bool isSelected) {
    return false;
  }

  static String? getBlockedReason({
    required Discount discount,
    required bool isSelected,
    required bool hasGlobalDiscount,
    required int selectedProductCount,
  }) {
    if (isSelected) return null;
    
    if (discount.scope == 'products') {
      if (hasGlobalDiscount) return "Hapus diskon transaksi dulu";
    }
    return null;
  }

  static bool isEligible({
    required Discount discount,
    required double subTotal,
    required List<int> cartProductIds,
    required List<int> cartCategoryIds,
    required bool hasGlobalDiscount,
    required int selectedProductCount,
    required bool isSelected,
  }) {
    return isMinPurchaseMet(discount, subTotal) &&
           isProductEligible(discount, cartProductIds, cartCategoryIds) &&
           !isMaxProductReached(discount, selectedProductCount, isSelected) &&
           !isBlockedByGlobal(discount, hasGlobalDiscount);
  }

  static bool canTap({
    required Discount discount,
    required double subTotal,
    required List<int> cartProductIds,
    required List<int> cartCategoryIds,
    required int selectedProductCount,
    required bool isSelected,
  }) {
    if (isSelected) return true;
    if (discount.scope == 'global') return true;
    
    return isMinPurchaseMet(discount, subTotal) &&
           isProductEligible(discount, cartProductIds, cartCategoryIds) &&
           !isMaxProductReached(discount, selectedProductCount, isSelected);
  }
}
