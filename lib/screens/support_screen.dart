import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

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

  @override
  void initState() {
    super.initState();
    _checkActiveTicket();
  }

  @override
  void dispose() {
    _typingDebounce?.cancel();
    _typingChannel?.unsubscribe();
    _messageController.dispose();
    super.dispose();
  }

  // ... (keeping other methods same, inserting _initRealtime)

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
      _broadcastTyping(_messageController.text.isNotEmpty);
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
          _listenToTicketStatus();
          _initRealtime(); // Initialize Realtime here
        }
      }
    } catch (e) {
      debugPrint('Error checking tickets: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ... (keep _listenToTicketStatus, _handleTicketClosed, _createTicket, _closeTicketByUser same)

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
        });
        _listenToTicketStatus();
        _initRealtime(); // And here
      }
    } catch (e) {
      // ... error handling
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isConnecting = false);
      }
    }
  }
 
  // ... (keep _closeTicketByUser)

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _activeTicketId == null) return;

    try {
       // Stop typing
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          : _activeTicketId == null
              ? _buildAIPlaceholder()
              : _buildChatInterface(),
    );
  }

  // _buildAIPlaceholder is same as before
  Widget _buildAIPlaceholder() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.smart_toy, size: 80, color: Color(0xFF2da832)),
          const SizedBox(height: 24),
          Text(
            'Hi! I\'m the AI Assistant.',
            style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            'I can help with common questions. If you need complex help, connect with a human agent.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _isConnecting ? null : _createTicket,
              icon: _isConnecting
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white))
                  : const Icon(Icons.headset_mic),
              label: Text(
                _isConnecting ? 'Connecting...' : 'Talk to Human Agent',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2da832),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // _buildChatInterface uses _supportClient now
  Widget _buildChatInterface() {
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
                        color: isAgent ? Colors.grey[200] : const Color(0xFF2da832),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: isAgent ? Radius.zero : const Radius.circular(16),
                          bottomRight: isAgent ? const Radius.circular(16) : Radius.zero,
                        ),
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
                            style: TextStyle(color: isAgent ? Colors.grey[600] : Colors.white70, fontSize: 10),
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
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, -2))],
          ),
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
      ],
    );
  }
}
