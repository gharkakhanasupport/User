import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TransitionScreen extends StatefulWidget {
  final Future<void> Function() onTransition;
  final String message;

  const TransitionScreen({
    super.key,
    required this.onTransition,
    required this.message,
  });

  @override
  State<TransitionScreen> createState() => _TransitionScreenState();
}

class _TransitionScreenState extends State<TransitionScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
    _executeTransition();
  }

  Future<void> _executeTransition() async {
    // Artificial delay for smooth UX transition effect
    await Future.delayed(const Duration(milliseconds: 600));
    await widget.onTransition();
    await Future.delayed(const Duration(milliseconds: 800));
    
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Enforce a hardcoded neutral look so it doesn't flash during theme changes
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RotationTransition(
              turns: _controller,
              child: const Icon(Icons.sync, size: 64, color: Color(0xFF2DA832)),
            ),
            const SizedBox(height: 24),
            Text(
              widget.message,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
