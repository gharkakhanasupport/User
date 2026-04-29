import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'theme/app_colors.dart';
import 'widgets/global_overlay.dart';
import 'widgets/update_overlay.dart';
import 'screens/splash_screen.dart';
import 'screens/main_layout.dart';
import 'screens/login_screen.dart';
import 'screens/phone_verification_screen.dart';
import 'providers/app_state.dart';
import 'services/fcm_service.dart';
import 'services/config_service.dart';
import 'services/in_app_notification_service.dart';
import 'package:responsive_framework/responsive_framework.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Log errors to console during development
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('❌ Flutter Error: ${details.exception}');
  };

  // Hardcoded fallback values (used when .env fails to load)
  const fallbackUrl = 'https://mwnpwuxrbaousgwgoyco.supabase.co';
  const fallbackAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im13bnB3dXhyYmFvdXNnd2dveWNvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc5ODU2MzYsImV4cCI6MjA4MzU2MTYzNn0.dTM9rguaiuHbrr59iPUsM5znDzXhOdRXbPQ11yOfZpM';

  // Load environment variables
  bool envLoaded = false;
  try {
    await dotenv.load(fileName: '.env');
    envLoaded = true;
    debugPrint('✅ Environment loaded');
  } catch (e) {
    debugPrint('⚠️ .env load failed: $e (using fallback values)');
  }

  // Read env values safely (dotenv.env throws if not loaded)
  String supabaseUrl = fallbackUrl;
  String supabaseAnonKey = fallbackAnonKey;
  if (envLoaded) {
    supabaseUrl = dotenv.env['SUPABASE_URL'] ?? fallbackUrl;
    supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? fallbackAnonKey;
  }

  // Initialize Firebase
  try {
    await Firebase.initializeApp();
    debugPrint('✅ Firebase initialized');
  } catch (e) {
    debugPrint('⚠️ Firebase init failed: $e');
  }

  // Initialize Supabase — MUST happen before runApp
  try {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
      debug: false,
    );
    debugPrint('✅ Supabase initialized');
  } catch (e) {
    debugPrint('❌ Supabase init failed: $e');
  }

  // Initialize global App State (Themes and Language)
  await AppState().initialize();

  // Initialize FCM push notifications (non-blocking)
  // Token registration happens after login via auth listener.
  FCMService().initialize();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    // Share the navigator key with InAppNotificationService
    InAppNotificationService.setNavigatorKey(_navigatorKey);
    // Delay auth listener setup to ensure Supabase is initialized by SplashScreen
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        _setupAuthListener();
      }
    });
  }

  void _setupAuthListener() {
    try {
      Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        final event = data.event;
        
        if (event == AuthChangeEvent.signedIn) {
          // User signed in (including email confirmation)
          // Register FCM token for push notifications (fire-and-forget)
          FCMService().registerTokenWithSupabase('customer');
          // Start in-app order notifications
          InAppNotificationService().startListening();
          _checkPhoneVerificationAndNavigate();
        } else if (event == AuthChangeEvent.signedOut) {
          // Stop in-app notifications
          InAppNotificationService().stopListening();
          // User signed out
          _navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        }
      });
    } catch (e) {
      debugPrint('Auth listener setup error: $e');
    }
  }

  Future<void> _checkPhoneVerificationAndNavigate() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    
    try {
      final userData = await Supabase.instance.client
          .from('users')
          .select('phone_verified')
          .eq('id', user.id)
          .maybeSingle();
          
      final phoneVerified = userData?['phone_verified'] == true;
      
      if (mounted) {
        // Bypass verification if disabled by admin
        if (!ConfigService().isOtpEnabled) {
          _navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const MainLayout()),
            (route) => false,
          );
          return;
        }

        if (phoneVerified) {
          _navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const MainLayout()),
            (route) => false,
          );
        } else {
          _navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const PhoneVerificationScreen()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        if (!ConfigService().isOtpEnabled) {
          _navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const MainLayout()),
            (route) => false,
          );
        } else {
          _navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const PhoneVerificationScreen()),
            (route) => false,
          );
        }
      }
    }
  }

  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState(),
      builder: (context, _) {
        return MaterialApp(
          navigatorKey: _navigatorKey,
          scaffoldMessengerKey: scaffoldMessengerKey,
          debugShowCheckedModeBanner: false,
          title: 'Ghar Ka Khana',
          locale: AppState().locale,
          supportedLocales: const [
            Locale('en'),
            Locale('hi'),
            Locale('bn'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary, brightness: Brightness.light),
            useMaterial3: true,
            textTheme: GoogleFonts.plusJakartaSansTextTheme(),
            scaffoldBackgroundColor: AppColors.backgroundLight,
          ),
          builder: (context, child) {
            if (child == null) return const SizedBox.shrink();
            
            return ResponsiveBreakpoints.builder(
              child: Builder(
                builder: (childContext) {
                  return BouncingScrollWrapper.builder(
                    childContext,
                    Container(
                      color: AppColors.backgroundLight,
                      child: MaxWidthBox(
                        maxWidth: 600,
                        child: ResponsiveScaledBox(
                          width: ResponsiveValue<double>(childContext, 
                            defaultValue: 450.0,
                            conditionalValues: [
                              Condition.equals(name: MOBILE, value: 450),
                              Condition.between(start: 800, end: 1100, value: 800),
                              Condition.between(start: 1000, end: 1200, value: 1000),
                            ]
                          ).value,
                          child: GlobalOverlay(
                            key: GlobalOverlayController.overlayKey,
                            child: UpdateOverlay(
                              child: child,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }
              ),
              breakpoints: [
                const Breakpoint(start: 0, end: 450, name: MOBILE),
                const Breakpoint(start: 451, end: 800, name: TABLET),
                const Breakpoint(start: 801, end: 1920, name: DESKTOP),
                const Breakpoint(start: 1921, end: double.infinity, name: '4K'),
              ],
            );
          },
          home: const SplashScreen(),
        );
      },
    );
  }
}
