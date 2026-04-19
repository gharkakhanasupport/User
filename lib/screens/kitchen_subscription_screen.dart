import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../services/payment_service.dart';
import '../services/subscription_service.dart';
import '../services/kitchen_service.dart';
import '../models/kitchen.dart';

class KitchenSubscriptionScreen extends StatefulWidget {
  final String kitchenName;
  final String imageUrl;
  final String rating;
  final String cookId;

  const KitchenSubscriptionScreen({
    super.key,
    required this.kitchenName,
    required this.imageUrl,
    required this.rating,
    required this.cookId,
  });

  @override
  State<KitchenSubscriptionScreen> createState() => _KitchenSubscriptionScreenState();
}

class _KitchenSubscriptionScreenState extends State<KitchenSubscriptionScreen> {
  final _paymentService = PaymentService();
  final _subscriptionService = SubscriptionService();
  final _kitchenService = KitchenService();
  String _selectedPlan = 'monthly';
  bool _isProcessing = false;
  bool _isLoading = true;
  bool _alreadySubscribed = false;
  Kitchen? _kitchen;

  @override
  void initState() {
    super.initState();
    _setupPaymentHandlers();
    _loadKitchenData();
  }

  Future<void> _loadKitchenData() async {
    setState(() => _isLoading = true);
    try {
      // Load kitchen details with subscription fields
      final kitchen = await _kitchenService.getKitchenByCookId(widget.cookId);
      final isSubscribed = await _subscriptionService.isSubscribedToKitchen(
        kitchen?.id ?? '',
      );

      if (mounted) {
        setState(() {
          _kitchen = kitchen;
          _alreadySubscribed = isSubscribed;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading kitchen data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _setupPaymentHandlers() {
    _paymentService.onSuccess = (PaymentSuccessResponse response) async {
      if (mounted) {
        // Create the subscription record in User DB
        await _subscriptionService.subscribeToKitchen(
          kitchenId: _kitchen?.id ?? '',
          kitchenName: widget.kitchenName,
          planType: _selectedPlan,
          price: _getPrice(),
          mealCount: _selectedPlan == 'weekly' ? 7 : 30,
          paymentId: response.paymentId,
        );
        setState(() => _isProcessing = false);
        _showSuccessDialog();
      }
    };
    _paymentService.onFailure = (PaymentFailureResponse response) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment Failed: ${response.message}'), backgroundColor: Colors.red),
        );
      }
    };
  }

  @override
  void dispose() {
    _paymentService.dispose();
    super.dispose();
  }

  double _getPrice() {
    if (_selectedPlan == 'weekly') {
      return _kitchen?.weeklyPlanPrice ?? 850;
    }
    return _kitchen?.monthlyPlanPrice ?? 3500;
  }

  Future<void> _handlePayment() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to subscribe')),
      );
      return;
    }

