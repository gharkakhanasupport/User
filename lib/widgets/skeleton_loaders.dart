import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Wraps any child with a shimmering gradient animation using the shimmer package.
class ShimmerEffect extends StatelessWidget {
  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;

  const ShimmerEffect({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: baseColor ?? const Color(0xFFE2E8F0),
      highlightColor: highlightColor ?? const Color(0xFFF8FAFC),
      child: child,
    );
  }
}

/// Skeleton placeholder box with rounded corners
class SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  final Color color;

  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Checkout page skeleton
class CheckoutSkeleton extends StatelessWidget {
  const CheckoutSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(children: [
          const SkeletonBox(width: double.infinity, height: 100),
          const SizedBox(height: 16),
          const SkeletonBox(width: double.infinity, height: 50),
          const SizedBox(height: 16),
          ...List.generate(3, (_) => const Padding(
            padding: EdgeInsets.only(bottom: 8.0),
            child: SkeletonBox(width: double.infinity, height: 40),
          )),
        ]),
      ),
    );
  }
}

/// Skeleton for a kitchen card on the home screen
class KitchenCardSkeleton extends StatelessWidget {
  const KitchenCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 20, offset: Offset(0, 4))],
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SkeletonBox(width: 112, height: 112, borderRadius: 16),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SkeletonBox(width: 140, height: 18),
            const SizedBox(height: 8),
            const SkeletonBox(width: 100, height: 14),
            const SizedBox(height: 12),
            const Row(children: [
              SkeletonBox(width: 60, height: 24, borderRadius: 12),
              SizedBox(width: 8),
              SkeletonBox(width: 50, height: 24, borderRadius: 12),
            ]),
            const SizedBox(height: 14),
            Container(height: 1, color: Colors.white),
            const SizedBox(height: 10),
            const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              SkeletonBox(width: 80, height: 14),
              SkeletonBox(width: 60, height: 14),
            ]),
          ])),
        ]),
      ),
    );
  }
}

/// Skeleton for a banner on the home screen
class BannerSkeleton extends StatelessWidget {
  const BannerSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const ShimmerEffect(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: SkeletonBox(
          width: double.infinity,
          height: 180,
          borderRadius: 24,
        ),
      ),
    );
  }
}

/// Skeleton for a menu item in the kitchen detail screen
class MenuItemSkeleton extends StatelessWidget {
  const MenuItemSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9)))),
        child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SkeletonBox(width: 16, height: 16, borderRadius: 4),
            SizedBox(height: 10),
            SkeletonBox(width: 150, height: 18),
            SizedBox(height: 8),
            SkeletonBox(width: 60, height: 16),
            SizedBox(height: 12),
            SkeletonBox(width: 200, height: 12),
            SizedBox(height: 4),
            SkeletonBox(width: 160, height: 12),
          ])),
          SizedBox(width: 16),
          SkeletonBox(width: 120, height: 120, borderRadius: 16),
        ]),
      ),
    );
  }
}

/// Full kitchen detail skeleton (header info + tabs + menu items)
class KitchenDetailSkeleton extends StatelessWidget {
  const KitchenDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Column(children: [
        // Category tabs skeleton
        ShimmerEffect(child: Container(
          height: 45, margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: List.generate(4, (i) => const Padding(
            padding: EdgeInsets.only(right: 12),
            child: SkeletonBox(width: 80, height: 40, borderRadius: 20),
          ))),
        )),
        // Menu items skeleton
        ...List.generate(4, (_) => const MenuItemSkeleton()),
      ]),
    );
  }
}

/// Wallet transaction skeleton
class TransactionSkeleton extends StatelessWidget {
  const TransactionSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          const SkeletonBox(width: 48, height: 48, borderRadius: 12),
          const SizedBox(width: 16),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SkeletonBox(width: 120, height: 16),
            SizedBox(height: 8),
            SkeletonBox(width: 80, height: 12),
          ])),
          const SkeletonBox(width: 60, height: 16),
        ]),
      ),
    );
  }
}

/// Order card skeleton
class OrderSkeleton extends StatelessWidget {
  const OrderSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Column(children: [
          Row(children: [
            SkeletonBox(width: 60, height: 60, borderRadius: 12),
            SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SkeletonBox(width: 140, height: 18),
              SizedBox(height: 8),
              SkeletonBox(width: 100, height: 14),
            ])),
          ]),
          SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            SkeletonBox(width: 100, height: 32, borderRadius: 16),
            SkeletonBox(width: 80, height: 32, borderRadius: 16),
          ]),
        ]),
      ),
    );
  }
}

/// Category page skeleton (horizontal specials + vertical items)
class CategorySkeleton extends StatelessWidget {
  const CategorySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildListDelegate([
        const SizedBox(height: 20),
        // Specials header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: const ShimmerEffect(child: SkeletonBox(width: 150, height: 24)),
        ),
        const SizedBox(height: 12),
        // Specials horizontal list
        SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 3,
            itemBuilder: (context, index) => const Padding(
              padding: EdgeInsets.only(right: 12),
              child: ShimmerEffect(child: SkeletonBox(width: 260, height: 220, borderRadius: 20)),
            ),
          ),
        ),
        const SizedBox(height: 30),
        // All items header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: const ShimmerEffect(child: SkeletonBox(width: 120, height: 24)),
        ),
        const SizedBox(height: 12),
        // Vertical items
        ...List.generate(5, (_) => const MenuItemSkeleton()),
      ]),
    );
  }
}

/// Ticket list skeleton for support
class TicketListSkeleton extends StatelessWidget {
  const TicketListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => ShimmerEffect(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(children: [
              SkeletonBox(width: 48, height: 48, borderRadius: 12),
              SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SkeletonBox(width: 140, height: 16),
                SizedBox(height: 8),
                SkeletonBox(width: 100, height: 12),
              ])),
              SkeletonBox(width: 40, height: 16),
            ]),
          ),
        ),
        childCount: 6,
      ),
    );
  }
}

/// Chat skeleton for support and AI chat
class ChatSkeleton extends StatelessWidget {
  const ChatSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 6,
      itemBuilder: (context, index) {
        final isLeft = index % 2 == 0;
        return ShimmerEffect(
          child: Align(
            alignment: isLeft ? Alignment.centerLeft : Alignment.centerRight,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: isLeft ? Radius.zero : const Radius.circular(16),
                  bottomRight: isLeft ? const Radius.circular(16) : Radius.zero,
                ),
              ),
              child: SkeletonBox(
                width: 140 + (index * 30.0) % 120,
                height: 40 + (index % 3 == 0 ? 20.0 : 0),
                borderRadius: 12,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Address card skeleton
class AddressCardSkeleton extends StatelessWidget {
  const AddressCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: const Row(children: [
          SkeletonBox(width: 40, height: 40, borderRadius: 20),
          SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SkeletonBox(width: 100, height: 16),
            SizedBox(height: 8),
            SkeletonBox(width: double.infinity, height: 12),
          ])),
        ]),
      ),
    );
  }
}

/// Typing indicator skeleton
class TypingSkeleton extends StatelessWidget {
  const TypingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const ShimmerEffect(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SkeletonBox(width: 8, height: 8, borderRadius: 4),
          SizedBox(width: 4),
          SkeletonBox(width: 8, height: 8, borderRadius: 4),
          SizedBox(width: 4),
          SkeletonBox(width: 8, height: 8, borderRadius: 4),
        ],
      ),
    );
  }
}
