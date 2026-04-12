import 'package:flutter/material.dart';

class AppColors {
  // Primary
  static const Color primary = Color(0xFF4CAF50); // A fresh green
  static const Color primaryDark = Color(0xFF388E3C);
  
  // Secondary / Accents
  static const Color secondaryGold = Color(0xFFC6A664);
  static const Color accentGreen = Color(0xFF8BC34A);
  
  // Backgrounds
  // "Very light green tint"
  static const Color backgroundLight = Color(0xFFF1F8E9); 
  // "Dark green/black for dark mode"
  static const Color backgroundDark = Color(0xFF1B281B); 
  
  // Cards
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color cardDark = Color(0xFF2C3E2D);

  // Text
  static const Color textMain = Color(0xFF1A1A1A);
  static const Color textMainDark = Color(0xFFE0E0E0);
  static const Color textSub = Color(0xFF666666);
  static const Color textSubDark = Color(0xFFA0A0A0);

  // Footer
  static const Color footerGreen = Color(0xFFDCEDC8); 
  static const Color footerGreenDark = Color(0xFF2E4631);
  static const Color footerRed = Color(0xFFFFCDD2);
  static const Color footerRedDark = Color(0xFF4E2628);

  // Gradients
  static const LinearGradient bgGradientLight = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFE8F5E9), Color(0xFFF9FBE7)],
  );

  static const LinearGradient bgGradientDark = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF1B281B), Color(0xFF253325)],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF66BB6A), Color(0xFF43A047)],
  );

  static const LinearGradient heroGradientRed = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE53935), Color(0xFFD32F2F)],
  );

  static const LinearGradient categoryGradientActive = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFAED581), Color(0xFFCDDC39)],
  );

  // Red Mode Colors
  static const Color primaryRed = Color(0xFFE53935);
  static const Color primaryRedDark = Color(0xFFC62828);
  static const Color backgroundLightRed = Color(0xFFFFEBEE);

  static const LinearGradient bgGradientRed = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFEBEE), Color(0xFFFFCDD2)],
  );

  // Category Theme Gradients
  static const LinearGradient bgGradientYellow = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFFDE7), Color(0xFFFFF59D)],
  );

  static const LinearGradient bgGradientOrange = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFF3E0), Color(0xFFFFCC80)],
  );

  static const LinearGradient bgGradientBlue = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFE3F2FD), Color(0xFF90CAF9)],
  );

  static const LinearGradient bgGradientWallet = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFE8F5E9), Color(0xFF66BB6A)], // Money Green
  );

  static const LinearGradient bgGradientPremium = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFF8E1), Color(0xFFFFD54F), Color(0xFFFF6F00)], // Gold Luxury
    stops: [0.0, 0.5, 1.0],
  );
  
  // Splash Screen Gradient
  static const RadialGradient splashGradient = RadialGradient(
    center: Alignment.center,
    radius: 1.0,
    colors: [Color(0xFF2DA832), Color(0xFFC2941B)],
    stops: [0.0, 1.0],
  );

  // Wallet Specific
  static const Color walletPrimary = Color(0xFF2DA931);
  static const Color walletSecondary = Color(0xFFC2941B);
  static const Color walletBgLight = Color(0xFFF6F8F6);
  static const Color walletBgDark = Color(0xFF131F13);

  // Premium Colors
  static const Color premiumGold = Color(0xFFC2941B);
  static const Color premiumBgLight = Color(0xFFFFF8E1);
  static const Color premiumSurface = Color(0xFFF6F8F6);
  static const Color primaryGreen = Color(0xFF2DA931);
}

