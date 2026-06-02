import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'services/audio_service.dart';
import 'services/download_service.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  bool _isShuffleEnabled = false;

  String _getArtistPicture(String artistName, String fallbackImageUrl) {
    final String cleanArtist = artistName.toLowerCase().replaceAll(' ', '').replaceAll('.', '');
    
    final Map<String, String> artistImages = {
      'arrahman': 'assets/ar_rahman.png',
      'anirudh': 'assets/anirudh.jpg',
      'yuvansankar': 'assets/yuvan.jpg',
      'yuvanshankar': 'assets/yuvan.jpg',
      'deva': 'https://i.pinimg.com/1200x/ed/ae/19/edae1927b2094577b713a011432c2856.jpg',
      'hiphopaadhi': 'assets/hiphop_tamizha.png',
      'hiphop': 'assets/hiphop_tamizha.png',
      'gvprakash': 'assets/gv_prakash.jpg',
      'saiabhyankkar': 'assets/sai_abhyankkar.png',
      'saiabhyankar': 'assets/sai_abhyankkar.png',
      'srikanthdeva': 'assets/srikanth_deva.png',
      'vijayantony': 'assets/vijay_antony.png',
      'harrisjayaraj': 'assets/harris_jayaraj.png',
    };

    for (final entry in artistImages.entries) {
      if (cleanArtist.contains(entry.key) || entry.key.contains(cleanArtist)) {
        return entry.value;
      }
    }

    if (fallbackImageUrl.isNotEmpty) {
      return fallbackImageUrl;
    }
    return 'https://i.pinimg.com/736x/5e/04/99/5e049992ef02750dad84fe7d44c061bc.jpg';
  }

  ImageProvider _getImageProvider(String path) {
    if (path.startsWith('assets/')) {
      return AssetImage(path);
    }
    return CachedNetworkImageProvider(path);
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212), // Dark fallback
      body: ValueListenableBuilder<Map<String, dynamic>?>(
        valueListenable: AudioService().currentSongNotifier,
        builder: (context, song, child) {
          if (song == null) {
            return Center(child: Text("No song playing", style: TextStyle(color: Colors.white)));
          }

          final String title = song['title'] ?? 'Unknown';
          final String artist = song['artist'] ?? 'Unknown';
          final String imageUrl = song['img'] ?? '';
          final String artistPic = _getArtistPicture(artist, imageUrl);
          final ImageProvider artistPicProvider = _getImageProvider(artistPic);

          return Stack(
            children: [
              // 1. Full Screen Blurred Background Image
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: artistPicProvider,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              // Glassmorphic dark blur overlay
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 45.0, sigmaY: 45.0),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.62),
                  ),
                ),
              ),

              // 2. Foreground Content
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                  child: Column(
                    children: [
                      // Top Row: Translucent Back, Now Playing, Translucent Heart
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                              child: Icon(
                                Icons.keyboard_arrow_left_rounded,
                                color: Theme.of(context).colorScheme.surface,
                                size: 24,
                              ),
                            ),
                          ),
                          Text(
                            "Now Playing",
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.surface,
                              letterSpacing: 0.5,
                            ),
                          ),
                          ValueListenableBuilder<List<Map<String, dynamic>>>(
                            valueListenable: AudioService().likedSongsNotifier,
                            builder: (context, likedSongs, child) {
                              final bool isLiked = AudioService().isSongLiked(song);
                              return GestureDetector(
                                onTap: () {
                                  AudioService().toggleLikeSong(song);
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withValues(alpha: 0.08),
                                  ),
                                  child: Icon(
                                    isLiked ? Icons.favorite : Icons.favorite_border,
                                    color: isLiked ? Colors.redAccent : Colors.white,
                                    size: 20,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),

                      const Spacer(flex: 1),
 
                       // Large circle album cover container with drop shadow & borders
                       Center(
                         child: Container(
                           width: MediaQuery.of(context).size.width * 0.72,
                           height: MediaQuery.of(context).size.width * 0.72,
                           decoration: BoxDecoration(
                             shape: BoxShape.circle,
                             border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 2),
                             boxShadow: [
                               BoxShadow(
                                 color: Colors.black.withValues(alpha: 0.4),
                                 blurRadius: 28,
                                 offset: const Offset(0, 12),
                               ),
                             ],
                           ),
                           child: ClipOval(
                             child: Image(
                               image: artistPicProvider,
                               fit: BoxFit.cover,
                               errorBuilder: (context, error, stackTrace) => Container(
                                 color: Theme.of(context).colorScheme.primary,
                                 child: Icon(
                                   Icons.music_note,
                                   size: 80,
                                   color: Color(0xFFE5B3B3),
                                 ),
                               ),
                             ),
                           ),
                         ),
                       ),
 
                       const Spacer(flex: 1),
 
                       // Title & Artist
                       Column(
                         children: [
                           Text(
                             title,
                             textAlign: TextAlign.center,
                             style: GoogleFonts.outfit(
                               fontSize: 24,
                               fontWeight: FontWeight.bold,
                               color: Theme.of(context).colorScheme.surface,
                             ),
                             maxLines: 1,
                             overflow: TextOverflow.ellipsis,
                           ),
                           SizedBox(height: 6),
                           Text(
                             artist,
                             textAlign: TextAlign.center,
                             style: GoogleFonts.inter(
                               fontSize: 14,
                               color: Colors.white60,
                               fontWeight: FontWeight.w500,
                             ),
                             maxLines: 1,
                             overflow: TextOverflow.ellipsis,
                           ),
                         ],
                       ),
 
                       const Spacer(flex: 1),
 
                       // Swipe-to-skip Next Up Card
                       const NextUpCard(),
 
                       const Spacer(flex: 1),
 
                       // Progress Bar & Timestamps
                       ValueListenableBuilder<Duration>(
                         valueListenable: AudioService().positionNotifier,
                         builder: (context, position, child) {
                           return ValueListenableBuilder<Duration>(
                             valueListenable: AudioService().durationNotifier,
                             builder: (context, duration, child) {
                               final posMs = position.inMilliseconds.toDouble();
                               final durMs = duration.inMilliseconds.toDouble();
                               final double progress = (durMs > 0) ? (posMs / durMs).clamp(0.0, 1.0) : 0.0;
 
                               String formatDuration(Duration d) {
                                 final minutes = d.inMinutes;
                                 final seconds = d.inSeconds % 60;
                                 return '$minutes:${seconds.toString().padLeft(2, '0')}';
                               }
 
                               final remaining = duration - position;
                               final remainingStr = remaining.isNegative ? "0:00" : "-${formatDuration(remaining)}";
 
                               return Column(
                                 children: [
                                   SliderTheme(
                                     data: SliderTheme.of(context).copyWith(
                                       trackHeight: 2.5,
                                       thumbColor: const Color(0xFFE5B3B3),
                                       activeTrackColor: const Color(0xFFE5B3B3),
                                       inactiveTrackColor: Colors.white24,
                                       thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5.0),
                                       overlayShape: const RoundSliderOverlayShape(overlayRadius: 10.0),
                                     ),
                                     child: Slider(
                                       value: progress,
                                       onChanged: (value) {
                                         final newPosMs = (value * durMs).toInt();
                                         AudioService().seek(Duration(milliseconds: newPosMs));
                                       },
                                     ),
                                   ),
                                   SizedBox(height: 2),
                                   Padding(
                                     padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                     child: Row(
                                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                       children: [
                                         Text(
                                           formatDuration(position),
                                           style: GoogleFonts.inter(
                                             color: Colors.white60,
                                             fontSize: 11.5,
                                             fontWeight: FontWeight.w500,
                                           ),
                                         ),
                                         Text(
                                           remainingStr,
                                           style: GoogleFonts.inter(
                                             color: Colors.white60,
                                             fontSize: 11.5,
                                             fontWeight: FontWeight.w500,
                                           ),
                                         ),
                                       ],
                                     ),
                                   ),
                                 ],
                               );
                            },
                           );
                         },
                       ),
 
                       const Spacer(flex: 1),

                      // Control Panel Row (Shuffle, Translucent Prev, Play/Pause Circle, Translucent Next, Queue)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.shuffle_rounded,
                              color: _isShuffleEnabled ? const Color(0xFFE5B3B3) : Colors.white54,
                            ),
                            onPressed: () {
                              setState(() {
                                _isShuffleEnabled = !_isShuffleEnabled;
                              });
                            },
                          ),
                          GestureDetector(
                            onTap: () {
                              AudioService().previousSong();
                            },
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                              child: Icon(
                                Icons.skip_previous_rounded,
                                color: Theme.of(context).colorScheme.surface,
                                size: 26,
                              ),
                            ),
                          ),
                          ValueListenableBuilder<bool>(
                            valueListenable: AudioService().isPlayingNotifier,
                            builder: (context, isPlaying, child) {
                              return ValueListenableBuilder<bool>(
                                valueListenable: AudioService().isLoadingNotifier,
                                builder: (context, isLoading, child) {
                                  return GestureDetector(
                                    onTap: () {
                                      AudioService().togglePlay();
                                    },
                                    child: Container(
                                      width: 68,
                                      height: 68,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Color(0xFFE5B3B3), // Accent color matching our theme
                                      ),
                                      child: Center(
                                        child: isLoading
                                            ? SizedBox(
                                                width: 22,
                                                height: 22,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2.0,
                                                  color: Theme.of(context).colorScheme.primary,
                                                ),
                                              )
                                            : Icon(
                                                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                                color: Theme.of(context).colorScheme.primary,
                                                size: 38,
                                              ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                          GestureDetector(
                            onTap: () {
                              AudioService().nextSong();
                            },
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                              child: Icon(
                                Icons.skip_next_rounded,
                                color: Theme.of(context).colorScheme.surface,
                                size: 26,
                              ),
                            ),
                          ),
                          ValueListenableBuilder<Set<String>>(
                            valueListenable: DownloadService().downloadingIdsNotifier,
                            builder: (context, downloadingIds, _) {
                              return ValueListenableBuilder<List<Map<String, dynamic>>>(
                                valueListenable: DownloadService().downloadedSongsNotifier,
                                builder: (context, downloadedSongs, _) {
                                  final isDownloading = DownloadService().isDownloading(song);
                                  final isDownloaded = DownloadService().isDownloaded(song);
                                  
                                  if (isDownloading) {
                                    return const Padding(
                                      padding: EdgeInsets.all(12.0),
                                      child: SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFE5B3B3)),
                                      ),
                                    );
                                  }
                                  
                                  return IconButton(
                                    icon: Icon(
                                      isDownloaded ? Icons.download_done_rounded : Icons.download_rounded,
                                      color: isDownloaded ? Colors.greenAccent : Colors.white54,
                                    ),
                                    onPressed: () {
                                      if (isDownloaded) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text("Already downloaded!"), duration: Duration(seconds: 1)),
                                        );
                                      } else {
                                        DownloadService().downloadSong(song);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text("Downloading..."), duration: Duration(seconds: 1)),
                                        );
                                      }
                                    },
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),

                      SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}


