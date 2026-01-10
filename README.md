# Ghar Ka Khana (GKK) - User App 🍛

"Maa Ke Haath Ka Swaad" - Delivering authentic home-cooked meals to your doorstep.

## 📱 Project Overview
This is the **User Application** for the Ghar Ka Khana ecosystem. It allows users to browse home kitchens, subscribe to meal plans, manage their wallet, and enjoy wholesome food. The app is built with **Flutter** and backed by **Supabase** for robust authentication and real-time data.

## ✨ Key Features Implemented

### 🔐 Authentication & Security
- **Supabase Auth Integration**: Secure email/password login and sign-up.
- **Google Sign-In**: Seamless one-tap login using native Google credentials.
- **Guest Mode**: Explore the app without immediate sign-up.
- **Password Reset**: Automated email flow for password recovery.
- **Deep Linking**: Custom url scheme (`com.example.ghar_ka_khana_user`) for handling email confirmations and auth redirects.

### 👤 Profile Management
- **Dynamic Profile Profile**: Real-time fetching of user details (Name, Email, Phone).
- **Edit Functionality**: Users can update their Name and Phone number, synced globally.
- **Avatar Management**: 
  - Upload profile pictures via **Camera** or **Gallery**.
  - Powered by **Supabase Storage** (Avatar bucket).
  - Images synced across the app (Home Screen AppBar, Profile Screen).
- **Member Badges**: Visual distinction between Guest and Registered users.

### 🎨 UI/UX Design
- **Premium Aesthetic**: Clean, modern interface with a focus on usability and "wow" factor.
- **Custom Navigation**: Bespoke Bottom Navigation Bar and App Bar with Veg/Non-Veg toggle.
- **Transitions**: Smooth animations and hero transitions for a polished feel.
- **Responsive Layouts**: Optimized for various screen sizes.

## 🛠️ Tech Stack using
- **Framework**: Flutter (Dart)
- **Backend as a Service**: Supabase (Auth, Postgres, Storage)
- **State Management**: `setState` (Local), StreamBuilders (Auth)
- **Plugins**: 
  - `supabase_flutter`
  - `google_sign_in`
  - `image_picker`
  - `google_fonts`
  - `flutter_svg`

## ⚙️ Configuration Details

### Android Configuration
- **Package Name**: `com.example.ghar_ka_khana_user`
- **Min SDK**: 21
- **Target SDK**: Flutter Default
- **Permissions**: Internet, Camera, Read External Storage.

### Supabase Setup
- **Project URL**: `https://mwnpwuxrbaousgwgoyco.supabase.co`
- **Storage**: Public `avatars` bucket with RLS policies enabled for authenticated uploads.
- **Auth Redirect**: `com.example.ghar_ka_khana_user://login-callback/`

### Google Sign-In Setup
- **SHA-1 Fingerprint**: `BE:AB:B2:7D:47:FC:47:B1:A1:91:2D:87:43:60:E0:23:D8:E9:99:E6`
- **Web Client ID**: `471367005406-etu5s1c66uqm2su7alrfl92s6qt87fee.apps.googleusercontent.com`

## 🚀 Getting Started

1. **Clone the repository**:
   ```bash
   git clone https://github.com/adiiiii13/GKK_User.git
   ```
2. **Install dependencies**:
   ```bash
   flutter pub get
   ```
3. **Run the app**:
   ```bash
   flutter run
   ```

## 📝 Recent Updates
- [x] Migrated package name to `com.example.ghar_ka_khana_user`
- [x] Integrated Google Sign-In with new SHA-1 keys
- [x] Fixed Profile Picture upload RLS policies
- [x] Added Deep Linking for accurate email verification redirects
- [x] Refined UI for Profile and Home screens

---
*Developed with ❤️ for the love of home food.*
