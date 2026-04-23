import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Live delivery radar card.
/// Shows a pulsing animated radar with the delivery agent's current position
/// relative to pickup (kitchen) and delivery (customer) points.
/// Gracefully handles missing coordinates by showing a stylized waiting animation.
class DeliveryRadarCard extends StatefulWidget {
  final double? pickupLat;
  final double? pickupLng;
  final double? deliveryLat;
  final double? deliveryLng;
  final double? agentLat;
  final double? agentLng;
  final String? partnerName;
  final String? otp;
  final bool isOnTheWay;

  const DeliveryRadarCard({
    super.key,
    this.pickupLat,
    this.pickupLng,
    this.deliveryLat,
    this.deliveryLng,
    this.agentLat,
    this.agentLng,
    this.partnerName,
    this.otp,
    this.isOnTheWay = false,
  });

  @override
  State<DeliveryRadarCard> createState() => _DeliveryRadarCardState();
}

class _DeliveryRadarCardState extends State<DeliveryRadarCard>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _sweepController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _sweepController.dispose();
    super.dispose();
  }

  /// Calculate distance between two lat/lng points in km (Haversine).
  double? _distanceKm() {
    if (widget.agentLat == null ||
        widget.agentLng == null ||
        widget.deliveryLat == null ||
        widget.deliveryLng == null) {
      return null;
    }
    const earthR = 6371.0;
    final dLat = _deg2rad(widget.deliveryLat! - widget.agentLat!);
    final dLng = _deg2rad(widget.deliveryLng! - widget.agentLng!);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(widget.agentLat!)) *
            math.cos(_deg2rad(widget.deliveryLat!)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthR * c;
  }

  double _deg2rad(double deg) => deg * math.pi / 180;

  String _etaText() {
    final d = _distanceKm();
    if (d == null) {
      return widget.isOnTheWay ? 'On the way' : 'Awaiting pickup';
    }
    // Assume avg speed 20 km/h for bike
    final minutes = ((d / 20.0) * 60).ceil().clamp(1, 120);
    return '~$minutes min';
  }

  String _distanceText() {
    final d = _distanceKm();
    if (d == null) return '—';
    if (d < 1) return '${(d * 1000).toStringAsFixed(0)} m';
    return '${d.toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    final hasAgent = widget.agentLat != null && widget.agentLng != null;
    final baseColor = widget.isOnTheWay
        ? const Color(0xFFE8722A)
        : const Color(0xFF16A34A);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            baseColor.withOpacity(0.08),
            baseColor.withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: baseColor.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: baseColor.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: baseColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  widget.isOnTheWay
                      ? Icons.delivery_dining_rounded
                      : Icons.radar_rounded,
                  color: baseColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isOnTheWay ? 'Live Delivery Tracking' : 'Finding a Partner',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: baseColor,
                      ),
                    ),
                    Text(
                      widget.isOnTheWay
                          ? 'Your partner is heading your way'
                          : 'A delivery partner will accept soon',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              // Live pulse indicator
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, _) {
                  final scale = 0.8 + 0.4 * _pulseController.value;
                  return Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: baseColor.withOpacity(0.3 + 0.7 * (1 - _pulseController.value)),
                    ),
                    transform: Matrix4.diagonal3Values(scale, scale, 1.0),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Radar visualization
          SizedBox(
            height: 220,
            child: AnimatedBuilder(
              animation: Listenable.merge([_pulseController, _sweepController]),
              builder: (context, _) {
                return CustomPaint(
                  size: const Size.fromHeight(220),
                  painter: _RadarPainter(
                    pulseValue: _pulseController.value,
                    sweepValue: _sweepController.value,
                    baseColor: baseColor,
                    hasAgent: hasAgent,
                    agentRelativeX: _agentRelativeX(),
                    agentRelativeY: _agentRelativeY(),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // ETA + Distance row
          Row(
            children: [
              Expanded(
                child: _infoTile(
                  icon: Icons.access_time_rounded,
                  label: 'ETA',
                  value: _etaText(),
                  color: baseColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _infoTile(
                  icon: Icons.straighten_rounded,
                  label: 'Distance',
                  value: _distanceText(),
                  color: baseColor,
                ),
              ),
            ],
          ),

          if (widget.partnerName != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: baseColor.withOpacity(0.15),
                    child: Icon(Icons.person, color: baseColor, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.partnerName!,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Your delivery partner',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.call, color: Color(0xFF16A34A), size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (widget.otp != null && widget.isOnTheWay) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: baseColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: baseColor.withOpacity(0.3), style: BorderStyle.solid),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock_outline_rounded, color: baseColor, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delivery OTP',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          widget.otp!,
                          style: GoogleFonts.robotoMono(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 6,
                            color: baseColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'Share with\npartner',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Position agent on radar (0..1 from pickup to delivery)
  double _agentRelativeX() {
    if (widget.agentLat == null ||
        widget.pickupLat == null ||
        widget.deliveryLat == null) {
      return 0.5;
    }
    final total = (widget.deliveryLng ?? 0) - (widget.pickupLng ?? 0);
    if (total == 0) return 0.5;
    final prog = ((widget.agentLng! - widget.pickupLng!) / total).clamp(0.0, 1.0);
    return prog;
  }

  double _agentRelativeY() {
    if (widget.agentLat == null ||
        widget.pickupLat == null ||
        widget.deliveryLat == null) {
      return 0.5;
    }
    final total = (widget.deliveryLat ?? 0) - (widget.pickupLat ?? 0);
    if (total == 0) return 0.5;
    final prog = ((widget.agentLat! - widget.pickupLat!) / total).clamp(0.0, 1.0);
    return prog;
  }
}

class _RadarPainter extends CustomPainter {
  final double pulseValue;
  final double sweepValue;
  final Color baseColor;
  final bool hasAgent;
  final double agentRelativeX;
  final double agentRelativeY;

  _RadarPainter({
    required this.pulseValue,
    required this.sweepValue,
    required this.baseColor,
    required this.hasAgent,
    required this.agentRelativeX,
    required this.agentRelativeY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2 - 10;

    // Background concentric circles (radar grid)
    final gridPaint = Paint()
      ..color = baseColor.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(center, maxRadius * i / 4, gridPaint);
    }

    // Cross lines
    canvas.drawLine(
      Offset(center.dx - maxRadius, center.dy),
      Offset(center.dx + maxRadius, center.dy),
      gridPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - maxRadius),
      Offset(center.dx, center.dy + maxRadius),
      gridPaint,
    );

    // Expanding pulse ring
    final pulseRadius = maxRadius * pulseValue;
    final pulsePaint = Paint()
      ..color = baseColor.withOpacity((1 - pulseValue) * 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, pulseRadius, pulsePaint);

    // Sweeping radar line
    final sweepAngle = sweepValue * 2 * math.pi;
    final sweepEnd = Offset(
      center.dx + maxRadius * math.cos(sweepAngle),
      center.dy + maxRadius * math.sin(sweepAngle),
    );
    final gradient = SweepGradient(
      startAngle: sweepAngle - math.pi / 3,
      endAngle: sweepAngle,
      colors: [
        baseColor.withOpacity(0),
        baseColor.withOpacity(0.4),
      ],
      transform: GradientRotation(sweepAngle - math.pi / 3),
    );
    final sweepRect = Rect.fromCircle(center: center, radius: maxRadius);
    final sweepPaint = Paint()
      ..shader = gradient.createShader(sweepRect)
      ..style = PaintingStyle.fill;
    canvas.drawArc(sweepRect, sweepAngle - math.pi / 3, math.pi / 3, true, sweepPaint);

    // Sweep line
    final linePaint = Paint()
      ..color = baseColor
      ..strokeWidth = 1.5;
    canvas.drawLine(center, sweepEnd, linePaint);

    // Pickup point (top-left-ish)
    final pickupPoint = Offset(
      center.dx - maxRadius * 0.6,
      center.dy - maxRadius * 0.5,
    );
    _drawLocationPin(canvas, pickupPoint, const Color(0xFF6C3FA0), Icons.restaurant);

    // Delivery point (bottom-right-ish)
    final deliveryPoint = Offset(
      center.dx + maxRadius * 0.6,
      center.dy + maxRadius * 0.5,
    );
    _drawLocationPin(canvas, deliveryPoint, const Color(0xFFE8722A), Icons.home);

    // Dashed path between pickup and delivery
    _drawDashedLine(canvas, pickupPoint, deliveryPoint, baseColor.withOpacity(0.4));

    // Agent marker (moving)
    final t = hasAgent ? ((agentRelativeX + agentRelativeY) / 2).clamp(0.0, 1.0) : 0.5;
    final agentPos = Offset.lerp(pickupPoint, deliveryPoint, t)!;

    // Pulsing glow around agent
    for (int i = 3; i > 0; i--) {
      final glowPaint = Paint()
        ..color = baseColor.withOpacity(0.15 * (1 - pulseValue) * i / 3)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(agentPos, 8 + (15 * pulseValue * i / 3), glowPaint);
    }

    // Agent dot
    canvas.drawCircle(
      agentPos,
      8,
      Paint()..color = baseColor,
    );
    canvas.drawCircle(
      agentPos,
      5,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      agentPos,
      3,
      Paint()..color = baseColor,
    );
  }

  void _drawLocationPin(Canvas canvas, Offset pos, Color color, IconData icon) {
    // Pin shadow
    canvas.drawCircle(
      Offset(pos.dx, pos.dy + 2),
      12,
      Paint()..color = Colors.black.withOpacity(0.2),
    );
    // Pin
    canvas.drawCircle(pos, 12, Paint()..color = color);
    canvas.drawCircle(pos, 12, Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
    // Icon
    final textPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      pos - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    const dashWidth = 6.0;
    const dashSpace = 4.0;
    final totalDist = (end - start).distance;
    final dashCount = (totalDist / (dashWidth + dashSpace)).floor();
    for (int i = 0; i < dashCount; i++) {
      final t1 = (i * (dashWidth + dashSpace)) / totalDist;
      final t2 = ((i * (dashWidth + dashSpace)) + dashWidth) / totalDist;
      canvas.drawLine(
        Offset.lerp(start, end, t1)!,
        Offset.lerp(start, end, t2)!,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_RadarPainter oldDelegate) => true;
}
