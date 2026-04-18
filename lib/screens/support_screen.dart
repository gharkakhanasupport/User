import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _messageController = TextEditingController();
  // Main DB for User Identity
  final _mainAuth = Supabase.instance.client.auth;

  // Dedicated Support DB
  final _supportClient = SupabaseClient(
    'https://lbdmdeutmuppgsbzrxcy.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxiZG1kZXV0bXVwcGdzYnpyeGN5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgyNDQzMzAsImV4cCI6MjA4MzgyMDMzMH0.SWsXY7rjT0uDvBsmadhtM7kS5qnHPrY26ce-wohwyBM',
  );
  
  String? _activeTicketId;
  bool _isLoading = true;
  bool _isConnecting = false;

  // Realtime Typing
  RealtimeChannel? _typingChannel;
  bool _isAgentTyping = false;
  Timer? _typingDebounce;

  // --- AI Chatbot States ---
  bool _isAiMode = true; // Always start in AI mode if no ticket
  int _currentGroqKeyIndex = 1;
  bool _isAiTyping = false;
  
  // Format: role: 'user' | 'assistant', content: String, status: 'none' | 'feedback_needed' | 'satisfied' | 'not_satisfied' | 'human_prompt'
  final List<Map<String, dynamic>> _aiMessages = [];

  @override
  void initState() {
    super.initState();
    _aiMessages.add({
      'role': 'assistant',
      'content': 'Hi! I\'m the AI Assistant. I can help with common questions about the app, orders, or subscriptions. How can I help you today?',
      'status': 'none',
      'created_at': DateTime.now().toIso8601String(),
    });
    _checkActiveTicket();
  }

  @override
  void dispose() {
    _typingDebounce?.cancel();
    _typingChannel?.unsubscribe();
    _messageController.dispose();
    super.dispose();
  }

  void _initRealtime() {
    if (_activeTicketId == null) return;
    
    _typingChannel = _supportClient.channel('chat_presence_$_activeTicketId');
    
    _typingChannel!
        .onBroadcast(event: 'typing', callback: (payload) {
          final isTyping = payload['is_typing'] as bool;
          final role = payload['role'] as String;
          
          if (role == 'agent' && mounted) {
            setState(() => _isAgentTyping = isTyping);
          }
        })
        .subscribe();

    _messageController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (_typingDebounce?.isActive ?? false) _typingDebounce!.cancel();
    
    _typingDebounce = Timer(const Duration(milliseconds: 500), () {
      if (!_isAiMode) {
         _broadcastTyping(_messageController.text.isNotEmpty);
      }
    });
  }

  Future<void> _broadcastTyping(bool isTyping) async {
    await _typingChannel?.sendBroadcastMessage(
      event: 'typing',
      payload: {'is_typing': isTyping, 'role': 'user'},
    );
  }

  Future<void> _checkActiveTicket() async {
    try {
      final userId = _mainAuth.currentUser!.id;
      final data = await _supportClient
          .from('support_tickets')
          .select()
          .eq('user_id', userId)
          .neq('status', 'closed')
          .maybeSingle(); 

      if (mounted) {
        setState(() {
          _activeTicketId = data?['id'];
          _isLoading = false;
        });
        
        if (_activeTicketId != null) {
          _isAiMode = false;
          _listenToTicketStatus();
          _initRealtime(); // Initialize Realtime here
        }
      }
    } catch (e) {
      debugPrint('Error checking tickets: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _listenToTicketStatus() {
    if (_activeTicketId == null) return;
    
    _supportClient
        .from('support_tickets')
        .stream(primaryKey: ['id'])
        .eq('id', _activeTicketId!)
        .listen((data) {
          if (data.isNotEmpty) {
            final status = data.first['status'];
            if (status == 'closed') {
               _handleTicketClosed();
            }
          }
        });
  }

  void _handleTicketClosed() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Icon(Icons.check_circle, color: Colors.green, size: 60),
        content: Text(
          'Your problem is solved.\nThank you for contacting!',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
  }

  Future<void> _closeTicketByUser() async {
    if (_activeTicketId == null) return;
    try {
      await _supportClient
          .from('support_tickets')
          .update({'status': 'closed'})
          .eq('id', _activeTicketId!);
    } catch (e) {
      debugPrint('Error closing ticket: $e');
    }
  }

  Future<void> _createTicket() async {
    setState(() => _isConnecting = true); 
    try {
      final userId = _mainAuth.currentUser!.id;
      final data = await _supportClient
          .from('support_tickets')
          .insert({'user_id': userId})
          .select()
          .single();

      if (mounted) {
        setState(() {
          _activeTicketId = data['id'];
          _isConnecting = false;
          _isAiMode = false; // Switch out of AI mode
        });
        
        // Notify human agent of the reason implicitly through initial ticket. 
        // We can pass context here if needed, but per request, just connect.
        _listenToTicketStatus();
        _initRealtime(); 
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isConnecting = false);
      }
    }
  }

  Future<String> _getAiResponse(String message) async {
    for (int i = 0; i < 5; i++) {
        String keyStr = 'GROQ_API_KEY_${_currentGroqKeyIndex.toString().padLeft(2, '0')}';
        String key = dotenv.env[keyStr] ?? '';
        
        _currentGroqKeyIndex++;
        if (_currentGroqKeyIndex > 5) _currentGroqKeyIndex = 1; // Round robin using only first 5 keys
        
        if (key.isEmpty) continue;

        try {
          final messages = _aiMessages.reversed
            .where((m) => m['role'] != 'error' && m['status'] != 'human_prompt')
            .map((m) => {'role': m['role'], 'content': m['content']})
            .toList();
            
          messages.insert(0, {
            'role': 'system', 
            'content': 'You are a helpful customer support assistant for "Ghar Ka Khana" food delivery app. Keep answers concise and polite. Provide definitive short answers.'
          });

          final response = await http.post(
            Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
            headers: {
              'Authorization': 'Bearer $key',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': 'llama-3.3-70b-versatile',
              'messages': messages,
            }),
          );
          
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            return data['choices'][0]['message']['content'];
          } else {
             debugPrint('Groq API Error $_currentGroqKeyIndex: ${response.body}');
          }
        } catch (e) {
          debugPrint('Groq catch: $e');
        }
    }
    return 'Sorry, I am having trouble connecting right now. Let me know if you would like me to try again or if you prefer to speak to an agent.';
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    if (_isAiMode) {
      _messageController.clear();
      setState(() {
        _aiMessages.insert(0, {
          'role': 'user', 
          'content': text, 
          'status': 'none',
          'created_at': DateTime.now().toIso8601String()
        });
        _isAiTyping = true;
      });
      
      final reply = await _getAiResponse(text);
      if (mounted) {
        setState(() {
          _isAiTyping = false;
          _aiMessages.insert(0, {
            'role': 'assistant', 
            'content': reply, 
            'status': 'feedback_needed',
            'created_at': DateTime.now().toIso8601String()
          });
        });
      }
    } else {
      // Send to human
      if (_activeTicketId == null) return;

      try {
        _broadcastTyping(false);
        _messageController.clear();
        
        final userId = _mainAuth.currentUser!.id;
        await _supportClient.from('chat_messages').insert({
          'ticket_id': _activeTicketId,
          'sender_id': userId,
          'message': text,
          'is_agent': false,
        });
      } catch (e) {
        debugPrint('Error sending message: $e');
      }
    }
  }

  void _handleFeedback(int index, bool satisfied) {
    setState(() {
      _aiMessages[index]['status'] = satisfied ? 'satisfied' : 'not_satisfied';
      if (!satisfied) {
        _aiMessages.insert(0, {
          'role': 'assistant',
          'content': 'I apologize that I couldn\'t resolve your issue. Would you like to talk to a human agent?',
          'status': 'human_prompt',
          'created_at': DateTime.now().toIso8601String()
        });
      } else {
        _aiMessages.insert(0, {
          'role': 'assistant',
          'content': 'Glad I could help!',
          'status': 'none',
          'created_at': DateTime.now().toIso8601String()
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text('Customer Support', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          if (_activeTicketId != null)
            TextButton(
              onPressed: _closeTicketByUser,
              child: Text(
                'Mark as Solved',
                style: GoogleFonts.plusJakartaSans(
                   color: Colors.green, fontWeight: FontWeight.bold
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isAiMode
              ? _buildAiChatInterface()
              : _buildHumanChatInterface(),
    );
  }

  Widget _buildAiChatInterface() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            reverse: true,
            padding: const EdgeInsets.all(16),
            itemCount: _aiMessages.length,
            itemBuilder: (context, index) {
              final msg = _aiMessages[index];
              final isUser = msg['role'] == 'user';
              final status = msg['status'];
              final time = DateTime.parse(msg['created_at']).toLocal();
              
              return Align(
                alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                  child: Column(
                    crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isUser ? const Color(0xFF2da832) : Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: isUser ? const Radius.circular(16) : Radius.zero,
                            bottomRight: isUser ? Radius.zero : const Radius.circular(16),
                          ),
                          boxShadow: [
                            if (!isUser) BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              msg['content'],
                              style: TextStyle(color: isUser ? Colors.white : Colors.black87, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              timeago.format(time),
                              style: TextStyle(color: isUser ? Colors.white70 : Colors.grey[500], fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      
                      if (!isUser && status == 'feedback_needed' && index == 0) // only for latest message
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0, left: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton.icon(
                                onPressed: () => _handleFeedback(index, true),
                                icon: const Icon(Icons.thumb_up, size: 16, color: Colors.green),
                                label: Text('Satisfied', style: GoogleFonts.plusJakartaSans(color: Colors.green)),
                              ),
                              TextButton.icon(
                                onPressed: () => _handleFeedback(index, false),
                                icon: const Icon(Icons.thumb_down, size: 16, color: Colors.red),
                                label: Text('Not Satisfied', style: GoogleFonts.plusJakartaSans(color: Colors.red)),
                              ),
                            ],
                          ),
                        ),
                        
                      if (!isUser && status == 'human_prompt')
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0, left: 8, bottom: 8),
                          child: ElevatedButton.icon(
                             onPressed: _isConnecting ? null : _createTicket,
                             icon: _isConnecting
                                 ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                 : const Icon(Icons.support_agent),
                             label: Text(_isConnecting ? 'Connecting...' : 'Talk to Human Agent'),
                             style: ElevatedButton.styleFrom(
                               backgroundColor: const Color(0xFF2da832),
                               foregroundColor: Colors.white,
                               elevation: 0,
                               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                             ),
                          ),
                        ),
                        
                      if (!isUser && status == 'not_satisfied' && index > 0)
                        Padding(
                           padding: const EdgeInsets.only(top: 4, left: 8),
                           child: Text('You marked this as unsatisfactory.', style: TextStyle(color: Colors.red[300], fontSize: 11)),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (_isAiTyping)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const SizedBox(
                  width: 16, height: 16, 
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2da832)),
                ),
                const SizedBox(width: 8),
                Text('AI assistant is typing...', style: GoogleFonts.plusJakartaSans(color: Colors.grey[600], fontStyle: FontStyle.italic)),
              ],
            ),
          ),
        _buildInputField(),
      ],
    );
  }

  Widget _buildHumanChatInterface() {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _supportClient
                .from('chat_messages')
                .stream(primaryKey: ['id'])
                .eq('ticket_id', _activeTicketId!)
                .order('created_at', ascending: false),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              
              final messages = snapshot.data!;
              if (messages.isEmpty) {
                 return const Center(child: Text('Connected to agent. Clear your doubt...'));
              }

              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  final isAgent = msg['is_agent'] as bool;
                  final time = DateTime.parse(msg['created_at']).toLocal();
                  
                  return Align(
                    alignment: isAgent ? Alignment.centerLeft : Alignment.centerRight,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                      decoration: BoxDecoration(
                        color: isAgent ? Colors.white : const Color(0xFF2da832),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: isAgent ? Radius.zero : const Radius.circular(16),
                          bottomRight: isAgent ? const Radius.circular(16) : Radius.zero,
                        ),
                        boxShadow: [
                          if (isAgent) BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            msg['message'],
                            style: TextStyle(color: isAgent ? Colors.black87 : Colors.white, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            timeago.format(time),
                            style: TextStyle(color: isAgent ? Colors.grey[500] : Colors.white70, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        if (_isAgentTyping)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const SizedBox(
                  width: 16, height: 16, 
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2da832)),
                ),
                const SizedBox(width: 8),
                Text('Agent is typing...', style: GoogleFonts.plusJakartaSans(color: Colors.grey[600], fontStyle: FontStyle.italic)),
              ],
            ),
          ),
        _buildInputField(),
      ],
    );
  }

  Widget _buildInputField() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.grey.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Type your message...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: const Color(0xFF2da832),
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white),
                onPressed: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
