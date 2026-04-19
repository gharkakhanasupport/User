import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/subscription.dart';
import '../services/subscription_service.dart';
import '../services/kitchen_service.dart';
import '../models/kitchen.dart';

class SubscriptionDetailsScreen extends StatefulWidget {
  final UserSubscription subscription;

  const SubscriptionDetailsScreen({
    super.key,
    required this.subscription,
  });

  @override
  State<SubscriptionDetailsScreen> createState() => _SubscriptionDetailsScreenState();
}

class _SubscriptionDetailsScreenState extends State<SubscriptionDetailsScreen> {
  final _subscriptionService = SubscriptionService();
  final _kitchenService = KitchenService();
  late UserSubscription _sub;
  Kitchen? _kitchen;
  bool _isLoadingKitchen = true;

  @override
  void initState() {
    super.initState();
    _sub = widget.subscription;
    _loadKitchenDetails();
  }

  Future<void> _loadKitchenDetails() async {
    try {
      final kitchen = await _kitchenService.getKitchenById(_sub.kitchenId);
      if (mounted) {
        setState(() {
          _kitchen = kitchen;
          _isLoadingKitchen = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingKitchen = false);
    }
  }

  Future<void> _toggleAutoRenew() async {
    final newValue = !_sub.autoRenewal;
    final success = await _subscriptionService.toggleAutoRenew(_sub.id, newValue);
    if (success && mounted) {
      setState(() {
        _sub = UserSubscription(
          id: _sub.id,
          userId: _sub.userId,
          kitchenId: _sub.kitchenId,
          planName: _sub.planName,
          planType: _sub.planType,
          monthlyPrice: _sub.monthlyPrice,
          mealCount: _sub.mealCount,
          status: _sub.status,
          startDate: _sub.startDate,
          endDate: _sub.endDate,
          nextBillingDate: _sub.nextBillingDate,
          lastPaymentId: _sub.lastPaymentId,
          autoRenewal: newValue,
          mealPreferences: _sub.mealPreferences,
          specialInstructions: _sub.specialInstructions,
          createdAt: _sub.createdAt,
          updatedAt: DateTime.now(),
          cancelledAt: _sub.cancelledAt,
          kitchenName: _sub.kitchenName,
          kitchenImageUrl: _sub.kitchenImageUrl,
          kitchenRating: _sub.kitchenRating,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Auto-renewal ${newValue ? 'enabled' : 'disabled'}'),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );
    }
  }

  Future<void> _cancelSubscription() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Cancel Subscription?',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to cancel your subscription to ${_sub.kitchenName ?? 'this kitchen'}? You will still have access until ${_sub.endDateDisplay}.',
          style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Keep', style: GoogleFonts.plusJakartaSans(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Cancel Subscription', style: GoogleFonts.plusJakartaSans(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _subscriptionService.cancelSubscription(_sub.id);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Subscription cancelled successfully'),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF2DA9A5);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F8F8),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Subscription Details',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Kitchen Card
            _buildKitchenCard(primaryColor),
            const SizedBox(height: 16),

            // Subscription Status Card
            _buildStatusCard(primaryColor),
            const SizedBox(height: 16),

            // Plan Details
            _buildPlanDetailsCard(),
            const SizedBox(height: 16),

            // Timeline
            _buildTimelineCard(),
            const SizedBox(height: 16),

            // Menu Card (if available)
            if (_kitchen?.subscriptionMenu != null && !_isLoadingKitchen)
              _buildMenuCard(),
            if (_kitchen?.subscriptionMenu != null && !_isLoadingKitchen)
              const SizedBox(height: 16),

            // Settings Card
            if (_sub.isActive) ...[
              _buildSettingsCard(),
              const SizedBox(height: 16),
            ],

            // Cancel Button
            if (_sub.isActive) _buildCancelButton(),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildKitchenCard(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, primaryColor.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white.withValues(alpha: 0.2),
              image: _sub.kitchenImageUrl != null
                  ? DecorationImage(
                      image: NetworkImage(_sub.kitchenImageUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: _sub.kitchenImageUrl == null
                ? const Icon(Icons.restaurant, color: Colors.white, size: 32)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _sub.kitchenName ?? _sub.planName,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (_sub.kitchenRating != null) ...[
                      const Icon(Icons.star, size: 14, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        _sub.kitchenRating!,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _sub.planLabel,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(Color primaryColor) {
    final progress = _sub.isActive
        ? 1 - (_sub.daysRemaining / (_sub.planType == 'weekly' ? 7 : 30))
        : 1.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Subscription Status',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _sub.isActive ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _sub.isActive ? Colors.green.shade200 : Colors.red.shade200,
                  ),
                ),
                child: Text(
                  _sub.isActive ? 'Active' : (_sub.isCancelled ? 'Cancelled' : 'Expired'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _sub.isActive ? Colors.green.shade700 : Colors.red.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_sub.isActive) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_sub.daysRemaining} days remaining',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                  ),
                ),
                Text(
                  '${(progress * 100).toStringAsFixed(0)}% used',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(
                  progress > 0.8 ? Colors.orange : primaryColor,
                ),
                minHeight: 6,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlanDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Plan Details',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          _buildDetailRow('Plan Type', _sub.planLabel),
          _buildDetailRow('Price', _sub.priceDisplay),
          _buildDetailRow('Meals', '${_sub.mealCount} days'),
          if (_sub.mealPreferences != null)
            _buildDetailRow('Preferences', _sub.mealPreferences!),
          if (_sub.specialInstructions != null)
            _buildDetailRow('Instructions', _sub.specialInstructions!),
        ],
      ),
    );
  }

  Widget _buildTimelineCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Timeline',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          _buildDetailRow('Start Date', _sub.startDateDisplay),
          _buildDetailRow('End Date', _sub.endDateDisplay),
          if (_sub.nextBillingDate != null)
            _buildDetailRow('Next Billing', _sub.nextBillingDisplay),
          if (_sub.lastPaymentId != null)
            _buildDetailRow('Payment ID', _sub.lastPaymentId!),
        ],
      ),
    );
  }

  Widget _buildMenuCard() {
    final menu = _kitchen!.subscriptionMenu!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Menu Included',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          ...menu.entries.map((entry) {
            final mealType = entry.key[0].toUpperCase() + entry.key.substring(1);
            final dishes = entry.value is List ? (entry.value as List).join(', ') : entry.value.toString();
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      mealType == 'Breakfast' ? Icons.wb_twilight :
                      mealType == 'Lunch' ? Icons.wb_sunny : Icons.nights_stay,
                      size: 16,
                      color: const Color(0xFF16A34A),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mealType,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          dishes,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSettingsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Settings',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Auto-Renewal',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    'Automatically renew when plan expires',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
              Switch(
                value: _sub.autoRenewal,
                onChanged: (_) => _toggleAutoRenew(),
                activeTrackColor: const Color(0xFF16A34A),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCancelButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _cancelSubscription,
        icon: const Icon(Icons.cancel_outlined, size: 18),
        label: Text(
          'Cancel Subscription',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          side: const BorderSide(color: Colors.red),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: const Color(0xFF64748B),
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0F172A),
              ),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
