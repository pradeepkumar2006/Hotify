import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'services/audio_service.dart';

class WeeklyWrappedScreen extends StatefulWidget {
  final int totalPlays;
  final String topArtist;
  final Map<String, dynamic>? topSong;

  const WeeklyWrappedScreen({
    super.key,
    required this.totalPlays,
    required this.topArtist,
    this.topSong,
  });

  @override
  State<WeeklyWrappedScreen> createState() => _WeeklyWrappedScreenState();
}

class _WeeklyWrappedScreenState extends State<WeeklyWrappedScreen> with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _totalPages = 3;
  Timer? _timer;
  
  late AnimationController _progressController;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..addListener(() {
        setState(() {});
      });

    _startStory();
  }

  void _startStory() {
    _progressController.forward(from: 0).whenComplete(() {
      _nextPage();
    });
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _progressController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          onTapUp: (details) {
            final screenWidth = MediaQuery.of(context).size.width;
            if (details.globalPosition.dx < screenWidth / 3) {
              _previousPage();
            } else {
              _nextPage();
            }
          },
          onLongPressDown: (_) => _progressController.stop(),
          onLongPressUp: () => _progressController.forward(),
          child: Stack(
            children: [
              PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                  _progressController.forward(from: 0).whenComplete(() {
                    _nextPage();
                  });
                  
                  if (index == 2 && widget.topSong != null) {
                    AudioService().playSong(widget.topSong!);
                  }
                },
                children: [
                  _buildSlide1(),
                  _buildSlide2(),
                  _buildSlide3(),
                ],
              ),
              Positioned(
                top: 10,
                left: 10,
                right: 10,
                child: Row(
                  children: List.generate(_totalPages, (index) {
                    return Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: _currentPage > index
                                ? 1.0
                                : _currentPage == index
                                    ? _progressController.value
                                    : 0.0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              Positioned(
                top: 24,
                right: 16,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlide1() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4A00E0), Color(0xFF8E2DE2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "This Week...",
                style: GoogleFonts.outfit(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "You played",
                style: GoogleFonts.inter(
                  fontSize: 24,
                  color: Colors.white70,
                ),
              ),
              Text(
                "${widget.totalPlays}",
                style: GoogleFonts.outfit(
                  fontSize: 80,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              Text(
                "songs in total.",
                style: GoogleFonts.inter(
                  fontSize: 24,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 40),
              const Icon(Icons.music_note_rounded, size: 80, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlide2() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Your Top Artist",
                style: GoogleFonts.outfit(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 40),
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white24,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(Icons.person, size: 100, color: Colors.white),
              ),
              const SizedBox(height: 30),
              Text(
                widget.topArtist,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlide3() {
    final song = widget.topSong;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF11998E), Color(0xFF38EF7D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Your #1 Track",
                style: GoogleFonts.outfit(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 40),
              if (song != null) ...[
                Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black38,
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: CachedNetworkImage(
                      imageUrl: song['img'] ?? '',
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => Container(
                        color: Colors.black26,
                        child: const Icon(Icons.music_note, color: Colors.white, size: 50),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Text(
                  song['title'] ?? 'Unknown',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  song['artist'] ?? '',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 40),
                const Text(
                  "Playing now...",
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ] else ...[
                const Icon(Icons.music_off, size: 100, color: Colors.white54),
                const SizedBox(height: 20),
                Text(
                  "No songs played yet",
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    color: Colors.white70,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
