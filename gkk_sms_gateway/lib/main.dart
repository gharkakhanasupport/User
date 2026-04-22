import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:another_telephony/telephony.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://mwnpwuxrbaousgwgoyco.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im13bnB3dXhyYmFvdXNnd2dveWNvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc5ODU2MzYsImV4cCI6MjA4MzU2MTYzNn0.dTM9rguaiuHbrr59iPUsM5znDzXhOdRXbPQ11yOfZpM',
  );

  runApp(const GKKGatewayApp());
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
        textTheme: GoogleFonts.plusJakartaSansTextTheme(
          ThemeData.dark().textTheme,
        ),
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

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  @override
  void dispose() {
    _stopListening();
    super.dispose();
  }

  // ─── Check SMS Permissions ─────────────────────────────────────────────
  Future<void> _checkPermissions() async {
    final granted = await telephony.requestSmsPermissions ?? false;
    if (mounted) {
      setState(() => _hasPermission = granted);
    }
  }

  // ─── Start Listening to sms_queue ─────────────────────────────────────
  void _startListening() {
    if (!_hasPermission) {
      _addLog('❌ SMS permission not granted', isError: true);
      return;
    }

    setState(() => _isRunning = true);
    _addLog('🟢 Gateway started — listening for OTP requests...');

    // Subscribe to Realtime INSERT events on sms_queue
    _channel = supabase
        .channel('sms_queue_channel')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'sms_queue',
          callback: (payload) {
            final newRecord = payload.newRecord;
            final phone = newRecord['phone'] as String?;
            final otp = newRecord['otp'] as String?;
            final id = newRecord['id'] as String?;
            final status = newRecord['status'] as String?;

            if (phone != null && otp != null && status == 'pending') {
              _sendSms(id!, phone, otp);
            }
          },
        )
        .subscribe();

    // Also process any pending messages that were queued before we started
    _processPending();
  }

  // ─── Stop Listening ────────────────────────────────────────────────────
  void _stopListening() {
    _channel?.unsubscribe();
    _channel = null;
    if (mounted) {
      setState(() => _isRunning = false);
      _addLog('🔴 Gateway stopped');
    }
  }

  // ─── Process Pending SMS (on startup) ─────────────────────────────────
  Future<void> _processPending() async {
    try {
      final pending = await supabase
          .from('sms_queue')
          .select()
          .eq('status', 'pending')
          .order('created_at', ascending: true);

      for (final row in pending) {
        final phone = row['phone'] as String?;
        final otp = row['otp'] as String?;
        final id = row['id'] as String?;

        if (phone != null && otp != null && id != null) {
          await _sendSms(id, phone, otp);
          // Small delay between messages to avoid SIM throttling
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    } catch (e) {
      _addLog('⚠️ Error processing pending: $e', isError: true);
    }
  }

  // ─── Send SMS via SIM Card ─────────────────────────────────────────────
  Future<void> _sendSms(String id, String phone, String otp) async {
    try {
      _addLog('📤 Sending OTP $otp to $phone...');

      await telephony.sendSms(
        to: phone,
        message: 'Your GKK verification code is $otp. Do not share this with anyone. - Ghar Ka Khana',
        statusListener: (status) {
          if (status == SendStatus.SENT) {
            _addLog('✅ SMS sent to $phone');
          } else if (status == SendStatus.DELIVERED) {
            _addLog('📬 SMS delivered to $phone');
          }
        },
      );

      // Update status in database
      await supabase
          .from('sms_queue')
          .update({'status': 'sent'})
          .eq('id', id);

      if (mounted) {
        setState(() => _sentCount++);
      }
    } catch (e) {
      _addLog('❌ Failed to send to $phone: $e', isError: true);

      // Mark as failed
      try {
        await supabase
            .from('sms_queue')
            .update({'status': 'failed'})
            .eq('id', id);
      } catch (_) {}

      if (mounted) {
        setState(() => _failedCount++);
      }
    }
  }

  // ─── Add Log Entry ─────────────────────────────────────────────────────
  void _addLog(String message, {bool isError = false}) {
    if (mounted) {
      setState(() {
        _logs.insert(0, _SmsLog(
          message: message,
          time: DateTime.now(),
          isError: isError,
        ));
        // Keep only last 50 logs
        if (_logs.length > 50) _logs.removeLast();
      });
    }
  }

  // ─── BUILD ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _isRunning ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'GKK SMS Gateway',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: [
          // Permission indicator
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(
              _hasPermission ? Icons.check_circle : Icons.warning,
              color: _hasPermission ? const Color(0xFF22C55E) : Colors.amber,
              size: 20,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── Stats Cards ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF1E293B),
            child: Row(
              children: [
                _buildStatCard('Sent', _sentCount.toString(), const Color(0xFF22C55E)),
                const SizedBox(width: 12),
                _buildStatCard('Failed', _failedCount.toString(), const Color(0xFFEF4444)),
                const SizedBox(width: 12),
                _buildStatCard('Status', _isRunning ? 'ON' : 'OFF',
                    _isRunning ? const Color(0xFF22C55E) : const Color(0xFF64748B)),
              ],
            ),
          ),

          // ─── Permission Warning ──────────────────────────────────
          if (!_hasPermission)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.amber.withValues(alpha: 0.15),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: Colors.amber, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SMS Permission Required',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            color: Colors.amber,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Go to Settings > Apps > GKK SMS Gateway > Allow Restricted Settings, then enable SMS.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: Colors.amber.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _checkPermissions,
                    child: Text('Retry', style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold, color: Colors.amber,
                    )),
                  ),
                ],
              ),
            ),

          // ─── Logs ─────────────────────────────────────────────────
          Expanded(
            child: _logs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.sms_outlined, size: 48, color: Colors.white.withValues(alpha: 0.2)),
                        const SizedBox(height: 16),
                        Text(
                          _isRunning ? 'Waiting for OTP requests...' : 'Tap START to begin',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      final log = _logs[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: log.isError
                              ? const Color(0xFFEF4444).withValues(alpha: 0.1)
                              : const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: log.isError
                                ? const Color(0xFFEF4444).withValues(alpha: 0.3)
                                : const Color(0xFF334155),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${log.time.hour.toString().padLeft(2, '0')}:${log.time.minute.toString().padLeft(2, '0')}:${log.time.second.toString().padLeft(2, '0')}',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 11,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                log.message,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  color: log.isError
                                      ? const Color(0xFFFCA5A5)
                                      : Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),

      // ─── Start / Stop Button ──────────────────────────────────────
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        color: const Color(0xFF1E293B),
        child: SafeArea(
          child: SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: _isRunning ? _stopListening : _startListening,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isRunning ? const Color(0xFFEF4444) : const Color(0xFF22C55E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_isRunning ? Icons.stop_circle : Icons.play_circle, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    _isRunning ? 'STOP GATEWAY' : 'START GATEWAY',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: color.withValues(alpha: 0.7),
              ),
            ),
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

  _SmsLog({
    required this.message,
    required this.time,
    this.isError = false,
  });
}
