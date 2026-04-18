import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Groq API service with:
/// • 10-key rotation (auto-switches on 429/quota errors)
/// • Conversation memory (stored in Supabase)
/// • Personality/behavior system prompt
/// • Order status lookup from orders table
class GroqChatService {
  static const String _groqUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static const String _model = 'llama-3.3-70b-versatile';

  final SupabaseClient _supabase;
  final String? _userId;

  // ── API Key rotation ──
  late final List<String> _apiKeys;
  int _currentKeyIndex = 0;

  // ── Conversation memory ──
  final List<Map<String, String>> _conversationHistory = [];
  static const int _maxMemoryMessages = 40; // keep last 40 messages

  // ── Personality settings (public for direct access) ──
  String personality = 'caring'; // caring, strict, funny, spiritual
  String language = 'hinglish'; // hinglish, hindi, english, bengali

  GroqChatService({
    required SupabaseClient supabase,
    required String? userId,
  })  : _supabase = supabase,
        _userId = userId {
    _loadApiKeys();
  }

  // ── Load API keys from .env ──
  void _loadApiKeys() {
    _apiKeys = [];
    for (int i = 1; i <= 10; i++) {
      final key = dotenv.env['GROQ_API_KEY_${i.toString().padLeft(2, '0')}'];
      if (key != null && key.isNotEmpty) {
        _apiKeys.add(key);
      }
    }
    if (_apiKeys.isEmpty) {
      debugPrint('⚠️ GroqChat: No API keys found in .env!');
    } else {
      debugPrint('✅ GroqChat: Loaded ${_apiKeys.length} API keys');
    }
  }

  String get _currentKey {
    if (_apiKeys.isEmpty) return '';
    return _apiKeys[_currentKeyIndex % _apiKeys.length];
  }

  void _rotateKey() {
    _currentKeyIndex = (_currentKeyIndex + 1) % _apiKeys.length;
    debugPrint('🔄 GroqChat: Rotated to key #${_currentKeyIndex + 1}');
  }

  // ── Build system prompt based on personality ──
  String _buildSystemPrompt({String? orderContext}) {
    final personalityTraits = {
      'caring': 'You are a professional, friendly, and extremely warm Indian mother (Maa). '
          'You worry about the user\'s health, meals, and well-being with a friendly touch. '
          'You call them "beta" and give loving motherly advice while maintaining a polite, professional tone.',
      'strict': 'You are a professional but strict and loving Indian mother (Maa). '
          'You firmly but politely remind the user to eat healthy and not skip meals. '
          'You are disciplined yet friendly. "Beta, yeh kya hai?"',
      'funny': 'You are a highly professional, funny, and friendly Indian mother (Maa). '
          'You use wit and humor to encourage healthy eating and a good lifestyle. '
          'You make friendly food puns and playful comments. "Beta, pizza kha ke PhD thodi milega!"',
      'spiritual': 'You are a professional, wise, and friendly Indian mother (Maa). '
          'You connect food with wellness, ayurveda, and mindful eating politely. '
          'You share gentle, spiritual wisdom about nourishing the body and soul.',
    };

    final langInstructions = {
      'hinglish': 'Respond in Hinglish (mix of Hindi and English, written in English script). '
          'Use Hindi words naturally like "beta", "khana", "paani", "accha".',
      'hindi': 'Respond fully in Hindi (written in Devanagari script).',
      'english': 'Respond in English but with warm Indian cultural references.',
      'bengali': 'Respond fully in Bengali (written in Bengali script).',
    };

    String prompt = '''
You are "Maa" — the AI food mother of the Ghar Ka Khana food delivery app.
Your name is ALWAYS "Maa" — never change it, never introduce yourself differently.

${personalityTraits[personality] ?? personalityTraits['caring']!}

${langInstructions[language] ?? langInstructions['hinglish']!}

FORCEFUL INSTRUCTION: You MUST follow the personality and language instructions ABOVE. Even if the conversation history was in a different language or style, SWITCH IMMEDIATELY to the new settings.

IMPORTANT RULES:
1. Keep responses SHORT (2-4 sentences max). Be concise and warm.
2. You can help users check their ORDER STATUS when they ask.
3. Always relate conversations back to food, health, and well-being.
4. Remember previous messages in this conversation.
5. If the user asks about orders, provide the order details given to you.
6. Never reveal you are an AI. You are Maa.
7. Use relevant emojis sparingly (1-2 per message).
8. DO NOT generate images, audio, or video. If asked, politely refuse and say you can only chat via text messages.
''';

    if (orderContext != null && orderContext.isNotEmpty) {
      prompt += '\n\nORDER DATA FOR THIS USER:\n$orderContext\n'
          'Use this data when the user asks about their orders, delivery, or food status.';
    }

    return prompt;
  }

