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

  final List<Map<String, String>> _presetCovers = [
    {
      'name': 'Peace (Anime)',
      'url': 'https://i.pinimg.com/736x/a2/e1/9b/a2e19b8849b293d05267b209d00b05b4.jpg',
    },
    {
      'name': 'Kollywood Cream',
      'url': 'https://i.pinimg.com/736x/11/a5/d8/11a5d89849b380387b9264fa58ea37ef.jpg',
    },
    {
      'name': 'Trending Now Tamil',
      'url': 'https://i.pinimg.com/736x/c5/67/67/c567677eaed5443a17065f50a55e7c38.jpg',
    },
    {
      'name': 'Default App Logo',
      'url': 'assets/logo.png',
    },
  ];

  @override
  void initState() {
    super.initState();
    _name = widget.playlist['name'] ?? 'My Playlist';
    _image = widget.playlist['image'] ?? 'assets/logo.png';
    _description = widget.playlist['description'] ?? 'peace 🎼';
    _songs = List<Map<String, dynamic>>.from(widget.playlist['songs'] ?? []);
  }

  void _updateParent() {
    widget.onPlaylistUpdated({
      'name': _name,
      'image': _image,
      'description': _description,
      'songs': _songs,
    });
  }

  ImageProvider _getImageProvider(String path) {
    if (path.startsWith('assets/')) {
      return AssetImage(path);
    }
    return CachedNetworkImageProvider(path);
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
                                  backgroundColor: alreadyAdded ? Colors.black12 : const Color(0xFF1DB954),
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

  void _showGalleryMockPicker(StateSetter setDialogState, Function(String) onSelected) {
    final List<Map<String, String>> mockPhotos = [
      {
        'title': 'Peace (Anime)',
        'url': 'https://i.pinimg.com/736x/a2/e1/9b/a2e19b8849b293d05267b209d00b05b4.jpg',
      },
      {
        'title': 'Lofi Chill',
        'url': 'https://i.pinimg.com/736x/c5/67/67/c567677eaed5443a17065f50a55e7c38.jpg',
      },
      {
        'title': 'Retro Vinyl',
        'url': 'https://i.pinimg.com/736x/11/a5/d8/11a5d89849b380387b9264fa58ea37ef.jpg',
      },
      {
        'title': 'Sad Vibes',
        'url': 'https://i.pinimg.com/736x/31/3d/37/313d37415bcc86057d6042795c8be010.jpg',
      },
      {
        'title': 'Neon Synth',
        'url': 'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=500&auto=format&fit=crop',
      },
      {
        'title': 'Acoustic Guitar',
        'url': 'https://images.unsplash.com/photo-1510915228340-29c85a43dcfe?w=500&auto=format&fit=crop',
      },
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'Select Photo from Gallery',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E1E24),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 240,
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1,
                    ),
                    itemCount: mockPhotos.length,
                    itemBuilder: (context, index) {
                      final item = mockPhotos[index];
                      final url = item['url']!;
                      return GestureDetector(
                        onTap: () {
                          onSelected(url);
                          Navigator.pop(context);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.black12),
                            image: DecorationImage(
                              image: _getImageProvider(url),
                              fit: BoxFit.cover,
                            ),
                          ),
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              width: double.infinity,
                              color: Colors.black54,
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                item['title']!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditDetailsDialog() {
    final nameController = TextEditingController(text: _name);
    final descController = TextEditingController(text: _description);
    final imageUrlController = TextEditingController(text: _image);
    String selectedUrl = _image;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                'Edit Playlist Info',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFF1E1E24)),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      style: GoogleFonts.inter(color: const Color(0xFF1E1E24)),
                      decoration: const InputDecoration(
                        labelText: 'Playlist Name',
                        labelStyle: TextStyle(color: Colors.black45),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF1E1E24))),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descController,
                      style: GoogleFonts.inter(color: const Color(0xFF1E1E24)),
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        labelStyle: TextStyle(color: Colors.black45),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF1E1E24))),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: imageUrlController,
                      style: GoogleFonts.inter(color: const Color(0xFF1E1E24)),
                      decoration: const InputDecoration(
                        labelText: 'Custom Image URL',
                        labelStyle: TextStyle(color: Colors.black45),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF1E1E24))),
                      ),
                      onChanged: (val) {
                        setDialogState(() {
                          selectedUrl = val.trim();
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _showGalleryMockPicker(setDialogState, (url) {
                            setDialogState(() {
                              selectedUrl = url;
                              imageUrlController.text = url;
                            });
                          });
                        },
                        icon: const Icon(Icons.photo_library_outlined, size: 18),
                        label: const Text('Add Photo from Device Gallery'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E1E24),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Or Select Preset Cover:',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 80,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _presetCovers.length,
                        itemBuilder: (context, index) {
                          final cover = _presetCovers[index];
                          final url = cover['url']!;
                          final isSelected = selectedUrl == url;
                          return GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                selectedUrl = url;
                                imageUrlController.text = url;
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 12),
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                border: isSelected
                                    ? Border.all(color: const Color(0xFF1DB954), width: 3)
                                    : Border.all(color: Colors.black12),
                                borderRadius: BorderRadius.circular(8),
                                image: DecorationImage(
                                  image: _getImageProvider(url),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.black54)),
                ),
                ElevatedButton(
                  onPressed: () {
                    final n = nameController.text.trim();
                    if (n.isNotEmpty) {
                      setState(() {
                        _name = n;
                        _description = descController.text.trim();
                        _image = selectedUrl;
                      });
                      _updateParent();
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E1E24),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  image: DecorationImage(
                    image: _getImageProvider(_image),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _name,
                    style: GoogleFonts.outfit(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _description,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.white70,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 12,
                        backgroundColor: Color(0xFF1DB954),
                        child: Icon(Icons.person, color: Colors.black87, size: 12),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'pradee❤',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.public, color: Colors.white54, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        _getPlaylistDuration(),
                        style: GoogleFonts.inter(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_circle_down_rounded, color: Colors.white54),
                    iconSize: 28,
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(Icons.share_outlined, color: Colors.white54),
                    iconSize: 22,
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert, color: Colors.white54),
                    iconSize: 24,
                    onPressed: () {},
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      Icons.shuffle,
                      color: _isShuffleEnabled ? const Color(0xFF1DB954) : Colors.white54,
                    ),
                    iconSize: 24,
                    onPressed: () {
                      setState(() {
                        _isShuffleEnabled = !_isShuffleEnabled;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
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
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1DB954),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.black,
                          size: 36,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildActionButton(
                      label: 'Add',
                      icon: Icons.add,
                      onTap: _showAddSongsSheet,
                    ),
                    _buildActionButton(
                      label: 'Edit',
                      icon: Icons.edit_note_rounded,
                      onTap: _showEditDetailsDialog,
                    ),
                    _buildActionButton(
                      label: 'Sort',
                      icon: Icons.swap_vert_rounded,
                      onTap: () {
                        setState(() {
                          _songs.sort((a, b) => a['title'].compareTo(b['title']));
                        });
                        _updateParent();
                      },
                    ),
                    _buildActionButton(
                      label: 'Name and details',
                      icon: Icons.edit_rounded,
                      onTap: _showEditDetailsDialog,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: _songs.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48.0),
                        child: Column(
                          children: [
                            const Icon(Icons.music_note_outlined, color: Colors.white30, size: 48),
                            const SizedBox(height: 12),
                            const Text(
                              'This playlist is empty.',
                              style: TextStyle(color: Colors.white70),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _showAddSongsSheet,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1DB954),
                                foregroundColor: Colors.black87,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: const Text('Add Songs', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
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
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            song['artist']!,
                            style: GoogleFonts.inter(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.more_vert, color: Colors.white54),
                            onPressed: () {
                              _showSongOptionsSheet(song, index);
                            },
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: ActionChip(
        onPressed: onTap,
        avatar: Icon(icon, color: Colors.white, size: 16),
        label: Text(
          label,
          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
        ),
        backgroundColor: Colors.white.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: Colors.white24),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  void _showSongOptionsSheet(Map<String, dynamic> song, int index) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E24),
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
                  style: const TextStyle(color: Colors.white),
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
                leading: const Icon(Icons.cancel_outlined, color: Colors.white54),
                title: const Text('Cancel', style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }
}
