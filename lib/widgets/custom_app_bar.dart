import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_colors.dart';
import '../screens/profile_screen.dart';

import '../screens/home_screen.dart';

class CustomAppBar extends StatefulWidget {
  final DietFilter dietFilter;
  final Function(DietFilter) onFilterChanged;

  const CustomAppBar({
    super.key,
    required this.dietFilter,
    required this.onFilterChanged,
  });

  @override
  State<CustomAppBar> createState() => _CustomAppBarState();
}

class _CustomAppBarState extends State<CustomAppBar> {
  String? _profileImageUrl;
  
  @override
  void initState() {
    super.initState();
    _loadProfileImage();
    
    // Listen for auth changes to update profile image
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (mounted) _loadProfileImage();
    });
  }

  void _loadProfileImage() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null && mounted) {
      setState(() {
        _profileImageUrl = user.userMetadata?['avatar_url'];
      });
    }
  }

  Alignment _getAlignment() {
    switch (widget.dietFilter) {
      case DietFilter.veg: return Alignment.centerLeft;
      case DietFilter.all: return Alignment.center;
      case DietFilter.nonVeg: return Alignment.centerRight;
    }
  }

  Color _getToggleColor() {
    switch (widget.dietFilter) {
      case DietFilter.veg: return Colors.green;
      case DietFilter.all: return Colors.grey.shade400;
      case DietFilter.nonVeg: return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo and Title (Wrapped in Expanded to prevent pushing toggle off screen)
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.cardLight,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.soup_kitchen, 
                    color: widget.dietFilter == DietFilter.nonVeg ? AppColors.primaryRed : AppColors.primary, 
                    size: 24
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Ghar Ka Khana',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textMain,
                          height: 1.2,
                        ),
                      ),
                      Text(
                        'Delivering love',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: AppColors.textSub,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 8),

          // 3-Way Toggle and Profile
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 3-WAY DIET TOGGLE
              GestureDetector(
                onTapDown: (details) {
                  final double width = 80.0;
                  final double x = details.localPosition.dx;
                  if (x < width / 3) {
                    widget.onFilterChanged(DietFilter.veg);
                  } else if (x < 2 * width / 3) {
                    widget.onFilterChanged(DietFilter.all);
                  } else {
                    widget.onFilterChanged(DietFilter.nonVeg);
                  }
                },
                child: Container(
                  width: 80,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Stack(
                    children: [
                      // Labels
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('V', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade400)),
                            Text('A', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade400)),
                            Text('N', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade400)),
                          ],
                        ),
                      ),
                      // Animated Slider
                      AnimatedAlign(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutBack,
                        alignment: _getAlignment(),
                        child: Container(
                          width: 30,
                          height: 30,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: _getToggleColor().withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                            border: Border.all(color: _getToggleColor(), width: 2),
                          ),
                          child: Center(
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _getToggleColor(),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Profile Icon
              GestureDetector(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProfileScreen()),
                  );
                  _loadProfileImage();
                },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                      ),
                    ],
                    color: Colors.grey.shade200,
                  ),
                  child: ClipOval(
                    child: _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                        ? Image.network(
                            _profileImageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.person, 
                              color: _getToggleColor(),
                            ),
                          )
                        : Icon(
                            Icons.person, 
                            color: _getToggleColor(),
                            size: 28,
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
