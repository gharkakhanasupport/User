import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/subscription_service.dart';
import '../models/subscription.dart';
import 'subscription_details_screen.dart';

class ManageSubscriptionsScreen extends StatefulWidget {
  final bool hideAppBar;
  const ManageSubscriptionsScreen({super.key, this.hideAppBar = false});

  @override
  State<ManageSubscriptionsScreen> createState() => _ManageSubscriptionsScreenState();
}

class _ManageSubscriptionsScreenState extends State<ManageSubscriptionsScreen> {
  final _subscriptionService = SubscriptionService();
  List<UserSubscription> _activeSubscriptions = [];
  List<UserSubscription> _pastSubscriptions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSubscriptions();
  }

  Future<void> _loadSubscriptions() async {
    setState(() => _isLoading = true);
    try {
      final all = await _subscriptionService.getUserSubscriptions();
      if (mounted) {
        setState(() {
          _activeSubscriptions = all.where((s) => s.isActive).toList();
          _pastSubscriptions = all.where((s) => !s.isActive).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading subscriptions: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color customPrimary = Color(0xFF2DA9A5);
    const Color backgroundLight = Color(0xFFF6F8F8);

    return Scaffold(
      backgroundColor: backgroundLight,
      appBar: widget.hideAppBar
          ? null
          : AppBar(
              backgroundColor: backgroundLight.withValues(alpha: 0.95),
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                'My Subscriptions',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              centerTitle: true,
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh, color: Color(0xFF64748B)),
                  onPressed: _loadSubscriptions,
                ),
              ],
            ),
      body: RefreshIndicator(
        onRefresh: _loadSubscriptions,
        color: customPrimary,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF2DA9A5)))
            : (_activeSubscriptions.isEmpty && _pastSubscriptions.isEmpty)
                ? _buildEmptyState()
                : SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Active Subscriptions
                        if (_activeSubscriptions.isNotEmpty) ...[
                          _buildSectionHeader('Active Subscriptions', _activeSubscriptions.length, customPrimary),
                          const SizedBox(height: 12),
                          ..._activeSubscriptions.map((sub) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _buildActiveCard(sub, customPrimary),
                              )),
                          const SizedBox(height: 24),
                        ],

                        // Past Subscriptions
                        if (_pastSubscriptions.isNotEmpty) ...[
                          _buildSectionHeader('Past Subscriptions', _pastSubscriptions.length, Colors.grey),
                          const SizedBox(height: 12),
                          ..._pastSubscriptions.map((sub) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _buildPastCard(sub),
                              )),
                        ],

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.card_membership, size: 64, color: Color(0xFF16A34A)),
            ),
            const SizedBox(height: 24),
            Text(
              'No Subscriptions Yet',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Text(
                'Subscribe to your favorite kitchens for daily home-cooked meals!',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: const Color(0xFF94A3B8),
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.explore, size: 18),
              label: Text(
                'Explore Kitchens',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$count',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveCard(UserSubscription sub, Color primaryColor) {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SubscriptionDetailsScreen(subscription: sub),
          ),
        );
        _loadSubscriptions(); // Refresh after returning
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Kitchen Image
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: const Color(0xFFF1F5F9),
                    image: sub.kitchenImageUrl != null
                        ? DecorationImage(
                            image: NetworkImage(sub.kitchenImageUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: sub.kitchenImageUrl == null
                      ? const Icon(Icons.restaurant, color: Color(0xFF94A3B8))
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              sub.kitchenName ?? sub.planName,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F172A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6, height: 6,
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade600,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Active',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        sub.planLabel,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildInfoChip(Icons.currency_rupee, sub.priceDisplay, 'Price'),
                  _buildInfoChip(Icons.calendar_today, '${sub.daysRemaining}d left', 'Remaining'),
                  _buildInfoChip(Icons.refresh, sub.autoRenewal ? 'On' : 'Off', 'Auto-Renew'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'View Details',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward_ios, size: 12, color: primaryColor),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String value, String label) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: const Color(0xFF64748B)),
            const SizedBox(width: 4),
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            color: const Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }

  Widget _buildPastCard(UserSubscription sub) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xFFF1F5F9),
              image: sub.kitchenImageUrl != null
                  ? DecorationImage(
                      image: NetworkImage(sub.kitchenImageUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: sub.kitchenImageUrl == null
                ? const Icon(Icons.restaurant, size: 20, color: Color(0xFF94A3B8))
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sub.kitchenName ?? sub.planName,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${sub.planLabel} • ${sub.startDateDisplay} - ${sub.endDateDisplay}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: sub.isCancelled ? Colors.red.shade50 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              sub.isCancelled ? 'Cancelled' : 'Expired',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: sub.isCancelled ? Colors.red.shade600 : Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
