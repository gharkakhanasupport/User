import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/localization.dart';
import 'info_detail_screen.dart';

class LegalHubScreen extends StatelessWidget {
  const LegalHubScreen({super.key});

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
          'about_app'.tr(context),
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
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          _buildHubItem(
            context,
            Icons.info_outline,
            'about_app'.tr(context),
            'about',
          ),
          _buildDivider(),
          _buildHubItem(
            context,
            Icons.privacy_tip_outlined,
            'privacy_policy'.tr(context),
            'privacy',
          ),
          _buildDivider(),
          _buildHubItem(
            context,
            Icons.receipt_long_outlined,
            'refund_policy'.tr(context),
            'refund',
          ),
          _buildHubItem(
            context,
            Icons.gavel_outlined,
            'terms_conditions'.tr(context),
            'terms',
          ),
          _buildDivider(),
          _buildHubItem(
            context,
            Icons.delete_forever_outlined,
            'account_deletion'.tr(context),
            'deletion',
          ),
        ],
      ),
    );
  }

  Widget _buildHubItem(BuildContext context, IconData icon, String title, String type) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF2DA931).withOpacity( 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: const Color(0xFF2DA931), size: 22),
      ),
      title: Text(
        title,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF121712),
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => InfoDetailScreen(title: title, type: type),
          ),
        );
      },
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Divider(height: 1, color: Colors.grey.shade100),
    );
  }
}
