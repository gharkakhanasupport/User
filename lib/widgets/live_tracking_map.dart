import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';

/// Swiggy/Zomato-style live tracking map using OpenStreetMap tiles.
/// Shows kitchen (pickup), customer (delivery), and an animated agent marker.
/// The agent marker smoothly animates between position updates.
class LiveTrackingMap extends StatefulWidget {
  final double pickupLat;
  final double pickupLng;
  final double deliveryLat;
  final double deliveryLng;
  final double? agentLat;
  final double? agentLng;
  final String kitchenName;

  const LiveTrackingMap({
    super.key,
    required this.pickupLat,
    required this.pickupLng,
    required this.deliveryLat,
    required this.deliveryLng,
    this.agentLat,
    this.agentLng,
    required this.kitchenName,
  });

  @override
  State<LiveTrackingMap> createState() => _LiveTrackingMapState();
}

class _LiveTrackingMapState extends State<LiveTrackingMap>
    with TickerProviderStateMixin {
  late final MapController _mapController;
  late AnimationController _agentMoveController;
  late AnimationController _pulseController;
  late Animation<LatLng> _agentPositionAnim;

  LatLng? _lastAgentPosition;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    _agentMoveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    final currentPos = widget.agentLat != null && widget.agentLng != null
        ? LatLng(widget.agentLat!, widget.agentLng!)
        : null;

    _lastAgentPosition = currentPos;
    final startPoint = currentPos ?? LatLng(widget.pickupLat, widget.pickupLng);
    _agentPositionAnim = _LatLngTween(
      begin: startPoint,
      end: startPoint,
    ).animate(
        CurvedAnimation(parent: _agentMoveController, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(covariant LiveTrackingMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.agentLat != null && widget.agentLng != null) {
      final newPos = LatLng(widget.agentLat!, widget.agentLng!);
      if (_lastAgentPosition == null ||
          newPos.latitude != _lastAgentPosition!.latitude ||
          newPos.longitude != _lastAgentPosition!.longitude) {
        _agentPositionAnim = _LatLngTween(
          begin: _lastAgentPosition ?? newPos,
          end: newPos,
        ).animate(CurvedAnimation(
            parent: _agentMoveController, curve: Curves.easeInOut));
        _lastAgentPosition = newPos;
        _agentMoveController.forward(from: 0);

        // Smoothly center map on agent
        _mapController.move(newPos, _mapController.camera.zoom);
      }
    }
  }

  @override
  void dispose() {
    _agentMoveController.dispose();
    _pulseController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pickup = LatLng(widget.pickupLat, widget.pickupLng);
    final delivery = LatLng(widget.deliveryLat, widget.deliveryLng);

    // Fit bounds to show all markers
    final allPoints = <LatLng>[pickup, delivery];
    if (_lastAgentPosition != null) allPoints.add(_lastAgentPosition!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Map Title Row
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.map_rounded,
                    color: Color(0xFF16A34A), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Live Location',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Live badge
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, _) {
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red
                          .withValues(alpha: 0.8 + 0.2 * _pulseController.value),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'LIVE',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        // Map
        Container(
          height: 280,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4)),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _lastAgentPosition ?? pickup,
                  initialZoom: 14,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.gkk.user',
                  ),
                  // Dashed route line between pickup and delivery
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: [pickup, delivery],
                        color:
                            const Color(0xFF16A34A).withValues(alpha: 0.6),
                        strokeWidth: 3,
                        pattern: const StrokePattern.dotted(
                          spacingFactor: 3,
                        ),
                      ),
                    ],
                  ),
                  // Static markers (kitchen + customer)
                  MarkerLayer(
                    markers: [
                      // Kitchen marker
                      Marker(
                        point: pickup,
                        width: 44,
                        height: 44,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                  color:
                                      Colors.deepOrange.withValues(alpha: 0.3),
                                  blurRadius: 8),
                            ],
                          ),
                          child: const Icon(Icons.restaurant_rounded,
                              color: Colors.deepOrange, size: 24),
                        ),
                      ),
                      // Customer marker
                      Marker(
                        point: delivery,
                        width: 44,
                        height: 44,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                  color: const Color(0xFF7C3AED)
                                      .withValues(alpha: 0.3),
                                  blurRadius: 8),
                            ],
                          ),
                          child: const Icon(Icons.home_rounded,
                              color: Color(0xFF7C3AED), size: 24),
                        ),
                      ),
                    ],
                  ),
                  // Animated agent marker
                  if (_lastAgentPosition != null)
                    AnimatedBuilder(
                      animation: Listenable.merge(
                          [_agentMoveController, _pulseController]),
                      builder: (context, _) {
                        final pos = _agentPositionAnim.value;
                        final pulseScale =
                            1.0 + 0.3 * _pulseController.value;
                        return MarkerLayer(
                          markers: [
                            // Pulse ring
                            Marker(
                              point: pos,
                              width: 60,
                              height: 60,
                              child: Transform.scale(
                                scale: pulseScale,
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFF16A34A)
                                        .withValues(
                                            alpha: 0.15 *
                                                (1 -
                                                    _pulseController.value)),
                                  ),
                                ),
                              ),
                            ),
                            // Bike icon
                            Marker(
                              point: pos,
                              width: 40,
                              height: 40,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF16A34A),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white, width: 3),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF16A34A)
                                          .withValues(alpha: 0.4),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.two_wheeler_rounded,
                                    color: Colors.white, size: 18),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                ],
              ),
              // Re-center button
              Positioned(
                bottom: 12,
                right: 12,
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  elevation: 4,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      if (_lastAgentPosition != null) {
                        _mapController.move(
                            _lastAgentPosition!, 16);
                      }
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(Icons.my_location_rounded,
                          color: Color(0xFF16A34A), size: 22),
                    ),
                  ),
                ),
              ),
              // Legend overlay
              Positioned(
                bottom: 12,
                left: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 6),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.restaurant_rounded,
                          color: Colors.deepOrange, size: 14),
                      const SizedBox(width: 4),
                      Text('Kitchen',
                          style: GoogleFonts.plusJakartaSans(fontSize: 10)),
                      const SizedBox(width: 10),
                      const Icon(Icons.two_wheeler_rounded,
                          color: Color(0xFF16A34A), size: 14),
                      const SizedBox(width: 4),
                      Text('Agent',
                          style: GoogleFonts.plusJakartaSans(fontSize: 10)),
                      const SizedBox(width: 10),
                      const Icon(Icons.home_rounded,
                          color: Color(0xFF7C3AED), size: 14),
                      const SizedBox(width: 4),
                      Text('You',
                          style: GoogleFonts.plusJakartaSans(fontSize: 10)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Custom Tween that linearly interpolates between two LatLng points.
class _LatLngTween extends Tween<LatLng> {
  _LatLngTween({required super.begin, required super.end});

  @override
  LatLng lerp(double t) {
    final lat = begin!.latitude + (end!.latitude - begin!.latitude) * t;
    final lng = begin!.longitude + (end!.longitude - begin!.longitude) * t;
    return LatLng(lat, lng);
  }
}
