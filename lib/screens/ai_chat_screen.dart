import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Maa AI Warm Color Palette ───
const Color _maaWarmBg = Color(0xFFFFF8F0);
const Color _maaSaffron = Color(0xFFE8722A);
const Color _maaSaffronLight = Color(0xFFFFF3E8);
const Color _maaSaffronBorder = Color(0xFFFADEC9);
const Color _maaDeepPurple = Color(0xFF6C3FA0);
const Color _maaTextDark = Color(0xFF2D1B0E);
const Color _maaTextSub = Color(0xFF8B7355);
const Color _maaGold = Color(0xFFC2941B);

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen>
    with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late AnimationController _glowController;
  late AnimationController _typingController;

  List<Map<String, dynamic>> _messages = [];
  bool _isTyping = false;

  // Hardcoded sample conversation
  final List<Map<String, dynamic>> _sampleMessages = [
    {
      'text': 'Beta, aaj kya khaya? Subah se kuch khaya ki nahi? 🍛',
      'isUser': false,
      'time': '9:00 AM',
      'type': 'text',
    },
    {
      'text': 'Good morning Maa! Bas chai pi li 😅',
      'isUser': true,
      'time': '9:02 AM',
      'type': 'text',
    },
    {
      'text':
          'Sirf chai?! Beta, yeh koi tarika hai? Tera pet khali hai aur tu chai pe jee raha hai. Chal, ek accha sa nashta order kar — paratha with dahi. Ghar jaisa milega!',
      'isUser': false,
      'time': '9:02 AM',
      'type': 'text',
    },
    {
      'text': '',
      'isUser': false,
      'time': '9:03 AM',
      'type': 'care_card',
      'cardTitle': 'Breakfast Skipped!',
      'cardSubtitle':
          'You haven\'t ordered breakfast today. Maa recommends Aloo Paratha + Curd from Sharma Kitchen.',
      'cardIcon': 'restaurant',
    },
    {
      'text': 'Haan Maa, order kar deta hoon 😊',
      'isUser': true,
      'time': '9:05 AM',
      'type': 'text',
    },
    {
      'text':
          'Good beta! Aur sun, lunch mein dal chawal khana — simple aur healthy. Zyada bahar ka mat khaa, paisa bhi bachega aur pet bhi sahi rahega. 💚',
      'isUser': false,
      'time': '9:05 AM',
      'type': 'text',
    },
  ];

  // Multiple Maa responses for variety
  final List<String> _maaResponses = [
    'Beta, Maa ko sab pata hai! Tere liye best meal suggest karungi. Thoda ruk... 🍲',
    'Hmm, achha choice hai! Bas portion zyada mat lena, pet kharab ho jayega. 😊',
    'Arey wah! Bahut achha beta. Maa khush hui. Paani bhi piyo time pe! 💧',
    'Dekh beta, ghar ka khana best hota hai. Bahar ka zyada mat kha. Maa ki baat maan. 🏠',
    'Thoda healthy bhi kha le — salad, dahi, fruits. Balance rakhna zaroori hai beta. 🥗',
    'Aaj teri Maa ki special recipe try kar — dal tadka with jeera rice. Comfort food hai! 🍛',
  ];

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

    _loadSampleConversation();
  }

  void _loadSampleConversation() {
    setState(() {
      _messages = List.from(_sampleMessages);
    });

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _isTyping = true);
    });
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add({
            'text':
                'Aur beta, paani pi raha hai na time pe? Dehydration se headache hota hai. 💧',
            'isUser': false,
            'time': '9:10 AM',
            'type': 'text',
          });
        });
        _scrollToBottom();
      }
    });
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

  void _onSendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({
        'text': text,
        'isUser': true,
        'time': 'Just now',
        'type': 'text',
      });
      _messageController.clear();
      _isTyping = true;
    });
    _scrollToBottom();

    final response = _maaResponses[Random().nextInt(_maaResponses.length)];
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add({
            'text': response,
            'isUser': false,
            'time': 'Just now',
            'type': 'text',
          });
        });
        _scrollToBottom();
      }
    });
  }

  void _onChipTap(String label) {
    _messageController.text = label;
    _onSendMessage();
  }

  @override
  void dispose() {
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
          Expanded(child: _buildMessageList()),
          if (_isTyping) _buildTypingIndicator(),
          _buildQuickReplyChips(),
          _buildInputBar(),
        ],
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
            _maaSaffron.withOpacity(0.15),
            _maaWarmBg,
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: _maaSaffron.withOpacity(0.08),
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
                color: _maaSaffron.withOpacity(0.25 + 0.2 * v),
                blurRadius: 16 + 8 * v,
                spreadRadius: 2 + 2 * v,
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _maaSaffronLight,
                  _maaSaffron.withOpacity(0.7),
                ],
                stops: const [0.4, 1.0],
              ),
              border: Border.all(color: Colors.white, width: 2.5),
            ),
            child: const Center(
              child: Text('\uD83D\uDE4F', style: TextStyle(fontSize: 22)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPersonaBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: _maaDeepPurple.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _maaDeepPurple.withOpacity(0.2)),
      ),
      child: Text(
        'Maa Mode',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: _maaDeepPurple,
        ),
      ),
    );
  }

  Widget _buildGlassMenuButton() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: const Icon(Icons.tune_rounded, size: 20, color: _maaTextSub),
        ),
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
                color: _maaDeepPurple.withOpacity(0.15),
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

    // Maa's message
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
              color: _maaSaffronBorder,
            ),
            child: const Center(
              child: Text('\uD83D\uDE4F', style: TextStyle(fontSize: 14)),
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
                  color: Colors.black.withOpacity(0.03),
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
                    _maaSaffronLight.withOpacity(0.92),
                    Colors.white.withOpacity(0.75),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: _maaSaffron.withOpacity(0.2), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: _maaSaffron.withOpacity(0.06),
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
                          color: _maaSaffron.withOpacity(0.12),
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
                          color: _maaSaffron.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        'Order Now',
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
                  _maaSaffron.withOpacity(0.4 + 0.4 * offset.abs()),
            ),
          ),
        );
      },
    );
  }

  // ─── QUICK REPLY CHIPS ───
  Widget _buildQuickReplyChips() {
    final chips = [
      'What should I eat? \uD83E\uDD14',
      'I\'m hungry! \uD83C\uDF7D\uFE0F',
      'Plan my meals \uD83D\uDCCB',
      'Budget khana \uD83D\uDCB0',
      'Something healthy \uD83E\uDD57',
    ];

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
                      color: Colors.black.withOpacity(0.03),
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
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 15, color: _maaTextDark),
                decoration: InputDecoration(
                  hintText: 'Maa se baat karo...',
                  hintStyle: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: const Color(0xFFBBA890),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: _maaWarmBg,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                ),
                onSubmitted: (_) => _onSendMessage(),
                textInputAction: TextInputAction.send,
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _onSendMessage,
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [_maaSaffron, _maaGold],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _maaSaffron.withOpacity(0.35),
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
