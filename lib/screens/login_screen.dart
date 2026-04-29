import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart' as gsi;
import '../core/localization.dart';
import 'signup_screen.dart';
import 'main_layout.dart';
import 'phone_verification_screen.dart';
import '../services/config_service.dart';
import '../services/in_app_update_service.dart';
import '../utils/error_handler.dart';
import '../widgets/update_overlay.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
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

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;
  bool _showEmailLogin = false; // Toggle for email/password section
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  SupabaseClient get supabase => Supabase.instance.client;

  // Web Client ID from google-services.json (client_type: 3)
  static const _webClientId = '471367005406-etu5s1c66uqm2su7alrfl92s6qt87fee.apps.googleusercontent.com';

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );

    _animController.forward();

    // Check for updates in background
    Future.delayed(const Duration(seconds: 2), () {
      InAppUpdateService.instance.checkForUpdate();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  // ─── Check phone verification and navigate ─────────────────────────────
  Future<void> _navigateAfterAuth() async {
    final user = supabase.auth.currentUser;
    if (user == null || !mounted) return;

    try {
      final userData = await supabase
          .from('users')
          .select('phone_verified')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      final phoneVerified = userData?['phone_verified'] == true;
      final isOtpEnabled = ConfigService().isOtpEnabled;

      if (phoneVerified || !isOtpEnabled) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainLayout()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PhoneVerificationScreen()),
        );
      }
    } catch (e) {
      // If check fails, go to phone verification to be safe
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PhoneVerificationScreen()),
        );
      }
    }
  }

  // ─── Email/Password Sign In ───────────────────────────────────────────
  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (mounted && response.session != null) {
        await _navigateAfterAuth();
      }
    } catch (e) {
      if (mounted) ErrorHandler.showGracefulError(context, e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Google Sign In ───────────────────────────────────────────────────
  Future<void> _signInWithGoogle() async {
    setState(() => _isGoogleLoading = true);

    try {
      final gsi.GoogleSignIn googleSignIn = gsi.GoogleSignIn(
        serverClientId: _webClientId,
      );

      // Sign out first to ensure account picker shows
      await googleSignIn.signOut();

      final googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        // User cancelled
        if (mounted) setState(() => _isGoogleLoading = false);
        return;
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null) {
        throw Exception('Failed to get authentication tokens from Google. Please check your SHA-1 configuration in Firebase Console.');
      }

      final response = await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      // Sync user profile to public.users table
      if (response.user != null) {
        final user = response.user!;
        final avatarUrl = user.userMetadata?['avatar_url'] ??
                          user.userMetadata?['picture'] ??
                          googleUser.photoUrl;

        try {
          await supabase.from('users').upsert({
            'id': user.id,
            'email': user.email ?? googleUser.email,
            'name': user.userMetadata?['full_name'] ?? googleUser.displayName ?? 'User',
            'profile_image_url': avatarUrl,
            'role': 'customer',
            'status': 'verified',
            'updated_at': DateTime.now().toIso8601String(),
          }, onConflict: 'id');
        } catch (e) {
          debugPrint('Profile sync note: $e');
        }
      }

      if (mounted) {
        await _navigateAfterAuth();
      }
    } catch (e) {
      if (mounted) ErrorHandler.showGracefulError(context, e);
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  // ─── Forgot Password ─────────────────────────────────────────────────
  void _showForgotPasswordSheet() {
    final resetEmailController = TextEditingController(text: _emailController.text.trim());
    final resetFormKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              return Form(
                key: resetFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'reset_pass'.tr(context),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22, fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'pass_reset_desc'.tr(context),
                      style: GoogleFonts.plusJakartaSans(fontSize: 14, color: const Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: resetEmailController,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'enter_email'.tr(context);
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                          return 'invalid_email'.tr(context);
                        }
                        return null;
                      },
                      decoration: _buildInputDecoration(
                        hint: 'email_hint'.tr(context),
                        icon: Icons.email_outlined,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity, height: 52,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (!resetFormKey.currentState!.validate()) return;
                          final email = resetEmailController.text.trim();
                          try {
                            await supabase.auth.resetPasswordForEmail(
                              email,
                              redirectTo: 'com.gharkakhana.user://login-callback/',
                            );
                            if (sheetContext.mounted) {
                              Navigator.pop(sheetContext);
                            }
                            if (mounted) {
                              _showSuccess('Password reset link sent to $email. Check your inbox!');
                            }
                          } catch (e) {
                            if (context.mounted) ErrorHandler.showGracefulError(context, e);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: Text(
                          'send_link'.tr(context),
                          style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────


  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: GoogleFonts.plusJakartaSans(fontSize: 13))),
          ],
        ),
        backgroundColor: const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF94A3B8)),
      prefixIcon: Icon(icon, color: const Color(0xFF64748B)),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF16A34A), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
    );
  }

  // ─── BUILD ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return UpdateOverlay(
      child: Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF0FDF4), Color(0xFFDCFCE7), Color(0xFFBBF7D0)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),

                      // Logo
                      Center(
                        child: Container(
                          width: 88, height: 88,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF16A34A).withValues(alpha: 0.25),
                                blurRadius: 24, spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.soup_kitchen, size: 44, color: Color(0xFF16A34A)),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Title
                      Center(
                        child: Text(
                          'welcome_back'.tr(context),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 32, fontWeight: FontWeight.bold,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          'welcome_desc'.tr(context),
                          style: GoogleFonts.plusJakartaSans(fontSize: 14, color: const Color(0xFF64748B)),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // ──────────────────────────────────────────────────
                      // PRIMARY: Google Sign In Button
                      // ──────────────────────────────────────────────────
                      SizedBox(
                        width: double.infinity, height: 56,
                        child: ElevatedButton(
                          onPressed: (_isLoading || _isGoogleLoading) ? null : _signInWithGoogle,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF1E293B),
                            disabledBackgroundColor: Colors.white.withValues(alpha: 0.7),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            elevation: 2,
                            shadowColor: Colors.black.withValues(alpha: 0.1),
                          ),
                          child: _isGoogleLoading
                              ? const SizedBox(
                                  width: 24, height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1E293B)),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Image.network(
                                      'https://www.google.com/favicon.ico',
                                      width: 24, height: 24,
                                      errorBuilder: (_, _, _) => const Icon(Icons.g_mobiledata, size: 28),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'continue_with_google'.tr(context),
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.w600, fontSize: 16,
                                        color: const Color(0xFF1E293B),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Divider
                      Row(
                        children: [
                          Expanded(child: Container(height: 1, color: const Color(0xFFE2E8F0))),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text('or_continue_with'.tr(context), style: GoogleFonts.plusJakartaSans(
                              fontSize: 12, color: const Color(0xFF94A3B8),
                            )),
                          ),
                          Expanded(child: Container(height: 1, color: const Color(0xFFE2E8F0))),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // ──────────────────────────────────────────────────
                      // SECONDARY: Email/Password (collapsible)
                      // ──────────────────────────────────────────────────
                      // Email/Password section with smooth animation
                      AnimatedCrossFade(
                        duration: const Duration(milliseconds: 300),
                        crossFadeState: _showEmailLogin
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        firstChild: Center(
                          child: TextButton.icon(
                            onPressed: () => setState(() => _showEmailLogin = true),
                            icon: const Icon(Icons.email_outlined, size: 20, color: Color(0xFF64748B)),
                            label: Text(
                              'Sign in with Email & Password',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14, fontWeight: FontWeight.w600,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ),
                        secondChild: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Email Field
                            Text('email'.tr(context), style: GoogleFonts.plusJakartaSans(
                              fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B),
                            )),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              decoration: _buildInputDecoration(hint: 'email_hint'.tr(context), icon: Icons.email_outlined),
                              validator: (value) {
                                if (!_showEmailLogin) return null;
                                if (value == null || value.trim().isEmpty) return 'enter_email'.tr(context);
                                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                                  return 'invalid_email'.tr(context);
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 16),

                            // Password Field
                            Text('password'.tr(context), style: GoogleFonts.plusJakartaSans(
                              fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B),
                            )),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _isLoading ? null : _signIn(),
                              decoration: _buildInputDecoration(
                                hint: 'password_hint'.tr(context),
                                icon: Icons.lock_outline,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                    color: const Color(0xFF64748B),
                                  ),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                              ),
                              validator: (value) {
                                if (!_showEmailLogin) return null;
                                if (value == null || value.isEmpty) return 'enter_password'.tr(context);
                                if (value.length < 6) return 'password_short'.tr(context);
                                return null;
                              },
                            ),

                            const SizedBox(height: 8),

                            // Forgot Password
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _showForgotPasswordSheet,
                                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 36)),
                                child: Text(
                                  'forgot_password'.tr(context),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13, fontWeight: FontWeight.w600,
                                    color: const Color(0xFF16A34A),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),

                            // Sign In Button
                            SizedBox(
                              width: double.infinity, height: 52,
                              child: ElevatedButton(
                                onPressed: (_isLoading || _isGoogleLoading) ? null : _signIn,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF16A34A),
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: const Color(0xFF16A34A).withValues(alpha: 0.6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  elevation: 0,
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 24, height: 24,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                      )
                                    : Text('sign_in'.tr(context), style: GoogleFonts.plusJakartaSans(
                                        fontSize: 16, fontWeight: FontWeight.bold,
                                      )),
                              ),
                            ),

                            const SizedBox(height: 14),

                            // Sign Up Link
                            Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'dont_have_account'.tr(context),
                                    style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF64748B)),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SignupScreen()));
                                    },
                                    child: Text(
                                      ' ${'sign_up'.tr(context)}',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF16A34A),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Guest Login
                      Center(
                        child: TextButton.icon(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context, MaterialPageRoute(builder: (_) => const MainLayout()),
                            );
                          },
                          icon: const Icon(Icons.person_outline, size: 18, color: Color(0xFF94A3B8)),
                          label: Text(
                            'continue_as_guest'.tr(context),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ),
      ),
      ),
      ),
    );
  }
}
