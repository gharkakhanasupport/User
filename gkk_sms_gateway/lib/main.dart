import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:another_telephony/telephony.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// ============================================================
/// GKK SMS Gateway — Robust Version
/// ============================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://mwnpwuxrbaousgwgoyco.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im13bnB3dXhyYmFvdXNnd2dveWNvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc5ODU2MzYsImV4cCI6MjA4MzU2MTYzNn0.dTM9rguaiuHbrr59iPUsM5znDzXhOdRXbPQ11yOfZpM',
  );

  _initForegroundTask();
  runApp(const GKKGatewayApp());
}

void _initForegroundTask() {
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'gkk_sms_gateway_channel',
      channelName: 'GKK SMS Gateway (Always Active)',
      channelDescription: 'Maintains the SMS bridge connection',
      channelImportance: NotificationChannelImportance.MAX,
      priority: NotificationPriority.HIGH,
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: true,
      playSound: false,
    ),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.repeat(5000),
      autoRunOnBoot: true,
      autoRunOnMyPackageReplaced: true,
      allowWakeLock: true,
      allowWifiLock: true,
    ),
  );
}

class GKKGatewayApp extends StatelessWidget {
  const GKKGatewayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GKK SMS Gateway',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF16A34A),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.plusJakartaSansTextTheme(ThemeData.dark().textTheme),
      ),
      home: const GatewayScreen(),
    );
  }
}

class GatewayScreen extends StatefulWidget {
  const GatewayScreen({super.key});

  @override
  State<GatewayScreen> createState() => _GatewayScreenState();
}

class _GatewayScreenState extends State<GatewayScreen> {
  final Telephony telephony = Telephony.instance;
  final supabase = Supabase.instance.client;

  bool _isRunning = false;
  bool _hasPermission = false;
  int _sentCount = 0;
  int _failedCount = 0;
  final List<_SmsLog> _logs = [];
  RealtimeChannel? _channel;
  Timer? _pollingTimer;
  final Set<String> _processingIds = {};

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  @override
  void dispose() {
    _stopGateway();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    final granted = await telephony.requestSmsPermissions ?? false;
    if (mounted) setState(() => _hasPermission = granted);
  }

  // ─── Gateway Lifecycle ────────────────────────────────────────────────
  void _startGateway() async {
    if (!_hasPermission) {
      _addLog('❌ Permissions missing!', isError: true);
      return;
    }

    // Start Foreground Service
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.restartService();
    } else {
      await FlutterForegroundTask.startService(
        notificationTitle: 'GKK Gateway Active',
        notificationText: 'Listening for OTP requests...',
        callback: null, // Basic foreground task
      );
    }

    setState(() => _isRunning = true);
    _addLog('🟢 Gateway Online');

