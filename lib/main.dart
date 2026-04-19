import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'theme/app_colors.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'providers/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
          _navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
            (route) => false,
          );
        } else if (event == AuthChangeEvent.signedOut) {
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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState(),
      builder: (context, _) {
        return MaterialApp(
          navigatorKey: _navigatorKey,
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
            textTheme: GoogleFonts.poppinsTextTheme(),
            scaffoldBackgroundColor: AppColors.backgroundLight,
          ),
          home: const SplashScreen(),
        );
      }
    );
  }
}
