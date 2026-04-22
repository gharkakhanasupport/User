import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_screen.dart';

class PhoneVerificationScreen extends StatefulWidget {
  const PhoneVerificationScreen({super.key});

  @override
  State<PhoneVerificationScreen> createState() => _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState extends State<PhoneVerificationScreen>
    with SingleTickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _otpControllers = List.generate(4, (_) => TextEditingController());
  final _otpFocusNodes = List.generate(4, (_) => FocusNode());
  final _phoneFormKey = GlobalKey<FormState>();

  SupabaseClient get supabase => Supabase.instance.client;

  bool _isPhoneStep = true; // true = enter phone, false = enter OTP
  bool _isSending = false;
  bool _isVerifying = false;
  String _phone = '';
  String _generatedOtp = '';
  int _resendCooldown = 0;
  Timer? _resendTimer;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    _resendTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  // ─── Generate & Send OTP ──────────────────────────────────────────────
  Future<void> _sendOtp() async {
    if (!_phoneFormKey.currentState!.validate()) return;

    setState(() => _isSending = true);

    try {
      _phone = '+91${_phoneController.text.trim()}';
      
      // Check if phone number is already used by another verified account
      final existingUser = await supabase
          .from('users')
          .select('id')
          .eq('phone', _phone)
          .eq('phone_verified', true)
          .limit(1)
          .maybeSingle();
          
      if (existingUser != null) {
        final currentUserId = supabase.auth.currentUser?.id;
        if (existingUser['id'] != currentUserId) {
          setState(() => _isSending = false);
          _showError('This phone number is already registered with another account.');
          return;
        }
      }

      _generatedOtp = (1000 + Random().nextInt(9000)).toString();

      // Insert into sms_queue — the Bridge Phone will pick this up
      await supabase.from('sms_queue').insert({
        'phone': _phone,
        'otp': _generatedOtp,
        'status': 'pending',
      });

      // Switch to OTP entry
      if (mounted) {
        setState(() {
          _isPhoneStep = false;
          _isSending = false;
        });
        _startResendTimer();
        _animController.reset();
        _animController.forward();
        // Auto-focus first OTP box
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) _otpFocusNodes[0].requestFocus();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        _showError('Failed to send OTP. Please try again.');
      }
    }
  }

  void _startResendTimer() {
    _resendCooldown = 60;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCooldown <= 0) {
        timer.cancel();
      } else {
        if (mounted) setState(() => _resendCooldown--);
      }
    });
  }

  // ─── Verify OTP ───────────────────────────────────────────────────────
  Future<void> _verifyOtp() async {
    final enteredOtp = _otpControllers.map((c) => c.text).join();
    if (enteredOtp.length != 4) {
      _showError('Please enter the complete 4-digit OTP');
      return;
    }

    setState(() => _isVerifying = true);

    try {
      if (enteredOtp == _generatedOtp) {
        // OTP matches — update user profile
        final userId = supabase.auth.currentUser?.id;
        if (userId != null) {
          await supabase.from('users').update({
            'phone': _phone,
            'phone_verified': true,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', userId);
        }

        // Clean up: mark OTP as used
        try {
          await supabase
              .from('sms_queue')
              .update({'status': 'verified'})
              .eq('phone', _phone)
              .eq('otp', _generatedOtp);
        } catch (_) {}

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
            (route) => false,
          );
        }
      } else {
        if (mounted) {
          setState(() => _isVerifying = false);
          _showError('Invalid OTP. Please try again.');
          // Clear OTP fields
          for (final c in _otpControllers) {
            c.clear();
          }
          _otpFocusNodes[0].requestFocus();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isVerifying = false);
        _showError('Verification failed. Please try again.');
      }
    }
  }

  // ─── Resend OTP ───────────────────────────────────────────────────────
  Future<void> _resendOtp() async {
    if (_resendCooldown > 0) return;

    setState(() => _isSending = true);

    try {
      _generatedOtp = (1000 + Random().nextInt(9000)).toString();

      await supabase.from('sms_queue').insert({
        'phone': _phone,
        'otp': _generatedOtp,
        'status': 'pending',
      });

      if (mounted) {
        setState(() => _isSending = false);
        _startResendTimer();
        _showSuccess('OTP resent to $_phone');
        // Clear old OTP entries
        for (final c in _otpControllers) {
          c.clear();
        }
        _otpFocusNodes[0].requestFocus();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        _showError('Failed to resend OTP.');
      }
    }
  }

  // ─── Skip Verification ────────────────────────────────────────────────
  void _skipVerification() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────
  void _showError(String msg) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(msg, style: GoogleFonts.plusJakartaSans(fontSize: 13))),
        ]),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(msg, style: GoogleFonts.plusJakartaSans(fontSize: 13))),
        ]),
        backgroundColor: const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ─── BUILD ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF0FDF4), Color(0xFFDCFCE7), Color(0xFFBBF7D0)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),

                    // Icon
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF16A34A).withValues(alpha: 0.25),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Icon(
                        _isPhoneStep ? Icons.phone_android : Icons.sms_outlined,
                        size: 48,
                        color: const Color(0xFF16A34A),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Title
                    Text(
                      _isPhoneStep ? 'Verify Your Phone' : 'Enter OTP',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isPhoneStep
                          ? 'We\'ll send a verification code to\nyour phone number'
                          : 'Enter the 4-digit code sent to\n$_phone',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: const Color(0xFF64748B),
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 40),

                    if (_isPhoneStep) _buildPhoneStep() else _buildOtpStep(),

                    const SizedBox(height: 24),

                    // Skip button
                    TextButton(
                      onPressed: _skipVerification,
                      child: Text(
                        'Skip for now',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Phone Number Entry Step ──────────────────────────────────────────
  Widget _buildPhoneStep() {
    return Form(
      key: _phoneFormKey,
      child: Column(
        children: [
          // Phone Input
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                // Country Code
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  decoration: const BoxDecoration(
                    border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🇮🇳', style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 6),
                      Text(
                        '+91',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                ),
                // Phone Number
                Expanded(
                  child: TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                    decoration: InputDecoration(
                      hintText: '9876543210',
                      hintStyle: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFFCBD5E1),
                        fontSize: 18,
                        letterSpacing: 1.5,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                      counterText: '',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter your phone number';
                      }
                      if (value.trim().length != 10) {
                        return 'Phone number must be 10 digits';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Send OTP Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isSending ? null : _sendOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFF16A34A).withValues(alpha: 0.6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _isSending
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      'Send Verification Code',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── OTP Entry Step ───────────────────────────────────────────────────
  Widget _buildOtpStep() {
    return Column(
      children: [
        // OTP Boxes
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (index) {
            return Container(
              width: 64,
              height: 72,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              child: TextFormField(
                controller: _otpControllers[index],
                focusNode: _otpFocusNodes[index],
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 1,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFF16A34A), width: 2),
                  ),
                ),
                onChanged: (value) {
                  if (value.isNotEmpty && index < 3) {
                    _otpFocusNodes[index + 1].requestFocus();
                  } else if (value.isEmpty && index > 0) {
                    _otpFocusNodes[index - 1].requestFocus();
                  }
                  // Auto-verify when all 4 digits entered
                  if (index == 3 && value.isNotEmpty) {
                    final fullOtp = _otpControllers.map((c) => c.text).join();
                    if (fullOtp.length == 4) {
                      _verifyOtp();
                    }
                  }
                },
              ),
            );
          }),
        ),

        const SizedBox(height: 28),

        // Verify Button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isVerifying ? null : _verifyOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFF16A34A).withValues(alpha: 0.6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: _isVerifying
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Text(
                    'Verify & Continue',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),

        const SizedBox(height: 20),

        // Resend Timer / Button
        if (_resendCooldown > 0)
          Text(
            'Resend code in ${_resendCooldown}s',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: const Color(0xFF94A3B8),
            ),
          )
        else
          TextButton(
            onPressed: _isSending ? null : _resendOtp,
            child: Text(
              'Resend Code',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF16A34A),
              ),
            ),
          ),

        const SizedBox(height: 12),

        // Change number
        TextButton(
          onPressed: () {
            setState(() {
              _isPhoneStep = true;
              for (final c in _otpControllers) {
                c.clear();
              }
            });
            _resendTimer?.cancel();
            _animController.reset();
            _animController.forward();
          },
          child: Text(
            'Change Phone Number',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B),
            ),
          ),
        ),
      ],
    );
  }
}
