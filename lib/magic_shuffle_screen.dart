import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'services/audio_service.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class MagicShuffleScreen extends StatefulWidget {
  final List<Map<String, dynamic>> initialSongs;

  const MagicShuffleScreen({super.key, required this.initialSongs});

  @override
  State<MagicShuffleScreen> createState() => _MagicShuffleScreenState();
}

class _MagicShuffleScreenState extends State<MagicShuffleScreen> with SingleTickerProviderStateMixin {
  late List<Map<String, dynamic>> _queue;
  final CardSwiperController _swiperController = CardSwiperController();
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _queue = List.from(widget.initialSongs);
    _queue.shuffle(); // Shuffle for extra magic!

    // Play the first song automatically
    if (_queue.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
         _playCurrentCard(0);
      });
    }
  }

  void _playCurrentCard(int index) {
    if (index < _queue.length) {
      AudioService().playSong(_queue[index], playlistContext: _queue);
    }
  }

  @override
  void dispose() {
    _swiperController.dispose();
    super.dispose();
  }

  ImageProvider _getImageProvider(Map<String, dynamic> song) {
    // Check if English song for crossover card image
    if ((song['language'] ?? '').toString().toLowerCase() == 'english') {
      final yearVal = int.tryParse(song['year']?.toString() ?? '');
      if (yearVal != null) {
        if (yearVal <= 2010) return const AssetImage('assets/crossover_1.png');
        if (yearVal <= 2015) return const AssetImage('assets/crossover_2.png');
        if (yearVal <= 2020) return const AssetImage('assets/crossover_3.png');
        return const AssetImage('assets/crossover_4.png');
      }
    }

    final path = song['img'] ?? '';
    if (path.isEmpty || path.contains('5e049992ef02750dad84fe7d44c061bc')) {
      return const AssetImage('assets/various_composers.png');
    }
    if (path.startsWith('http')) {
      return CachedNetworkImageProvider(path);
    }
    return AssetImage(path);
  }

  bool _onSwipe(
    int previousIndex,
    int? currentIndex,
    CardSwiperDirection direction,
  ) {
    final song = _queue[previousIndex];
    if (direction == CardSwiperDirection.right) {
      // Swiped right (Like)
      if (!AudioService().isSongLiked(song)) {
        AudioService().toggleLikeSong(song);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added ${song['title']} to Liked Songs ♥️'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.primary,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } else {
      // Swiped left (Skip) - no action needed for lists
    }

    if (currentIndex != null) {
      setState(() {
        _currentIndex = currentIndex;
      });
      _playCurrentCard(currentIndex);
    } else {
      // Out of cards
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No more magic songs!')),
      );
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(FeatherIcons.chevronDown, color: Colors.white, size: 30.sp),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Magic Shuffle',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            fontSize: 20.sp,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Dynamic Blurred Background
          if (_queue.isNotEmpty && _currentIndex < _queue.length)
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 800),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 1.05, end: 1.0).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: ImageFiltered(
                  key: ValueKey(_queue[_currentIndex]['img'] ?? _currentIndex),
                  imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                  child: SizedBox.expand(
                    child: Image(
                      image: _getImageProvider(_queue[_currentIndex]),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.65), // Dim the blurred image
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                SizedBox(height: 10.h),
                Expanded(
                  child: _queue.isEmpty
                      ? const Center(child: CircularProgressIndicator(color: Colors.white))
                      : CardSwiper(
                          controller: _swiperController,
                          cardsCount: _queue.length,
                          onSwipe: _onSwipe,
                          numberOfCardsDisplayed: 3,
                          backCardOffset: Offset(0, 40.h),
                          duration: const Duration(milliseconds: 400),
                          maxAngle: 30,
                          padding: EdgeInsets.symmetric(horizontal: 36.w, vertical: 24.h), // increased padding reduces card size
                        cardBuilder: (context, index, horizontalThresholdPercentage, verticalThresholdPercentage) {
                          final song = _queue[index];
                          return Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24.r),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  blurRadius: 20.r,
                                  offset: Offset(0, 10.h),
                                ),
                              ],
                              image: DecorationImage(
                                image: _getImageProvider(song),
                                fit: BoxFit.cover,
                              ),
                            ),
                            child: Stack(
                              children: [
                                // Glassmorphic bottom info section
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 30.h),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(24.r)),
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          Colors.black.withValues(alpha: 0.9),
                                        ],
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          song['title'] ?? 'Unknown',
                                          style: GoogleFonts.outfit(
                                            fontSize: 28.sp,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        SizedBox(height: 8.h),
                                        Text(
                                          song['composer'] ?? song['artist'] ?? 'Unknown Artist',
                                          style: GoogleFonts.inter(
                                            fontSize: 16.sp,
                                            color: Colors.white70,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        SizedBox(height: 12.h),
                                        Row(
                                          children: List.generate(
                                            15,
                                            (i) => Container(
                                              margin: EdgeInsets.only(right: 4.w),
                                              width: 3.w,
                                              height: (10 + (i * 3 % 15)).h,
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(alpha: 0.5),
                                                borderRadius: BorderRadius.circular(2.r),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // Swiping indicators (LIKE / SKIP)
                                if (horizontalThresholdPercentage > 0)
                                  Positioned(
                                    top: 40.h,
                                    left: 40.w,
                                    child: Transform.rotate(
                                      angle: -0.2,
                                      child: Container(
                                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: Colors.greenAccent, width: 4.w),
                                          borderRadius: BorderRadius.circular(12.r),
                                        ),
                                        child: Text(
                                          'LIKE',
                                          style: GoogleFonts.outfit(
                                            color: Colors.greenAccent,
                                            fontSize: 32.sp,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                else if (horizontalThresholdPercentage < 0)
                                  Positioned(
                                    top: 40.h,
                                    right: 40.w,
                                    child: Transform.rotate(
                                      angle: 0.2,
                                      child: Container(
                                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: Colors.redAccent, width: 4.w),
                                          borderRadius: BorderRadius.circular(12.r),
                                        ),
                                        child: Text(
                                          'SKIP',
                                          style: GoogleFonts.outfit(
                                            color: Colors.redAccent,
                                            fontSize: 32.sp,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              // Action Buttons
              Padding(
                padding: EdgeInsets.symmetric(vertical: 30.h, horizontal: 40.w),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildFloatingButton(
                      icon: FeatherIcons.x,
                      color: Colors.redAccent,
                      onTap: () {
                        _swiperController.swipe(CardSwiperDirection.left);
                      },
                    ),
                    _buildFloatingButton(
                      icon: FeatherIcons.heart,
                      color: Colors.greenAccent,
                      size: 64.r, // middle button is larger
                      onTap: () {
                        _swiperController.swipe(CardSwiperDirection.right);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingButton({required IconData icon, required Color color, required VoidCallback onTap, double? size}) {
    final double actualSize = size ?? 56.r;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: actualSize,
        height: actualSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.1),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 2.w),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.2),
              blurRadius: 16.r,
              offset: Offset(0, 4.h),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: actualSize * 0.45),
      ),
    );
  }
}
