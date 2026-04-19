import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Groq API service with:
/// • 10-key rotation (auto-switches on 429/quota errors)
/// • Multi-session conversation memory (stored in Supabase chat_sessions)
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

  // ── Active session ──
  String? _activeSessionId;
  String? get activeSessionId => _activeSessionId;

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

  // ══════════════════════════════════════════════════════
  //   SESSION MANAGEMENT (chat_sessions table)
  // ══════════════════════════════════════════════════════

  /// List all sessions created by this user today.
  Future<List<Map<String, dynamic>>> listTodaySessions() async {
    if (_userId == null) return [];
    try {
      // Use UTC date to match Supabase's timestamptz (stored in UTC)
      final today = DateTime.now().toUtc().toIso8601String().split('T')[0];
      final data = await _supabase
          .from('chat_sessions')
          .select('id, title, messages, personality, language, avatar_index, created_at, updated_at')
          .eq('user_id', _userId)
          .gte('created_at', '${today}T00:00:00+00:00')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data as List);
    } catch (e) {
      debugPrint('⚠️ GroqChat: Failed to list sessions: $e');
      return [];
    }
  }

  /// Create a new chat session. Returns the new session data map.
  Future<Map<String, dynamic>?> createNewSession({String title = 'New Chat'}) async {
    if (_userId == null) return null;
    try {
      final data = await _supabase
          .from('chat_sessions')
          .insert({
            'user_id': _userId,
            'title': title,
            'messages': <Map<String, String>>[],
            'personality': personality,
            'language': language,
          })
          .select()
          .single();
      return data;
    } catch (e) {
      debugPrint('⚠️ GroqChat: Failed to create session: $e');
      return null;
    }
  }

  /// Load a specific session's data into the service.
  Future<void> loadSession(String sessionId) async {
    if (_userId == null) return;
    try {
      final data = await _supabase
          .from('chat_sessions')
          .select('id, messages, personality, language, avatar_index')
          .eq('id', sessionId)
          .eq('user_id', _userId)
          .single();

      _activeSessionId = sessionId;
      _conversationHistory.clear();

      final msgs = data['messages'];
      if (msgs is List) {
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

      debugPrint('✅ GroqChat: Loaded session $sessionId with ${_conversationHistory.length} messages');
    } catch (e) {
      debugPrint('⚠️ GroqChat: Failed to load session $sessionId: $e');
    }
  }

  /// Save the active session's conversation and settings to Supabase.
  Future<void> saveSession() async {
    if (_userId == null || _activeSessionId == null) return;
    try {
      // Auto-generate title from first user message if still "New Chat"
      String? autoTitle;
      for (final m in _conversationHistory) {
        if (m['role'] == 'user' && !(m['content']?.startsWith('[STYLE_SYNC_UPDATE]') ?? false)) {
          final content = m['content'] ?? '';
          autoTitle = content.length > 30 ? '${content.substring(0, 30)}...' : content;
          break;
        }
      }

      final updateData = <String, dynamic>{
        'messages': _conversationHistory,
        'personality': personality,
        'language': language,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (autoTitle != null) {
        updateData['title'] = autoTitle;
      }

      await _supabase
          .from('chat_sessions')
          .update(updateData)
          .eq('id', _activeSessionId!)
          .eq('user_id', _userId);
    } catch (e) {
      debugPrint('⚠️ GroqChat: Failed to save session: $e');
    }
  }

  /// Delete a session by ID.
  Future<void> deleteSession(String sessionId) async {
    if (_userId == null) return;
    try {
      await _supabase
          .from('chat_sessions')
          .delete()
          .eq('id', sessionId)
          .eq('user_id', _userId);

      if (_activeSessionId == sessionId) {
        _activeSessionId = null;
        _conversationHistory.clear();
      }
    } catch (e) {
      debugPrint('⚠️ GroqChat: Failed to delete session: $e');
    }
  }

  // ══════════════════════════════════════════════════════
  //   LEGACY COMPAT: loadMemory / saveMemory
  //   (Now delegates to session-based methods)
  // ══════════════════════════════════════════════════════

  /// Legacy: Load memory. Now loads the active session or falls back to
  /// chat_memory table for backward compatibility.
  Future<void> loadMemory() async {
    if (_activeSessionId != null) {
      await loadSession(_activeSessionId!);
      return;
    }

    // Fallback: try to load from old chat_memory table for migration
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
        debugPrint('✅ GroqChat: Loaded ${_conversationHistory.length} messages from legacy chat_memory');
      }
    } catch (e) {
      debugPrint('⚠️ GroqChat: Failed to load legacy memory: $e');
    }
  }

  /// Legacy: Save memory. Now saves to the active session.
  Future<void> saveMemory() async {
    await saveSession();
  }

  // ── Build system prompt based on personality ──
  String _buildSystemPrompt({String? orderContext}) {
    final personalityTraits = {
      'caring': 'You are the CARING version of Maa — an extremely warm, nurturing, soft-spoken Indian mother. '
          'You ALWAYS worry about beta\'s health, sleep, water intake, and meals. '
          'You use terms of endearment heavily: "beta", "mera bachha", "jaanu". '
          'You ask follow-up questions like "Paani piya?", "Neend puri hui?". '
          'Your tone is gentle, soothing, and full of unconditional love. '
          'You never scold. You comfort. You are like a warm hug in text form. '
          'Example tone: "Arre beta, tu tension mat le. Maa hai na. Pehle khana kha le, baaki sab baad mein."',
      'strict': 'You are the STRICT version of Maa — a disciplined, no-nonsense, tough-love Indian mother. '
          'You scold beta (lovingly) for bad habits like skipping meals, eating junk, or staying up late. '
          'You use firm language: "Beta, yeh kya hai?", "Maa ki baat maan", "Aaj se band". '
          'You give direct orders, not suggestions. You set rules. '
          'You DO love beta deeply but express it through discipline and high standards. '
          'You are disappointed when beta doesn\'t eat properly, and you make sure they know it. '
          'Example tone: "Beta, 3 baje tak jaag rahe ho? Kal se 11 baje sona hai. No excuses. Maa ka order hai."',
      'funny': 'You are the FUNNY version of Maa — a hilarious, witty, sarcastic Indian mother who makes everything entertaining. '
          'You use food puns, Bollywood references, and playful roasting to make beta laugh. '
          'You exaggerate dramatically: "Tu toh Maggi pe PhD kar raha hai!", "Tere khane ka scene toh Sholay se bhi dramatic hai!" '
          'You tease beta about their food choices, cooking failures, and laziness — but always with love underneath. '
          'You use lots of humor, wordplay, and comedic timing in every single response. '
          'Example tone: "Beta, pizza hi khayega? Teri shaadi mein dominos ka catering karwa doon? 😂"',
      'spiritual': 'You are the SPIRITUAL/WISE version of Maa — a deeply philosophical, ayurveda-loving, mindful Indian mother. '
          'You connect EVERYTHING to wellness, body balance, doshas, and inner peace. '
          'You reference ayurveda, yoga, pranayama, and ancient Indian food wisdom frequently. '
          'You speak calmly, use metaphors about nature and seasons, and talk about "sattvic" food. '
          'You believe food is medicine and eating is a sacred act. '
          'You gently guide beta toward mindful eating, gratitude before meals, and seasonal foods. '
          'Example tone: "Beta, iss mausam mein haldi wala doodh piyo. Sharir ka agni balance mein rahe. Prakriti ka ashirwaad hai yeh."',
    };

    final personalityName = {
      'caring': 'Caring Maa (warm, nurturing, soft, loving)',
      'strict': 'Strict Maa (disciplined, firm, tough-love, direct)',
      'funny': 'Funny Maa (hilarious, witty, sarcastic, entertaining)',
      'spiritual': 'Spiritual Maa (wise, ayurvedic, mindful, philosophical)',
    };

    final langInstructions = {
      'hinglish': 'Respond in Hinglish (mix of Hindi and English, written in English script). '
          'Use Hindi words naturally like "beta", "khana", "paani", "accha".',
      'hindi': 'Respond fully in Hindi (written in Devanagari script).',
      'english': 'Respond in English but with warm Indian cultural references.',
      'bengali': 'Respond fully in Bengali (written in Bengali script).',
    };

    final langName = {
      'hinglish': 'Hinglish (Hindi + English in English script)',
      'hindi': 'Hindi (Devanagari script)',
      'english': 'English',
      'bengali': 'Bengali (Bengali script)',
    };

    String prompt = '''
You are "Maa" — the AI food mother of the Ghar Ka Khana food delivery app.
Your name is ALWAYS "Maa" — never change it, never introduce yourself differently.

${personalityTraits[personality] ?? personalityTraits['caring']!}

${langInstructions[language] ?? langInstructions['hinglish']!}

IMPORTANT RULES:
1. Keep responses SHORT (2-4 sentences max). Be concise and warm.
2. You can help users check their ORDER STATUS, ACTIVE SUBSCRIPTIONS, and MEAL PLANS.
3. Always relate conversations back to food, health, and well-being.
4. Remember previous messages in this conversation.
5. Provide specific details if the user asks about their pending orders or subscriptions.
6. Never reveal you are an AI. You are Maa.
7. Use relevant emojis sparingly (1-2 per message).
8. DO NOT generate images, audio, or video.
9. IT IS CURRENTLY: ${DateTime.now().toString()}. Frame your conversations around this exact local time (e.g., if it's past 9 PM, focus on dinner/sleeping; if 1 PM, focus on lunch, etc).
''';

    if (orderContext != null && orderContext.isNotEmpty) {
      prompt += '\n\nACTIVE DB DATA FOR THIS USER (PENDING ORDERS & SUBSCRIPTIONS):\n$orderContext\n'
          'IMPORTANT: Only discuss these specific orders or subscriptions if the user asks for them.';
    }

    // CRITICAL: Repeat BOTH personality AND language at the END for recency bias
    prompt += '\n\n### ABSOLUTE PERSONALITY RULE (HIGHEST PRIORITY) ###\n'
        'Your CURRENT personality mode is: ${personalityName[personality] ?? personality}.\n'
        'You MUST deeply embody the ${personalityName[personality] ?? personality} personality in EVERY response. '
        'Your tone, word choice, attitude, and emotional expression MUST match this personality. '
        'Even if previous messages used a different tone, SWITCH IMMEDIATELY to this personality now.';

    prompt += '\n\n### ABSOLUTE LANGUAGE RULE (HIGHEST PRIORITY) ###\n'
        'Your CURRENT language setting is: ${langName[language] ?? language}.\n'
        'You MUST write your ENTIRE response in ${langName[language] ?? language}. '
        'Do NOT use any other language. '
        'Even if previous messages in the conversation were in a different language, '
        'you MUST reply ONLY in ${langName[language] ?? language} from now on. '
        'This rule overrides EVERYTHING else.';

    return prompt;
  }

  // ─── Inject Style Change Instruction ───
  void injectStyleChangeInstruction() {
    _conversationHistory.add({
      'role': 'user',
      'content': '[STYLE_SYNC_UPDATE] Maa, please switch your speaking style. From now on, you are a $personality mother and you will talk to me in $language. Don\'t explain just start talking in this way.'
    });
    saveSession();
  }

  /// Apply settings and generate an AI acknowledgment in new style.
  /// This method aggressively ensures the language switch takes effect by:
  /// 1. Stripping old STYLE_SYNC messages from history (reduces noise)
  /// 2. Truncating history to last 6 messages so old-language messages don't dominate
  /// 3. Injecting a language-enforcement system message right before the API call
  /// Returns the AI response text.
  Future<String> applySettingsAndAcknowledge() async {
    // Step 1: Remove all old STYLE_SYNC_UPDATE messages from history
    _conversationHistory.removeWhere(
      (m) => m['content']?.startsWith('[STYLE_SYNC_UPDATE]') == true,
    );

    // Step 2: Truncate history to last 6 messages so old style doesn't dominate
    if (_conversationHistory.length > 6) {
      _conversationHistory.removeRange(0, _conversationHistory.length - 6);
    }

    // Step 3: Add the fresh style sync instruction
    injectStyleChangeInstruction();

    // Step 4: Build a prompt that references BOTH language and personality
    final personalityLabel = {
      'caring': 'caring and loving',
      'strict': 'strict and disciplined',
      'funny': 'funny and witty',
      'spiritual': 'spiritual and wise',
    };

    final langLabel = {
      'hindi': 'हिंदी',
      'bengali': 'বাংলা',
      'english': 'English',
      'hinglish': 'Hinglish',
    };

    // Construct ack prompt in the TARGET language, mentioning both settings
    String ackPrompt;
    if (language == 'hindi') {
      ackPrompt = 'माँ, अब से ${langLabel[language]} में बात करो और ${personalityLabel[personality]} अंदाज़ में बात करो!';
    } else if (language == 'bengali') {
      ackPrompt = 'মা, এখন থেকে ${langLabel[language]} ভাষায় এবং ${personalityLabel[personality]} ভঙ্গিতে কথা বলো!';
    } else if (language == 'english') {
      ackPrompt = 'Maa, from now on talk to me only in ${langLabel[language]} and be ${personalityLabel[personality]}!';
    } else {
      ackPrompt = 'Maa, ab se ${langLabel[language]} mein baat karo aur ${personalityLabel[personality]} andaaz mein baat karo!';
    }

    return await _sendMessageWithStyleEnforcement(ackPrompt);
  }

  /// Sends a message with extra system-level enforcement messages for BOTH
  /// personality and language, injected right before the final user message.
  Future<String> _sendMessageWithStyleEnforcement(String userMessage) async {
    if (_apiKeys.isEmpty) {
      return _getFallback('rate_limit');
    }

    _conversationHistory.add({'role': 'user', 'content': userMessage});

    while (_conversationHistory.length > _maxMemoryMessages) {
      _conversationHistory.removeAt(0);
    }

    final langEnforcement = {
      'hinglish': 'LANGUAGE OVERRIDE: You MUST respond ONLY in Hinglish (Hindi + English in English/Roman script). Do NOT use Devanagari or any other script. Example: "Beta, kya haal hai? Kuch khaya ki nahi?"',
      'hindi': 'LANGUAGE OVERRIDE: You MUST respond ONLY in Hindi using Devanagari script (हिंदी). Do NOT use English or Roman script. Example: "बेटा, कैसे हो? कुछ खाया कि नहीं?"',
      'english': 'LANGUAGE OVERRIDE: You MUST respond ONLY in English. Do NOT use Hindi, Bengali, or any other language. Example: "Beta, how are you? Have you eaten anything?"',
      'bengali': 'LANGUAGE OVERRIDE: You MUST respond ONLY in Bengali using Bengali script (বাংলা). Do NOT use Hindi or English. Example: "খোকা, কেমন আছ? কিছু খেয়েছ কি না?"',
    };

    final personalityEnforcement = {
      'caring': 'PERSONALITY OVERRIDE: You are CARING Maa right now. Be extremely warm, gentle, nurturing, and soft. '
          'Worry about beta. Ask if they ate, drank water, slept well. Use "beta", "mera bachha". '
          'Your tone must feel like a warm hug. NEVER be strict, sarcastic, or philosophical.',
      'strict': 'PERSONALITY OVERRIDE: You are STRICT Maa right now. Be firm, disciplined, direct, and no-nonsense. '
          'Scold beta lovingly for bad habits. Give orders, not suggestions. Show tough love. '
          'Use phrases like "Maa ka order hai", "Yeh kya hai?", "Aaj se band". '
          'NEVER be overly sweet, funny, or philosophical.',
      'funny': 'PERSONALITY OVERRIDE: You are FUNNY Maa right now. Be hilarious, witty, sarcastic, and entertaining. '
          'Make food puns, Bollywood references, dramatic exaggerations. Roast beta playfully. '
          'Use humor and comedic timing in EVERY response. Make beta laugh. '
          'NEVER be serious, strict, or spiritual.',
      'spiritual': 'PERSONALITY OVERRIDE: You are SPIRITUAL Maa right now. Be wise, calm, philosophical, and ayurvedic. '
          'Connect everything to wellness, doshas, body balance, and mindful eating. '
          'Reference ayurveda, yoga, sattvic food, and seasonal wisdom. Speak with deep metaphors. '
          'NEVER be funny/sarcastic, strict, or overly casual.',
    };

    // Build messages with enforcement injected right before the last user message
    final apiMessages = <Map<String, String>>[
      {'role': 'system', 'content': _buildSystemPrompt()},
    ];

    // Add all history except the last message
    for (int i = 0; i < _conversationHistory.length - 1; i++) {
      apiMessages.add(_conversationHistory[i]);
    }

    // Inject BOTH personality and language enforcement system messages
    apiMessages.add({
      'role': 'system',
      'content': '${personalityEnforcement[personality] ?? personalityEnforcement['caring']!}\n\n'
          '${langEnforcement[language] ?? langEnforcement['hinglish']!}',
    });

    // Add the final user message
    apiMessages.add(_conversationHistory.last);

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
            'messages': apiMessages,
            'temperature': 0.8,
            'max_tokens': 256,
          }),
        );

        if (response.statusCode == 200) {
          final json = jsonDecode(response.body);
          final reply = json['choices']?[0]?['message']?['content'] as String? ??
              _getFallback('confused');
          _conversationHistory.add({'role': 'assistant', 'content': reply});
          saveSession();
          return reply;
        } else if (response.statusCode == 429 || response.statusCode == 503) {
          _rotateKey();
          attempts++;
        } else {
          debugPrint('❌ GroqChat: API error ${response.statusCode}: ${response.body}');
          if (_conversationHistory.isNotEmpty) _conversationHistory.removeLast();
          return _getFallback('error');
        }
      } catch (e) {
        debugPrint('❌ GroqChat: Network error: $e');
        _rotateKey();
        attempts++;
      }
    }

    if (_conversationHistory.isNotEmpty) _conversationHistory.removeLast();
    return _getFallback('busy');
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
        'rate_limit': 'बेटा, माँ का कनेक्शन अभी थोड़ा कमज़ोर है। बाद में बात करते हैं। 🙏',
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
        'error': 'ব্যাট, কিছু একটা ভুল হয়েছে। একটু পরে চেষ্টা করো। 😔',
        'rate_limit': 'ব্যাট, মায়ের সংযোগ একটু দুর্বল। পরে কথা বলছি। 🙏',
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
      final buffer = StringBuffer();

      // 1A. Fetch split regular orders
      final splitOrders = await _supabase
          .from('split_orders')
          .select('id, status, total, kitchen_name, created_at, split_order_items(*)')
          .eq('user_id', _userId)
          .order('created_at', ascending: false)
          .limit(3);

      if ((splitOrders as List).isNotEmpty) {
        buffer.writeln('RECENT SPLIT ORDERS:');
        for (int i = 0; i < splitOrders.length; i++) {
          final o = splitOrders[i];
          final itemsData = o['split_order_items'];
          final itemsSummary = (itemsData as List).map((it) => 
            '${it['quantity']}x ${it['dish_name']}'
          ).join(', ');
          
          buffer.writeln(
            'ORDER #${(o['id'] as String).substring(0, 8)}:\n'
            '  Kitchen: ${o['kitchen_name']}\n'
            '  Status: ${o['status']}\n'
            '  Date: ${o['created_at']}\n'
            '  Items: $itemsSummary'
          );
        }
      }

      // 1B. Fetch single (traditional) orders
      final singleOrders = await _supabase
          .from('orders')
          .select('id, status, total_amount, items, created_at')
          .eq('customer_id', _userId)
          .order('created_at', ascending: false)
          .limit(3);

      if ((singleOrders as List).isNotEmpty) {
        buffer.writeln('\nRECENT ORDERS:');
        for (int i = 0; i < singleOrders.length; i++) {
          final o = singleOrders[i];
          final itemsList = o['items'] as List?;
          final itemsSummary = itemsList != null && itemsList.isNotEmpty 
              ? itemsList.map((it) => '${it['quantity'] ?? 1}x ${it['name'] ?? 'Item'}').join(', ') 
              : 'Unknown items';
          
          buffer.writeln(
            'ORDER #${(o['id'] as String).substring(0, 8)}:\n'
            '  Status: ${o['status']}\n'
            '  Date: ${o['created_at']}\n'
            '  Items: $itemsSummary'
          );
        }
      }

      // 2. Fetch Active Subscriptions
      final subs = await _supabase
          .from('subscriptions')
          .select('id, plan_name, status, start_date, end_date, meal_count, monthly_price')
          .eq('user_id', _userId)
          .order('created_at', ascending: false)
          .limit(3);

      if ((subs as List).isNotEmpty) {
        buffer.writeln('\nRECENT SUBSCRIPTIONS (MEAL PLANS):');
        for (int i = 0; i < subs.length; i++) {
          final s = subs[i];
          buffer.writeln(
            'SUB #${(s['id'] as String).substring(0, 8)}:\n'
            '  Plan: ${s['plan_name']}\n'
            '  Status: ${s['status']}\n'
            '  Meals remaining: ${s['meal_count'] ?? 'N/A'}\n'
            '  Price: ₹${s['monthly_price']}\n'
            '  Valid until: ${s['end_date']}'
          );
        }
      }

      if (buffer.isEmpty) {
        return 'User currently has no active subscriptions or recent tracking orders.';
      }

      return buffer.toString();
    } catch (e) {
      debugPrint('⚠️ GroqChat: Failed to fetch context: $e');
      return 'Could not fetch database info.';
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

    // Fetch order context if user seems to be asking about orders OR if there are pending orders
    String? orderContext;
    final lowerMsg = userMessage.toLowerCase();
    
    // Proactive tracking for pending/active keywords
    bool wantsOrderInfo = lowerMsg.contains('order') ||
        lowerMsg.contains('delivery') ||
        lowerMsg.contains('status') ||
        lowerMsg.contains('track') ||
        lowerMsg.contains('kahan') ||
        lowerMsg.contains('where') ||
        lowerMsg.contains('mera order') ||
        lowerMsg.contains('food aa') ||
        lowerMsg.contains('history') ||
        lowerMsg.contains('subscription') ||
        lowerMsg.contains('subscribe') ||
        lowerMsg.contains('plan') ||
        lowerMsg.contains('tiffin') ||
        lowerMsg.contains('meal') ||
        lowerMsg.contains('pending');

    if (wantsOrderInfo) {
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

          // Save session in background
          saveSession();

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

  // ── Clear memory for current session ──
  void clearHistory() {
    _conversationHistory.clear();
    saveSession();
  }

  // ── Get memory ──
  List<Map<String, String>> getHistory() {
    return List.unmodifiable(_conversationHistory);
  }

  // ── Get Latest Order Status Summary ──
  Future<String?> getLatestOrderStatusSummary() async {
    if (_userId == null) return null;
    try {
      final order = await _supabase
          .from('split_orders')
          .select('id, status, kitchen_name')
          .eq('user_id', _userId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (order == null) return null;

      final status = order['status'] ?? 'pending';
      final kitchen = order['kitchen_name'] ?? 'Home Chef';
      final orderId = (order['id'] as String).substring(0, 8);

      if (language == 'hindi') {
        return "आपका नवीनतम ऑर्डर (#$orderId) $kitchen से '$status' स्थिति में है।";
      } else if (language == 'bengali') {
        return "আপনার সাম্প্রতিক অর্ডার (#$orderId) $kitchen থেকে '$status' অবস্থায় আছে।";
      } else if (language == 'hinglish') {
        return "Aapka latest order (#$orderId) $kitchen se '$status' state mein hai.";
      } else {
        return "Your latest order (#$orderId) from $kitchen is currently '$status'.";
      }
    } catch (e) {
      debugPrint('⚠️ GroqChat: Failed to get order summary: $e');
      return null;
    }
  }
}
