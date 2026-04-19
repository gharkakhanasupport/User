import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'login_screen.dart';
import 'support_screen.dart';
import 'transition_screen.dart';
import 'manage_subscriptions_screen.dart';
import 'address_edit_screen.dart';
import '../providers/app_state.dart';
import '../core/localization.dart';
import '../models/saved_address.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Locale? _lastLocale;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentLocale = Localizations.localeOf(context);
    if (_lastLocale != currentLocale) {
      _lastLocale = currentLocale;
      if (mounted) setState(() {});
    }
  }

  bool _notificationsEnabled = true;
  bool _isLoading = false;
  
  // User data from Supabase
  String _userName = 'Guest User';
  String _userEmail = 'guest@gharkaKhana.demo';
  String _userPhone = '+91 00000 00000';
  String _profileImageUrl = '';
  bool _isGuest = true;
  List<SavedAddress> _addresses = [];
  bool _isAddressLoading = false;

  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadUserAddresses();
  }

  Future<void> _loadUserAddresses() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    setState(() => _isAddressLoading = true);
    try {
      final response = await _supabase
          .from('saved_addresses')
          .select()
          .eq('user_id', user.id)
          .order('is_default', ascending: false)
          .order('created_at', ascending: false);
      
      if (mounted) {
        setState(() {
          _addresses = (response as List).map((x) => SavedAddress.fromJson(x)).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading addresses: $e');
    } finally {
      if (mounted) setState(() => _isAddressLoading = false);
    }
  }

  Future<void> _loadUserData() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      setState(() {
        _isGuest = false;
        _userEmail = user.email ?? 'No email';
        
        // Check multiple possible name fields from Google OAuth
        _userName = user.userMetadata?['full_name'] ?? 
                    user.userMetadata?['name'] ?? 
                    user.userMetadata?['display_name'] ??
                    user.email?.split('@').first ?? 
                    'User';
        
        _userPhone = user.userMetadata?['phone'] ?? user.phone ?? 'Not provided';
        
        // Check multiple possible avatar fields from Google OAuth  
        _profileImageUrl = user.userMetadata?['avatar_url'] ?? 
                          user.userMetadata?['picture'] ?? 
                          '';
      });
      
      // Also try to fetch from users table for synced data
      try {
        final userData = await _supabase
            .from('users')
            .select('name, avatar_url, phone')
            .eq('id', user.id)
            .maybeSingle();
        
        if (userData != null && mounted) {
          setState(() {
            if (userData['name'] != null && userData['name'].toString().isNotEmpty) {
              _userName = userData['name'];
            }
            if (userData['avatar_url'] != null && userData['avatar_url'].toString().isNotEmpty) {
              _profileImageUrl = userData['avatar_url'];
            }
            if (userData['phone'] != null && userData['phone'].toString().isNotEmpty) {
              _userPhone = userData['phone'];
            }
          });
        }
      } catch (e) {
        debugPrint('Could not fetch user data from users table: $e');
      }
    }
  }

  Future<void> _updateUserProfile({String? name, String? phone, String? avatarUrl}) async {
    if (_isGuest) {
      _showGuestMessage();
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final userId = _supabase.auth.currentUser!.id;
      
      // Update auth metadata
      final updates = <String, dynamic>{};
      if (name != null) updates['full_name'] = name;
      if (phone != null) updates['phone'] = phone;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
      
      await _supabase.auth.updateUser(
        UserAttributes(data: updates),
      );
      
      // Also sync to public.users table for Admin visibility
      final dbUpdates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (name != null) dbUpdates['name'] = name;
      if (phone != null) dbUpdates['phone'] = phone;
      if (avatarUrl != null) dbUpdates['avatar_url'] = avatarUrl;
      
      await _supabase.from('users').update(dbUpdates).eq('id', userId);
      
      await _loadUserData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('profile_updated'.tr(context)),
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadImage() async {
    if (_isGuest) {
      _showGuestMessage();
      return;
    }
    
    // Show bottom sheet with options
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'choose_photo'.tr(context),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.camera_alt, color: Color(0xFF16A34A)),
              ),
              title: Text('take_photo'.tr(context), style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
              subtitle: Text('camera'.tr(context), style: GoogleFonts.plusJakartaSans(color: Colors.grey)),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            const Divider(),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.photo_library, color: Colors.blue),
              ),
              title: Text('gallery'.tr(context), style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
              subtitle: Text('gallery_desc'.tr(context), style: GoogleFonts.plusJakartaSans(color: Colors.grey)),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
    
    if (source == null) return;
    
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, maxWidth: 500);
    
    if (pickedFile == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      final userId = _supabase.auth.currentUser!.id;
      final fileExt = pickedFile.path.split('.').last;
      final fileName = '$userId/avatar.$fileExt';
      
      final bytes = await File(pickedFile.path).readAsBytes();
      
      await _supabase.storage.from('avatars').uploadBinary(
        fileName,
        bytes,
        fileOptions: const FileOptions(upsert: true),
      );
      
      final imageUrl = _supabase.storage.from('avatars').getPublicUrl(fileName);
      
      await _updateUserProfile(avatarUrl: imageUrl);
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showGuestMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('signin_to_edit'.tr(context)),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: SnackBarAction(
          label: 'Sign In',
          textColor: Colors.white,
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            );
          },
        ),
      ),
    );
  }

  void _showEditDialog(String title, String currentValue, Function(String) onSave) {
    final controller = TextEditingController(text: currentValue);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${'edit'.tr(context)} $title', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: '${'enter'.tr(context)} $title',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF16A34A), width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr(context), style: GoogleFonts.plusJakartaSans(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              onSave(controller.text);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('save'.tr(context), style: GoogleFonts.plusJakartaSans(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _changePassword() async {
    if (_isGuest) {
      _showGuestMessage();
      return;
    }
    
    final emailController = TextEditingController(text: _userEmail);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('reset_pass'.tr(context), style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'pass_reset_desc'.tr(context),
              style: GoogleFonts.plusJakartaSans(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: 'email'.tr(context),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr(context), style: GoogleFonts.plusJakartaSans(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _supabase.auth.resetPasswordForEmail(emailController.text);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('pass_reset_sent'.tr(context)),
                      backgroundColor: const Color(0xFF16A34A),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('send_link'.tr(context), style: GoogleFonts.plusJakartaSans(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF2DA931);
    const Color textMain = Color(0xFF121712);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha: 0.95),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: textMain),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'my_profile'.tr(context),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textMain,
          ),
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.settings, color: primaryColor),
              onPressed: () {},
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade50, height: 1),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadUserData,
        color: const Color(0xFF16A34A),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 32),
        child: Column(
          children: [
            // Profile Header
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickAndUploadImage,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 112,
                          height: 112,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 20,
                                offset: const Offset(0, 4),
                              ),
                            ],
                            color: Colors.grey.shade200,
                          ),
                          child: ClipOval(
                            child: _profileImageUrl.isNotEmpty
                                ? Image.network(
                                    _profileImageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Icon(
                                      Icons.person,
                                      size: 50,
                                      color: Colors.grey.shade400,
                                    ),
                                  )
                                : Icon(
                                    Icons.person,
                                    size: 50,
                                    color: Colors.grey.shade400,
                                  ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: primaryColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 2,
                              ),
                            ],
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _userName,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: textMain,
                    ),
                  ),
                  if (!_isGuest)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFFCEFC2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.workspace_premium, size: 16, color: Color(0xFFC2941B)),
                          const SizedBox(width: 4),
                          Text(
                            'member'.tr(context),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFC2941B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_isGuest)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'guest_mode'.tr(context),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => _showEditDialog('Name', _userName, (value) {
                      _updateUserProfile(name: value);
                    }),
                    child: Text(
                      'edit_name'.tr(context),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const Divider(color: Color(0xFFF6F8F6), thickness: 8),
            
            // Account Details
            _buildSectionHeader(Icons.person, 'account_details'.tr(context)),
            _buildEditableDetailItem(Icons.mail, 'email'.tr(context), _userEmail, () {
              // Email is read-only as it's the auth identifier
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Email cannot be changed directly'),
                  backgroundColor: Colors.orange,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            }),
            _buildHorizontalDivider(),
            _buildEditableDetailItem(Icons.call, 'phone_number'.tr(context), _userPhone, () {
              _showEditDialog('Phone', _userPhone, (value) {
                _updateUserProfile(phone: value);
              });
            }),
            _buildHorizontalDivider(),
            _buildEditableActionItem(Icons.lock, 'change_password'.tr(context), 
              subtitle: _isGuest ? 'Sign in to manage' : 'Tap to reset',
              onTap: _changePassword,
            ),
            
            const Divider(color: Color(0xFFF6F8F6), thickness: 8),
            
            // Delivery Addresses
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: primaryColor),
                      const SizedBox(width: 8),
                      Text(
                        'delivery_addresses'.tr(context),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textMain,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_isAddressLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (_addresses.isEmpty)
                    _buildEmptyAddressState()
                  else
                    ..._addresses.map((addr) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildAddressCard(
                        addr.label,
                        addr.streetAddress,
                        addr.type.toLowerCase() == 'home' ? Icons.home : 
                        addr.type.toLowerCase() == 'work' ? Icons.work : Icons.location_on,
                        addr.isDefault ? primaryColor : Colors.grey.shade600,
                        addr.isDefault,
                        onEdit: () => _navigateToAddressEdit(address: addr),
                        onDelete: () => _deleteAddress(addr.id),
                      ),
                    )),
                  const SizedBox(height: 4),
                  OutlinedButton.icon(
                    onPressed: () => _navigateToAddressEdit(),
                    icon: const Icon(Icons.add),
                    label: Text('add_new_address'.tr(context)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryColor,
                      side: BorderSide(color: primaryColor.withValues(alpha: 0.5), style: BorderStyle.none), // Using dashed border simulation is tricky, sticking to styling
                      backgroundColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: primaryColor.withValues(alpha: 0.5)), // Added solid border for now
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                ],
              ),
            ),
            
            const Divider(color: Color(0xFFF6F8F6), thickness: 8),
            
            // App Settings
            _buildSectionHeader(Icons.settings, 'settings'.tr(context)),
            _buildToggleItem(Icons.notifications, 'notifications'.tr(context), _notificationsEnabled, (val) => setState(() => _notificationsEnabled = val)),
            _buildHorizontalDivider(),

            _buildActionItem(
              Icons.translate, 
              'language'.tr(context), 
              trailingText: AppState().locale.languageCode == 'hi' ? 'Hindi' : (AppState().locale.languageCode == 'bn' ? 'Bengali' : 'English'),
              onTap: () => _showLanguagePicker(),
            ),
            _buildHorizontalDivider(),
            _buildActionItem(Icons.card_membership, 'My Subscriptions', onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageSubscriptionsScreen()));
            }),
            _buildHorizontalDivider(),
            _buildActionItem(Icons.support_agent, 'help_support'.tr(context), onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportScreen()));
            }),
            _buildActionItem(Icons.info, 'about_app'.tr(context)),
            
            const SizedBox(height: 24),
            
            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(top: BorderSide(color: Colors.grey.shade100)),
              ),
              child: Column(
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Supabase.instance.client.auth.signOut();
                      if (context.mounted) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (context) => const LoginScreen()),
                          (route) => false,
                        );
                      }
                    },
                    icon: const Icon(Icons.logout),
                    label: Text('logout'.tr(context)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryColor,
                      side: const BorderSide(color: primaryColor),
                      backgroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${'app_version'.tr(context)} 2.4.0',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: Colors.grey.shade400,
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

  void _showLanguagePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('select_lang'.tr(context), style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildLanguageOption('English', 'en'),
            _buildLanguageOption('Hindi / हिंदी', 'hi'),
            _buildLanguageOption('Bengali / বাংলা', 'bn'),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption(String title, String langCode) {
    return ListTile(
      title: Text(title, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
      trailing: AppState().locale.languageCode == langCode ? const Icon(Icons.check_circle, color: Color(0xFF2DA832)) : null,
      onTap: () {
        Navigator.pop(context); // Close bottom sheet
        if (AppState().locale.languageCode != langCode) {
           Navigator.push(context, MaterialPageRoute(
            builder: (context) => TransitionScreen(
              message: 'changing_language'.tr(context), // Note: This grabs the old language immediately since the state updates in transition
              onTransition: () async {
                await AppState().setLocale(Locale(langCode));
              },
            ),
          ));
        }
      },
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF2DA931)),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF121712),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalDivider() {
    return const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFF6F8F6));
  }

  Widget _buildEditableDetailItem(IconData icon, String title, String value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: const Color(0xFF2DA931), size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF121712),
                    ),
                  ),
                  Text(
                    value,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.edit, size: 18, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableActionItem(IconData icon, String title, {String? subtitle, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: const Color(0xFF2DA931), size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF121712),
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: Colors.grey.shade400,
                      ),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Widget _buildActionItem(IconData icon, String title, {String? subtitle, String? trailingText, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: const Color(0xFF2DA931), size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF121712),
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: Colors.grey.shade400,
                      ),
                    ),
                ],
              ),
            ),
            if (trailingText != null) ...[
              Text(
                trailingText,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleItem(IconData icon, String title, bool value, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.grey.shade700, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF121712),
                ),
              ),
            ],
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFF2DA931),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToAddressEdit({SavedAddress? address}) async {
    if (_isGuest) {
      _showGuestMessage();
      return;
    }

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddressEditScreen(address: address),
      ),
    );

    // Refresh the address list if something was saved/deleted
    if (result == true) {
      await _loadUserAddresses();
    }
  }

  Widget _buildEmptyAddressState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.location_off_outlined, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'No addresses saved yet',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Add an address for faster delivery',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAddress(String addressId) async {
    if (_isGuest) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Address'),
        content: const Text('Are you sure you want to delete this address?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await _supabase.from('saved_addresses').delete().eq('id', addressId);
      await _loadUserAddresses();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildAddressCard(String type, String address, IconData icon, Color iconColor, bool isPrimary, {VoidCallback? onEdit, VoidCallback? onDelete}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isPrimary)
              Container(width: 4, color: const Color(0xFF2DA931)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isPrimary ? Colors.green.shade50 : Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: iconColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                type,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF121712),
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 18),
                                    color: const Color(0xFF2DA931),
                                    onPressed: onEdit,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                  const SizedBox(width: 12),
                                  IconButton(
                                    icon: const Icon(Icons.delete, size: 18),
                                    color: Colors.grey.shade400,
                                    onPressed: onDelete,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            address,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                              height: 1.4,
                            ),
                          ),
                        ],
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