    if (_alreadySubscribed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You already have an active subscription with this kitchen'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    _paymentService.openCheckout(
      amount: _getPrice(),
      kitchenName: widget.kitchenName,
      userEmail: user.email ?? 'customer@example.com',
      userPhone: user.phone ?? user.userMetadata?['phone'] ?? '9999999999',
      description: '${_selectedPlan == 'weekly' ? 'Weekly' : 'Monthly'} Subscription for ${widget.kitchenName}',
      notes: {
        'order_type': 'kitchen_subscription',
        'user_id': user.id,
        'cook_id': widget.cookId,
        'kitchen_id': _kitchen?.id ?? '',
        'plan_duration': _selectedPlan,
      },
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 64),
            const SizedBox(height: 16),
            Text('Subscription Successful!', style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'You are now subscribed to ${widget.kitchenName}.\n${_selectedPlan == 'weekly' ? '7' : '30'} days of delicious meals!',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                minimumSize: const Size(double.infinity, 48),
              ),
              child: const Text('Continue', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Subscription Plan',
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF0F172A),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF16A34A)))
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Already Subscribed Banner
                        if (_alreadySubscribed)
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF3CD),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFFFD700)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline, color: Color(0xFFC2941B)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'You already have an active subscription with this kitchen.',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF856404),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Kitchen Info Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: const Color(0xFFF1F5F9),
                                  image: widget.imageUrl.isNotEmpty
                                      ? DecorationImage(
                                          image: NetworkImage(widget.imageUrl),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: widget.imageUrl.isEmpty
                                    ? const Icon(Icons.restaurant, color: Color(0xFF94A3B8))
                                    : null,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.kitchenName,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.star, size: 14, color: Color(0xFFC2941B)),
                                        const SizedBox(width: 4),
                                        Text(
                                          widget.rating,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '• ${_kitchen?.isVegetarian == true ? 'Pure Veg' : 'Home-style'}',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12,
                                            color: const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // No Subscription Available Message
                        if (!(_kitchen?.hasSubscription ?? false)) ...[
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.info_outline, size: 48, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                Text(
                                  'Subscription plans not available yet',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF475569),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'This kitchen hasn\'t set up subscription pricing yet. Check back soon!',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Plan Selection (only if kitchen offers subscriptions)
                        if (_kitchen?.hasSubscription ?? false) ...[
                          Text(
                            'Choose Plan Duration',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              if (_kitchen?.weeklyPlanPrice != null)
                                Expanded(
                                  child: _buildPlanOption(
                                    'weekly',
                                    'Weekly',
                                    '7 Days',
                                    '₹${_kitchen!.weeklyPlanPrice!.toStringAsFixed(0)}',
                                  ),
                                ),
                              if (_kitchen?.weeklyPlanPrice != null && _kitchen?.monthlyPlanPrice != null)
                                const SizedBox(width: 12),
                              if (_kitchen?.monthlyPlanPrice != null)
                                Expanded(
                                  child: _buildPlanOption(
                                    'monthly',
                                    'Monthly',
                                    '30 Days',
                                    '₹${_kitchen!.monthlyPlanPrice!.toStringAsFixed(0)}',
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Menu Highlights
                          Text(
                            'What\'s on the Menu?',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildMenuSection(),
                          const SizedBox(height: 24),

                          // Benefits
                          _buildBenefitsSection(),
                        ],
                      ],
                    ),
                  ),
                ),

                // Bottom Bar (only if kitchen offers subscriptions and not already subscribed)
                if ((_kitchen?.hasSubscription ?? false) && !_alreadySubscribed)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: Colors.grey.shade100)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Amount',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                            Text(
                              '₹${_getPrice().toStringAsFixed(0)}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton(
                          onPressed: _isProcessing ? null : _handlePayment,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 4,
                            shadowColor: const Color(0xFF16A34A).withValues(alpha: 0.4),
                          ),
                          child: _isProcessing
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Text(
                                  'Pay & Subscribe',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildMenuSection() {
    final menu = _kitchen?.subscriptionMenu;
    if (menu == null || menu.isEmpty) {
      // Fallback: show generic info
      return Column(
        children: [
          _buildMenuItem('Breakfast', 'Fresh daily items', Icons.wb_twilight),
          const SizedBox(height: 12),
          _buildMenuItem('Lunch', 'Home-style meals', Icons.wb_sunny),
          const SizedBox(height: 12),
          _buildMenuItem('Dinner', 'Comfort food', Icons.nights_stay),
        ],
      );
    }

    final List<Widget> items = [];
    final mealIcons = {
      'breakfast': Icons.wb_twilight,
      'lunch': Icons.wb_sunny,
      'dinner': Icons.nights_stay,
    };

    menu.forEach((mealType, dishes) {
      final dishList = dishes is List ? dishes.join(', ') : dishes.toString();
      items.add(
        _buildMenuItem(
          mealType[0].toUpperCase() + mealType.substring(1),
          dishList,
          mealIcons[mealType.toLowerCase()] ?? Icons.restaurant,
        ),
      );
      items.add(const SizedBox(height: 12));
    });

    return Column(children: items);
  }

  Widget _buildBenefitsSection() {
    final benefits = _kitchen?.subscriptionBenefits ??
        ['Free Delivery on all meals', 'Skip or Pause anytime', 'Weekly Menu updates'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCFCE7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Subscription Benefits',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF166534),
            ),
          ),
          const SizedBox(height: 12),
          ...benefits.map((b) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildBenefitItem(b),
              )),
        ],
      ),
    );
  }

  Widget _buildPlanOption(String type, String title, String duration, String price) {
    final isSelected = _selectedPlan == type;
    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = type),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFDCFCE7) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            if (type == 'monthly')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Best Value',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isSelected ? const Color(0xFF166534) : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              price,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              duration,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(String meal, String desc, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: const Color(0xFF475569)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(meal, style: GoogleFonts.plusJakartaSans(
                fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A),
              )),
              Text(desc, style: GoogleFonts.plusJakartaSans(
                fontSize: 12, color: const Color(0xFF64748B),
              )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBenefitItem(String text) {
    return Row(
      children: [
        const Icon(Icons.check_circle, size: 16, color: Color(0xFF16A34A)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: GoogleFonts.plusJakartaSans(
            fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF166534),
          )),
        ),
      ],
    );
  }
}
