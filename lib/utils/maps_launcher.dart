import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Shared launcher for phone calls + Google Maps navigation.
/// Used by User + Kitchen apps (Delivery has its own NavigationService).
class MapsLauncher {
  /// Open phone dialer with pre-filled number.
  static Future<bool> call(String? phone) async {
    if (phone == null || phone.trim().isEmpty) return false;
    final clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri(scheme: 'tel', path: clean);
    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri);
      }
    } catch (e) {
      debugPrint('[MapsLauncher] call error: $e');
    }
    return false;
  }

  /// Navigate to lat/lng in Google Maps with driving directions.
  static Future<bool> navigateTo({
    required double lat,
    required double lng,
    String? label,
  }) async {
    if (lat == 0.0 && lng == 0.0) return false;

    // Try Google Maps native intent first
    final geoUri = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
    try {
      if (await canLaunchUrl(geoUri)) {
        return await launchUrl(geoUri);
      }
    } catch (_) {}

    // Fallback: browser
    final webUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=$lat,$lng&travelmode=driving',
    );
    try {
      if (await canLaunchUrl(webUri)) {
        return await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('[MapsLauncher] nav error: $e');
    }
    return false;
  }

  /// Show location pin without directions.
  static Future<bool> showPin({
    required double lat,
    required double lng,
    String? label,
  }) async {
    if (lat == 0.0 && lng == 0.0) return false;
    final q = label != null ? '($label)' : '';
    final uri = Uri.parse('geo:$lat,$lng?q=$lat,$lng$q');
    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri);
      }
      final web = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
      );
      return await launchUrl(web, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('[MapsLauncher] pin error: $e');
      return false;
    }
  }
}