class NextUpCard extends StatelessWidget {
  const NextUpCard({super.key});

  Map<String, dynamic>? _getNextSong() {
    final playlist = AudioService().playlist;
    final index = AudioService().currentIndex;
    if (playlist.isEmpty || index == -1 || playlist.length <= 1) {
      return null;
    }
    final nextIndex = (index + 1) % playlist.length;
    return playlist[nextIndex];
  }

  @override
  Widget build(BuildContext context) {
    final nextSong = _getNextSong();
    if (nextSong == null) return const SizedBox.shrink();

    final title = nextSong['title'] ?? 'Unknown';
    final artist = nextSong['artist'] ?? 'Unknown';

    return Container(
      width: double.infinity,
      height: 60,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Dismissible(
        key: ValueKey(nextSong['id'] ?? title),
        direction: DismissDirection.endToStart, // Swipe left to skip
        onDismissed: (direction) {
          AudioService().nextSong();
        },
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24.0),
          decoration: BoxDecoration(
            color: const Color(0xFFE5B3B3).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Skipping",
                style: TextStyle(color: Theme.of(context).colorScheme.surface, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              SizedBox(width: 8),
              Icon(Icons.skip_next_rounded, color: Theme.of(context).colorScheme.surface, size: 24),
            ],
          ),
        ),
        child: Container(
          width: double.infinity,
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.06),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFE5B3B3).withValues(alpha: 0.12),
                ),
                child: Icon(
                  Icons.queue_music_rounded,
                  color: Color(0xFFE5B3B3),
                  size: 16,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "NEXT UP",
                      style: GoogleFonts.inter(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFE5B3B3),
                        letterSpacing: 1.0,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "$title • $artist",
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Swipe left to skip",
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: Colors.white30,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_left_rounded,
                    color: Colors.white30,
                    size: 14,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
