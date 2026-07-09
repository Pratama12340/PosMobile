import 'package:flutter_test/flutter_test.dart';
import 'package:sistem_pos/core/models/discount_model.dart';
import 'package:sistem_pos/core/utils/discount_eligibility_helper.dart';

void main() {
  group('DiscountEligibilityHelper Tests', () {
    test('isProductEligible returns true for matching product', () {
      final discount = Discount(
        id: 1,
        name: 'Promo',
        scope: 'products',
        type: 'percentage',
        value: 10,
        minPurchase: 0,
        productIds: [1, 2],
      );

      bool eligible = DiscountEligibilityHelper.isProductEligible(
        discount,
        [2, 3], // cart contains product 2
        [],
      );
      expect(eligible, isTrue);
    });

    test('isProductEligible returns false for non-matching product', () {
      final discount = Discount(
        id: 1,
        name: 'Promo',
        scope: 'products',
        type: 'percentage',
        value: 10,
        minPurchase: 0,
        productIds: [1, 2],
      );

      bool eligible = DiscountEligibilityHelper.isProductEligible(
        discount,
        [3, 4], // cart does not contain product 1 or 2
        [],
      );
      expect(eligible, isFalse);
    });

    test('isMinPurchaseMet validates subTotal', () {
      final discount = Discount(
        id: 1,
        name: 'Promo',
        scope: 'global',
        type: 'percentage',
        value: 10,
        minPurchase: 50000,
      );

      expect(DiscountEligibilityHelper.isMinPurchaseMet(discount, 60000, []), isTrue);
      expect(DiscountEligibilityHelper.isMinPurchaseMet(discount, 40000, []), isFalse);
    });

    test('isBlockedByGlobal blocks product discounts when global is active', () {
      final productDiscount = Discount(
        id: 1,
        name: 'Promo',
        scope: 'products',
        type: 'percentage',
        value: 10,
        minPurchase: 0,
      );

      expect(DiscountEligibilityHelper.isBlockedByGlobal(productDiscount, true), isTrue);
      expect(DiscountEligibilityHelper.isBlockedByGlobal(productDiscount, false), isFalse);
    });

    test('isMaxProductReached blocks new product discounts when 2 are selected', () {
      final productDiscount = Discount(
        id: 1,
        name: 'Promo',
        scope: 'products',
        type: 'percentage',
        value: 10,
        minPurchase: 0,
      );

      // Not selected yet, already 2 selected -> Blocked
      expect(DiscountEligibilityHelper.isMaxProductReached(productDiscount, 2, false), isTrue);
      
      // Selected -> Not blocked (can toggle off)
      expect(DiscountEligibilityHelper.isMaxProductReached(productDiscount, 2, true), isFalse);
      
      // Not selected, 1 selected -> Not blocked
      expect(DiscountEligibilityHelper.isMaxProductReached(productDiscount, 1, false), isFalse);
    });
  });
}
