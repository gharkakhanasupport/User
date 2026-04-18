import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DishDetailScreen extends StatefulWidget {
  final dynamic item;
  final int quantity;
  final Function(int delta) onUpdate;

  const DishDetailScreen({
    super.key,
    required this.item,
    required this.quantity,
    required this.onUpdate,
  });

  @override
  State<DishDetailScreen> createState() => _DishDetailScreenState();
}

class _DishDetailScreenState extends State<DishDetailScreen> {
  late int _localQuantity;

  @override
  void initState() {
    super.initState();
    _localQuantity = widget.quantity;
  }

  void _updateQty(int delta) {
    setState(() {
      _localQuantity += delta;
      if (_localQuantity < 0) _localQuantity = 0;
    });
    widget.onUpdate(delta);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final String imageUrl = item.imageUrl ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // 1. Large Image Header
              SliverAppBar(
                expandedHeight: 400,
                pinned: true,
                elevation: 0,
                backgroundColor: Colors.white,
                leading: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: CircleAvatar(
                    backgroundColor: Colors.white.withValues(alpha: 0.9),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Hero(
                    tag: 'dish_${item.id}',
                    child: imageUrl.isNotEmpty
                        ? Image.network(imageUrl, fit: BoxFit.cover)
                        : Container(
                            color: const Color(0xFFF1F5F9),
                            child: const Icon(Icons.fastfood, size: 80, color: Color(0xFFCBD5E1)),
                          ),
                  ),
                ),
              ),

              // 2. Dish Details
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              item.name,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          const Icon(Icons.share_outlined, color: Colors.grey),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.star, size: 14, color: Color(0xFF16A34A)),
                                const SizedBox(width: 4),
                                Text('4.8', style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF16A34A),
                                )),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text('1.2k+ ratings', style: GoogleFonts.plusJakartaSans(
                            fontSize: 12, color: Colors.grey.shade500,
                          )),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        '₹${item.price.toStringAsFixed(0)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF16A34A),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Divider(height: 1),
                      const SizedBox(height: 24),
                      Text(
                        'Description',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        item.description ?? 'This authentic home-made dish is prepared with fresh ingredients and traditional spices to give you the real taste of home.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          color: const Color(0xFF64748B),
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Add dietary info
                      Row(
                        children: [
                          const Icon(Icons. timer_outlined, size: 20, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text('Delivery in 35-40 mins', style: GoogleFonts.plusJakartaSans(color: Colors.grey.shade600)),
                        ],
                      ),
                      const SizedBox(height: 120), // Space for bottom bar
                    ],
                  ),
                ),
              ),
            ],
          ),

          // 3. Floating Bottom Bar
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    if (_localQuantity > 0) ...[
                      Container(
                        height: 56,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () => _updateQty(-1),
                              icon: const Icon(Icons.remove, color: Color(0xFF16A34A)),
                            ),
                            Text('$_localQuantity', style: GoogleFonts.plusJakartaSans(
                              fontSize: 18, fontWeight: FontWeight.bold,
                            )),
                            IconButton(
                              onPressed: () => _updateQty(1),
                              icon: const Icon(Icons.add, color: Color(0xFF16A34A)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          if (_localQuantity == 0) _updateQty(1);
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: Text(
                          _localQuantity > 0 ? 'VIEW CART' : 'ADD TO CART',
                          style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