    // Subscribe to Realtime
    _channel = supabase
        .channel('sms_queue_channel')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'sms_queue',
          callback: (payload) {
            final newRecord = payload.newRecord;
            if (newRecord['status'] == 'pending') {
              final id = newRecord['id'] as String;
              final phone = newRecord['phone'] as String;
              final otp = newRecord['otp'] as String;
              _sendSms(id, phone, otp); // Process INSTANTLY from payload
            }
          },
        )
        .subscribe((status, [error]) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            _addLog('⚡ Realtime connected — Ready for instant OTPs');
          } else if (status == RealtimeSubscribeStatus.channelError) {
            _addLog('⚠️ Realtime error: $error', isError: true);
          }
        });

    _processQueue();

    // Reliable Polling (Every 2 seconds as fallback)
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (_) => _processQueue());
  }

  void _stopGateway() async {
    await FlutterForegroundTask.stopService();
    _channel?.unsubscribe();
    _pollingTimer?.cancel();
    if (mounted) setState(() => _isRunning = false);
    _addLog('🔴 Gateway Offline');
  }

  // ─── Queue Processing ──────────────────────────────────────────────────
  bool _isBusy = false;
  Future<void> _processQueue() async {
    if (_isBusy) return;
    _isBusy = true;

    try {
      final pending = await supabase
          .from('sms_queue')
          .select()
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      if (pending.isEmpty) return;

      final Set<String> processedPhones = {};
      final List<String> oldIds = [];

      for (final row in pending) {
        final id = row['id'] as String;
        final phone = row['phone'] as String;
        final otp = row['otp'] as String;

        if (_processingIds.contains(id)) continue;

        // Skip older OTPs for the same phone
        if (processedPhones.contains(phone)) {
          oldIds.add(id);
          continue;
        }

        processedPhones.add(phone);
        _processingIds.add(id);
        
        // Execute SMS sending
        _sendSms(id, phone, otp).whenComplete(() => _processingIds.remove(id));
        await Future.delayed(const Duration(milliseconds: 200));
      }

      // Cleanup old OTPs
      if (oldIds.isNotEmpty) {
        await supabase.from('sms_queue').update({'status': 'failed'}).inFilter('id', oldIds);
      }
    } catch (e) {
      _addLog('⚠️ Sync Error: $e', isError: true);
    } finally {
      _isBusy = false;
    }
  }

  // ─── SMS Logic ────────────────────────────────────────────────────────
  Future<void> _sendSms(String id, String phone, String otp) async {
    try {
      // Added 2-second delay to prevent "instant" firing rejections from carriers
      await Future.delayed(const Duration(seconds: 2));

      // Clean phone number
      String cleanPhone = phone.replaceAll(RegExp(r'\s+'), '');
      if (!cleanPhone.startsWith('+')) cleanPhone = '+$cleanPhone';

      _addLog('📤 Sending $otp to $cleanPhone...');

      await telephony.sendSms(
        to: cleanPhone,
        message: 'Hello! Use $otp as your login code for Ghar Ka Khana. Valid for 5 minutes.',
        statusListener: (status) async {
          if (status == SendStatus.SENT) {
            _addLog('✅ SENT: $cleanPhone');
            await _updateDbStatus(id, 'sent');
            if (mounted) setState(() => _sentCount++);
          } else {
            _addLog('❌ FAILED: Carrier rejected $cleanPhone', isError: true);
            await _updateDbStatus(id, 'failed');
            if (mounted) setState(() => _failedCount++);
          }
        },
      );
    } catch (e) {
      _addLog('❌ ERROR: $e', isError: true);
      await _updateDbStatus(id, 'failed');
    }
  }

  Future<void> _updateDbStatus(String id, String status) async {
    try {
      await supabase.from('sms_queue').update({'status': status}).eq('id', id);
    } catch (e) {
      _addLog('⚠️ DB Update failed: $id', isError: true);
    }
  }

  void _addLog(String msg, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _logs.insert(0, _SmsLog(message: msg, time: DateTime.now(), isError: isError));
      if (_logs.length > 50) _logs.removeLast();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('GKK SMS Bridge', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _processQueue,
            tooltip: 'Manual Sync',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF1E293B),
            child: Row(
              children: [
                _statCard('Sent', '$_sentCount', Colors.green),
                const SizedBox(width: 12),
                _statCard('Failed', '$_failedCount', Colors.red),
                const SizedBox(width: 12),
                _statCard('Active', _isRunning ? 'YES' : 'NO', _isRunning ? Colors.blue : Colors.grey),
              ],
            ),
          ),
          if (!_hasPermission)
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.red.withAlpha(51),
              child: const Text('⚠️ SMS Permission Missing! Grant in Settings.', textAlign: TextAlign.center),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _logs.length,
              itemBuilder: (ctx, i) {
                final log = _logs[i];
                return ListTile(
                  dense: true,
                  leading: Text('${log.time.hour}:${log.time.minute}:${log.time.second}', 
                    style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  title: Text(log.message, 
                    style: TextStyle(color: log.isError ? Colors.redAccent : Colors.white70, fontSize: 13)),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: _isRunning ? _stopGateway : _startGateway,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isRunning ? Colors.red : Colors.green,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(_isRunning ? 'SHUTDOWN GATEWAY' : 'START GATEWAY', 
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ),
      ),
    );
  }

  Widget _statCard(String label, String val, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withAlpha(25),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withAlpha(76)),
        ),
        child: Column(
          children: [
            Text(val, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class _SmsLog {
  final String message;
  final DateTime time;
  final bool isError;
  _SmsLog({required this.message, required this.time, this.isError = false});
}
