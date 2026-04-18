import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Admin-controlled rate limit settings fetched from Supabase.
class ChatSettings {
  final int chatsPerDay;
  final int messagesPerChat;
  final bool rateLimitingEnabled;

  const ChatSettings({
    this.chatsPerDay = 5,
    this.messagesPerChat = 20,
    this.rateLimitingEnabled = true,
  });

  factory ChatSettings.fromMap(Map<String, dynamic> map) {
    return ChatSettings(
      chatsPerDay: (map['chats_per_day'] as num?)?.toInt() ?? 5,
      messagesPerChat: (map['messages_per_chat'] as num?)?.toInt() ?? 20,
      rateLimitingEnabled: map['rate_limiting_enabled'] as bool? ?? true,
    );
  }
}

/// Per-user daily usage counters.
class ChatUsage {
  final int chatCount;
  final int messageCount;

  const ChatUsage({this.chatCount = 0, this.messageCount = 0});

  factory ChatUsage.fromMap(Map<String, dynamic> map) {
    return ChatUsage(
      chatCount: (map['chat_count'] as num?)?.toInt() ?? 0,
      messageCount: (map['message_count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Service that manages AI chat rate limiting.
///
/// • Fetches settings from `chat_settings` singleton row
/// • Subscribes to Supabase Realtime for instant admin updates
/// • Tracks per-user daily usage via `chat_usage` table
/// • Provides guard methods: [canStartNewChat], [canSendMessage]
class ChatRateLimitService extends ChangeNotifier {
  final SupabaseClient _supabase;
  final String? _userId;

  ChatSettings _settings = const ChatSettings();
  ChatUsage _usage = const ChatUsage();
  bool _loading = true;
  RealtimeChannel? _channel;

  ChatRateLimitService({
    required SupabaseClient supabase,
    required String? userId,
  })  : _supabase = supabase,
        _userId = userId {
    _init();
  }

  // ─── Public getters ───
  ChatSettings get settings => _settings;
  ChatUsage get usage => _usage;
  bool get loading => _loading;

  bool get canStartNewChat =>
      !_settings.rateLimitingEnabled ||
      _usage.chatCount < _settings.chatsPerDay;

  bool get canSendMessage =>
      !_settings.rateLimitingEnabled ||
      _usage.messageCount < _settings.messagesPerChat;

  int get chatsRemaining => _settings.rateLimitingEnabled
      ? (_settings.chatsPerDay - _usage.chatCount).clamp(0, _settings.chatsPerDay)
      : 999;

  int get messagesRemaining => _settings.rateLimitingEnabled
      ? (_settings.messagesPerChat - _usage.messageCount)
          .clamp(0, _settings.messagesPerChat)
      : 999;

  // ─── Initialization ───
  Future<void> _init() async {
    await Future.wait([_fetchSettings(), _fetchUsage()]);
    _loading = false;
    notifyListeners();
    _subscribeToRealtimeSettings();
  }

  // ─── Fetch settings from chat_settings singleton ───
  Future<void> _fetchSettings() async {
    try {
      final data = await _supabase
          .from('chat_settings')
          .select('chats_per_day, messages_per_chat, rate_limiting_enabled')
          .eq('id', 1)
          .single();

      _settings = ChatSettings.fromMap(data);
    } catch (e) {
      debugPrint('⚠️ ChatRateLimit: Failed to fetch settings: $e');
      // Keep defaults
    }
  }

  // ─── Fetch today's usage for this user ───
  Future<void> _fetchUsage() async {
    if (_userId == null) return;

    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      final data = await _supabase
          .from('chat_usage')
          .select('chat_count, message_count')
          .eq('user_id', _userId)
          .eq('date', today)
          .maybeSingle();

      _usage = data != null ? ChatUsage.fromMap(data) : const ChatUsage();
    } catch (e) {
      debugPrint('⚠️ ChatRateLimit: Failed to fetch usage: $e');
    }
  }

  // ─── Subscribe to Realtime changes on chat_settings ───
  void _subscribeToRealtimeSettings() {
    _channel = _supabase
        .channel('chat-settings-realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'chat_settings',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: 1,
          ),
          callback: (payload) {
            // Admin changed settings — apply immediately
            debugPrint('🔄 ChatRateLimit: Settings updated via Realtime');
            final newData = payload.newRecord;
            _settings = ChatSettings.fromMap(newData);
            notifyListeners();
          },
        )
        .subscribe();
  }

  // ─── Record a new chat (increment chat_count) ───
  Future<void> recordNewChat() async {
    if (_userId == null) return;

    try {
      await _supabase.rpc('increment_chat_usage', params: {
        'p_user_id': _userId,
        'p_field': 'chat_count',
      });
      await _fetchUsage();
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ ChatRateLimit: Failed to record chat: $e');
    }
  }

  // ─── Record a new message (increment message_count) ───
  Future<void> recordNewMessage() async {
    if (_userId == null) return;

    try {
      await _supabase.rpc('increment_chat_usage', params: {
        'p_user_id': _userId,
        'p_field': 'message_count',
      });
      await _fetchUsage();
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ ChatRateLimit: Failed to record message: $e');
    }
  }

  // ─── Cleanup ───
  @override
  void dispose() {
    if (_channel != null) {
      _supabase.removeChannel(_channel!);
    }
    super.dispose();
  }
}
