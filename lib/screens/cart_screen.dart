import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CartScreen extends StatelessWidget {
  final Map<String, int> cartItems;
  final Map<String, int> itemPrices;
  final Map<String, String> itemImages;
  final String kitchenName;

  const CartScreen({
    super.key,
    required this.cartItems,
    required this.itemPrices,
    required this.itemImages,
    required this.kitchenName,
  });

  @override
  Widget build(BuildContext context) {
    int itemTotal = 0;
    cartItems.forEach((key, quantity) {
      itemTotal += (itemPrices[key] ?? 0) * quantity;
    });

    const int deliveryFee = 30;
    const int taxes = 15; // Simplified tax logic
    final int grandTotal = itemTotal + deliveryFee + taxes;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              kitchenName,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E293B),
              ),
            ),
            Text(
              'Delivery in 35 mins',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFF1F5F9), height: 1),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Items List
                  ...cartItems.entries.where((e) => e.value > 0).map((entry) {
                    final name = entry.key;
                    final quantity = entry.value;
                    final price = itemPrices[name] ?? 0;
                    final imageUrl = itemImages[name] ?? '';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Row(
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            margin: const EdgeInsets.only(top: 4, right: 8),
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFF16A34A)),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(Icons.circle, size: 8, color: Color(0xFF16A34A)),
                          ),
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF1E293B),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '₹${price * quantity}',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF1E293B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      _buildQtyBtn(Icons.remove, () {}),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        child: Text(
                                          '$quantity',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF16A34A),
                                          ),
                                        ),
                                      ),
                                      _buildQtyBtn(Icons.add, () {}),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),

                  const Divider(height: 32, thickness: 8, color: Color(0xFFF8FAFC)),

                  // Coupon Section
                  Text(
                    'Offers & Benefits',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.local_offer, color: Color(0xFFC2941B), size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Apply Coupon Code',
                              hintStyle: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                color: const Color(0xFF94A3B8),
                              ),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {},
                          child: Text(
                            'APPLY',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF16A34A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 32, thickness: 8, color: Color(0xFFF8FAFC)),

                  // Bill Details
                  Text(
                    'Bill Details',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildBillRow('Item Total', '₹$itemTotal'),
                  _buildBillRow('Delivery Fee', '₹$deliveryFee'),
                  _buildBillRow('Taxes & Charges', '₹$taxes'),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(),
                  ),
                  _buildBillRow('To Pay', '₹$grandTotal', isBold: true),
                ],
              ),
            ),
          ),

          // Sticky Payment Footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: ElevatedButton(
                onPressed: () {
                   // Payment handling would go here
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size(double.infinity, 56),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '₹$grandTotal',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'TOTAL',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Text(
                        'Proceed to Pay',
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: isBold ? const Color(0xFF1E293B) : const Color(0xFF64748B),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: isBold ? const Color(0xFF1E293B) : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQtyBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Icon(icon, size: 16, color: const Color(0xFF16A34A)),
      ),
    );
  }
}
