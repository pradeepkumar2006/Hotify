import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'services/audio_service.dart';
import 'player_screen.dart';

class ArtistDetailsScreen extends StatefulWidget {
  final String artistName;
  final String artistImage;
  final List<Map<String, dynamic>> artistSongs;

  const ArtistDetailsScreen({
    super.key,
    required this.artistName,
    required this.artistImage,
    required this.artistSongs,
  });

  @override
  State<ArtistDetailsScreen> createState() => _ArtistDetailsScreenState();
}

class _ArtistDetailsScreenState extends State<ArtistDetailsScreen> {
  late ScrollController _scrollController;
  final ValueNotifier<double> _scrollOffsetNotifier = ValueNotifier<double>(0.0);
  bool _isSearching = false;
  List<Map<String, dynamic>> _allArtistSongs = [];
  List<Map<String, dynamic>> _filteredSongs = [];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(() {
      if (_scrollController.hasClients) {
        _scrollOffsetNotifier.value = _scrollController.offset;
      }
    });

    // Receive the pre-filtered songs list directly from the parent screen
    _allArtistSongs = widget.artistSongs;
    _filteredSongs = List.from(_allArtistSongs);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _scrollOffsetNotifier.dispose();
    super.dispose();
  }

  ImageProvider _getImageProvider(String path) {
    if (path.startsWith('assets/')) {
      return AssetImage(path);
    }
    return CachedNetworkImageProvider(path);
  }

  ImageProvider _getSongImageProvider(Map<String, dynamic> song) {
    // Always use the artist's photo for all song tiles on this screen
    final String img = widget.artistImage;
    if (img.startsWith('http')) {
      return CachedNetworkImageProvider(img);
    }
    if (img.startsWith('assets/')) {
      return AssetImage(img);
    }
    return const CachedNetworkImageProvider(
      'https://i.pinimg.com/736x/5e/04/99/5e049992ef02750dad84fe7d44c061bc.jpg',
    );
  }

  String _getSongDuration(Map<String, dynamic> song) {
    final idStr = song['id']?.toString() ?? '';
    final int hash = idStr.hashCode.abs();
    final int minutes = 3 + (hash % 2);
    final int seconds = 10 + (hash % 45);
    return "$minutes:${seconds.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Stack(
        children: [
          // 1. Background Layer (Artist Image with Parallax & Stretch zoom - Performance Optimized)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 580, // Extra height limit to cover drag pull-downs
            child: IgnorePointer(
              child: ValueListenableBuilder<double>(
                valueListenable: _scrollOffsetNotifier,
                builder: (context, scrollOffset, child) {
                  double translationY = 0.0;
                  double imageHeight = 380.0;
                  double imageScale = 1.0;
                  double imageOpacity = 1.0;
                  
                  if (scrollOffset > 0) {
                    translationY = -(scrollOffset * 0.5);
                    imageOpacity = (1.0 - (scrollOffset / 300.0)).clamp(0.0, 1.0);
                  } else {
                    imageHeight = 380.0 - scrollOffset;
                    imageScale = 1.0 - (scrollOffset * 0.0025);
                  }
                  
                  return Transform.translate(
                    offset: Offset(0, translationY),
                    child: SizedBox(
                      height: imageHeight,
                      child: Transform.scale(
                        scale: imageScale,
                        alignment: Alignment.topCenter,
                        child: Opacity(
                          opacity: imageOpacity,
                          child: Container(
                            decoration: BoxDecoration(
                              image: DecorationImage(
                                image: _getImageProvider(widget.artistImage),
                                fit: BoxFit.cover,
                              ),
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.black.withValues(alpha: 0.6),
                                    Colors.black.withValues(alpha: 0.1),
                                    Colors.black.withValues(alpha: 0.7),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  stops: const [0.0, 0.5, 1.0],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // 2. Artist Name on Expanded Image (follows parallax and fades out - Performance Optimized)
          Positioned(
            top: 290,
            left: 24,
            child: IgnorePointer(
              child: ValueListenableBuilder<double>(
                valueListenable: _scrollOffsetNotifier,
                builder: (context, scrollOffset, child) {
                  final double expandedNameOpacity = (1.0 - (scrollOffset / 150.0)).clamp(0.0, 1.0);
                  final double translationY = scrollOffset > 0 ? -(scrollOffset * 0.65) : -(scrollOffset * 0.5);
                  
                  return Transform.translate(
                    offset: Offset(0, translationY),
                    child: Opacity(
                      opacity: expandedNameOpacity,
                      child: Text(
                        widget.artistName,
                        style: GoogleFonts.outfit(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // 3. Scrollable Content (Songs List inside a Curved sliding container - Virtualized for performance)
          Positioned.fill(
            child: CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              cacheExtent: 1000,
              slivers: [
                // Transparent spacer to push the sliding card below the visible header
                const SliverToBoxAdapter(
                  child: SizedBox(height: 330),
                ),
                
                // Curved sliding container header
                SliverToBoxAdapter(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
                          blurRadius: 12,
                          offset: const Offset(0, -6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Sliding sheet drag indicator bar
                        Center(
                          child: Container(
                            margin: const EdgeInsets.only(top: 14, bottom: 8),
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        // Songs Header Text
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Text(
                            'Songs',
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),

                // Handle empty state virtualized
                if (_filteredSongs.isEmpty)
                  SliverToBoxAdapter(
                    child: Container(
                      color: Theme.of(context).colorScheme.surface,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40.0),
                          child: Text(
                            'No songs found for this artist.',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45)),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Virtualized List of Songs
                if (_filteredSongs.isNotEmpty)
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final song = _filteredSongs[index];
                        return Container(
                          color: Theme.of(context).colorScheme.surface,
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4.0),
                            child: ListTile(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(
                                  width: 56,
                                  height: 56,
                                  child: Image(
                                    image: ResizeImage(_getSongImageProvider(song), width: 100, height: 100),
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      final fallback = widget.artistImage;
                                      if (fallback.startsWith('http') && !fallback.contains('5e049992ef02750dad84fe7d44c061bc')) {
                                        return CachedNetworkImage(
                                          imageUrl: fallback,
                                          fit: BoxFit.cover,
                                          width: 56,
                                          height: 56,
                                          memCacheWidth: 100,
                                          memCacheHeight: 100,
                                          errorWidget: (c, u, e) => Container(
                                            color: Colors.grey.shade800,
                                            child: const Icon(
                                              Icons.music_note,
                                              color: Colors.white54,
                                              size: 28,
                                            ),
                                          ),
                                        );
                                      }
                                      // Generate an avatar with the song's artist name or the screen's artist name
                                      final artistName = song['artist'] ?? widget.artistName;
                                      return CachedNetworkImage(
                                        imageUrl: 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(artistName)}&background=random&size=128',
                                        fit: BoxFit.cover,
                                        width: 56,
                                        height: 56,
                                        memCacheWidth: 100,
                                        memCacheHeight: 100,
                                        errorWidget: (c, u, e) => Container(
                                          color: Colors.grey.shade800,
                                          child: const Icon(
                                            Icons.music_note,
                                            color: Colors.white54,
                                            size: 28,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              title: Text(
                                song['title'] ?? '',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                song['composer'] ?? song['artist'] ?? '',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Icon(
                                    Icons.favorite_border,
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                                    size: 18,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _getSongDuration(song),
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              onTap: () {
                                AudioService().playSong(
                                  song,
                                  playlistContext: _filteredSongs,
                                );
                                Navigator.of(context).push(
                                  CupertinoPageRoute(
                                    builder: (context) => const PlayerScreen(),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                      childCount: _filteredSongs.length,
                    ),
                  ),

                // Bottom spacer to allow scrolling past list elements
                SliverToBoxAdapter(
                  child: Container(
                    height: 120,
                    color: Theme.of(context).colorScheme.surface,
                  ),
                ),
              ],
            ),
          ),

          // 4. Fixed Top Navigation Bar Background (Fades in on scroll - Performance Optimized)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 95,
            child: IgnorePointer(
              child: ValueListenableBuilder<double>(
                valueListenable: _scrollOffsetNotifier,
                builder: (context, scrollOffset, child) {
                  final double navBarOpacity = (scrollOffset / 180.0).clamp(0.0, 1.0);
                  return Container(
                    color: Colors.white.withValues(alpha: navBarOpacity),
                  );
                },
              ),
            ),
          ),

          // 5. Fixed Top Navigation Bar Elements (Back & Search Button & Animated Title - Performance Optimized)
          Positioned(
            top: 50,
            left: 16,
            right: 16,
            child: ValueListenableBuilder<double>(
              valueListenable: _scrollOffsetNotifier,
              builder: (context, scrollOffset, child) {
                final double navBarOpacity = (scrollOffset / 180.0).clamp(0.0, 1.0);
                final bool isNavbarWhite = navBarOpacity > 0.8;
                
                final Color navIconColor = isNavbarWhite ? Theme.of(context).colorScheme.primary : Colors.white;
                final Color navIconBg = isNavbarWhite ? Colors.transparent : Colors.black.withValues(alpha: 0.3);
                
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: navIconBg,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: navIconColor,
                          size: 20,
                        ),
                      ),
                    ),
                    
                    Expanded(
                      child: Center(
                        child: Opacity(
                          opacity: _isSearching ? 1.0 : navBarOpacity,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: _isSearching
                                ? Container(
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: TextField(
                                      autofocus: true,
                                      style: TextStyle(
                                          color: Theme.of(context).colorScheme.primary,
                                          fontSize: 14),
                                      decoration: InputDecoration(
                                        hintText: 'Search songs...',
                                        hintStyle: TextStyle(
                                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                            fontSize: 14),
                                        border: InputBorder.none,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      ),
                                      onChanged: (value) {
                                        setState(() {
                                          if (value.isEmpty) {
                                            _filteredSongs = List.from(_allArtistSongs);
                                          } else {
                                            final lowercaseQuery = value.toLowerCase();
                                            _filteredSongs = _allArtistSongs.where((song) {
                                              final title = (song['title'] ?? '').toString().toLowerCase();
                                              return title.contains(lowercaseQuery);
                                            }).toList();
                                          }
                                        });
                                      },
                                    ),
                                  )
                                : Text(
                                    widget.artistName,
                                    style: GoogleFonts.outfit(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                          ),
                        ),
                      ),
                    ),

                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isSearching = !_isSearching;
                          if (!_isSearching) {
                            _filteredSongs = List.from(_allArtistSongs);
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _isSearching ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.95) : navIconBg,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isSearching ? Icons.close : FeatherIcons.search,
                          color: _isSearching ? Theme.of(context).colorScheme.primary : navIconColor,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class BottomCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final Path path = Path();
    path.lineTo(0, size.height - 50);
    
    final firstControlPoint = Offset(size.width / 2, size.height);
    final firstEndPoint = Offset(size.width, size.height - 50);
    
    path.quadraticBezierTo(
      firstControlPoint.dx,
      firstControlPoint.dy,
      firstEndPoint.dx,
      firstEndPoint.dy,
    );
    
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
