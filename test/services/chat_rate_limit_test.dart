import 'package:flutter_test/flutter_test.dart';
import 'package:ghar_ka_khana/services/chat_rate_limit_service.dart';

void main() {
  group('ChatSettings', () {
    test('default values are correct', () {
      const settings = ChatSettings();
      expect(settings.chatsPerDay, 5);
      expect(settings.messagesPerChat, 20);
      expect(settings.rateLimitingEnabled, true);
    });

    test('fromMap parses all fields', () {
      final settings = ChatSettings.fromMap({
        'chats_per_day': 10,
        'messages_per_chat': 50,
        'rate_limiting_enabled': false,
      });
      expect(settings.chatsPerDay, 10);
      expect(settings.messagesPerChat, 50);
      expect(settings.rateLimitingEnabled, false);
    });

    test('fromMap handles missing fields with defaults', () {
      final settings = ChatSettings.fromMap({});
      expect(settings.chatsPerDay, 5);
      expect(settings.messagesPerChat, 20);
      expect(settings.rateLimitingEnabled, true);
    });

    test('fromMap handles null values', () {
      final settings = ChatSettings.fromMap({
        'chats_per_day': null,
        'messages_per_chat': null,
        'rate_limiting_enabled': null,
      });
      expect(settings.chatsPerDay, 5);
      expect(settings.messagesPerChat, 20);
      expect(settings.rateLimitingEnabled, true);
    });
  });

  group('ChatUsage', () {
    test('default values are zero', () {
      const usage = ChatUsage();
      expect(usage.chatCount, 0);
      expect(usage.messageCount, 0);
    });

    test('fromMap parses correctly', () {
      final usage = ChatUsage.fromMap({
        'chat_count': 3,
        'message_count': 15,
      });
      expect(usage.chatCount, 3);
      expect(usage.messageCount, 15);
    });

    test('fromMap handles missing values', () {
      final usage = ChatUsage.fromMap({});
      expect(usage.chatCount, 0);
      expect(usage.messageCount, 0);
    });
  });
}
