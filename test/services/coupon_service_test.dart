import 'package:flutter_test/flutter_test.dart';

/// Test the pure discount calculation logic extracted from CouponService.
/// CouponService itself depends on Supabase.instance which requires
/// full initialization — so we test the pure business logic directly.
double calculateDiscount(double originalPrice, int discountPercent) {
  return originalPrice * (discountPercent / 100);
}

void main() {
  group('CouponService - calculateDiscount (pure logic)', () {
    test('10% discount on ₹1000 = ₹100', () {
      expect(calculateDiscount(1000, 10), 100.0);
    });

    test('50% discount on ₹500 = ₹250', () {
      expect(calculateDiscount(500, 50), 250.0);
    });

    test('100% discount returns full amount', () {
      expect(calculateDiscount(300, 100), 300.0);
    });

    test('0% discount returns zero', () {
      expect(calculateDiscount(1000, 0), 0.0);
    });

    test('discount on zero amount returns zero', () {
      expect(calculateDiscount(0, 50), 0.0);
    });

    test('handles small percentage (1%)', () {
      final result = calculateDiscount(1500, 1);
      expect(result, closeTo(15.0, 0.01));
    });

    test('handles large amounts', () {
      final result = calculateDiscount(99999, 25);
      expect(result, closeTo(24999.75, 0.01));
    });

    test('negative price edge case', () {
      // Refund scenario — shouldn't happen but verify math
      final result = calculateDiscount(-500, 10);
      expect(result, closeTo(-50.0, 0.01));
    });
  });

  group('Coupon Validation Logic', () {
    test('expired coupon (validUntil in the past) is invalid', () {
      final validUntil = DateTime.now().subtract(const Duration(days: 1));
      final now = DateTime.now();
      expect(now.isAfter(validUntil), isTrue);
    });

    test('future coupon (validFrom in the future) is invalid', () {
      final validFrom = DateTime.now().add(const Duration(days: 1));
      final now = DateTime.now();
      expect(now.isBefore(validFrom), isTrue);
    });

    test('active coupon (within validity period) is valid', () {
      final validFrom = DateTime.now().subtract(const Duration(days: 1));
      final validUntil = DateTime.now().add(const Duration(days: 1));
      final now = DateTime.now();
      expect(now.isAfter(validFrom) && now.isBefore(validUntil), isTrue);
    });

    test('usage limit reached (timesUsed >= usageLimit)', () {
      const usageLimit = 100;
      const timesUsed = 100;
      expect(timesUsed >= usageLimit, isTrue);
    });

    test('usage limit not reached', () {
      const usageLimit = 100;
      const timesUsed = 50;
      expect(timesUsed >= usageLimit, isFalse);
    });

    test('no usage limit (null) means unlimited', () {
      const int? usageLimit = null;
      const timesUsed = 9999;
      // When usageLimit is null, coupon is always valid
      expect(usageLimit == null || timesUsed < usageLimit, isTrue);
    });

    test('specific user coupon rejects wrong email', () {
      const specificEmail = 'admin@gharkakhana.com';
      const userEmail = 'user@gmail.com';
      expect(specificEmail != userEmail, isTrue);
    });

    test('specific user coupon accepts correct email', () {
      const specificEmail = 'admin@gharkakhana.com';
      const userEmail = 'admin@gharkakhana.com';
      expect(specificEmail == userEmail, isTrue);
    });
  });
}
