import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Flutter Local Notifications plugin instance for background handler
final FlutterLocalNotificationsPlugin _bgLocalNotifications =
    FlutterLocalNotificationsPlugin();

/// Personalize message by replacing @user with actual user name
/// This is a top-level function so it can be used in background handler
String _personalizeMessageStatic(String text) {
  try {
    final user = Supabase.instance.client.auth.currentUser;
    final userName = user?.userMetadata?['full_name'] ?? 
                     user?.userMetadata?['name'] ?? 
                     'User';
    return text.replaceAll('@user', userName);
  } catch (e) {
    debugPrint('⚠️ Personalization error: $e');
    return text.replaceAll('@user', 'User');
  }
}

/// Download image from URL - top-level function for background handler
/// Returns local file path or null if failed
Future<String?> _downloadImageStatic(String imageUrl) async {
  try {
    debugPrint('📥 BG: Downloading image from: $imageUrl');
    
    final uri = Uri.tryParse(imageUrl);
    if (uri == null || !uri.hasScheme) return null;
    
    final response = await http.get(uri).timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw Exception('Timeout'),
    );
    
    if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
      final tempDir = await getTemporaryDirectory();
      final fileName = 'bg_notification_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(response.bodyBytes);
      
      if (await file.exists() && await file.length() > 0) {
        debugPrint('✅ BG: Image downloaded: ${file.path}');
        return file.path;
      }
    }
  } catch (e) {
    debugPrint('⚠️ BG: Image download error: $e');
  }
  return null;
}

/// Top-level function to handle background/terminated state messages
/// Must be a top-level function (not a class method)
/// 
/// Now handles DATA-ONLY messages and shows personalized notifications
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase (required for background isolate)
  await Firebase.initializeApp();
  
  debugPrint('🔔 Background message received');
  debugPrint('📦 Data payload: ${message.data}');
  
  // Handle DATA messages (sent from Admin app)
  final data = message.data;
  if (data.isNotEmpty && data['title'] != null) {
    // Initialize Supabase for personalization
    try {
      await dotenv.load(fileName: ".env");
      await Supabase.initialize(
        url: dotenv.env['SUPABASE_URL'] ?? '',
        anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
      );
    } catch (e) {
      // Supabase might already be initialized or dotenv might fail
      debugPrint('⚠️ Supabase background init error: $e');
    }
    
    // Personalize the message
    final title = _personalizeMessageStatic(data['title'] ?? 'GharKaKhana');
    final body = _personalizeMessageStatic(data['body'] ?? '');
    final imageUrl = data['image_url'];
    
    // Initialize local notifications
    const androidSettings = AndroidInitializationSettings('@drawable/ic_notification');
    const initSettings = InitializationSettings(android: androidSettings);
    await _bgLocalNotifications.initialize(initSettings);
    
    // Create notification channel
    const androidChannel = AndroidNotificationChannel(
      'gkk_notifications',
      'GharKaKhana Notifications',
      description: 'Notifications from GharKaKhana',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );
    
    await _bgLocalNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
    
    // Build notification details (with or without image)
    AndroidNotificationDetails androidDetails;
    final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    
    if (imageUrl != null && imageUrl.isNotEmpty) {
      // First show text notification immediately
      androidDetails = AndroidNotificationDetails(
        'gkk_notifications',
        'GharKaKhana Notifications',
        channelDescription: 'Notifications from GharKaKhana',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        icon: '@drawable/ic_notification',
        color: Color(0xFF2da832),
        enableVibration: true,
        playSound: true,
      );
      
      await _bgLocalNotifications.show(
        notificationId,
        title,
        body,
        NotificationDetails(android: androidDetails),
      );
      
      // Then try to download image and update notification
      final localImagePath = await _downloadImageStatic(imageUrl);
      if (localImagePath != null) {
        final bigPictureStyle = BigPictureStyleInformation(
          FilePathAndroidBitmap(localImagePath),
          contentTitle: title,
          summaryText: body,
          htmlFormatContentTitle: true,
          htmlFormatSummaryText: true,
        );
        
        androidDetails = AndroidNotificationDetails(
          'gkk_notifications',
          'GharKaKhana Notifications',
          channelDescription: 'Notifications from GharKaKhana',
          importance: Importance.high,
          priority: Priority.high,
          showWhen: true,
          icon: '@drawable/ic_notification',
          color: Color(0xFF2da832),
          enableVibration: true,
          playSound: false, // No sound on update
          styleInformation: bigPictureStyle,
          largeIcon: FilePathAndroidBitmap(localImagePath),
        );
        
        // Update notification with image
        await _bgLocalNotifications.show(
          notificationId, // Same ID to update
          title,
          body,
          NotificationDetails(android: androidDetails),
        );
        debugPrint('✅ BG notification updated with image');
      }
    } else {
      androidDetails = const AndroidNotificationDetails(
        'gkk_notifications',
        'GharKaKhana Notifications',
        channelDescription: 'Notifications from GharKaKhana',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        icon: '@drawable/ic_notification',
        color: Color(0xFF2da832),
        enableVibration: true,
        playSound: true,
      );
      
      await _bgLocalNotifications.show(
        notificationId,
        title,
        body,
        NotificationDetails(android: androidDetails),
      );
    }
    
    debugPrint('✅ Background notification shown: $title');
  }
}

