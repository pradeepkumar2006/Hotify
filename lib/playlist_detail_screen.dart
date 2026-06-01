import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'services/audio_service.dart';
import 'player_screen.dart';

class PlaylistDetailScreen extends StatefulWidget {
  final Map<String, dynamic> playlist;
  final List<Map<String, dynamic>> allSongs;
  final Function(Map<String, dynamic> updatedPlaylist) onPlaylistUpdated;

  const PlaylistDetailScreen({
    super.key,
    required this.playlist,
    required this.allSongs,
    required this.onPlaylistUpdated,
  });

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  late String _name;
  late String _image;
  late String _description;
  late List<Map<String, dynamic>> _songs;
  bool _isShuffleEnabled = false;

  @override
  void initState() {
    super.initState();
    _name = widget.playlist['name'] ?? 'My Playlist';
    _image = widget.playlist['image'] ?? 'assets/logo.png';
    _description = widget.playlist['description'] ?? '';
    if (widget.playlist['isLikedSongs'] == true) {
      _songs = List<Map<String, dynamic>>.from(AudioService().likedSongsNotifier.value);
      AudioService().likedSongsNotifier.addListener(_onLikedSongsChanged);
    } else {
      _songs = List<Map<String, dynamic>>.from(widget.playlist['songs'] ?? []);
    }
  }

  void _onLikedSongsChanged() {
    if (mounted) {
      setState(() {
        _songs = List<Map<String, dynamic>>.from(AudioService().likedSongsNotifier.value);
      });
    }
  }

  @override
  void dispose() {
    if (widget.playlist['isLikedSongs'] == true) {
      AudioService().likedSongsNotifier.removeListener(_onLikedSongsChanged);
    }
    super.dispose();
  }

  void _updateParent() {
    if (widget.playlist['isLikedSongs'] == true) return;
    widget.onPlaylistUpdated({
      'name': _name,
      'image': _image,
      'description': _description,
      'songs': _songs,
    });
  }

  ImageProvider _getImageProvider(String path) {
    if (path.isEmpty) {
      return const AssetImage('assets/logo.png');
    }
    if (path.startsWith('assets/')) {
      return AssetImage(path);
    }
    if (path.startsWith('http://') || path.startsWith('https/')) {
      return CachedNetworkImageProvider(path);
    }
    return FileImage(File(path));
  }

  String _getPlaylistDuration() {
    if (_songs.isEmpty) return "0 songs";
    int totalMinutes = 0;
    for (final song in _songs) {
      final idStr = song['id']?.toString() ?? '';
      final int hash = idStr.hashCode.abs();
      totalMinutes += 3 + (hash % 2);
    }
    final int hours = totalMinutes ~/ 60;
    final int minutes = totalMinutes % 60;
    if (hours > 0) {
      return "${_songs.length} songs • ${hours}h ${minutes}m";
    }
    return "${_songs.length} songs • ${minutes}m";
  }

