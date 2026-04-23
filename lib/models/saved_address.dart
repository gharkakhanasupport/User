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
  final String? name;
  final String? phone;
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
    this.name,
    this.phone,
    this.pincode,
    required this.type,
  });

  String get fullAddress {
    final parts = [streetAddress];
    if (area.isNotEmpty && area != 'Default') parts.add(area);
    if (city.isNotEmpty && city != 'Default') parts.add(city);
    if (state.isNotEmpty && state != 'Default') parts.add(state);
    if (pincode != null && pincode!.isNotEmpty) parts.add(pincode!);
    return parts.join(', ');
  }

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
      name: json['name'],
      phone: json['phone'],
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
      'name': name,
      'phone': phone,
      'pincode': pincode,
      'type': type,
    };
  }
}