/// FCM Push Notification Service for receiving notifications from Admin app.
/// 
/// This service:
/// 1. Initializes Firebase Messaging
/// 2. Subscribes to the 'all_users' topic
/// 3. Handles foreground, background, and terminated state notifications
/// 4. Personalizes @user placeholders with actual user name
class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Initialize FCM and set up notification handlers
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Set up background message handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Request notification permissions
      await _requestPermissions();

      // Initialize local notifications for foreground display
      await _initializeLocalNotifications();

      // Subscribe to the all_users topic to receive broadcast messages
      await _subscribeToTopic();

      // Set up foreground message handler
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle notification tap when app is in background/terminated
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Check if app was opened from a notification
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }

      // Get FCM token for debugging
      final token = await _messaging.getToken();
      debugPrint('📱 FCM Token: $token');

      _isInitialized = true;
      debugPrint('✅ FCM Service initialized successfully');
    } catch (e) {
      debugPrint('❌ FCM initialization error: $e');
    }
  }

  /// Request notification permissions from the user
  Future<void> _requestPermissions() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    debugPrint('🔐 Notification permission status: ${settings.authorizationStatus}');
  }

  /// Initialize local notifications for displaying when app is in foreground
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@drawable/ic_notification');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        debugPrint('📲 Local notification tapped: ${response.payload}');
        // Handle notification tap here
      },
    );

    // Create notification channel for Android
    const androidChannel = AndroidNotificationChannel(
      'gkk_notifications',
      'GharKaKhana Notifications',
      description: 'Notifications from GharKaKhana',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  /// Subscribe to the all_users topic for broadcast messages
  Future<void> _subscribeToTopic() async {
    await _messaging.subscribeToTopic('all_users');
    debugPrint('✅ Subscribed to topic: all_users');
  }

  /// Handle foreground messages - show local notification with personalization
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('🔔 Foreground message received');
    debugPrint('📦 Data: ${message.data}');

    // Handle DATA messages (from Admin app)
    final data = message.data;
    if (data.isNotEmpty && data['title'] != null) {
      // Personalize the message by replacing @user with actual name
      final personalizedTitle = _personalizeMessage(data['title'] ?? 'GharKaKhana');
      final personalizedBody = _personalizeMessage(data['body'] ?? '');
      final imageUrl = data['image_url'];
      
      // Fire and forget - don't await
      _showNotificationWithImage(
        title: personalizedTitle,
        body: personalizedBody,
        payload: jsonEncode(data),
        imageUrl: imageUrl,
      );
    }
  }
  
  /// Wrapper to show notification with optional image (handles async)
  /// Shows text notification immediately, then updates with image when ready
  Future<void> _showNotificationWithImage({
    required String title,
    required String body,
    String? payload,
    String? imageUrl,
  }) async {
    final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    
    try {
      if (imageUrl != null && imageUrl.isNotEmpty) {
        // Step 1: Show text notification immediately (don't wait for image)
        await _showLocalNotificationWithId(
          id: notificationId,
          title: title,
          body: body,
          payload: payload,
        );
        
        // Step 2: Download image in background
        final localImagePath = await _downloadImage(imageUrl);
        
        // Step 3: Update notification with image if download succeeded
        if (localImagePath != null) {
          await _showLocalNotificationWithId(
            id: notificationId, // Same ID to replace the notification
            title: title,
            body: body,
            payload: payload,
            localImagePath: localImagePath,
          );
          debugPrint('✅ Notification updated with image');
        }
      } else {
        // No image, just show text notification
        await _showLocalNotificationWithId(
          id: notificationId,
          title: title,
          body: body,
          payload: payload,
        );
      }
    } catch (e) {
      debugPrint('⚠️ Notification error: $e');
      // Fallback to simple notification
      await _showLocalNotification(title: title, body: body, payload: payload);
    }
  }

  /// Personalize message by replacing placeholders with user data
  /// Supports: @user - replaced with user's display name
  String _personalizeMessage(String text) {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final userName = user?.userMetadata?['full_name'] ?? 
                       user?.userMetadata?['name'] ?? 
                       'User';
      
      // Replace @user with actual name
      return text.replaceAll('@user', userName);
    } catch (e) {
      debugPrint('⚠️ Personalization error: $e');
      return text.replaceAll('@user', 'User');
    }
  }

  /// Download image from URL and save to temporary file
  /// Returns the local file path or null if failed
  /// Has 8 second timeout to prevent blocking
  Future<String?> _downloadImage(String imageUrl) async {
    try {
      debugPrint('📥 Downloading image from: $imageUrl');
      
      // Validate URL
      final uri = Uri.tryParse(imageUrl);
      if (uri == null || !uri.hasScheme) {
        debugPrint('⚠️ Invalid image URL');
        return null;
      }
      
      // Download with timeout
      final response = await http.get(uri).timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          debugPrint('⚠️ Image download timed out');
          throw Exception('Download timeout');
        },
      );
      
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        final tempDir = await getTemporaryDirectory();
        final fileName = 'notification_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);
        
        // Verify file exists and has content
        if (await file.exists() && await file.length() > 0) {
          debugPrint('✅ Image downloaded: ${file.path} (${response.bodyBytes.length} bytes)');
          return file.path;
        }
      } else {
        debugPrint('⚠️ Image download failed: status ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('⚠️ Image download error: $e');
    }
    return null;
  }

  /// Show a local notification with optional image (image should be pre-downloaded)
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
    String? localImagePath,
  }) async {
    // Build Android notification details with optional BigPicture style
    AndroidNotificationDetails androidDetails;
    
    if (localImagePath != null) {
      // Show notification with downloaded image
      try {
        final BigPictureStyleInformation bigPictureStyle = BigPictureStyleInformation(
          FilePathAndroidBitmap(localImagePath),
          contentTitle: title,
          summaryText: body,
          htmlFormatContentTitle: true,
          htmlFormatSummaryText: true,
        );
        
        androidDetails = AndroidNotificationDetails(
          'gkk_notifications',
          'GharKaKhana Notifications',
          channelDescription: 'Notifications from GharKaKhana',
          importance: Importance.high,
          priority: Priority.high,
          showWhen: true,
          icon: '@drawable/ic_notification',
          color: const Color(0xFF2da832),
          enableVibration: true,
          playSound: true,
          styleInformation: bigPictureStyle,
          largeIcon: FilePathAndroidBitmap(localImagePath),
        );
      } catch (e) {
        debugPrint('⚠️ Image notification failed: $e');
        androidDetails = const AndroidNotificationDetails(
          'gkk_notifications',
          'GharKaKhana Notifications',
          channelDescription: 'Notifications from GharKaKhana',
          importance: Importance.high,
          priority: Priority.high,
          showWhen: true,
          icon: '@drawable/ic_notification',
          color: Color(0xFF2da832),
          enableVibration: true,
          playSound: true,
        );
      }
    } else {
      androidDetails = const AndroidNotificationDetails(
        'gkk_notifications',
        'GharKaKhana Notifications',
        channelDescription: 'Notifications from GharKaKhana',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        icon: '@drawable/ic_notification',
        color: Color(0xFF2da832),
        enableVibration: true,
        playSound: true,
      );
    }

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Show a local notification with a specific ID (for updating notifications)
  Future<void> _showLocalNotificationWithId({
    required int id,
    required String title,
    required String body,
    String? payload,
    String? localImagePath,
  }) async {
    // Build Android notification details with optional BigPicture style
    AndroidNotificationDetails androidDetails;
    
    if (localImagePath != null) {
      try {
        final BigPictureStyleInformation bigPictureStyle = BigPictureStyleInformation(
          FilePathAndroidBitmap(localImagePath),
          contentTitle: title,
          summaryText: body,
          htmlFormatContentTitle: true,
          htmlFormatSummaryText: true,
        );
        
        androidDetails = AndroidNotificationDetails(
          'gkk_notifications',
          'GharKaKhana Notifications',
          channelDescription: 'Notifications from GharKaKhana',
          importance: Importance.high,
          priority: Priority.high,
          showWhen: true,
          icon: '@drawable/ic_notification',
          color: const Color(0xFF2da832),
          enableVibration: true,
          playSound: false, // Don't play sound on update
          styleInformation: bigPictureStyle,
          largeIcon: FilePathAndroidBitmap(localImagePath),
        );
      } catch (e) {
        debugPrint('⚠️ Image notification failed: $e');
        androidDetails = const AndroidNotificationDetails(
          'gkk_notifications',
          'GharKaKhana Notifications',
          channelDescription: 'Notifications from GharKaKhana',
          importance: Importance.high,
          priority: Priority.high,
          showWhen: true,
          icon: '@drawable/ic_notification',
          color: Color(0xFF2da832),
          enableVibration: true,
          playSound: true,
        );
      }
    } else {
      androidDetails = const AndroidNotificationDetails(
        'gkk_notifications',
        'GharKaKhana Notifications',
        channelDescription: 'Notifications from GharKaKhana',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        icon: '@drawable/ic_notification',
        color: Color(0xFF2da832),
        enableVibration: true,
        playSound: true,
      );
    }

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      id, // Use specific ID for updates
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Handle notification tap when app is in background/terminated
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('📲 Notification tapped: ${message.notification?.title}');
    // Navigate to specific screen based on message data if needed
    // You can use a navigation service or global navigator key here
  }

  /// Unsubscribe from the all_users topic
  Future<void> unsubscribeFromTopic() async {
    await _messaging.unsubscribeFromTopic('all_users');
    debugPrint('🚫 Unsubscribed from topic: all_users');
  }

  /// Get the current FCM token
  Future<String?> getToken() async {
    return await _messaging.getToken();
  }
}

