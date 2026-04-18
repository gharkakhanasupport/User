import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/chat_rate_limit_service.dart';
import '../services/groq_chat_service.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../core/localization.dart';

// ─── Maa AI Warm Color Palette ───
const Color _maaWarmBg = Color(0xFFFFF8F0);
const Color _maaSaffron = Color(0xFFE8722A);
const Color _maaSaffronLight = Color(0xFFFFF3E8);
const Color _maaSaffronBorder = Color(0xFFFADEC9);
const Color _maaDeepPurple = Color(0xFF6C3FA0);
const Color _maaTextDark = Color(0xFF2D1B0E);
const Color _maaTextSub = Color(0xFF8B7355);
const Color _maaGold = Color(0xFFC2941B);

// ─── 3 Anime Maa Avatar Paths ───
const List<String> _maaAvatarPaths = [
  'assets/maa_avatars/maa_avatar_1.png',
  'assets/maa_avatars/maa_avatar_2.png',
  'assets/maa_avatars/maa_avatar_3.png',
];

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen>
    with TickerProviderStateMixin {
  Locale? _lastLocale;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentLocale = Localizations.localeOf(context);
    if (_lastLocale != currentLocale) {
      _lastLocale = currentLocale;
      _syncLanguageWithLocale(currentLocale);
    }
  }

  void _syncLanguageWithLocale(Locale locale) {
    final langMap = {
      'hi': 'hindi',
      'bn': 'bengali',
      'en': 'english'
    };
    final targetLang = langMap[locale.languageCode] ?? 'hinglish';
    
    // Only auto-sync if history is short or user hasn't manually diverged too much? 
    // Actually, user wants it to adapt immediately. 
    if (_groqService.language != targetLang) {
       _groqService.language = targetLang;
       // If history is showing, we might want to inject a style change instruction
       if (_messages.isNotEmpty) {
         _groqService.injectStyleChangeInstruction();
       }
       if (mounted) setState(() {});
    }
  }

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late AnimationController _glowController;
  late AnimationController _typingController;

  List<Map<String, dynamic>> _messages = [];
  bool _isTyping = false;
  bool _isCooldown = false; // 2.5s cooldown between messages

  // ─── Services ───
  late final ChatRateLimitService _rateLimitService;
  late final GroqChatService _groqService;

  // ─── Avatar selection (0, 1, or 2) ───
  int _selectedAvatarIndex = 0;

  @override
  void initState() {
    super.initState();

    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _typingController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();

    // Initialize services
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;

    _rateLimitService = ChatRateLimitService(
      supabase: supabase,
      userId: userId,
    );
    _rateLimitService.addListener(_onServiceChanged);

    _groqService = GroqChatService(
      supabase: supabase,
      userId: userId,
    );

    // Record this as a new chat session
    _rateLimitService.recordNewChat();

    // Load memory & settings from Supabase
    _initChat();
  }

  Future<void> _initChat() async {
    await _groqService.loadMemory();
    await _loadAvatarPreference();

    // Sync language with AppState locale if it's the first time or set to default
    // We only sync if memory doesn't have a specific language set yet (heuristic)
    // Actually, user wants it to sync. So let's check AppState.
    if (!mounted) return;
    final appLocale = context.read<AppState>().locale;
    final langMap = {'hi': 'hindi', 'en': 'english', 'bn': 'bengali'};
    
    // If we have history, show it. Otherwise show greeting.
    if (_groqService.getHistory().isEmpty) {
      // If new chat, sync language once from app locale
      final syncedLang = langMap[appLocale.languageCode] ?? 'hinglish';
      if (_groqService.language == 'hinglish') {
         _groqService.language = syncedLang;
      }
      
      setState(() {
        _messages = [
          {
            'text': _getGreeting(),
            'isUser': false,
            'time': _formattedTime(),
            'type': 'text',
          },
        ];
      });
    } else {
      setState(() {
        _messages = _groqService.getHistory()
          .where((m) => m['role'] != 'system')
          .map((m) => {
            'text': m['content'],
            'isUser': m['role'] == 'user',
            'time': _formattedTime(), // Approximation for history
            'type': 'text',
          }).toList();
      });
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    final lang = _groqService.language;
    final persona = _groqService.personality;

    final greetings = {
      'hindi': {
        'morning': 'नमस्ते बेटा! ☀️ क्या तुमने नाश्ता किया? माँ को बताओ, क्या खाओगे?',
        'afternoon': 'नमस्ते बेटा! 🍛 दोपहर का खाना खाया? माँ आज तुम्हारे लिए क्या बना दे?',
        'night': 'नमस्ते बेटा! 🌙 क्या तुमने डिनर कर लिया? माँ को बताओ माँ तुम्हारे लिए क्या भेज दे?',
        'generic': 'नमस्ते बेटा! ❤️ माँ यहाँ है। बताओ माँ तुम्हारे लिए क्या स्वादिष्ट खाना भेज दे?'
      },
      'english': {
        'morning': 'Good morning beta! ☀️ Did you have breakfast? Tell Maa, what would you like to eat?',
        'afternoon': 'Beta, it\'s lunch time! 🍛 Did you order anything yet? Tell Maa.',
        'night': 'Beta, it\'s dinner time! 🌙 What would you like to eat today? Maa will suggest something.',
        'generic': 'Hello beta! ❤️ Maa is here. Tell Maa what delicious food she can send for you.'
      },
      'bengali': {
        'morning': 'সুপ্রভাত খোকা! ☀️ প্রাতঃরাশ করেছ? মাকে বলো, তুমি কি খাবে?',
        'afternoon': 'খোকা, দুপুরের খাবারের সময় হয়ে গেছে! 🍛 কিছু কি খেয়েছ? মাকে বলো।',
        'night': 'খোকা, রাতের খাবারের সময় হয়ে গেছে! 🌙 আজ কি খাবে? মা আজ তোমার জন্য কি পাঠিয়ে দেব?',
        'generic': 'হ্যালো খোকা! ❤️ মা এখানে আছে। বলো মা তোমার জন্য কি সুস্বাদু খাবার পাঠিয়ে দেব?'
      },
      'hinglish': {
        'morning': 'Good morning beta! ☀️ Aaj nashta kiya? Maa ko bata, kya khayega?',
        'afternoon': 'Beta, lunch time ho gaya! 🍛 Kuch order kiya ki nahi? Bata Maa ko.',
        'night': 'Beta, dinner ka time ho gaya! 🌙 Aaj kya khana hai? Maa suggest karegi.',
        'generic': 'Hello beta! ❤️ Maa yahan hai. Bata Maa tere liye kya mangwa de?'
      }
    };

    final timeKey = hour < 12 ? 'morning' : (hour < 17 ? 'afternoon' : 'night');
    String msg = greetings[lang]?[timeKey] ?? greetings['hinglish']![timeKey]!;

    if (persona == 'strict') {
      msg = msg.replaceAll('beta!', 'beta.');
    } else if (persona == 'funny') {
      msg = msg.replaceFirst('☀️', '🍱');
      msg = msg.replaceFirst('🍛', '🥘');
    }

    return msg;
  }

  String _formattedTime() {
    final now = DateTime.now();
    final hour = now.hour > 12 ? now.hour - 12 : now.hour;
    final amPm = now.hour >= 12 ? 'PM' : 'AM';
    return '${hour == 0 ? 12 : hour}:${now.minute.toString().padLeft(2, '0')} $amPm';
  }

  Future<void> _loadAvatarPreference() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final data = await Supabase.instance.client
          .from('chat_memory')
          .select('avatar_index')
          .eq('user_id', userId)
          .maybeSingle();

      if (data != null && data['avatar_index'] != null) {
        setState(() {
          _selectedAvatarIndex = (data['avatar_index'] as num).toInt().clamp(0, 2);
        });
      }
    } catch (_) {}
  }

  Future<void> _saveAvatarPreference(int index) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await Supabase.instance.client.from('chat_memory').upsert({
        'user_id': userId,
        'avatar_index': index,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');
    } catch (_) {}
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ─── SEND MESSAGE (with Groq, rate limit, and cooldown) ───
  Future<void> _onSendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isTyping || _isCooldown) return;

    // ─── Rate limit guard ───
    if (!_rateLimitService.canSendMessage) {
      _showRateLimitDialog(
        'Message limit reached',
        'You have used all ${_rateLimitService.settings.messagesPerChat} messages for this chat today. Come back tomorrow! 🙏',
      );
      return;
    }

    // Record the message
    _rateLimitService.recordNewMessage();

    // Add user message to UI
    setState(() {
      _messages.add({
        'text': text,
        'isUser': true,
        'time': _formattedTime(),
        'type': 'text',
      });
      _messageController.clear();
      _isTyping = true;
      _isCooldown = true;
    });
    _scrollToBottom();

    // Call Groq API
    final response = await _groqService.sendMessage(text);

    if (mounted) {
      setState(() {
        _isTyping = false;
        _messages.add({
          'text': response,
          'isUser': false,
          'time': _formattedTime(),
          'type': 'text',
        });
      });
      _scrollToBottom();
    }

    // 2.5 second cooldown
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        setState(() => _isCooldown = false);
      }
    });
  }

  void _showRateLimitDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _maaWarmBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.timer_off_rounded, color: _maaSaffron, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: _maaTextDark,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: _maaTextSub,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'OK',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                color: _maaSaffron,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onChipTap(String label) {
    _messageController.text = label;
    _onSendMessage();
  }

  @override
  void dispose() {
    _rateLimitService.removeListener(_onServiceChanged);
    _rateLimitService.dispose();
    _glowController.dispose();
    _typingController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _maaWarmBg,
      body: Column(
        children: [
          _buildMaaHeader(),
          _buildRateLimitBanner(),
          Expanded(child: _buildMessageList()),
          if (_isTyping) _buildTypingIndicator(),
          if (_isCooldown && !_isTyping) _buildCooldownIndicator(),
          _buildQuickReplyChips(),
          _buildInputBar(),
        ],
      ),
    );
  }

  // ─── RATE LIMIT STATUS BANNER ───
  Widget _buildRateLimitBanner() {
    if (_rateLimitService.loading) return const SizedBox.shrink();
    if (!_rateLimitService.settings.rateLimitingEnabled) {
      return const SizedBox.shrink();
    }

    final msgsLeft = _rateLimitService.messagesRemaining;
    final chatsLeft = _rateLimitService.chatsRemaining;
    final isLow = msgsLeft <= 3 || chatsLeft <= 1;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isLow
            ? const Color(0xFFFFF0E0)
            : _maaSaffronLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLow
              ? _maaSaffron.withValues(alpha: 0.4)
              : _maaSaffronBorder,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isLow ? Icons.warning_amber_rounded : Icons.chat_bubble_outline,
            size: 16,
            color: isLow ? _maaSaffron : _maaTextSub,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$msgsLeft messages left today • $chatsLeft chats remaining',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isLow ? _maaSaffron : _maaTextSub,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── COOLDOWN INDICATOR ───
  Widget _buildCooldownIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(left: 52, bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _maaSaffronLight.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: _maaSaffron.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Wait a moment...',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                color: _maaTextSub,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── HEADER ───
  Widget _buildMaaHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _maaSaffron.withValues(alpha: 0.15),
            _maaWarmBg,
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: _maaSaffron.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 20),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new,
                    size: 20, color: _maaTextDark),
              ),
              const SizedBox(width: 4),
              _buildMaaAvatar(),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Maa',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: _maaTextDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildPersonaBadge(),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ghar ki yaad, yahan bhi \u2764\uFE0F',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: _maaTextSub,
                      ),
                    ),
                  ],
                ),
              ),
              _buildGlassMenuButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMaaAvatar() {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        final v = _glowController.value;
        return Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _maaSaffron.withValues(alpha: 0.25 + 0.2 * v),
                blurRadius: 16 + 8 * v,
                spreadRadius: 2 + 2 * v,
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
            ),
            child: ClipOval(
              child: Image.asset(
                _maaAvatarPaths[_selectedAvatarIndex],
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: _maaSaffronLight,
                  child: const Center(
                    child: Text('\uD83D\uDE4F', style: TextStyle(fontSize: 22)),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPersonaBadge() {
    final labels = {
      'caring': 'Caring Maa',
      'strict': 'Strict Maa',
      'funny': 'Funny Maa',
      'spiritual': 'Wise Maa',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: _maaDeepPurple.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _maaDeepPurple.withValues(alpha: 0.2)),
      ),
      child: Text(
        labels[_groqService.personality] ?? 'Maa Mode',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: _maaDeepPurple,
        ),
      ),
    );
  }

  // ─── SETTINGS BUTTON (now opens settings sheet) ───
  Widget _buildGlassMenuButton() {
    return GestureDetector(
      onTap: _openSettingsSheet,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.tune_rounded, size: 20, color: _maaTextSub),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  //   SETTINGS BOTTOM SHEET
  // ══════════════════════════════════════════════════════
  void _openSettingsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SettingsSheet(
        currentPersonality: _groqService.personality,
        currentLanguage: _groqService.language,
        currentAvatarIndex: _selectedAvatarIndex,
        onPersonalityChanged: (val) {
          setState(() => _groqService.personality = val);
          _groqService.injectStyleChangeInstruction();
        },
        onLanguageChanged: (val) {
          setState(() => _groqService.language = val);
          _groqService.injectStyleChangeInstruction();
        },
        onAvatarChanged: (index) {
          setState(() => _selectedAvatarIndex = index);
          _saveAvatarPreference(index);
        },
        onClearChat: () {
          setState(() {
            _messages = [
              {
                'text': 'Beta, sab fresh! Bata kya help chahiye? 🌟',
                'isUser': false,
                'time': _formattedTime(),
                'type': 'text',
              }
            ];
          });
          _groqService.clearHistory();
          Navigator.pop(ctx);
        },
      ),
    );
  }

  // ─── MESSAGE LIST ───
  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        return TweenAnimationBuilder<double>(
          key: ValueKey('msg_$index'),
          tween: Tween(begin: 0.0, end: 1.0),
          duration:
              Duration(milliseconds: 500 + (index * 60).clamp(0, 300)),
          curve: Curves.easeOutBack,
          builder: (context, value, child) {
            return Opacity(
              opacity: value.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: message['type'] == 'care_card'
                    ? _buildCareCard(message)
                    : _buildTextBubble(message),
              ),
            );
          },
        );
      },
    );
  }

  // ─── TEXT BUBBLE ───
  Widget _buildTextBubble(Map<String, dynamic> message) {
    final isUser = message['isUser'] == true;
    final text = message['text'] ?? '';
    final time = message['time'] ?? '';

    if (isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, left: 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72,
          ),
          decoration: BoxDecoration(
            color: _maaDeepPurple,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(4),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(18),
            ),
            boxShadow: [
              BoxShadow(
                color: _maaDeepPurple.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                text,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  height: 1.45,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                time,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Maa's message with avatar
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: Image.asset(
                _maaAvatarPaths[_selectedAvatarIndex],
                width: 28,
                height: 28,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: _maaSaffronBorder,
                  child: const Center(
                    child: Text('\uD83D\uDE4F', style: TextStyle(fontSize: 14)),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72,
            ),
            decoration: BoxDecoration(
              color: _maaSaffronLight,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
              border: Border.all(color: _maaSaffronBorder, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    height: 1.45,
                    color: _maaTextDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    color: _maaTextSub,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── CARE CARD (Glassmorphism) ───
  Widget _buildCareCard(Map<String, dynamic> message) {
    final title = message['cardTitle'] ?? '';
    final subtitle = message['cardSubtitle'] ?? '';

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16, left: 36),
        width: MediaQuery.of(context).size.width * 0.78,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _maaSaffronLight.withValues(alpha: 0.92),
                    Colors.white.withValues(alpha: 0.75),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: _maaSaffron.withValues(alpha: 0.2), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: _maaSaffron.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _maaSaffron.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.restaurant,
                            size: 20, color: _maaSaffron),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: _maaTextDark,
                          ),
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios,
                          size: 14, color: _maaTextSub),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      height: 1.4,
                      color: _maaTextSub,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_maaSaffron, _maaGold],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: _maaSaffron.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        'order_now'.tr(context).toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
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

  // ─── TYPING INDICATOR ───
  Widget _buildTypingIndicator() {
    final lang = _groqService.language;
    final typingText = {
      'hindi': 'माँ टाइप कर रही है',
      'english': 'Maa is typing',
      'hinglish': 'Maa is typing',
      'bengali': 'মা লিখছে',
    };

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(left: 52, bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: _maaSaffronLight,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _maaSaffronBorder, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              typingText[lang] ?? typingText['hinglish']!,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: _maaTextSub,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(width: 8),
            _buildDot(0),
            const SizedBox(width: 5),
            _buildDot(1),
            const SizedBox(width: 5),
            _buildDot(2),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(int index) {
    return AnimatedBuilder(
      animation: _typingController,
      builder: (context, child) {
        final offset =
            sin((_typingController.value * 2 * pi) + (index * 0.9));
        return Transform.translate(
          offset: Offset(0, -4 * offset.abs()),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  _maaSaffron.withValues(alpha: 0.4 + 0.4 * offset.abs()),
            ),
          ),
        );
      },
    );
  }

  // ─── QUICK REPLY CHIPS ───
  Widget _buildQuickReplyChips() {
    final lang = _groqService.language;
    final replies = {
      'hindi': [
        'माँ, मेरा ऑर्डर कहाँ है? 📦',
        'आज स्पेशल क्या है? 🤔',
        'मुझे भूख लगी है! 🍽\uFE0F',
        'हेल्दी खाना बताओ 🥗',
      ],
      'english': [
        'Maa, where is my order? 📦',
        'What\'s special today? 🤔',
        'I\'m hungry! 🍽\uFE0F',
        'Something healthy 🥗',
      ],
      'hinglish': [
        'Maa, mera order kahan hai? 📦',
        'Aaj special kya hai? 🤔',
        'Mujhe bhook lagi hai! 🍽\uFE0F',
        'Kuch healthy batao 🥗',
      ],
      'bengali': [
        'মা, আমার অর্ডার কোথায়? 📦',
        'আজ বিশেষ কি আছে? 🤔',
        'আমার খুব খিদে পেয়েছে! 🍽\uFE0F',
        'স্বাস্থ্যকর কিছু বলো 🥗',
      ],
    };

    final chips = replies[lang] ?? replies['hinglish']!;

    return Container(
      height: 52,
      padding: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: chips.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () => _onChipTap(chips[index]),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _maaSaffronBorder, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Text(
                  chips[index],
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _maaSaffron,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── INPUT BAR ───
  Widget _buildInputBar() {
    final canSend = !_isTyping && !_isCooldown;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                enabled: canSend,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 15, color: _maaTextDark),
                decoration: InputDecoration(
                  hintText: canSend
                      ? 'chat_hint'.tr(context)
                      : 'please_wait'.tr(context),
                  hintStyle: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: const Color(0xFFBBA890),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: canSend
                      ? _maaWarmBg
                      : _maaWarmBg.withValues(alpha: 0.5),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                ),
                onSubmitted: (_) => _onSendMessage(),
                textInputAction: TextInputAction.send,
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: canSend ? _onSendMessage : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: canSend
                        ? [_maaSaffron, _maaGold]
                        : [_maaSaffron.withValues(alpha: 0.3), _maaGold.withValues(alpha: 0.3)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _maaSaffron.withValues(alpha: canSend ? 0.35 : 0.1),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: const Icon(Icons.send_rounded,
                    color: Colors.white, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════
//   SETTINGS BOTTOM SHEET WIDGET
// ══════════════════════════════════════════════════════
class _SettingsSheet extends StatefulWidget {
  final String currentPersonality;
  final String currentLanguage;
  final int currentAvatarIndex;
  final ValueChanged<String> onPersonalityChanged;
  final ValueChanged<String> onLanguageChanged;
  final ValueChanged<int> onAvatarChanged;
  final VoidCallback onClearChat;

  const _SettingsSheet({
    required this.currentPersonality,
    required this.currentLanguage,
    required this.currentAvatarIndex,
    required this.onPersonalityChanged,
    required this.onLanguageChanged,
    required this.onAvatarChanged,
    required this.onClearChat,
  });

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  late String _personality;
  late String _language;
  late int _avatarIndex;

  @override
  void initState() {
    super.initState();
    _personality = widget.currentPersonality;
    _language = widget.currentLanguage;
    _avatarIndex = widget.currentAvatarIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _maaWarmBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: _maaTextSub.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),

            // Title
            Row(
              children: [
                const Icon(Icons.tune_rounded, color: _maaSaffron, size: 24),
                const SizedBox(width: 10),
                Text(
                  'Maa Settings',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _maaTextDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Chatbot name "Maa" cannot be changed',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: _maaTextSub,
                fontStyle: FontStyle.italic,
              ),
            ),

            const SizedBox(height: 24),

            // ── Avatar Selection ──
            _sectionTitle('Choose Maa\'s Avatar', Icons.face_retouching_natural),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(3, (i) {
                final isSelected = _avatarIndex == i;
                return GestureDetector(
                  onTap: () {
                    setState(() => _avatarIndex = i);
                    widget.onAvatarChanged(i);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? _maaSaffron : _maaSaffronBorder,
                        width: isSelected ? 3 : 1.5,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: _maaSaffron.withValues(alpha: 0.3),
                                blurRadius: 12,
                                spreadRadius: 2,
                              )
                            ]
                          : [],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        _maaAvatarPaths[i],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: _maaSaffronLight,
                          child: Center(
                            child: Text('${i + 1}',
                                style: const TextStyle(fontSize: 20)),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),

            const SizedBox(height: 28),

            // ── Personality ──
            _sectionTitle('Maa\'s Personality', Icons.psychology),
            const SizedBox(height: 12),
            _buildOptionGrid(
              options: {
                'caring': ('💕', 'Caring', 'Warm & nurturing'),
                'strict': ('👩‍🏫', 'Strict', 'Firm but loving'),
                'funny': ('😄', 'Funny', 'Witty & playful'),
                'spiritual': ('🧘', 'Spiritual', 'Wise & calm'),
              },
              selected: _personality,
              onSelect: (val) {
                setState(() => _personality = val);
                widget.onPersonalityChanged(val);
              },
            ),

            const SizedBox(height: 28),

            // ── Language ──
            _sectionTitle('Maa\'s Language', Icons.language),
            const SizedBox(height: 12),
            _buildOptionGrid(
              options: {
                'hinglish': ('🇮🇳', 'Hinglish', 'Hindi + English'),
                'hindi': ('🕉️', 'Hindi', 'Pure Hindi'),
                'english': ('🌐', 'English', 'English only'),
                'bengali': ('🇧🇩', 'Bengali', 'Pure Bengali'),
              },
              selected: _language,
              onSelect: (val) {
                setState(() => _language = val);
                widget.onLanguageChanged(val);
              },
            ),

            const SizedBox(height: 28),

            // ── Clear Chat ──
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: _maaWarmBg,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      title: Text(
                        'Clear Chat History?',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          color: _maaTextDark,
                        ),
                      ),
                      content: Text(
                        'This will clear Maa\'s memory of your conversations. She\'ll forget everything!',
                        style: GoogleFonts.plusJakartaSans(
                          color: _maaTextSub,
                          height: 1.5,
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text('Cancel',
                              style: GoogleFonts.plusJakartaSans(
                                  color: _maaTextSub)),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            widget.onClearChat();
                          },
                          child: Text('Clear',
                              style: GoogleFonts.plusJakartaSans(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                label: Text(
                  'Clear Chat & Memory',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: _maaSaffron),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: _maaTextDark,
          ),
        ),
      ],
    );
  }

  Widget _buildOptionGrid({
    required Map<String, (String emoji, String label, String subtitle)> options,
    required String selected,
    required ValueChanged<String> onSelect,
  }) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options.entries.map((e) {
        final isSelected = e.key == selected;
        final (emoji, label, subtitle) = e.value;
        return GestureDetector(
          onTap: () => onSelect(e.key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: (MediaQuery.of(context).size.width - 60) / 2,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? _maaSaffronLight : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? _maaSaffron : _maaSaffronBorder,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: _maaSaffron.withValues(alpha: 0.15),
                        blurRadius: 8,
                        spreadRadius: 1,
                      )
                    ]
                  : [],
            ),
            child: Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? _maaSaffron : _maaTextDark,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          color: _maaTextSub,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle, color: _maaSaffron, size: 18),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