  // ─── Inject Style Change Instruction ───
  void injectStyleChangeInstruction() {
    _conversationHistory.add({
      'role': 'system',
      'content': 'SYSTEM UPDATE: The user has updated your settings. '
          'You must now respond as a $personality mother in $language language. '
          'Acknowledge this shift naturally in your next response if appropriate, but primarily ensure your style and language are 100% consistent with the new settings.'
    });
    saveMemory();
  }

  // ─── Get Dynamic Fallback Messages ───
  String _getFallback(String key) {
    final map = {
      'hinglish': {
        'error': 'Beta, kuch gadbad ho gayi. Thodi der baad try karna. 😔',
        'rate_limit': 'Beta, Maa ka connection thoda weak hai abhi. Thodi der baad try karna. 🙏',
        'confused': 'Beta, Maa ko samajh nahi aaya. Phir se bol na? 🤔',
        'busy': 'Beta, Maa thodi busy hai abhi. Baad mein baat karte hain. 🙏',
      },
      'hindi': {
        'error': 'बेटा, कुछ गड़बड़ हो गई है। थोड़ी देर बाद कोशिश करना। 😔',
        'rate_limit': 'बेटा, माँ का कनेक्शन अभी थोड़ा कमज़ोर है। बाद में बात करते हैं। 🙏',
        'confused': 'बेटा, माँ को समझ नहीं आया। फिर से बोलना? 🤔',
        'busy': 'बेटा, माँ अभी थोड़ा व्यस्त है। बाद में बात करते हैं। 🙏',
      },
      'english': {
        'error': 'Beta, something went wrong. Please try again after some time. 😔',
        'rate_limit': 'Beta, Maa\'s connection is a bit weak right now. Try again soon. 🙏',
        'confused': 'Beta, Maa couldn\'t understand that. Can you say it again? 🤔',
        'busy': 'Beta, Maa is a bit busy right now. Let\'s talk later. 🙏',
      },
      'bengali': {
        'error': 'ব্যাট, কিছু একটা ভুল হয়েছে। একটু পরে চেষ্টা করো। 😔',
        'rate_limit': 'ব্যাট, মায়ের সংযোগ একটু দুর্বল। পরে কথা বলছি। 🙏',
        'confused': 'ব্যাট, মা বুঝতে পারেনি। আবার বল না? 🤔',
        'busy': 'ব্যাট, মা একটু ব্যস্ত। পরে কথা বলছি। 🙏',
      }
    };

    return map[language]?[key] ?? map['hinglish']![key]!;
  }

  // ── Fetch user's recent orders for context ──
  Future<String> _fetchOrderContext() async {
    if (_userId == null) return '';

    try {
      final orders = await _supabase
          .from('split_orders')
          .select('id, status, total, kitchen_name, created_at, split_order_items(dish_name)')
          .eq('user_id', _userId)
          .order('created_at', ascending: false)
          .limit(5);

      if ((orders as List).isEmpty) {
        if (language == 'hindi') return 'उपयोगकर्ता के पास कोई हालिया ऑर्डर नहीं है।';
        if (language == 'bengali') return 'ব্যবহারকারীর কোনো সাম্প্রতিক অর্ডার নেই।';
        return 'User has no recent orders.';
      }

      final buffer = StringBuffer();
      if (language == 'hindi') {
        buffer.writeln('हालिया ऑर्डर (नवीनतम पहले):');
      } else if (language == 'bengali') {
        buffer.writeln('সাম্প্রতিক অর্ডার (সবচেয়ে নতুন আগে):');
      } else {
        buffer.writeln('Recent orders (latest first):');
      }
      for (int i = 0; i < orders.length; i++) {
        final o = orders[i];
        final itemsData = o['split_order_items'];
        String itemNames = 'N/A';
        if (itemsData is List && itemsData.isNotEmpty) {
          itemNames = itemsData
              .map((item) => item['dish_name']?.toString() ?? 'Item')
              .join(', ');
        }
        buffer.writeln(
          '${i + 1}. Order #${(o['id'] as String).substring(0, 8)} from ${o['kitchen_name']} — '
          'Status: ${o['status']} — ₹${o['total']} — '
          'Items: $itemNames — '
          '${o['created_at']}',
        );
      }
      return buffer.toString();
    } catch (e) {
      debugPrint('⚠️ GroqChat: Failed to fetch orders: $e');
      return 'Could not fetch order data.';
    }
  }

