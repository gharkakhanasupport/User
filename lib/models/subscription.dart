/// Model representing a User's subscription to a Kitchen.
/// Maps to the `subscriptions` table in User DB.
class UserSubscription {
  final String id;
  final String userId;
  final String kitchenId;
  final String planName;
  final String planType; // 'weekly' | 'monthly'
  final double monthlyPrice;
  final int mealCount;
  final String status; // 'active' | 'expired' | 'cancelled' | 'paused'
  final DateTime startDate;
  final DateTime endDate;
  final DateTime? nextBillingDate;
  final String? lastPaymentId;
  final bool autoRenewal;
  final String? mealPreferences;
  final String? specialInstructions;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? cancelledAt;

  // Joined fields (not in DB, fetched separately)
  final String? kitchenName;
  final String? kitchenImageUrl;
  final String? kitchenRating;

  UserSubscription({
    required this.id,
    required this.userId,
    required this.kitchenId,
    required this.planName,
    required this.planType,
    required this.monthlyPrice,
    required this.mealCount,
    required this.status,
    required this.startDate,
    required this.endDate,
    this.nextBillingDate,
    this.lastPaymentId,
    this.autoRenewal = true,
    this.mealPreferences,
    this.specialInstructions,
    required this.createdAt,
    required this.updatedAt,
    this.cancelledAt,
    this.kitchenName,
    this.kitchenImageUrl,
    this.kitchenRating,
  });

  factory UserSubscription.fromMap(Map<String, dynamic> map) {
    return UserSubscription(
      id: (map['id'] ?? '').toString(),
      userId: (map['user_id'] ?? '').toString(),
      kitchenId: (map['kitchen_id'] ?? '').toString(),
      planName: map['plan_name'] ?? '',
      planType: map['plan_type'] ?? 'monthly',
      monthlyPrice: double.tryParse(map['monthly_price']?.toString() ?? '0') ?? 0,
      mealCount: int.tryParse(map['meal_count']?.toString() ?? '0') ?? 0,
      status: map['status'] ?? 'active',
      startDate: DateTime.parse(map['start_date'] ?? DateTime.now().toIso8601String()),
      endDate: DateTime.parse(map['end_date'] ?? DateTime.now().toIso8601String()),
      nextBillingDate: map['next_billing_date'] != null
          ? DateTime.parse(map['next_billing_date'])
          : null,
      lastPaymentId: map['last_payment_id'],
      autoRenewal: map['auto_renewal'] ?? true,
      mealPreferences: map['meal_preferences'],
      specialInstructions: map['special_instructions'],
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(map['updated_at'] ?? DateTime.now().toIso8601String()),
      cancelledAt: map['cancelled_at'] != null
          ? DateTime.parse(map['cancelled_at'])
          : null,
    );
  }

  /// Days remaining until the subscription expires.
  int get daysRemaining {
    final now = DateTime.now();
    return endDate.difference(now).inDays.clamp(0, 9999);
  }

  /// Whether the subscription is still active and not expired.
  bool get isActive => status == 'active' && endDate.isAfter(DateTime.now());

  /// Whether the subscription has expired.
  bool get isExpired => status == 'expired' || endDate.isBefore(DateTime.now());

  /// Whether the subscription has been cancelled.
  bool get isCancelled => status == 'cancelled';

  /// Display-friendly plan label (e.g., "Weekly Plan" or "Monthly Plan").
  String get planLabel {
    if (planType == 'weekly') return 'Weekly Plan';
    return 'Monthly Plan';
  }

  /// Display price string.
  String get priceDisplay => '₹${monthlyPrice.toStringAsFixed(0)}';

  /// Formatted start date.
  String get startDateDisplay {
    return '${_monthName(startDate.month)} ${startDate.day}, ${startDate.year}';
  }

  /// Formatted end date.
  String get endDateDisplay {
    return '${_monthName(endDate.month)} ${endDate.day}, ${endDate.year}';
  }

  /// Formatted next billing date.
  String get nextBillingDisplay {
    if (nextBillingDate == null) return 'N/A';
    return '${_monthName(nextBillingDate!.month)} ${nextBillingDate!.day}, ${nextBillingDate!.year}';
  }

  static String _monthName(int month) {
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month];
  }
}
