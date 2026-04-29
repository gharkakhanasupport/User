import 'package:flutter_test/flutter_test.dart';

/// Extracted status → notification data mapping from OrderStatusNotifier.
/// The original class depends on OrderService/FCMService which require
/// Supabase, so we test the core logic in isolation.
Map<String, String>? statusNotificationData(String status, String kitchenName) {
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

void main() {
  group('Status Notification Mapping', () {
    const kitchen = 'Maa Ki Rasoi';

    test('confirmed returns correct notification', () {
      final notif = statusNotificationData('confirmed', kitchen);
      expect(notif, isNotNull);
      expect(notif!['title'], 'Order Confirmed! ✅');
      expect(notif['body'], contains(kitchen));
    });

    test('accepted maps same as confirmed', () {
      final confirmed = statusNotificationData('confirmed', kitchen);
      final accepted = statusNotificationData('accepted', kitchen);
      expect(confirmed!['title'], accepted!['title']);
    });

    test('preparing returns cooking notification', () {
      final notif = statusNotificationData('preparing', kitchen);
      expect(notif!['title'], 'Being Prepared 🍳');
      expect(notif['body'], contains('cooking'));
    });

    test('ready returns pickup notification', () {
      final notif = statusNotificationData('ready', kitchen);
      expect(notif!['title'], 'Food is Ready! 🎉');
      expect(notif['body'], contains('packed'));
    });

    test('out_for_delivery returns delivery notification', () {
      final notif = statusNotificationData('out_for_delivery', kitchen);
      expect(notif!['title'], 'On the Way! 🏍️');
      expect(notif['body'], contains('delivery'));
    });

    test('delivered returns completion notification', () {
      final notif = statusNotificationData('delivered', kitchen);
      expect(notif!['title'], 'Delivered! 🎊');
      expect(notif['body'], contains('rate'));
    });

    test('completed maps same as delivered', () {
      final delivered = statusNotificationData('delivered', kitchen);
      final completed = statusNotificationData('completed', kitchen);
      expect(delivered!['title'], completed!['title']);
    });

    test('rejected returns decline notification', () {
      final notif = statusNotificationData('rejected', kitchen);
      expect(notif!['title'], 'Order Declined 😔');
      expect(notif['body'], contains('refund'));
    });

    test('cancelled returns cancellation notification', () {
      final notif = statusNotificationData('cancelled', kitchen);
      expect(notif!['title'], 'Order Cancelled');
    });

    test('pending returns null (no notification)', () {
      expect(statusNotificationData('pending', kitchen), isNull);
    });

    test('unknown status returns null', () {
      expect(statusNotificationData('unknown_status', kitchen), isNull);
    });

    test('empty status returns null', () {
      expect(statusNotificationData('', kitchen), isNull);
    });

    test('all statuses include kitchen name in body', () {
      final statuses = [
        'confirmed', 'preparing', 'ready',
        'out_for_delivery', 'delivered', 'rejected', 'cancelled',
      ];
      for (final status in statuses) {
        final notif = statusNotificationData(status, kitchen);
        expect(notif!['body'], contains(kitchen),
            reason: 'Status "$status" should include kitchen name');
      }
    });

    test('notification data keys are always title and body', () {
      final statuses = [
        'confirmed', 'preparing', 'ready',
        'out_for_delivery', 'delivered', 'rejected', 'cancelled',
      ];
      for (final status in statuses) {
        final notif = statusNotificationData(status, kitchen);
        expect(notif!.keys, containsAll(['title', 'body']),
            reason: 'Status "$status" must have title and body');
      }
    });

    test('handles special characters in kitchen name', () {
      const specialKitchen = "Mom's Kitchen & Café (Best)";
      final notif = statusNotificationData('confirmed', specialKitchen);
      expect(notif!['body'], contains(specialKitchen));
    });

    test('handles empty kitchen name', () {
      final notif = statusNotificationData('confirmed', '');
      expect(notif, isNotNull);
      expect(notif!['body'], contains('has accepted your order'));
    });
  });

  group('Order Status Flow Validation', () {
    test('complete happy-path flow produces correct sequence', () {
      const kitchen = 'Test Kitchen';
      final flow = ['confirmed', 'preparing', 'ready', 'out_for_delivery', 'delivered'];
      final titles = flow.map((s) => statusNotificationData(s, kitchen)!['title']!).toList();

      expect(titles, [
        'Order Confirmed! ✅',
        'Being Prepared 🍳',
        'Food is Ready! 🎉',
        'On the Way! 🏍️',
        'Delivered! 🎊',
      ]);
    });

    test('rejection flow stops at rejected', () {
      const kitchen = 'Test Kitchen';
      final flow = ['confirmed', 'rejected'];
      final titles = flow.map((s) => statusNotificationData(s, kitchen)!['title']!).toList();

      expect(titles, [
        'Order Confirmed! ✅',
        'Order Declined 😔',
      ]);
    });
  });
}
