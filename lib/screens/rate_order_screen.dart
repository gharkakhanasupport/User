import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/review_service.dart';

/// Rate a delivered order — kitchen + optional delivery partner.
class RateOrderScreen extends StatefulWidget {
  final String orderId;
  final String cookId;
  final String kitchenName;
  final String? deliveryPartnerId;

  const RateOrderScreen({
    super.key,
    required this.orderId,
    required this.cookId,
    required this.kitchenName,
    this.deliveryPartnerId,
  });

  @override
  State<RateOrderScreen> createState() => _RateOrderScreenState();
}

class _RateOrderScreenState extends State<RateOrderScreen> {
  int _kitchenRating = 0;
  int _deliveryRating = 0;
  final _kitchenComment = TextEditingController();
  final _deliveryComment = TextEditingController();
  final _reviewService = ReviewService();
  bool _submitting = false;

  @override
  void dispose() {
    _kitchenComment.dispose();
    _deliveryComment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_kitchenRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tap a star to rate the kitchen')),
      );
      return;
    }
    setState(() => _submitting = true);

    final ok = await _reviewService.submitReview(
      orderId: widget.orderId,
      cookId: widget.cookId,
      kitchenRating: _kitchenRating,
      deliveryRating: _deliveryRating == 0 ? null : _deliveryRating,
      kitchenComment: _kitchenComment.text.trim().isEmpty ? null : _kitchenComment.text.trim(),
      deliveryComment: _deliveryComment.text.trim().isEmpty ? null : _deliveryComment.text.trim(),
      deliveryPartnerId: widget.deliveryPartnerId,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thanks for rating!'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not submit review. Try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _starRow(int current, ValueChanged<int> onChange) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final filled = i < current;
        return IconButton(
          iconSize: 40,
          onPressed: () => onChange(i + 1),
          icon: Icon(
            filled ? Icons.star_rounded : Icons.star_outline_rounded,
            color: filled ? Colors.amber : Colors.grey.shade400,
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text('Rate your order', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Kitchen block
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
              ),
              child: Column(
                children: [
                  Text('How was your food from', style: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.grey.shade600)),
                  const SizedBox(height: 4),
                  Text(
                    widget.kitchenName,
                    style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _starRow(_kitchenRating, (v) => setState(() => _kitchenRating = v)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _kitchenComment,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Tell them what you liked (optional)',
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Delivery block (optional)
            if (widget.deliveryPartnerId != null)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
                ),
                child: Column(
                  children: [
                    Text(
                      'Rate your delivery partner',
                      style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text('Optional', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey.shade500)),
                    const SizedBox(height: 12),
                    _starRow(_deliveryRating, (v) => setState(() => _deliveryRating = v)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _deliveryComment,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Feedback for the rider (optional)',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _submitting
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : Text('Submit Review', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
