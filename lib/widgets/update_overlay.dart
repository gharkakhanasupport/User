import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/in_app_update_service.dart';
import '../theme/app_colors.dart';

/// Crunchyroll-style update banner and restart modal.
/// Listens to [InAppUpdateService] and shows contextual UI:
///   - Slide-down banner: "New update available" → tap to download
///   - During download: progress indicator in banner
///   - Download complete: full-screen modal asking to restart
class UpdateOverlay extends StatefulWidget {
  final Widget child;
  const UpdateOverlay({super.key, required this.child});

  @override
  State<UpdateOverlay> createState() => _UpdateOverlayState();
}

class _UpdateOverlayState extends State<UpdateOverlay> with SingleTickerProviderStateMixin {
  final _service = InAppUpdateService.instance;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    _service.addListener(_onUpdateStateChanged);
  }

  @override
  void dispose() {
    _service.removeListener(_onUpdateStateChanged);
    _slideController.dispose();
    super.dispose();
  }

  void _onUpdateStateChanged() {
    if (!mounted) return;
    final state = _service.state;

    if (state == UpdateState.available ||
        state == UpdateState.downloading ||
        state == UpdateState.downloadFailed) {
      _slideController.forward();
    } else if (state == UpdateState.dismissed || state == UpdateState.idle) {
      _slideController.reverse();
    } else if (state == UpdateState.readyToInstall) {
      _slideController.reverse();
      // Show restart modal after banner slides away
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _showRestartModal();
      });
    }
    setState(() {});
  }

  void _showRestartModal() {
    showGeneralDialog(
      context: context,
      barrierDismissible: !_service.isForced,
      barrierLabel: 'Update Ready',
      barrierColor: Colors.black.withValues(alpha: 0.6),
      transitionDuration: const Duration(milliseconds: 400),
      transitionBuilder: (context, anim, secondaryAnim, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
          child: child,
        );
      },
      pageBuilder: (context, anim, secondaryAnim) {
        return Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  blurRadius: 40,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated check icon
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primary.withValues(alpha: 0.1), AppColors.primary.withValues(alpha: 0.05)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.system_update_alt_rounded, size: 48, color: AppColors.primary),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Update Ready!',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'The latest version has been downloaded.\nRestart the app to enjoy new features and improvements.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: const Color(0xFF64748B),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  // Restart button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _service.installUpdate();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.restart_alt_rounded, size: 20),
                          const SizedBox(width: 8),
                          Text('Restart Now', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                  if (!_service.isForced) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('Later', style: GoogleFonts.plusJakartaSans(fontSize: 14, color: const Color(0xFF94A3B8))),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        // Slide-down update banner
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SlideTransition(
            position: _slideAnimation,
            child: _buildBanner(),
          ),
        ),
      ],
    );
  }

  Widget _buildBanner() {
    final state = _service.state;
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      padding: EdgeInsets.fromLTRB(20, topPadding + 12, 12, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: state == UpdateState.downloadFailed
              ? [const Color(0xFFDC2626), const Color(0xFFB91C1C)]
              : [AppColors.primary, const Color(0xFF2E7D32)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              state == UpdateState.downloading
                  ? Icons.downloading_rounded
                  : state == UpdateState.downloadFailed
                      ? Icons.error_outline_rounded
                      : Icons.system_update_rounded,
              color: Colors.white, size: 22,
            ),
          ),
          const SizedBox(width: 12),

          // Text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _bannerTitle(state),
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _bannerSubtitle(state),
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                  ),
                ),
                // Download progress bar
                if (state == UpdateState.downloading) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      minHeight: 3,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Action button
          _buildBannerAction(state),
        ],
      ),
    );
  }

  String _bannerTitle(UpdateState state) {
    switch (state) {
      case UpdateState.available:
        return _service.isForced ? 'Critical Update Required' : 'New Update Available';
      case UpdateState.downloading:
        return 'Downloading Update...';
      case UpdateState.downloadFailed:
        return 'Download Failed';
      default:
        return 'Update';
    }
  }

  String _bannerSubtitle(UpdateState state) {
    switch (state) {
      case UpdateState.available:
        return _service.isForced
            ? 'Please update to continue using the app'
            : 'Tap to download in the background';
      case UpdateState.downloading:
        return 'You can keep browsing while we update';
      case UpdateState.downloadFailed:
        return 'Tap retry or update from Play Store';
      default:
        return '';
    }
  }

  Widget _buildBannerAction(UpdateState state) {
    if (state == UpdateState.downloading) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: SizedBox(
          width: 24, height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    }

    if (state == UpdateState.downloadFailed) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        _actionChip('Retry', Icons.refresh_rounded, () => _service.retry()),
        const SizedBox(width: 4),
        _actionChip('Store', Icons.open_in_new_rounded, () => _service.launchPlayStore()),
      ]);
    }

    // Available state
    return Row(mainAxisSize: MainAxisSize.min, children: [
      _actionChip(
        _service.isForced ? 'Update' : 'Download',
        Icons.download_rounded,
        () => _service.startBackgroundDownload(),
      ),
      if (!_service.isForced) ...[
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.close, color: Colors.white, size: 20),
          onPressed: () => _service.dismiss(),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    ]);
  }

  Widget _actionChip(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 4),
          Text(label, style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}
