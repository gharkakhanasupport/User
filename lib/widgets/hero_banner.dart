import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_colors.dart';

class OfferData {
  final String id;
  final String tag;
  final String title;
  final String subtitle;
  final String imageUrl;
  final String? clickUrl;
  final Color badgeColor;
  final Color backgroundColor;
  final String templateStyle;

  OfferData({
    required this.id,
    required this.tag,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    this.clickUrl,
    this.badgeColor = AppColors.secondaryGold,
    this.backgroundColor = Colors.white,
    this.templateStyle = 'classic',
  });

  factory OfferData.fromJson(Map<String, dynamic> json) {
    final badgeColorHex = json['badge_color']?.toString() ?? '#FF9800';
    final bgColorHex = json['background_color']?.toString() ?? '#FFFFFF';

    return OfferData(
      id: json['id'] ?? '',
      tag: json['tag'] ?? 'OFFER',
      title: json['title'] ?? '',
      subtitle: json['subtitle'] ?? '',
      imageUrl: json['image_url'] ?? '',
      clickUrl: json['click_url'],
      badgeColor: _hexToColor(badgeColorHex),
      backgroundColor: _hexToColor(bgColorHex),
      templateStyle: json['template_style'] ?? 'classic',
    );
  }

  static Color _hexToColor(String? hex) {
    if (hex == null || hex.isEmpty) {
      return Colors.white;
    }
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) {
      try {
        return Color(int.parse('FF$hex', radix: 16));
      } catch (e) {
        debugPrint('🎨 Error parsing color: $hex - $e');
        return Colors.white;
      }
    }
    return Colors.white;
  }

  /// Check if background is dark (for text contrast)
  bool get isDarkBackground {
    final luminance = backgroundColor.computeLuminance();
    return luminance < 0.5;
  }
}

class HeroBanner extends StatefulWidget {
  final bool isVeg;

  const HeroBanner({super.key, required this.isVeg});

  @override
  State<HeroBanner> createState() => HeroBannerState();
}

