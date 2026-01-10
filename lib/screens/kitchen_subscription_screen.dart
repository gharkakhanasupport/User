import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class KitchenSubscriptionScreen extends StatefulWidget {
  final String kitchenName;
  final String imageUrl;
  final String price;
  final String rating;

  const KitchenSubscriptionScreen({
    super.key,
    required this.kitchenName,
    required this.imageUrl,
    required this.price,
    required this.rating,
  });

  @override
  State<KitchenSubscriptionScreen> createState() => _KitchenSubscriptionScreenState();
}

class _KitchenSubscriptionScreenState extends State<KitchenSubscriptionScreen> {
  String _selectedPlan = 'Monthly';

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
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                            image: DecorationImage(
                              image: NetworkImage(widget.imageUrl),
                              fit: BoxFit.cover,
                            ),
                          ),
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
                                    '• Home-style',
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

                  // Plan Selection
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
                      Expanded(child: _buildPlanOption('Weekly', '7 Days', '₹850')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildPlanOption('Monthly', '30 Days', widget.price)),
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
                  _buildMenuItem('Breakfast', 'Aloo Paratha, Poha, Idli Sambhar', Icons.wb_twilight),
                  const SizedBox(height: 12),
                  _buildMenuItem('Lunch', 'Rajma Chawal, Roti Sabzi, Dal Makhani', Icons.wb_sunny),
                  const SizedBox(height: 12),
                  _buildMenuItem('Dinner', 'Paneer Bhurji, Mixed Veg, Khichdi', Icons.nights_stay),

                  const SizedBox(height: 24),
                  
                  // Benefits
                  Container(
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
                        _buildBenefitItem('Free Delivery on all meals'),
                        const SizedBox(height: 8),
                        _buildBenefitItem('Skip or Pause anytime'),
                        const SizedBox(height: 8),
                        _buildBenefitItem('Weekly Menu updates'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Bar
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade100)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
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
                          _selectedPlan == 'Monthly' ? widget.price : '₹850',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton(
                      onPressed: () {
                        // Implement payment logic here
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Processing Payment...')),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                        shadowColor: const Color(0xFF16A34A).withOpacity(0.4),
                      ),
                      child: Text(
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanOption(String title, String duration, String price) {
    final isSelected = _selectedPlan == title;
    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = title),
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
              Text(
                meal,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              Text(
                desc,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                ),
              ),
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
        Text(
          text,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF166534),
          ),
        ),
      ],
    );
  }
}
