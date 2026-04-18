class SavedAddress {
  final String id;
  final String userId;
  final String label;
  final String streetAddress;
  final String area;
  final String city;
  final String state;
  final String country;
  final double? latitude;
  final double? longitude;
  final bool isDefault;
  final String? fullAddress;
  final String? fullName;
  final String? phoneNumber;
  final String? pincode;
  final String type;

  SavedAddress({
    required this.id,
    required this.userId,
    required this.label,
    required this.streetAddress,
    required this.area,
    required this.city,
    required this.state,
    required this.country,
    this.latitude,
    this.longitude,
    required this.isDefault,
    this.fullAddress,
    this.fullName,
    this.phoneNumber,
    this.pincode,
    required this.type,
  });

  factory SavedAddress.fromJson(Map<String, dynamic> json) {
    return SavedAddress(
      id: json['id'],
      userId: json['user_id'],
      label: json['label'] ?? '',
      streetAddress: json['street_address'] ?? '',
      area: json['area'] ?? '',
      city: json['city'] ?? '',
      state: json['state'] ?? '',
      country: json['country'] ?? 'India',
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
      isDefault: json['is_default'] ?? false,
      fullAddress: json['full_address'],
      fullName: json['full_name'],
      phoneNumber: json['phone_number'],
      pincode: json['pincode'],
      type: json['type'] ?? 'Home',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'label': label,
      'street_address': streetAddress,
      'area': area,
      'city': city,
      'state': state,
      'country': country,
      'latitude': latitude,
      'longitude': longitude,
      'is_default': isDefault,
      'full_address': fullAddress,
      'full_name': fullName,
      'phone_number': phoneNumber,
      'pincode': pincode,
      'type': type,
    };
  }
}
