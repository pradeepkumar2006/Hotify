import 'dart:io';
import 'dart:async';
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
      AudioService().userPlaylistsNotifier.addListener(_onCustomPlaylistChanged);
    }

    // Fallback: If the playlist image is missing or is the dummy Pinterest image, use the artist image instead
    if ((_image.isEmpty || _image == 'assets/logo.png' || _image.contains('5e049992ef02750dad84fe7d44c061bc')) && _songs.isNotEmpty) {
      final firstArtist = _songs.first['artist'] ?? '';
      _image = _getArtistPicture(firstArtist, '');
    }
  }

  void _onLikedSongsChanged() {
    if (mounted) {
      setState(() {
        _songs = List<Map<String, dynamic>>.from(AudioService().likedSongsNotifier.value);
      });
    }
  }

  void _onCustomPlaylistChanged() {
    if (mounted) {
      final updatedPlaylists = AudioService().userPlaylistsNotifier.value;
      final idx = updatedPlaylists.indexWhere((p) => p['name'] == _name);
      if (idx != -1) {
        setState(() {
          _songs = List<Map<String, dynamic>>.from(updatedPlaylists[idx]['songs'] ?? []);
        });
      }
    }
  }

  @override
  void dispose() {
    if (widget.playlist['isLikedSongs'] == true) {
      AudioService().likedSongsNotifier.removeListener(_onLikedSongsChanged);
    } else {
      AudioService().userPlaylistsNotifier.removeListener(_onCustomPlaylistChanged);
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
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return CachedNetworkImageProvider(path);
    }
    return FileImage(File(path));
  }

  String _getArtistPicture(String artistName, String fallbackImageUrl) {
    final String cleanArtist = artistName.toLowerCase().replaceAll(' ', '').replaceAll('.', '');
    
    final Map<String, String> artistImages = {
      'arrahman': 'assets/ar_rahman.png',
      'anirudh': 'assets/anirudh.jpg',
      'yuvansankar': 'assets/yuvan.jpg',
      'yuvanshankar': 'assets/yuvan.jpg',
      'deva': 'assets/deva.jpg',
      'hiphopaadhi': 'assets/hiphop_tamizha.png',
      'hiphop': 'assets/hiphop_tamizha.png',
      'gvprakash': 'assets/gv_prakash.jpg',
      'saiabhyankkar': 'assets/sai_abhyankkar.png',
      'saiabhyankar': 'assets/sai_abhyankkar.png',
      'srikanthdeva': 'assets/srikanth_deva.png',
      'vijayantony': 'assets/vijay_antony.png',
      'harrisjayaraj': 'assets/harris_jayaraj.png',
      'dsp': 'assets/dsp.png',
      'devissriprasad': 'assets/dsp.png',
      'devisriprasad': 'assets/dsp.png',
      'dimman': 'assets/imman.png',
      'imman': 'assets/imman.png',
      'snarunagiri': 'assets/sn_arunagiri.png',
      'arunagiri': 'assets/sn_arunagiri.png',
      'ilaiyaraaja': 'assets/ilaiyaraaja.png',
      'ilayaraja': 'assets/ilaiyaraaja.png',
      'karthikraja': 'assets/karthik_raja.png',
      'msviswanathan': 'assets/msv.png',
      'viswanathan': 'assets/msv.png',
      'variouscomposers': 'assets/various_composers.png',
    };

    for (final entry in artistImages.entries) {
      if (cleanArtist.contains(entry.key) || entry.key.contains(cleanArtist)) {
        return entry.value;
      }
    }

    if (fallbackImageUrl.isNotEmpty && !fallbackImageUrl.contains('5e049992ef02750dad84fe7d44c061bc')) {
      return fallbackImageUrl;
    }
    return 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(artistName)}&background=random&size=256';
  }

  ImageProvider _getSongImageProvider(Map<String, dynamic> song) {
    // Check if English song for crossover card image
    if ((song['language'] ?? '').toString().toLowerCase() == 'english') {
      final yearVal = int.tryParse(song['year']?.toString() ?? '');
      if (yearVal != null) {
        if (yearVal <= 2010) {
          return const AssetImage('assets/crossover_1.png');
        } else if (yearVal <= 2015) {
          return const AssetImage('assets/crossover_2.png');
        } else if (yearVal <= 2020) {
          return const AssetImage('assets/crossover_3.png');
        } else {
          return const AssetImage('assets/crossover_4.png');
        }
      }
    }

    final String artist = song['artist'] ?? '';
    String imagePath = _getArtistPicture(artist, song['img'] ?? '');
    
    if (imagePath.startsWith('assets/') &&
        !imagePath.endsWith('.jpg') &&
        !imagePath.endsWith('.jpeg') &&
        !imagePath.endsWith('.png')) {
      imagePath = _getArtistPicture(artist, song['img'] ?? '');
    }
    return _getImageProvider(imagePath);
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
    Timer? searchDebounce;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
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
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Text(
                        'Add Songs to $_name',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      SizedBox(height: 16),
                      TextField(
                        controller: searchController,
                        style: GoogleFonts.inter(color: Theme.of(context).colorScheme.primary),
                        decoration: InputDecoration(
                          hintText: 'Search songs or artists...',
                          prefixIcon: Icon(FeatherIcons.search, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38)),
                          filled: true,
                          fillColor: Colors.black.withValues(alpha: 0.04),
                          contentPadding: const EdgeInsets.symmetric(vertical: 12.0),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (val) {
                          searchDebounce?.cancel();
                          searchDebounce = Timer(const Duration(milliseconds: 250), () async {
                            final query = val.toLowerCase().trim();
                            
                            List<Map<String, dynamic>> localFiltered = [];
                            if (query.isEmpty) {
                              localFiltered = List.from(widget.allSongs);
                            } else {
                              localFiltered = widget.allSongs.where((song) {
                                final title = (song['title'] ?? '').toString().toLowerCase();
                                final artist = (song['artist'] ?? '').toString().toLowerCase();
                                return title.contains(query) || artist.contains(query);
                              }).toList();
                            }
                            
                            if (context.mounted) {
                              setSheetState(() {
                                filteredSongs = localFiltered;
                              });
                            }
                            
                            if (query.isNotEmpty) {
                              final jioSaavnResults = await AudioService().searchJioSaavn(query);
                              if (context.mounted && searchController.text.toLowerCase().trim() == query) {
                                setSheetState(() {
                                  final existingIds = filteredSongs.map((s) => s['id'].toString()).toSet();
                                  for (var js in jioSaavnResults) {
                                    if (!existingIds.contains(js['id'].toString())) {
                                      filteredSongs.add(js);
                                    }
                                  }
                                });
                              }
                            }
                          });
                        },
                      ),
                      SizedBox(height: 16),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          cacheExtent: 1000,
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
                                    image: ResizeImage(_getSongImageProvider(song), width: 80, height: 80),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              title: Text(
                                song['title']!,
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                song['artist']!,
                                style: GoogleFonts.inter(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54)),
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
                                  backgroundColor: alreadyAdded ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12) : Theme.of(context).colorScheme.primary,
                                  foregroundColor: alreadyAdded ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38) : Theme.of(context).colorScheme.onPrimary,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Text(alreadyAdded ? 'Added' : 'Add', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.primary),
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
                  errorBuilder: (context, error, stackTrace) => Image.asset(
                    'assets/logo.png',
                    fit: BoxFit.cover,
                  ),
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
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Theme.of(context).colorScheme.primary, Color(0xFF2E2E38)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.favorite_rounded,
                                color: Theme.of(context).colorScheme.surface,
                                size: 64,
                              ),
                              SizedBox(height: 8),
                              Text(
                                "Top Liked Songs",
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.surface,
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
                        image: (_image.isEmpty || 
                                _image == 'assets/logo.png' || 
                                _image.contains('5e049992ef02750dad84fe7d44c061bc') || 
                                _image.contains('various_composers.png')) && _songs.isNotEmpty
                            ? _getSongImageProvider(_songs.first)
                            : _getImageProvider(_image),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Image.asset(
                          'assets/logo.png',
                          fit: BoxFit.cover,
                        ),
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
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (_description.isNotEmpty) ...[
                                      Text(
                                        _description,
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
                                          fontStyle: FontStyle.italic,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ] else
                                      Text(
                                        _getPlaylistDuration(),
                                        style: GoogleFonts.inter(
                                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
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
                                      icon: Icon(Icons.add, color: Theme.of(context).colorScheme.primary),
                                      tooltip: 'Add Songs',
                                      onPressed: _showAddSongsSheet,
                                    ),
                                  IconButton(
                                    icon: Icon(Icons.swap_vert_rounded, color: Theme.of(context).colorScheme.primary),
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
                                      color: _isShuffleEnabled ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _isShuffleEnabled = !_isShuffleEnabled;
                                      });
                                    },
                                  ),
                                  SizedBox(width: 4),
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
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.primary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Icon(
                                          Icons.play_arrow_rounded,
                                          color: Theme.of(context).colorScheme.surface,
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
                      Divider(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12), height: 1),
          // 60% Scrollable Songs List
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: _songs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.music_note_outlined, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.26), size: 48),
                          SizedBox(height: 12),
                          Text(
                            'This playlist is empty.',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54)),
                          ),
                          if (widget.playlist['isLikedSongs'] != true) ...[
                            SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _showAddSongsSheet,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: Text('Add Songs', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ] else ...[
                            SizedBox(height: 8),
                            Text(
                              'Songs you like on Home screen will appear here!',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38), fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      cacheExtent: 1000,
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
                                image: ResizeImage(_getSongImageProvider(song), width: 80, height: 80),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Image.asset(
                                  'assets/logo.png',
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                          title: Text(
                            song['title']!,
                            style: GoogleFonts.inter(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            song['artist']!,
                            style: GoogleFonts.inter(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.more_vert, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45)),
                            onPressed: () {
                              _showSongOptionsSheet(song, index);
                            },
                          ),
                          onTap: () {
                            AudioService().playSong(song, playlistContext: _songs);
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const PlayerScreen(),
                              ),
                            );
                          },
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                title: Text(
                  'Remove "${song['title']}" from playlist',
                  style: TextStyle(color: Theme.of(context).colorScheme.primary),
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
                leading: Icon(Icons.cancel_outlined, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54)),
                title: Text('Cancel', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }
}
