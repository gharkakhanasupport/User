import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'login_screen.dart';
import 'support_screen.dart';
import 'kitchen_loading_screen.dart';
import 'add_address_screen.dart';
import '../services/kitchen_service.dart';
import '../models/kitchen.dart';
import '../services/user_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _notificationsEnabled = true;
  bool _isLoading = false;
  
  // User data from Supabase
  String _userName = 'Guest User';
  String _userEmail = 'guest@gharkaKhana.demo';
  String _userPhone = '+91 00000 00000';
  String _profileImageUrl = '';
  String _userAddress = '';
  bool _isGuest = true;
  
  // Services
  final _kitchenService = KitchenService();
  final _userService = UserService();
  Kitchen? _myKitchen;
  bool _isCook = false;

  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      setState(() {
        _isGuest = false;
        _userEmail = user.email ?? 'No email';
        _userPhone = user.userMetadata?['phone'] ?? user.phone ?? 'Not provided';
        _userName = user.userMetadata?['full_name'] ?? user.userMetadata?['name'] ?? 'User';
        _profileImageUrl = user.userMetadata?['avatar_url'] ?? user.userMetadata?['picture'] ?? '';
      });
      
      try {
        // 1. Fetch from 'users' table
        final userData = await _userService.getUserData(user.id);
        
        if (userData != null && mounted) {
          setState(() {
            _userName = userData['name'] ?? _userName;
            _profileImageUrl = userData['avatar_url'] ?? _profileImageUrl;
            _userPhone = userData['phone'] ?? _userPhone;
            _userAddress = userData['address'] ?? '';
          });
        }

        // 2. Fetch kitchen data for this user
        var kitchen = await _kitchenService.getKitchenByCookId(user.id);
        if (kitchen == null && _userPhone != 'Not provided') {
          kitchen = await _kitchenService.getKitchenByPhone(_userPhone);
        }

        if (mounted) {
          setState(() {
            _myKitchen = kitchen;
            _isCook = kitchen != null;
          });
        }
      } catch (e) {
        debugPrint('Could not fetch user/kitchen data: $e');
      }
    }
  }

  Future<void> _saveProfileChanges(String newName, String newPhone, String newAddress) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final success = await _userService.updateProfile(
        id: user.id,
        name: newName,
        phone: newPhone,
        address: newAddress,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile saved successfully!'), backgroundColor: Colors.green),
          );
          _loadUserData();
        } else {
          throw Exception('Update failed');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save profile'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _pickAndUploadImage() async {
    if (_isGuest) return;
    
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, maxWidth: 500);
    
    if (pickedFile == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      final userId = _supabase.auth.currentUser!.id;
      final fileExt = pickedFile.path.split('.').last;
      final fileName = '$userId/avatar.$fileExt';
      final bytes = await File(pickedFile.path).readAsBytes();
      
      await _supabase.storage.from('avatars').uploadBinary(
        fileName, bytes,
        fileOptions: const FileOptions(upsert: true),
      );
      
      final imageUrl = _supabase.storage.from('avatars').getPublicUrl(fileName);
      
      await _userService.updateProfile(id: userId, avatarUrl: imageUrl);
      await _loadUserData();
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showEditDialog(String title, String currentValue, Function(String) onSave) {
    final controller = TextEditingController(text: currentValue);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Edit $title', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          maxLines: title == 'Address' ? 3 : 1,
          decoration: InputDecoration(
            hintText: 'Enter $title',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              onSave(controller.text);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2DA931)),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
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
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: textMain),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('My Profile', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold, color: textMain)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. Profile Photo & Name
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickAndUploadImage,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 112, height: 112,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)],
                            color: Colors.grey.shade200,
                          ),
                          child: ClipOval(
                            child: _profileImageUrl.isNotEmpty
                                ? Image.network(_profileImageUrl, fit: BoxFit.cover)
                                : const Icon(Icons.person, size: 50, color: Colors.grey),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(color: primaryColor, shape: BoxShape.circle),
                          child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(_userName, style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.bold, color: textMain)),
                  TextButton(
                    onPressed: () => _showEditDialog('Name', _userName, (val) => _saveProfileChanges(val, _userPhone, _userAddress)),
                    child: const Text('Edit Name', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

            const Divider(color: Color(0xFFF6F8F6), thickness: 8),

            // 2. Account Details
            _buildSectionHeader(Icons.person_outline, 'Account'),
            _buildDetailItem(Icons.mail_outline, 'Email', _userEmail),
            _buildDetailItem(Icons.call_outlined, 'Phone', _userPhone, onEdit: () => _showEditDialog('Phone', _userPhone, (val) => _saveProfileChanges(_userName, val, _userAddress))),
            _buildDetailItem(Icons.receipt_long_outlined, 'My Orders', 'View order history', onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('My Orders feature coming soon!')));
            }),

            const Divider(color: Color(0xFFF6F8F6), thickness: 8),

            // 3. My Kitchen (For Cooks)
            if (_isCook && _myKitchen != null) ...[
              _buildSectionHeader(Icons.restaurant, 'My Kitchen'),
              _buildKitchenItem(),
              const Divider(color: Color(0xFFF6F8F6), thickness: 8),
            ],

            // 4. Delivery Address
            _buildSectionHeader(Icons.location_on_outlined, 'Delivery Address'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildAddressCard(),
            ),

            const SizedBox(height: 32),
            
            // Logout
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton.icon(
                onPressed: () async {
                  await _supabase.auth.signOut();
                  if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
                },
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF2DA931), size: 20),
          const SizedBox(width: 8),
          Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
        ],
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String title, String value, {VoidCallback? onEdit, VoidCallback? onTap}) {
    return ListTile(
      onTap: onTap ?? onEdit,
      leading: Icon(icon, color: Colors.grey.shade600),
      title: Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)),
      subtitle: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black)),
      trailing: onEdit != null ? const Icon(Icons.edit, size: 18, color: Color(0xFF2DA931)) : const Icon(Icons.chevron_right),
    );
  }

  Widget _buildKitchenItem() {
    return ListTile(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => KitchenLoadingScreen(
          kitchenName: _myKitchen!.kitchenName,
          kitchenSubtitle: _myKitchen!.subtitle,
          rating: _myKitchen!.ratingText,
          ratingCount: '(${_myKitchen!.totalOrders})',
          imageUrl: _myKitchen!.displayImage ?? 'https://via.placeholder.com/150',
          tag: _myKitchen!.isVegetarian ? 'Pure Veg' : 'Home-style',
          time: _myKitchen!.isAvailable ? 'Open Now' : 'Closed',
          isVeg: _myKitchen!.isVegetarian,
          cookId: _myKitchen!.cookId,
          kitchenPhotos: _myKitchen!.kitchenPhotos,
        )));
      },
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(_myKitchen!.displayImage ?? 'https://via.placeholder.com/150', width: 50, height: 50, fit: BoxFit.cover),
      ),
      title: Text(_myKitchen!.kitchenName, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(_myKitchen!.subtitle),
      trailing: const Icon(Icons.chevron_right),
    );
  }

  Widget _buildAddressCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Delivery Address', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              IconButton(
                icon: const Icon(Icons.edit, color: Color(0xFF2DA931), size: 20),
                onPressed: () async {
                  final newAddress = await Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (_) => AddAddressScreen(initialAddress: _userAddress))
                  );
                  if (newAddress != null) {
                    _saveProfileChanges(_userName, _userPhone, newAddress);
                  }
                },
              ),
            ],
          ),
          if (_userAddress.isEmpty)
            TextButton.icon(
              onPressed: () async {
                final newAddress = await Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (_) => const AddAddressScreen())
                );
                if (newAddress != null) {
                  _saveProfileChanges(_userName, _userPhone, newAddress);
                }
              },
              icon: const Icon(Icons.add_location_alt, color: Color(0xFF2DA931)),
              label: const Text('Add your delivery address', style: TextStyle(color: Color(0xFF2DA931))),
            )
          else
            Text(
              _userAddress,
              style: const TextStyle(fontSize: 15, color: Colors.black, height: 1.4),
            ),
        ],
      ),
    );
  }
}
