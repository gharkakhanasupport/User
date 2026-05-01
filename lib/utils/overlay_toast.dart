import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../screens/main_layout.dart';

class OverlayToast {
  static OverlayEntry? _currentEntry;

  static void show(
    BuildContext context, 
    String message, {
    IconData? icon, 
    Color? color,
    String? imageUrl,
    int? quantity,
    bool persistent = false,
  }) {
    final overlay = Overlay.of(context);
    
    // Remove previous entry if exists
    if (_currentEntry != null && _currentEntry!.mounted) {
      _currentEntry!.remove();
      _currentEntry = null;
    }

    _currentEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          bottom: 100, // Positioned above the bottom nav/snackbar area
          left: 16,
          right: 16,
          child: Material(
            color: Colors.transparent,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: Opacity(
                    opacity: value,
                    child: child,
                  ),
                );
              },
              child: GestureDetector(
                onTap: () {
                  if (_currentEntry != null && _currentEntry!.mounted) {
                    _currentEntry!.remove();
                    _currentEntry = null;
                  }
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const MainLayout(initialIndex: 1)),
                    (route) => false,
                  );
                },
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A), // Blinkit solid green
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 8),
                      // Image section
                      if (imageUrl != null && imageUrl.isNotEmpty)
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: Colors.white, width: 1),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Icon(Icons.fastfood, color: Color(0xFF16A34A), size: 20),
                            ),
                          ),
                        )
                      else if (icon != null)
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, color: Colors.white, size: 24),
                        ),
                      
                      const SizedBox(width: 12),
                      
                      // Text section
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'View cart',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (quantity != null && quantity > 0)
                              Text(
                                '$quantity item${quantity > 1 ? 's' : ''}',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                            else
                              Text(
                                message,
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      
                      // Arrow section
                      const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 28),
                      const SizedBox(width: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(_currentEntry!);

    if (!persistent) {
      Future.delayed(const Duration(seconds: 4), () {
        if (_currentEntry != null && _currentEntry!.mounted) {
          _currentEntry!.remove();
          _currentEntry = null;
        }
      });
    }
  }

  static void hide() {
    if (_currentEntry != null && _currentEntry!.mounted) {
      _currentEntry!.remove();
      _currentEntry = null;
    }
  }
}
