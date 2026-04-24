class OrderStatus {
  static const String pending = 'pending';
  static const String confirmed = 'confirmed';
  static const String preparing = 'preparing';
  static const String ready = 'ready';
  static const String outForDelivery = 'out_for_delivery';
  static const String delivered = 'delivered';
  static const String cancelled = 'cancelled';

  /// Helper to get a user-friendly label for display if localization is missing
  static String getLabel(String status) {
    switch (status) {
      case pending: return 'Pending';
      case confirmed: return 'Confirmed';
      case preparing: return 'Preparing';
      case ready: return 'Ready for Pickup';
      case outForDelivery: return 'Out for Delivery';
      case delivered: return 'Delivered';
      case cancelled: return 'Cancelled';
      default: return 'Processing';
    }
  }
}
