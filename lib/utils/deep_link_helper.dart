import 'package:share_plus/share_plus.dart';

/// Utility for generating and handling deep links for GKK app.
/// 
/// Deep link format: https://gharkakhana.app/{type}/{id}
/// Custom scheme: com.gharkakhana.user://{type}/{id}
/// 
/// When users tap the link:
/// - If app is installed: opens directly to the kitchen/item
/// - If app is NOT installed: falls back to Play Store listing
class DeepLinkHelper {
  // Base URL for web-based deep links
  static const String _baseUrl = 'https://gharkakhana.app';
  
  // App Play Store URL (fallback)
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.gharkakhana.user';

  // Custom scheme for direct app linking
  static const String _scheme = 'com.gharkakhana.user';

  /// Generate a shareable URL for a kitchen.
  static String kitchenUrl(String cookId) {
    return '$_baseUrl/kitchen/$cookId';
  }

  /// Generate a shareable URL for a menu item.
  static String itemUrl(String itemId, String cookId) {
    return '$_baseUrl/item/$itemId?kitchen=$cookId';
  }

  /// Generate a custom-scheme deep link for a kitchen (app-only).
  static String kitchenDeepLink(String cookId) {
    return '$_scheme://kitchen/$cookId';
  }

  /// Generate a custom-scheme deep link for a menu item (app-only).
  static String itemDeepLink(String itemId, String cookId) {
    return '$_scheme://item/$itemId?kitchen=$cookId';
  }

  /// Share a kitchen with a rich message including the deep link.
  static Future<void> shareKitchen({
    required String kitchenName,
    required String cookId,
    String? description,
  }) async {
    final url = kitchenUrl(cookId);
    final cleanName = kitchenName.replaceAll('_', ' ');
    final desc = description?.replaceAll('_', ' ') ?? 'Homemade food delivered to your door';
    
    final message = '🍽️ Check out $cleanName on Ghar Ka Khana!\n\n'
        '$desc\n\n'
        'Download the app: $playStoreUrl\n\n'
        '👉 $url';

    await SharePlus.instance.share(ShareParams(text: message));
  }

  /// Share a menu item with a rich message including the deep link.
  static Future<void> shareItem({
    required String itemName,
    required String itemId,
    required String cookId,
    String? kitchenName,
    double? price,
  }) async {
    final url = itemUrl(itemId, cookId);
    final cleanName = itemName.replaceAll('_', ' ');
    final priceStr = price != null ? ' • ₹${price.toStringAsFixed(0)}' : '';
    
    String message = '🍛 $cleanName$priceStr\n';
    if (kitchenName != null && kitchenName.isNotEmpty) {
      final cleanKitchen = kitchenName.replaceAll('_', ' ');
      message += 'from $cleanKitchen on Ghar Ka Khana!\n\n';
    } else {
      message += 'on Ghar Ka Khana!\n\n';
    }
    
    message += 'Download the app: $playStoreUrl\n\n'
        '👉 $url';

    await SharePlus.instance.share(ShareParams(text: message));
  }

  /// Parse a deep link URI and return the route info.
  /// Returns null if the URI is not a valid GKK deep link.
  static DeepLinkRoute? parseUri(Uri uri) {
    // Handle custom scheme: com.gharkakhana.user://kitchen/{id}
    // Handle web URL: https://gharkakhana.app/kitchen/{id}
    final segments = uri.pathSegments;
    
    if (segments.isEmpty) return null;

    if (segments[0] == 'kitchen' && segments.length >= 2) {
      return DeepLinkRoute(
        type: DeepLinkType.kitchen,
        id: segments[1],
      );
    }

    if (segments[0] == 'item' && segments.length >= 2) {
      return DeepLinkRoute(
        type: DeepLinkType.item,
        id: segments[1],
        extraParams: {'kitchen': uri.queryParameters['kitchen'] ?? ''},
      );
    }

    return null;
  }
}

enum DeepLinkType { kitchen, item }

class DeepLinkRoute {
  final DeepLinkType type;
  final String id;
  final Map<String, String>? extraParams;

  DeepLinkRoute({
    required this.type,
    required this.id,
    this.extraParams,
  });
}
