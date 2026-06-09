import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MusicalGalaxyView extends StatefulWidget {
  final Function(String name, String image) onArtistTap;

  const MusicalGalaxyView({super.key, required this.onArtistTap});

  @override
  State<MusicalGalaxyView> createState() => _MusicalGalaxyViewState();
}

class _MusicalGalaxyViewState extends State<MusicalGalaxyView> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _userRotation = 0.0;

  final List<Map<String, dynamic>> _planets = [
    {
      'name': 'Anirudh',
      'image': 'assets/anirudh.jpg',
      'color': const Color(0xFFFF4E50), // Red
      'size': 65.0,
    },
    {
      'name': 'A.R. Rahman',
      'image': 'assets/ar_rahman.png',
      'color': const Color(0xFF4A90E2), // Blue
      'size': 75.0, // slightly bigger
    },
    {
      'name': 'Yuvan',
      'image': 'assets/yuvan.jpg',
      'color': const Color(0xFFF5A623), // Orange
      'size': 60.0,
    },
    {
      'name': 'G.V. Prakash',
      'image': 'assets/gv_prakash.jpg',
      'color': const Color(0xFFBD10E0), // Purple
      'size': 55.0,
    },
    {
      'name': 'Harris Jayaraj',
      'image': 'assets/harris_jayaraj.png',
      'color': const Color(0xFF50E3C2), // Teal
      'size': 60.0,
    },
    {
      'name': 'Ilaiyaraaja',
      'image': 'assets/ilaiyaraaja.png',
      'color': const Color(0xFFE899A8), // Pink
      'size': 70.0,
    },
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  ImageProvider _getImageProvider(String path) {
    if (path.startsWith('http')) {
      return NetworkImage(path);
    }
    return AssetImage(path);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'Musical Galaxy',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'Spin the galaxy to explore your favorite artists',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
            ),
          ),
        ),
        const SizedBox(height: 24),
        GestureDetector(
          onPanUpdate: (details) {
            setState(() {
              // Adjust rotation based on horizontal drag
              _userRotation -= details.delta.dx * 0.01;
            });
          },
          child: Container(
            height: 260,
            width: double.infinity,
            color: Colors.transparent, // to catch gestures
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final double currentRotation = (_controller.value * 2 * math.pi) + _userRotation;
                
                // Calculate positions
                final double centerX = MediaQuery.of(context).size.width / 2;
                final double centerY = 130;
                final double radiusX = 140; // horizontal spread
                final double radiusY = 40;  // vertical depth (perspective)

                List<Widget> planetWidgets = [];

                for (int i = 0; i < _planets.length; i++) {
                  final planet = _planets[i];
                  final double angle = currentRotation + (i * (2 * math.pi / _planets.length));
                  
                  final double x = centerX + math.cos(angle) * radiusX;
                  final double y = centerY + math.sin(angle) * radiusY;
                  
                  // scale based on depth (y position relative to center)
                  // sin(angle) goes from -1 (back) to 1 (front)
                  final double depth = math.sin(angle); 
                  final double scale = 0.6 + (0.4 * ((depth + 1) / 2)); // 0.6 to 1.0

                  planetWidgets.add(
                    Positioned(
                      left: x - (planet['size'] / 2),
                      top: y - (planet['size'] / 2),
                      child: Transform.scale(
                        scale: scale,
                        child: GestureDetector(
                          onTap: () {
                            widget.onArtistTap(planet['name'], planet['image']);
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: planet['size'],
                                height: planet['size'],
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: (planet['color'] as Color).withValues(alpha: 0.6),
                                      blurRadius: 20 * scale,
                                      spreadRadius: 2 * scale,
                                    ),
                                    BoxShadow(
                                      color: (planet['color'] as Color).withValues(alpha: 0.3),
                                      blurRadius: 40 * scale,
                                      spreadRadius: 10 * scale,
                                    ),
                                  ],
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    width: 2,
                                  ),
                                ),
                                child: ClipOval(
                                  child: Image(
                                    image: _getImageProvider(planet['image']),
                                    fit: BoxFit.cover,
                                    width: planet['size'],
                                    height: planet['size'],
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      width: planet['size'],
                                      height: planet['size'],
                                      color: Colors.grey.shade900,
                                      child: const Icon(Icons.person, color: Colors.white54),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Only show label if it's somewhat in the front
                              if (depth > -0.2)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    planet['name'],
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }

                // Sort widgets by depth (Y value) so front planets draw on top
                planetWidgets.sort((a, b) {
                  final posA = a as Positioned;
                  final posB = b as Positioned;
                  return posA.top!.compareTo(posB.top!);
                });

                return Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    // Back planets
                    ...planetWidgets.where((w) => (w as Positioned).top! < centerY - 25), 
                    
                    // Core / Sun
                    Positioned(
                      left: centerX - 25,
                      top: centerY - 25,
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).colorScheme.primary,
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
                              blurRadius: 30,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.music_note_rounded,
                          color: Theme.of(context).colorScheme.surface,
                          size: 24,
                        ),
                      ),
                    ),

                    // Front planets
                    ...planetWidgets.where((w) => (w as Positioned).top! >= centerY - 25), 
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
