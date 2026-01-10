import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_colors.dart';
import '../screens/profile_screen.dart';

class CustomAppBar extends StatefulWidget {
  final bool isVeg;
  final VoidCallback onToggle;

  const CustomAppBar({
    super.key,
    required this.isVeg,
    required this.onToggle,
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
      _loadProfileImage();
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo and Title
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.cardLight,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.soup_kitchen, 
                  color: widget.isVeg ? AppColors.primary : AppColors.primaryRed, 
                  size: 28
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ghar Ka Khana',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textMain,
                      height: 1.2,
                    ),
                  ),
                  Text(
                    'Delivering love',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.textSub,
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          // Toggle and Profile
          Row(
            children: [
              // Veg Toggle (Interactive)
              GestureDetector(
                onTap: widget.onToggle,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 56,
                  height: 32,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.cardLight,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: (widget.isVeg ? Colors.green : Colors.red).withOpacity(0.2),
                    ),
                  ),
                  child: Stack(
                    children: [
                      AnimatedAlign(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        alignment: widget.isVeg ? Alignment.centerLeft : Alignment.centerRight,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: widget.isVeg ? Colors.green : Colors.red, 
                              width: 2
                            ),
                          ),
                          child: Center(
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: widget.isVeg ? Colors.green : Colors.red,
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
              // Profile Icon with dynamic image
              GestureDetector(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProfileScreen()),
                  );
                  // Refresh profile image when returning from profile screen
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
                        color: Colors.black.withOpacity(0.05),
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
                              color: widget.isVeg ? AppColors.primary : AppColors.primaryRed,
                            ),
                          )
                        : Icon(
                            Icons.person, 
                            color: widget.isVeg ? AppColors.primary : AppColors.primaryRed,
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
