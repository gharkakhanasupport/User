import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:location/location.dart' as loc;
import '../models/saved_address.dart';
import '../core/localization.dart';
import '../utils/error_handler.dart';
import '../services/user_service.dart';

// ─── Design tokens ───
const Color _primary = Color(0xFF2DA931);
const Color _primaryLight = Color(0xFFEAF7EA);
const Color _bg = Color(0xFFF9FAFB);
const Color _textDark = Color(0xFF121712);
const Color _textSub = Color(0xFF6B7280);
const Color _cardBorder = Color(0xFFE5E7EB);

class AddressEditScreen extends StatefulWidget {
  final SavedAddress? address; // null = Add mode, non-null = Edit mode

  const AddressEditScreen({super.key, this.address});

  @override
  State<AddressEditScreen> createState() => _AddressEditScreenState();
}

class _AddressEditScreenState extends State<AddressEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;

  // Controllers — map 1:1 to saved_addresses columns
  late final TextEditingController _labelController;
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _streetController;
  late final TextEditingController _areaController;
  late final TextEditingController _cityController;
  late final TextEditingController _stateController;
  late final TextEditingController _pincodeController;
  late final TextEditingController _countryController;

  String _selectedType = 'Home';
  bool _isDefault = false;
  bool _isSaving = false;
  bool _isFetchingLocation = false;

  // Coordinates (stored silently)
  double? _latitude;
  double? _longitude;

  bool get _isEditing => widget.address != null;

  @override
  void initState() {
    super.initState();
    final a = widget.address;
    _labelController = TextEditingController(text: a?.label ?? '');
    _nameController = TextEditingController(text: a?.name ?? '');
    _phoneController = TextEditingController(text: a?.phone ?? '');
    _streetController = TextEditingController(text: a?.streetAddress ?? '');
    _areaController = TextEditingController(text: (a?.area != null && a!.area != 'Default') ? a.area : '');
    _cityController = TextEditingController(text: (a?.city != null && a!.city != 'Default') ? a.city : '');
    _stateController = TextEditingController(text: (a?.state != null && a!.state != 'Default') ? a.state : '');
    _pincodeController = TextEditingController(text: a?.pincode ?? '');
    _countryController = TextEditingController(text: a?.country ?? 'India');
    _selectedType = a?.type ?? 'Home';
    _isDefault = a?.isDefault ?? false;
    _latitude = a?.latitude;
    _longitude = a?.longitude;
  }

  @override
  void dispose() {
    _labelController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _streetController.dispose();
    _areaController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════
  //   GPS AUTO-FILL
  // ══════════════════════════════════════════
  Future<void> _fetchCurrentLocation() async {
    setState(() => _isFetchingLocation = true);

    try {
      // 1. Check & request permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ErrorHandler.showGracefulError(context, 'location_permission_denied'.tr(context));
          }
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ErrorHandler.showGracefulError(context, 'location_permission_permanent'.tr(context));
        }
        return;
      }

      // 2. Check & Request Location Service (GPS)
      final locManager = loc.Location();
      bool serviceEnabled = await locManager.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await locManager.requestService();
        if (!serviceEnabled) {
          if (mounted) {
            ErrorHandler.showGracefulError(context, 'location_disabled'.tr(context));
          }
          return;
        }
      }

      // 3. Get current position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      // 4. Reverse geocode
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;

          // Build street parts
          final streetParts = <String>[];
          if (place.name != null && place.name!.isNotEmpty) streetParts.add(place.name!);
          if (place.street != null && place.street!.isNotEmpty && place.street != place.name) {
            streetParts.add(place.street!);
          }
          if (place.subThoroughfare != null && place.subThoroughfare!.isNotEmpty) {
            streetParts.add(place.subThoroughfare!);
          }
          if (place.thoroughfare != null && place.thoroughfare!.isNotEmpty && !streetParts.contains(place.thoroughfare)) {
            streetParts.add(place.thoroughfare!);
          }
          _streetController.text = streetParts.take(3).join(', ');

          _areaController.text = place.subLocality ?? place.locality ?? '';
          _cityController.text = place.locality ?? '';
          _stateController.text = place.administrativeArea ?? '';
          _pincodeController.text = place.postalCode ?? '';
          _countryController.text = place.country ?? 'India';
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location fetched successfully! ✅')),
          );
        }
      } else {
        if (mounted) {
          ErrorHandler.showGracefulError(context, 'Could not determine address from location');
        }
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showGracefulError(context, e);
      }
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  // ══════════════════════════════════════════
  //   SAVE / UPDATE
  // ══════════════════════════════════════════
  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final userId = _supabase.auth.currentUser!.id;

      final data = <String, dynamic>{
        'user_id': userId,
        'label': _labelController.text.trim(),
        'name': _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : null,
        'phone': _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
        'street_address': _streetController.text.trim(),
        'area': _areaController.text.trim().isNotEmpty ? _areaController.text.trim() : 'Default',
        'city': _cityController.text.trim().isNotEmpty ? _cityController.text.trim() : 'Default',
        'state': _stateController.text.trim().isNotEmpty ? _stateController.text.trim() : 'Default',
        'pincode': _pincodeController.text.trim().isNotEmpty ? _pincodeController.text.trim() : null,
        'country': _countryController.text.trim().isNotEmpty ? _countryController.text.trim() : 'India',
        'latitude': _latitude,
        'longitude': _longitude,
        'type': _selectedType,
        'is_default': _isDefault,
      };

      // If setting as default, unset previous defaults first
      if (_isDefault) {
        await _supabase
            .from('saved_addresses')
            .update({'is_default': false})
            .eq('user_id', userId);
      }

      if (_isEditing) {
        await _supabase
            .from('saved_addresses')
            .update(data)
            .eq('id', widget.address!.id);
      } else {
        final result = await _supabase.from('saved_addresses').insert(data).select().single();
        // If we just added a new address and it's default, we need its ID for users table
        if (_isDefault) {
          final newId = result['id'];
          final userService = UserService();
          await userService.updateProfile(
            id: userId,
            defaultAddressId: newId,
            primaryAddress: SavedAddress.fromJson(result).fullAddress,
          );
        }
      }

      // If editing an existing address and it's marked as default (or was already default)
      if (_isDefault && _isEditing) {
        final userService = UserService();
        await userService.updateProfile(
          id: userId,
          defaultAddressId: widget.address!.id,
          primaryAddress: SavedAddress.fromJson({...data, 'id': widget.address!.id}).fullAddress,
        );
      }

      if (mounted) {
        Navigator.pop(context, true); // return true = data changed
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showGracefulError(context, e);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }



  // ══════════════════════════════════════════
  //   DELETE
  // ══════════════════════════════════════════
  Future<void> _deleteAddress() async {
    if (!_isEditing) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('delete_address'.tr(context),
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        content: Text('delete_address_confirm'.tr(context),
            style: GoogleFonts.plusJakartaSans(color: _textSub)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cancel'.tr(context),
                style: GoogleFonts.plusJakartaSans(color: _textSub)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('delete'.tr(context),
                style: GoogleFonts.plusJakartaSans(
                    color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSaving = true);
    try {
      await _supabase
          .from('saved_addresses')
          .delete()
          .eq('id', widget.address!.id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ErrorHandler.showGracefulError(context, e);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }


  // ══════════════════════════════════════════
  //   UI
  // ══════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEditing ? 'edit_address'.tr(context) : 'add_address'.tr(context),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _textDark,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _deleteAddress,
              tooltip: 'Delete',
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade100, height: 1),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── GPS Auto-fill button ──
            _buildLocationButton(),
            const SizedBox(height: 20),

            // ── Address Type chips ──
            _buildTypeSelector(),
            const SizedBox(height: 20),

            // ── Label ──
            _buildField(
              controller: _labelController,
              label: 'address_label'.tr(context),
              hint: 'e.g. My Home, Dad\'s Place',
              icon: Icons.label_outline,
              required: true,
            ),
            const SizedBox(height: 16),

            // ── Contact info section ──
            _buildSectionTitle('contact_info'.tr(context)),
            const SizedBox(height: 12),
            _buildField(
              controller: _nameController,
              label: 'full_name'.tr(context),
              hint: 'Receiver\'s full name',
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 12),
            _buildField(
              controller: _phoneController,
              label: 'phone_number'.tr(context),
              hint: '+91 XXXXX XXXXX',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 20),

            // ── Address details section ──
            _buildSectionTitle('address_details'.tr(context)),
            const SizedBox(height: 12),
            _buildField(
              controller: _streetController,
              label: 'street_address'.tr(context),
              hint: 'House no., Building, Street',
              icon: Icons.home_outlined,
              maxLines: 2,
              required: true,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildField(
                    controller: _areaController,
                    label: 'area'.tr(context),
                    hint: 'Area / Locality',
                    icon: Icons.map_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildField(
                    controller: _pincodeController,
                    label: 'pincode'.tr(context),
                    hint: '6-digit PIN',
                    icon: Icons.pin_drop_outlined,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildField(
                    controller: _cityController,
                    label: 'city'.tr(context),
                    hint: 'City',
                    icon: Icons.location_city_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildField(
                    controller: _stateController,
                    label: 'state'.tr(context),
                    hint: 'State',
                    icon: Icons.flag_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildField(
              controller: _countryController,
              label: 'country'.tr(context),
              hint: 'Country',
              icon: Icons.public_outlined,
            ),
            const SizedBox(height: 20),

            // ── Set as default ──
            _buildDefaultToggle(),
            const SizedBox(height: 24),

            // ── Save button ──
            _buildSaveButton(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── GPS LOCATION BUTTON ──
  Widget _buildLocationButton() {
    return Material(
      borderRadius: BorderRadius.circular(16),
      color: Colors.white,
      elevation: 0,
      child: InkWell(
        onTap: _isFetchingLocation ? null : _fetchCurrentLocation,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _primary.withOpacity( 0.3)),
            gradient: LinearGradient(
              colors: [_primaryLight, Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _primary.withOpacity( 0.12),
                  shape: BoxShape.circle,
                ),
                child: _isFetchingLocation
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: _primary,
                        ),
                      )
                    : const Icon(Icons.my_location_rounded,
                        color: _primary, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'use_current_location'.tr(context),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'auto_fill_address'.tr(context),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: _textSub,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: _primary.withOpacity( 0.5)),
            ],
          ),
        ),
      ),
    );
  }

  // ── TYPE SELECTOR CHIPS ──
  Widget _buildTypeSelector() {
    final types = [
      {'value': 'Home', 'icon': Icons.home_rounded, 'label': 'addr_home'.tr(context)},
      {'value': 'Work', 'icon': Icons.work_rounded, 'label': 'addr_work'.tr(context)},
      {'value': 'Other', 'icon': Icons.location_on_rounded, 'label': 'addr_other'.tr(context)},
    ];

    return Row(
      children: types.map((t) {
        final isSelected = _selectedType == t['value'];
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: t != types.last ? 10 : 0,
            ),
            child: GestureDetector(
              onTap: () => setState(() => _selectedType = t['value'] as String),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected ? _primary : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? _primary : _cardBorder,
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: _primary.withOpacity( 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Column(
                  children: [
                    Icon(
                      t['icon'] as IconData,
                      color: isSelected ? Colors.white : _textSub,
                      size: 22,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      t['label'] as String,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : _textSub,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── SECTION TITLE ──
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: _textDark,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  // ── TEXT FIELD ──
  Widget _buildField({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool required = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: GoogleFonts.plusJakartaSans(fontSize: 14, color: _textDark),
      validator: required
          ? (val) {
              if (val == null || val.trim().isEmpty) {
                return '$label is required';
              }
              return null;
            }
          : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          color: Colors.grey.shade400,
        ),
        labelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: _textSub,
        ),
        prefixIcon: icon != null
            ? Padding(
                padding: const EdgeInsets.only(left: 12, right: 8),
                child: Icon(icon, size: 20, color: _primary.withOpacity( 0.7)),
              )
            : null,
        prefixIconConstraints:
            const BoxConstraints(minWidth: 40, minHeight: 40),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red),
        ),
      ),
    );
  }

  // ── DEFAULT TOGGLE ──
  Widget _buildDefaultToggle() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => setState(() => _isDefault = !_isDefault),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _cardBorder),
          ),
          child: Row(
            children: [
              Icon(
                _isDefault ? Icons.star_rounded : Icons.star_outline_rounded,
                color: _isDefault ? const Color(0xFFC2941B) : _textSub,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'set_default'.tr(context),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _textDark,
                      ),
                    ),
                    Text(
                      'default_address_desc'.tr(context),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: _textSub,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _isDefault,
                onChanged: (val) => setState(() => _isDefault = val),
                activeThumbColor: _primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── SAVE BUTTON ──
  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveAddress,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _primary.withOpacity( 0.5),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isSaving
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Text(
                _isEditing
                    ? 'save_changes'.tr(context)
                    : 'save_address'.tr(context),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}
