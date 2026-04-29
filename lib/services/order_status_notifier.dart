import 'dart:async';
import 'package:flutter/material.dart';
import 'order_service.dart';
import 'fcm_service.dart';

/// Listens to real-time order status changes and fires local push notifications.
/// Singleton — call `start()` once after login, `stop()` on logout.
class OrderStatusNotifier {
  static final OrderStatusNotifier _instance = OrderStatusNotifier._internal();
  factory OrderStatusNotifier() => _instance;
  OrderStatusNotifier._internal();

  final OrderService _orderService = OrderService();
  final FCMService _fcmService = FCMService();
  StreamSubscription? _subscription;

  /// Tracks the last-known status of each order to detect transitions
  final Map<String, String> _lastKnownStatus = {};

  bool _isRunning = false;

  /// Start listening for order status changes.
  /// Safe to call multiple times — will no-op if already running.
  void start() {
    if (_isRunning) return;
    _isRunning = true;

    _subscription = _orderService.getMyOrdersStream().listen(
      (orders) {
        for (final order in orders) {
          final orderId = order['id']?.toString() ?? '';
          final newStatus = (order['status'] ?? 'pending').toString();
          final kitchenName = (order['kitchen_name'] ?? 'Kitchen').toString();

          if (orderId.isEmpty) continue;

          final oldStatus = _lastKnownStatus[orderId];

          // Only fire notification if status actually changed (not on first load)
          if (oldStatus != null && oldStatus != newStatus) {
            _fireStatusNotification(
              orderId: orderId,
              status: newStatus,
              kitchenName: kitchenName,
            );
          }

          _lastKnownStatus[orderId] = newStatus;
        }
      },
      onError: (e) {
        debugPrint('OrderStatusNotifier: Stream error: $e');
      },
    );

    debugPrint('🔔 OrderStatusNotifier: Started listening');
  }

  /// Stop listening. Call on logout.
  void stop() {
    _subscription?.cancel();
    _subscription = null;
    _lastKnownStatus.clear();
    _isRunning = false;
    debugPrint('🔕 OrderStatusNotifier: Stopped');
  }

  /// Fire a contextual notification for each status transition.
  void _fireStatusNotification({
    required String orderId,
    required String status,
    required String kitchenName,
  }) {
    final notif = _statusNotificationData(status, kitchenName);
    if (notif == null) return; // Unknown/unimportant status

    _fcmService.showOrderNotification(
      title: notif['title']!,
      body: notif['body']!,
      payload: 'order_tracking:$orderId',
    );

    debugPrint('🔔 Notification fired: ${notif['title']} for order $orderId');
  }

  /// Returns title+body for each meaningful status, null for statuses
  /// that don't need a notification (e.g. pending).
  Map<String, String>? _statusNotificationData(
      String status, String kitchenName) {
    switch (status) {
      case 'confirmed':
      case 'accepted':
        return {
          'title': 'Order Confirmed! ✅',
          'body': '$kitchenName has accepted your order. Preparation will begin shortly.',
        };
      case 'preparing':
        return {
          'title': 'Being Prepared 🍳',
          'body': '$kitchenName is cooking your food with love! Sit tight.',
        };
      case 'ready':
        return {
          'title': 'Food is Ready! 🎉',
          'body': 'Your order from $kitchenName is packed and waiting for pickup.',
        };
      case 'out_for_delivery':
        return {
          'title': 'On the Way! 🏍️',
          'body': 'Your food from $kitchenName is out for delivery. Track it live!',
        };
      case 'delivered':
      case 'completed':
        return {
          'title': 'Delivered! 🎊',
          'body': 'Enjoy your meal from $kitchenName! Don\'t forget to rate your experience ⭐',
        };
      case 'rejected':
        return {
          'title': 'Order Declined 😔',
          'body': '$kitchenName couldn\'t fulfill your order. A refund will be processed.',
        };
      case 'cancelled':
        return {
          'title': 'Order Cancelled',
          'body': 'Your order from $kitchenName has been cancelled.',
        };
      default:
        return null;
    }
  }
}
