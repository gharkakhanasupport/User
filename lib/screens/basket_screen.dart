import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/localization.dart';
import 'my_orders_screen.dart';
import 'manage_subscriptions_screen.dart';
import '../widgets/global_cart_tab.dart';

class BasketScreen extends StatefulWidget {
  final int initialTabIndex;
  const BasketScreen({super.key, this.initialTabIndex = 0});

  @override
  State<BasketScreen> createState() => _BasketScreenState();
}

class _BasketScreenState extends State<BasketScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: widget.initialTabIndex);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'basket'.tr(context),
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1E293B),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF16A34A),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF16A34A),
          indicatorWeight: 3,
          labelStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
          unselectedLabelStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          tabs: [
            Tab(text: 'my_cart'.tr(context)),
            Tab(text: 'orders'.tr(context)),
            const Tab(text: 'Subscriptions'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const GlobalCartTab(),
          const MyOrdersScreen(hideAppBar: true),
          const ManageSubscriptionsScreen(hideAppBar: true),
        ],
      ),
    );
  }
}