  void _showAddSongsSheet() {
    final searchController = TextEditingController();
    List<Map<String, dynamic>> filteredSongs = List.from(widget.allSongs);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.black12,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Text(
                        'Add Songs to $_name',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E1E24),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: searchController,
                        style: GoogleFonts.inter(color: const Color(0xFF1E1E24)),
                        decoration: InputDecoration(
                          hintText: 'Search songs or artists...',
                          prefixIcon: const Icon(FeatherIcons.search, color: Colors.black38),
                          filled: true,
                          fillColor: Colors.black.withValues(alpha: 0.04),
                          contentPadding: const EdgeInsets.symmetric(vertical: 12.0),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (val) {
                          setSheetState(() {
                            filteredSongs = widget.allSongs.where((song) {
                              final title = (song['title'] ?? '').toString().toLowerCase();
                              final artist = (song['artist'] ?? '').toString().toLowerCase();
                              return title.contains(val.toLowerCase()) || artist.contains(val.toLowerCase());
                            }).toList();
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: filteredSongs.length,
                          itemBuilder: (context, index) {
                            final song = filteredSongs[index];
                            final bool alreadyAdded = _songs.any((s) => s['id'] == song['id']);
                            return ListTile(
                              leading: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  image: DecorationImage(
                                    image: _getImageProvider(song['img'] ?? 'assets/logo.png'),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              title: Text(
                                song['title']!,
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: const Color(0xFF1E1E24),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                song['artist']!,
                                style: GoogleFonts.inter(fontSize: 12, color: Colors.black54),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: ElevatedButton(
                                onPressed: alreadyAdded
                                    ? null
                                    : () {
                                        setState(() {
                                          _songs.add(song);
                                        });
                                        _updateParent();
                                        setSheetState(() {});
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Added "${song['title']}" to playlist'),
                                            duration: const Duration(milliseconds: 600),
                                          ),
                                        );
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: alreadyAdded ? Colors.black12 : const Color(0xFF1E1E24),
                                  foregroundColor: alreadyAdded ? Colors.black38 : Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Text(alreadyAdded ? 'Added' : 'Add', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E1E24)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Full screen background cover image
          if (widget.playlist['isLikedSongs'] != true)
            Positioned.fill(
              child: Opacity(
                opacity: 0.08, // Subtle background texture
                child: Image(
                  image: _getImageProvider(_image),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          // Content Column
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 30% Fixed Height Top Section (Full Edge-to-Edge Cover Image)
              SizedBox(
                height: screenHeight * 0.30,
                width: double.infinity,
                child: widget.playlist['isLikedSongs'] == true
                    ? Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF1E1E24), Color(0xFF2E2E38)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.favorite_rounded,
                                color: Colors.white,
                                size: 64,
                              ),
                              SizedBox(height: 8),
                              Text(
                                "Top Liked Songs",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Image(
                        image: _getImageProvider(_image),
                        fit: BoxFit.cover,
                      ),
              ),
              // Rest of the content wrapped in SafeArea (excluding top notch)
              Expanded(
                child: SafeArea(
                  top: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 10% Fixed Height Details Row
                      SizedBox(
                        height: screenHeight * 0.10,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      _name,
                                      style: GoogleFonts.outfit(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF1E1E24),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (_description.isNotEmpty) ...[
                                      Text(
                                        _description,
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: Colors.black54,
                                          fontStyle: FontStyle.italic,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ] else
                                      Text(
                                        _getPlaylistDuration(),
                                        style: GoogleFonts.inter(
                                          color: Colors.black45,
                                          fontSize: 11,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              // Compact Row of Action Buttons (black/grey style)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (widget.playlist['isLikedSongs'] != true)
                                    IconButton(
                                      icon: const Icon(Icons.add, color: Color(0xFF1E1E24)),
                                      tooltip: 'Add Songs',
                                      onPressed: _showAddSongsSheet,
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.swap_vert_rounded, color: Color(0xFF1E1E24)),
                                    tooltip: 'Sort Songs',
                                    onPressed: () {
                                      setState(() {
                                        _songs.sort((a, b) => a['title'].compareTo(b['title']));
                                      });
                                      _updateParent();
                                    },
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.shuffle,
                                      color: _isShuffleEnabled ? const Color(0xFF1E1E24) : Colors.black38,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _isShuffleEnabled = !_isShuffleEnabled;
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 4),
                                  GestureDetector(
                                    onTap: () {
                                      if (_songs.isNotEmpty) {
                                        final playList = _isShuffleEnabled ? (List<Map<String, dynamic>>.from(_songs)..shuffle()) : _songs;
                                        AudioService().playSong(playList.first, playlistContext: playList);
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) => const PlayerScreen(),
                                          ),
                                        );
                                      } else {
                                        _showAddSongsSheet();
                                      }
                                    },
                                    child: Container(
                                      width: 36,
                                      height: 36,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF1E1E24),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Center(
                                        child: Icon(
                                          Icons.play_arrow_rounded,
                                          color: Colors.white,
                                          size: 22,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Divider(color: Colors.black12, height: 1),
          // 60% Scrollable Songs List
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: _songs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.music_note_outlined, color: Colors.black26, size: 48),
                          const SizedBox(height: 12),
                          const Text(
                            'This playlist is empty.',
                            style: TextStyle(color: Colors.black54),
                          ),
                          if (widget.playlist['isLikedSongs'] != true) ...[
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _showAddSongsSheet,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E1E24),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: const Text('Add Songs', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ] else ...[
                            const SizedBox(height: 8),
                            const Text(
                              'Songs you like on Home screen will appear here!',
                              style: TextStyle(color: Colors.black38, fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.only(top: 8, bottom: 150),
                      itemCount: _songs.length,
                      itemBuilder: (context, index) {
                        final song = _songs[index];
                        return ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: Image(
                                image: _getImageProvider(song['img'] ?? 'assets/logo.png'),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          title: Text(
                            song['title']!,
                            style: GoogleFonts.inter(
                              color: const Color(0xFF1E1E24),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            song['artist']!,
                            style: GoogleFonts.inter(
                              color: Colors.black54,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.more_vert, color: Colors.black45),
                            onPressed: () {
                              _showSongOptionsSheet(song, index);
                            },
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    ),
  ),
],
),
],
),
    );
  }

  void _showSongOptionsSheet(Map<String, dynamic> song, int index) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                title: Text(
                  'Remove "${song['title']}" from playlist',
                  style: const TextStyle(color: Color(0xFF1E1E24)),
                ),
                onTap: () {
                  setState(() {
                    _songs.removeAt(index);
                  });
                  _updateParent();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Removed "${song['title']}"'),
                      duration: const Duration(milliseconds: 600),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.cancel_outlined, color: Colors.black54),
                title: const Text('Cancel', style: TextStyle(color: Color(0xFF1E1E24))),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }
}
