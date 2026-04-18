import 'package:flutter/material.dart';
import '../providers/app_state.dart';

class AppLocalizations {
  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'profile': 'Profile',
      'language': 'Language',
      'dark_mode': 'Dark Mode',
      'my_orders': 'My Orders',
      'support': 'Customer Support',
      'save': 'Save Changes',
      'settings': 'Settings',
      'home': 'Home',
      'cart': 'Cart',
      'wallet': 'Wallet',
      'manage_subs': 'Manage Subscriptions',
      'logout': 'Log Out',
      'take_photo': 'Take Photo',
      'gallery': 'Choose from Gallery',
      'remove_photo': 'Remove Photo',
      'cancel': 'Cancel',
      'auth_login': 'Login',
      'auth_signup': 'Sign Up',
      'changing_theme': 'Changing Theme...',
      'changing_language': 'Changing Language...',
      'notifications': 'Push Notifications',
      'help_support': 'Help & Support',
    },
    'hi': {
      'profile': 'प्रोफ़ाइल',
      'language': 'भाषा',
      'dark_mode': 'डार्क मोड',
      'my_orders': 'मेरे ऑर्डर',
      'support': 'ग्राहक सहायता',
      'save': 'परिवर्तन सहेजें',
      'settings': 'सेटिंग्स',
      'home': 'होम',
      'cart': 'कार्ट',
      'wallet': 'बटुआ',
      'manage_subs': 'सदस्यता प्रबंधित करें',
      'logout': 'लॉग आउट',
      'take_photo': 'फोटो लें',
      'gallery': 'गैलरी से चुनें',
      'remove_photo': 'फोटो हटाएं',
      'cancel': 'रद्द करें',
      'auth_login': 'लॉगिन',
      'auth_signup': 'साइन अप',
      'changing_theme': 'थीम बदल रहा है...',
      'changing_language': 'भाषा बदल रहा है...',
      'notifications': 'सूचनाएं',
      'help_support': 'सहायता',
    },
    'bn': {
      'profile': 'প্রোফাইল',
      'language': 'ভাষা',
      'dark_mode': 'ডার্ক মোড',
      'my_orders': 'আমার অর্ডার',
      'support': 'গ্রাহক সহায়তা',
      'save': 'সংরক্ষণ করুন',
      'settings': 'সেটিংস',
      'home': 'হোম',
      'cart': 'কার্ট',
      'wallet': 'মানিব্যাগ',
      'manage_subs': 'সাবস্ক্রিপশন পরিচালনা',
      'logout': 'লগ আউট',
      'take_photo': 'ছবি তুলুন',
      'gallery': 'গ্যালারি থেকে বাছুন',
      'remove_photo': 'ছবি সরান',
      'cancel': 'বাতিল',
      'auth_login': 'লগ ইন',
      'auth_signup': 'সাইন আপ',
      'changing_theme': 'থিম পরিবর্তন হচ্ছে...',
      'changing_language': 'ভাষা পরিবর্তন হচ্ছে...',
      'notifications': 'পুশ বিজ্ঞপ্তি',
      'help_support': 'সহায়তা',
    },
  };

  static String of(BuildContext context, String key) {
    final languageCode = AppState().locale.languageCode;
    final Map<String, String>? dict = _localizedValues[languageCode] ?? _localizedValues['en'];
    return dict?[key] ?? _localizedValues['en']?[key] ?? key;
  }
}

extension LocalizedString on String {
  String tr(BuildContext context) {
    return AppLocalizations.of(context, this);
  }
}