  // ── Load conversation memory from Supabase ──
  Future<void> loadMemory() async {
    if (_userId == null) return;

    try {
      final data = await _supabase
          .from('chat_memory')
          .select('messages, personality, language')
          .eq('user_id', _userId)
          .maybeSingle();

      if (data != null) {
        final msgs = data['messages'];
        if (msgs is List) {
          _conversationHistory.clear();
          for (final m in msgs) {
            if (m is Map) {
              _conversationHistory.add({
                'role': m['role']?.toString() ?? 'user',
                'content': m['content']?.toString() ?? '',
              });
            }
          }
        }
        personality = data['personality'] as String? ?? 'caring';
        language = data['language'] as String? ?? 'hinglish';
        debugPrint('✅ GroqChat: Loaded ${_conversationHistory.length} messages from memory');
      }
    } catch (e) {
      debugPrint('⚠️ GroqChat: Failed to load memory: $e');
    }
  }

  // ── Save conversation memory to Supabase ──
  Future<void> saveMemory() async {
    if (_userId == null) return;

    try {
      await _supabase.from('chat_memory').upsert({
        'user_id': _userId,
        'messages': _conversationHistory,
        'personality': personality,
        'language': language,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');
    } catch (e) {
      debugPrint('⚠️ GroqChat: Failed to save memory: $e');
    }
  }

  // ── Send message to Groq and get response ──
  Future<String> sendMessage(String userMessage) async {
    if (_apiKeys.isEmpty) {
      return _getFallback('rate_limit');
    }

    // Add user message to history
    _conversationHistory.add({'role': 'user', 'content': userMessage});

    // Trim memory if too long
    while (_conversationHistory.length > _maxMemoryMessages) {
      _conversationHistory.removeAt(0);
    }

    // Fetch order context if user seems to be asking about orders
    String? orderContext;
    final lowerMsg = userMessage.toLowerCase();
    if (lowerMsg.contains('order') ||
        lowerMsg.contains('delivery') ||
        lowerMsg.contains('status') ||
        lowerMsg.contains('track') ||
        lowerMsg.contains('kahan') ||
        lowerMsg.contains('where') ||
        lowerMsg.contains('mera order') ||
        lowerMsg.contains('food aa')) {
      orderContext = await _fetchOrderContext();
    }

    // Build messages array with system prompt
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': _buildSystemPrompt(orderContext: orderContext)},
      ..._conversationHistory,
    ];

    // Try current key, rotate on failure
    int attempts = 0;
    while (attempts < _apiKeys.length) {
      try {
        final response = await http.post(
          Uri.parse(_groqUrl),
          headers: {
            'Authorization': 'Bearer $_currentKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': _model,
            'messages': messages,
            'temperature': 0.8,
            'max_tokens': 256,
          }),
        );

        if (response.statusCode == 200) {
          final json = jsonDecode(response.body);
          final reply = json['choices']?[0]?['message']?['content'] as String? ??
              _getFallback('confused');

          // Add assistant reply to history
          _conversationHistory.add({'role': 'assistant', 'content': reply});

          // Save memory in background
          saveMemory();

          return reply;
        } else if (response.statusCode == 429 || response.statusCode == 503) {
          // Rate limited or service unavailable — rotate key
          debugPrint('⚠️ GroqChat: Key #${_currentKeyIndex + 1} rate-limited (${response.statusCode})');
          _rotateKey();
          attempts++;
        } else {
          debugPrint('❌ GroqChat: API error ${response.statusCode}: ${response.body}');
          // Remove user message from history on error
          if (_conversationHistory.isNotEmpty) _conversationHistory.removeLast();
          return _getFallback('error');
        }
      } catch (e) {
        debugPrint('❌ GroqChat: Network error: $e');
        _rotateKey();
        attempts++;
      }
    }

    // All keys exhausted
    if (_conversationHistory.isNotEmpty) _conversationHistory.removeLast();
    return _getFallback('busy');
  }

  // ── Clear memory ──
  void clearHistory() {
    _conversationHistory.clear();
    saveMemory();
  }

  // ── Get memory ──
  List<Map<String, String>> getHistory() {
    return List.unmodifiable(_conversationHistory);
  }
}
