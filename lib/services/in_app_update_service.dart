import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'config_service.dart';

/// Manages in-app update lifecycle: check → download in background → prompt restart.
/// Notifies listeners on state changes so UI can react.
class InAppUpdateService extends ChangeNotifier {
  static final InAppUpdateService _instance = InAppUpdateService._();
  static InAppUpdateService get instance => _instance;
  InAppUpdateService._();

  UpdateState _state = UpdateState.idle;
  UpdateState get state => _state;

  bool _isForced = false;
  bool get isForced => _isForced;

  String _currentVersion = '';
  String get currentVersion => _currentVersion;

  /// Play Store URL fallback
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.gharkakhana.user';

  void _setState(UpdateState s) {
    _state = s;
    notifyListeners();
  }

  /// Check for updates. Called once from MainLayout after the app is running.
  Future<bool> checkForUpdate() async {
    if (!Platform.isAndroid) return false;
    if (_state != UpdateState.idle && _state != UpdateState.dismissed && _state != UpdateState.downloadFailed) {
      // If already downloading or ready, just return true
      if (_state == UpdateState.downloading || _state == UpdateState.readyToInstall || _state == UpdateState.available) {
        return true;
      }
    }

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;
      _currentVersion = packageInfo.version;

      final minVersion = ConfigService().minVersion;
      final latestVersion = ConfigService().latestVersion;

      debugPrint('📦 App: ${packageInfo.version}+$currentBuild | Remote: min=$minVersion, latest=$latestVersion');

      // Critical forced update
      if (currentBuild < minVersion && minVersion > 0) {
        _isForced = true;
        _setState(UpdateState.available);
        return true;
      }

      // Check Play Store for flexible update
      try {
        final info = await InAppUpdate.checkForUpdate();
        if (info.updateAvailability == UpdateAvailability.updateAvailable) {
          if (info.flexibleUpdateAllowed) {
            _isForced = false;
            _setState(UpdateState.available);
            return true;
          } else if (info.immediateUpdateAllowed) {
            // If only immediate is allowed, treat as forced
            _isForced = true;
            _setState(UpdateState.available);
            return true;
          }
        }
      } catch (e) {
        debugPrint('Play Store check failed: $e');
      }

      // Fallback: our DB says there's a newer version
      if (currentBuild < latestVersion && latestVersion > 0) {
        _isForced = false;
        _setState(UpdateState.available);
        return true;
      }

      // No update needed
      _setState(UpdateState.idle);
      return false;
    } catch (e) {
      debugPrint('Update check error: $e');
      _setState(UpdateState.idle);
      return false;
    }
  }

  /// Start downloading the update in background
  Future<void> startBackgroundDownload() async {
    _setState(UpdateState.downloading);

    try {
      if (_isForced) {
         await InAppUpdate.performImmediateUpdate();
         _setState(UpdateState.idle);
         return;
      }
      
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
         await InAppUpdate.startFlexibleUpdate();
         _setState(UpdateState.readyToInstall);
      } else {
         // Fallback to URL if Play Store API isn't seeing the update but our DB did
         _setState(UpdateState.downloadFailed);
      }
    } catch (e) {
      debugPrint('Flexible update failed: $e');
      // If flexible fails, it might be an immediate-only update
      _setState(UpdateState.downloadFailed);
    }
  }

  /// Install the downloaded update (triggers app restart)
  Future<void> installUpdate() async {
    _setState(UpdateState.installing);
    try {
      await InAppUpdate.completeFlexibleUpdate();
    } catch (e) {
      debugPrint('Complete update failed: $e');
      _setState(UpdateState.downloadFailed);
    }
  }

  /// Dismiss the update banner (only for non-forced)
  void dismiss() {
    if (!_isForced) {
      _setState(UpdateState.dismissed);
    }
  }

  /// Reset state (e.g., after failed download, user wants to retry)
  void retry() {
    _setState(UpdateState.available);
  }
}

enum UpdateState {
  idle,          // No update / not checked yet
  available,     // Update found, show "Download" banner
  downloading,   // Downloading in background
  readyToInstall,// Downloaded, show "Restart" modal
  installing,    // Installing...
  downloadFailed,// Download failed, show retry
  dismissed,     // User dismissed (non-forced only)
}
