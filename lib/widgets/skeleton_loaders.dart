import 'package:flutter/material.dart';

/// A lightweight shimmer effect widget — no external packages needed.
/// Wraps any child with a shimmering gradient animation.
class ShimmerEffect extends StatefulWidget {
  final Widget child;
  final Color baseColor;
  final Color highlightColor;
  final Duration duration;

  const ShimmerEffect({
    super.key,
    required this.child,
    this.baseColor = const Color(0xFFE2E8F0),
    this.highlightColor = const Color(0xFFF8FAFC),
    this.duration = const Duration(milliseconds: 1500),
  });

  @override
  State<ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<ShimmerEffect> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [widget.baseColor, widget.highlightColor, widget.baseColor],
              stops: [
                (_controller.value - 0.3).clamp(0.0, 1.0),
                _controller.value,
                (_controller.value + 0.3).clamp(0.0, 1.0),
              ],
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Skeleton placeholder box with rounded corners
class SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(borderRadius),
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
            Row(children: [
              SkeletonBox(width: 60, height: 24, borderRadius: 12),
              const SizedBox(width: 8),
              SkeletonBox(width: 50, height: 24, borderRadius: 12),
            ]),
            const SizedBox(height: 14),
            Container(height: 1, color: const Color(0xFFE2E8F0)),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const SkeletonBox(width: 80, height: 14),
              const SkeletonBox(width: 60, height: 14),
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
    return ShimmerEffect(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        height: 160,
        decoration: BoxDecoration(
          color: const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(20),
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
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SkeletonBox(width: 16, height: 16, borderRadius: 4),
            const SizedBox(height: 10),
            const SkeletonBox(width: 150, height: 18),
            const SizedBox(height: 8),
            const SkeletonBox(width: 60, height: 16),
            const SizedBox(height: 12),
            const SkeletonBox(width: 200, height: 12),
            const SizedBox(height: 4),
            const SkeletonBox(width: 160, height: 12),
          ])),
          const SizedBox(width: 16),
          const SkeletonBox(width: 120, height: 120, borderRadius: 16),
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
          child: Row(children: List.generate(4, (i) => Padding(
            padding: const EdgeInsets.only(right: 12),
            child: SkeletonBox(width: 80, height: 40, borderRadius: 20),
          ))),
        )),
        // Menu items skeleton
        ...List.generate(4, (_) => const MenuItemSkeleton()),
      ]),
    );
  }
}

/// Home screen kitchen list skeleton
class HomeKitchenListSkeleton extends StatelessWidget {
  final int count;
  const HomeKitchenListSkeleton({super.key, this.count = 3});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(count, (_) => const KitchenCardSkeleton()),
    );
  }
}