class HeroBannerState extends State<HeroBanner> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;
  RealtimeChannel? _realtimeChannel;

  List<OfferData> _offers = [];
  bool _isLoading = true;

  // Fallback offers if database fails
  final List<OfferData> _fallbackOffers = [
    OfferData(
      id: '1',
      tag: 'LIMITED OFFER',
      title: 'Flat 20% off\non Lunch Thali',
      subtitle: 'Mom\'s Special • Healthy & Fresh',
      imageUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuDbZxs_Cg6fVR4wxAmMbBFpss3m3g8kWNEQaDUP8Oq8cPti0k8cqvcbS9FRAYYz8_pC-41FyJXzJJRGFSMEXBVsapyhZhErDCbvDEFaczJhtNclACePGGptJPdqc7hMcWJAzdJdMlCQrlKDNYGEmQHnAVF02jfhoLDX0w-6QKcNPgwDyXqcxEhXRnx5_I-ITT0l4LIiBodUdzs9gZD6MX9-D4-p-qmO7BJosXEXalpI0BwGmnSJn9PKedWsMq3Y6tvgNfOS7sfJB9-x',
    ),
  ];

  @override
  void initState() {
    super.initState();
    loadBanners();
    _setupRealtimeSubscription();
  }

  /// Setup Supabase Realtime to listen for banner changes
  void _setupRealtimeSubscription() {
    _realtimeChannel = Supabase.instance.client
        .channel('carousel_cards_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'carousel_cards',
          callback: (payload) {
            debugPrint('🔄 Realtime update received: ${payload.eventType}');
            // Reload banners when any change occurs
            loadBanners();
          },
        )
        .subscribe();
    debugPrint('📡 Realtime subscription setup for carousel_cards');
  }

  /// Load banners from database - public for external refresh
  Future<void> loadBanners() async {
    debugPrint('🎠 Loading banners from database...');
    try {
      final response = await Supabase.instance.client
          .from('carousel_cards')
          .select()
          .eq('is_active', true)
          .order('order_position', ascending: true);

      debugPrint('🎠 Banner response: $response');
      debugPrint('🎠 Banner count: ${response.length}');

      if (response.isNotEmpty) {
        setState(() {
          _offers = (response as List)
              .map((json) => OfferData.fromJson(json))
              .toList();
          _isLoading = false;
        });
        debugPrint('🎠 Loaded ${_offers.length} banners from database');
      } else {
        debugPrint('🎠 No banners in database, using fallback');
        setState(() {
          _offers = _fallbackOffers;
          _isLoading = false;
        });
      }

      _startAutoScroll();
    } catch (e) {
      debugPrint('🎠 Error loading banners: $e');
      setState(() {
        _offers = _fallbackOffers;
        _isLoading = false;
      });
      _startAutoScroll();
    }
  }

  void _startAutoScroll() {
    _timer?.cancel();
    if (_offers.isEmpty) return;

    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_currentPage < _offers.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }

      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  Future<void> _handleBannerTap(OfferData offer) async {
    final url = offer.clickUrl?.trim();
    if (url == null || url.isEmpty) {
      debugPrint('🚫 Banner tap: No click URL defined');
      return;
    }

    debugPrint('🔗 Attempting to launch URL: $url');

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback: try launching anyway (sometimes canLaunch returns false on Android 11+ but it works)
        debugPrint(
          '⚠️ canLaunchUrl returned false, trying to launch anyway...',
        );
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('❌ Error launching URL: $e');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _realtimeChannel?.unsubscribe();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 180,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_offers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemCount: _offers.length,
            itemBuilder: (context, index) {
              final offer = _offers[index];
              // Build based on template style
              switch (offer.templateStyle) {
                case 'full_image':
                  return _buildFullImageTemplate(offer);
                case 'split_view':
                  return _buildSplitViewTemplate(offer);
                case 'center_focus':
                  return _buildCenterFocusTemplate(offer);
                case 'stacked':
                  return _buildStackedTemplate(offer);
                case 'classic':
                default:
                  return _buildClassicTemplate(offer);
              }
            },
          ),
        ),
        const SizedBox(height: 12),
        // Pagination Dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_offers.length, (index) {
            bool isActive = _currentPage == index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: isActive ? 24 : 8,
              height: 6,
              decoration: BoxDecoration(
                color: isActive
                    ? (widget.isVeg ? AppColors.primary : AppColors.primaryRed)
                    : Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            );
          }),
        ),
      ],
    );
  }

  // ============ TEMPLATE 1: CLASSIC (Current Design) ============
  Widget _buildClassicTemplate(OfferData offer) {
    return GestureDetector(
      onTap: () => _handleBannerTap(offer),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          gradient: widget.isVeg
              ? AppColors.heroGradient
              : AppColors.heroGradientRed,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color:
                  (widget.isVeg
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFFE53935))
                      .withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Content
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: offer.badgeColor,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      offer.tag,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    offer.title,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    offer.subtitle,
                    style: GoogleFonts.poppins(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            // Image
            Positioned(
              right: -20,
              bottom: -20,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 4,
                  ),
                ),
                child: ClipOval(
                  child: Image.network(
                    offer.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: Colors.grey.shade300,
                      child: const Icon(
                        Icons.image,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Badge
            Positioned(
              top: 20,
              right: 80,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: offer.badgeColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'LIMITED',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 7,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'OFFER',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============ TEMPLATE 2: FULL IMAGE ============
  Widget _buildFullImageTemplate(OfferData offer) {
    return GestureDetector(
      onTap: () => _handleBannerTap(offer),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // Full background image
              Positioned.fill(
                child: Image.network(
                  offer.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: widget.isVeg
                        ? AppColors.primary
                        : AppColors.primaryRed,
                  ),
                ),
              ),
              // Gradient overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                ),
              ),
              // Content at bottom
              Positioned(
                left: 20,
                right: 20,
                bottom: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: offer.badgeColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        offer.tag,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      offer.title,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      offer.subtitle,
                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============ TEMPLATE 3: SPLIT VIEW ============
  Widget _buildSplitViewTemplate(OfferData offer) {
    return GestureDetector(
      onTap: () => _handleBannerTap(offer),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: offer.backgroundColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            // Left side - Text
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: offer.badgeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        offer.tag,
                        style: GoogleFonts.poppins(
                          color: offer.isDarkBackground
                              ? Colors.white
                              : offer.badgeColor,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      offer.title,
                      style: GoogleFonts.poppins(
                        color: offer.isDarkBackground
                            ? Colors.white
                            : Colors.black87,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      offer.subtitle,
                      style: GoogleFonts.poppins(
                        color: offer.isDarkBackground
                            ? Colors.white70
                            : Colors.grey.shade600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Divider
            Container(
              width: 1,
              height: 120,
              color: offer.isDarkBackground
                  ? Colors.white24
                  : Colors.grey.shade200,
            ),
            // Right side - Image
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
              child: SizedBox(
                width: 140,
                height: double.infinity,
                child: Image.network(
                  offer.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: offer.badgeColor.withValues(alpha: 0.2),
                    child: Icon(Icons.image, color: offer.badgeColor),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============ TEMPLATE 4: CENTER FOCUS ============
  Widget _buildCenterFocusTemplate(OfferData offer) {
    return GestureDetector(
      onTap: () => _handleBannerTap(offer),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // Background image
              Positioned.fill(
                child: Image.network(
                  offer.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: widget.isVeg
                        ? AppColors.primary
                        : AppColors.primaryRed,
                  ),
                ),
              ),
              // Dark overlay
              Positioned.fill(
                child: Container(color: Colors.black.withValues(alpha: 0.5)),
              ),
              // Centered content
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: offer.badgeColor,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          offer.tag,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        offer.title,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          height: 1.1,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        offer.subtitle,
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============ TEMPLATE 5: STACKED ============
  Widget _buildStackedTemplate(OfferData offer) {
    return GestureDetector(
      onTap: () => _handleBannerTap(offer),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: offer.backgroundColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // Top - Image (60%)
            Expanded(
              flex: 6,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Image.network(
                        offer.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            Container(color: offer.badgeColor.withValues(alpha: 0.2)),
                      ),
                    ),
                    // Tag badge
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: offer.badgeColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          offer.tag,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Bottom - Text (40%)
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            offer.title,
                            style: GoogleFonts.poppins(
                              color: offer.isDarkBackground
                                  ? Colors.white
                                  : Colors.black87,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              height: 1.1,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            offer.subtitle,
                            style: GoogleFonts.poppins(
                              color: offer.isDarkBackground
                                  ? Colors.white70
                                  : Colors.grey.shade600,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: widget.isVeg
                            ? AppColors.primary
                            : AppColors.primaryRed,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_forward,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
