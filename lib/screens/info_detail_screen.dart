import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class InfoDetailScreen extends StatelessWidget {
  final String title;
  final String type;

  const InfoDetailScreen({
    super.key,
    required this.title,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF121712)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF121712),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade100, height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (type) {
      case 'about':
        return _buildAboutContent();
      case 'privacy':
        return _buildPrivacyContent();
      case 'refund':
        return _buildRefundContent();
      case 'terms':
        return _buildTermsContent();
      case 'deletion':
        return _buildDeletionContent();
      default:
        return const Center(child: Text('No content available'));
    }
  }

  Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF121712),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          content,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            height: 1.6,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildAboutContent() {
    return Column(
      children: [
        _buildSection(
          'The Craving',
          'At Ghar Ka Khana, we focus on providing simple, warm, and familiar food for those moments when you\'re tired after a long day and crave a comforting meal without a complex decision process.',
        ),
        _buildSection(
          'Discovery',
          'We emphasize a clean and calm ordering experience that doesn\'t feel like "work," allowing you to decide quickly and with confidence, knowing you\'re getting real home-cooked food.',
        ),
        _buildSection(
          'Human Touch',
          'Every meal comes from a real home kitchen, not a mass-produced restaurant. Our verified home chefs use real recipes and authentic care to bring you the best homemade experience.',
        ),
      ],
    );
  }

  Widget _buildPrivacyContent() {
    return Column(
      children: [
        _buildSection(
          'Data Collection',
          'We collect personal details such as your name, email, phone number, and delivery address to facilitate orders. Payment information is securely handled via Razorpay.',
        ),
        _buildSection(
          'Usage & Protection',
          'Your data is used solely to process orders, improve your experience, and provide updates. We use secure systems and trusted partners, and we never sell your data to third parties.',
        ),
        _buildSection(
          'User Control',
          'You have full control over your data. You can update or delete your profile information at any time and opt out of non-essential communications.',
        ),
        _buildSection(
          'Contact',
          'For any privacy-related concerns, you can reach out to us at gharkakhanasupport@gmail.com.',
        ),
      ],
    );
  }

  Widget _buildRefundContent() {
    return Column(
      children: [
        _buildSection(
          'User Cancellations',
          'A full refund is available if an order is cancelled BEFORE it is picked up by our delivery partner. Once the order is in transit, no refunds can be processed.',
        ),
        _buildSection(
          'Chef Cancellations',
          'In the rare event that a home chef needs to cancel your order, a full refund will be issued to your original payment method immediately.',
        ),
        _buildSection(
          'Failed Payments',
          'Failed transactions are handled according to the standard processes of our payment provider (Razorpay). Funds usually return to your account within 5-7 business days.',
        ),
        _buildSection(
          'Support',
          'For refund queries, contact us at gharkakhanasupport@gmail.com or call 8910894306.',
        ),
      ],
    );
  }

  Widget _buildTermsContent() {
    return Column(
      children: [
        _buildSection(
          'Nature of Service',
          'Ghar Ka Khana is a marketplace connecting customers with independent home chefs. We are a technology platform, not a restaurant entity.',
        ),
        _buildSection(
          'Ordering & Payments',
          'Orders are offers to purchase products. All payments are processed in INR via Razorpay. Delivery charges apply based on distance.',
        ),
        _buildSection(
          'Cancellations',
          'Full refunds are issued if cancelled before cooking starts. Partial or no refunds may apply once the cooking process has begun.',
        ),
        _buildSection(
          'Prohibitions',
          'Fraud, harassment, automated scraping, and any illegal use of the platform are strictly prohibited and may lead to account termination.',
        ),
      ],
    );
  }

  Widget _buildDeletionContent() {
    return Column(
      children: [
        _buildSection(
          'How to Request Deletion',
          'To delete your account, please send an email to gharkakhanasupport@gmail.com with the subject line: "Account Deletion Request – [Your Registered Phone Number]".',
        ),
        _buildSection(
          'What Gets Deleted',
          'After identity verification, all your profile data, order history, and saved addresses will be permanently deleted from our servers.',
        ),
        _buildSection(
          'Timeline',
          'The account deletion process is typically completed within 7 business days of receiving your request.',
        ),
      ],
    );
  }
}
