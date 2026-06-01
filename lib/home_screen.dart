import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'profile_screen.dart';
import 'services/audio_service.dart';
import 'player_screen.dart';
import 'artist_details_screen.dart';
import 'create_playlist_screen.dart';
import 'playlist_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  String _searchQuery = '';

  // Custom navigation items matching the mockup (Home, Search, Create, Vibe Stats)
  final List<Map<String, dynamic>> _navItems = const [
    {'label': 'Home', 'icon': FeatherIcons.home},
    {'label': 'Search', 'icon': FeatherIcons.search},
    {'label': 'Create', 'icon': FeatherIcons.plusSquare},
    {'label': 'Vibe Stats', 'icon': Icons.equalizer_rounded},
  ];

  // User playlists collection for the Create tab
  final List<Map<String, dynamic>> _userPlaylists = [];

  // Weekly stats play counts for Vibe Stats heatmap
  Map<String, int> _weeklyPlayStats = {
    'Mon': 0,
    'Tue': 0,
    'Wed': 0,
    'Thu': 0,
    'Fri': 0,
    'Sat': 0,
    'Sun': 0,
  };

  // Detailed day-period heatmap play counts
  Map<String, int> _heatmapPlayStats = {};

  String? _profileImagePath;

  Future<void> _loadProfileImage() async {
    try {
      if (kIsWeb) return; // File system not supported on web
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/profile_info.json');
      if (await file.exists()) {
        final decoded = json.decode(await file.readAsString());
        if (decoded is Map && decoded.containsKey('profileImagePath')) {
          setState(() {
            _profileImagePath = decoded['profileImagePath'];
          });
        }
      }
    } catch (e) {
      debugPrint("Error loading profile image path: $e");
    }
  }

  Widget _buildProfileAvatar({double radius = 15, double iconSize = 14}) {
    ImageProvider? provider;
    if (_profileImagePath != null && _profileImagePath!.isNotEmpty) {
      if (kIsWeb ||
          _profileImagePath!.startsWith('http') ||
          _profileImagePath!.startsWith('blob:')) {
        provider = NetworkImage(_profileImagePath!);
      } else {
        provider = FileImage(File(_profileImagePath!));
      }
    } else {
      // Check firebase photoUrl
      final User? currentUser = Firebase.apps.isNotEmpty
          ? FirebaseAuth.instance.currentUser
          : null;
      if (currentUser?.photoURL != null && currentUser!.photoURL!.isNotEmpty) {
        final String photoUrl = currentUser.photoURL!;
        if (photoUrl.startsWith('http') || photoUrl.startsWith('blob:')) {
          provider = NetworkImage(photoUrl);
        } else if (!kIsWeb) {
          provider = FileImage(File(photoUrl));
        }
      }
    }

    if (provider != null) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: provider,
        backgroundColor: const Color(0xFF1E1E24),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFF1E1E24),
      child: Icon(FeatherIcons.user, color: Colors.white, size: iconSize),
    );
  }

  late PageController _recentlyPlayedController;
  double _currentPage = 1.0;

  // Track genre play counts for dynamic Daily Mix generation
  final Map<String, int> _genrePlayCounts = {
    'Melody / Romance': 5,
    'Kuthu / Dance': 4,
    'Lofi / Chill': 3,
    'Classical / Instrumental': 2,
    'SAD': 1,
  };

  List<Map<String, dynamic>> get _topGenres {
    final sorted = List<Map<String, dynamic>>.from(_genreCards);
    sorted.sort((a, b) {
      final countA = _genrePlayCounts[a['genre']] ?? 0;
      final countB = _genrePlayCounts[b['genre']] ?? 0;
      return countB.compareTo(countA);
    });
    return sorted.take(4).toList();
  }

  final List<Map<String, dynamic>> _genreCards = const [
    {
      'genre': 'Melody / Romance',
      'label': 'MELODIES',
      'gradient': LinearGradient(
        colors: [Color(0xFFE899A8), Color(0xFFFFB099)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'glow': Color(0xFFE899A8),
      'image': 'assets/melody_cat.png',
    },
    {
      'genre': 'Kuthu / Dance',
      'label': 'KUTHU',
      'gradient': LinearGradient(
        colors: [Color(0xFFFF5E62), Color(0xFFFF926B)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'glow': Color(0xFFFF5E62),
      'image': 'assets/kuthu_cat.png',
    },
    {
      'genre': 'Lofi / Chill',
      'label': 'CHILL VIBES',
      'gradient': LinearGradient(
        colors: [Color(0xFF8CA6FC), Color(0xFFC7B1FC)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'glow': Color(0xFF8CA6FC),
      'image':
          'https://i.pinimg.com/736x/c5/67/67/c567677eaed5443a17065f50a55e7c38.jpg',
    },
    {
      'genre': 'Classical / Instrumental',
      'label': 'CLASSICAL SOUNDS',
      'gradient': LinearGradient(
        colors: [Color(0xFFD4AF37), Color(0xFFE4D5B7)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'glow': Color(0xFFD4AF37),
      'image': 'assets/classical_cat.png',
    },
    {
      'genre': 'SAD',
      'label': 'SAD SONGS',
      'gradient': LinearGradient(
        colors: [Color(0xFFD4AF37), Color(0xFFE4D5B7)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'glow': Color(0xFFD4AF37),
      'image':
          'https://i.pinimg.com/736x/31/3d/37/313d37415bcc86057d6042795c8be010.jpg',
    },
  ];

  String _getSongGenre(Map<String, dynamic> song) {
    final title = (song['title'] ?? '').toString().toLowerCase();
    final artist = (song['artist'] ?? '').toString().toLowerCase();
    final src = (song['src'] ?? '').toString().toLowerCase();

    if (title.contains('theme') ||
        title.contains('instrumental') ||
        title.contains('violin') ||
        title.contains('flute') ||
        title.contains('piano') ||
        title.contains('guitar') ||
        src.contains('instrumental')) {
      return 'Classical / Instrumental';
    }

    if (title.contains('lofi') ||
        title.contains('chill') ||
        title.contains('vibe') ||
        title.contains('slowed') ||
        title.contains('reverb') ||
        title.contains('night') ||
        title.contains('lo-fi') ||
        artist.contains('yuvan') ||
        src.contains('lofi') ||
        src.contains('chill')) {
      return 'Lofi / Chill';
    }

    if (artist.contains('deva') ||
        artist.contains('hip hop') ||
        artist.contains('aadhi') ||
        artist.contains('anirudh') ||
        title.contains('kuthu') ||
        title.contains('dance') ||
        title.contains('gaana') ||
        title.contains('beat') ||
        title.contains('rap') ||
        title.contains('danga') ||
        title.contains('marana') ||
        title.contains('local') ||
        title.contains('aluma') ||
        title.contains('donu') ||
        title.contains('sodakku') ||
        title.contains('pistah') ||
        title.contains('jalabulajangu') ||
        title.contains('pathala') ||
        title.contains('arabic')) {
      return 'Kuthu / Dance';
    }

    if (title.contains('pookkal') ||
        title.contains('love') ||
        title.contains('meghame') ||
        title.contains('kaatrile') ||
        title.contains('aaruyire') ||
        title.contains('penne') ||
        title.contains('romance') ||
        title.contains('melody') ||
        title.contains('konjum') ||
        title.contains('un perai') ||
        title.contains('vizhi') ||
        title.contains('kanave') ||
        title.contains('nee') ||
        title.contains('enodu') ||
        title.contains('thuli') ||
        title.contains('anbe') ||
        title.contains('kadhal') ||
        title.contains('malare') ||
        title.contains('kurumba') ||
        title.contains('poo') ||
        artist.contains('rahman') ||
        artist.contains('g v prakash') ||
        artist.contains('g.v. prakash') ||
        artist.contains('gv prakash')) {
      return 'Melody / Romance';
    }

    final id = song['id'] is int
        ? song['id'] as int
        : (song['id']?.toString().hashCode ?? 0);
    switch (id % 4) {
      case 0:
        return 'Melody / Romance';
      case 1:
        return 'Kuthu / Dance';
      case 2:
        return 'Lofi / Chill';
      default:
        return 'Classical / Instrumental';
    }
  }

  void _showGenreSongs(
    String genreName,
    String displayName,
    Gradient cardGradient,
  ) {
    final genreSongs = _allSongs.where((song) {
      return _getSongGenre(song) == genreName;
    }).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // Drag handle
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: cardGradient,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.music_note_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: GoogleFonts.outfit(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1E1E24),
                              ),
                            ),
                            Text(
                              '${genreSongs.length} Songs in Library',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                // Songs list
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: genreSongs.length,
                    itemBuilder: (context, index) {
                      final song = genreSongs[index];
                      return ListTile(
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E24),
                            borderRadius: BorderRadius.circular(6),
                            image: DecorationImage(
                              image: _getSongImageProvider(song),
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
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.play_arrow,
                          color: Color(0xFF1E1E24),
                        ),
                        onTap: () {
                          Navigator.pop(context); // close sheet
                          AudioService().playSong(
                            song,
                            playlistContext: genreSongs,
                          ); // play song
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
              ],
            );
          },
        );
      },
    );
  }

  List<Map<String, dynamic>> _recentlyPlayed = [];
  List<Map<String, dynamic>> _allSongs = [];
  List<Map<String, dynamic>> _magicPlaylist = [];
  bool _isLoadingSongs = true;

  final List<Map<String, String>> _artists = const [
    {'name': 'A.R. Rahman', 'image': 'assets/ar_rahman.png'},
    {'name': 'Anirudh', 'image': 'assets/anirudh.jpg'},
    {'name': 'Yuvan Sankar Raja', 'image': 'assets/yuvan.jpg'},
    {
      'name': 'Deva',
      'image':
          'https://i.pinimg.com/1200x/ed/ae/19/edae1927b2094577b713a011432c2856.jpg',
    },
    {'name': 'Hip Hop Aadhi', 'image': 'assets/hiphop_tamizha.png'},
    {'name': 'GV Prakash Kumar', 'image': 'assets/gv_prakash.jpg'},
    {'name': 'Sai Abhyankkar', 'image': 'assets/sai_abhyankkar.png'},
    {'name': 'Srikanth Deva', 'image': 'assets/srikanth_deva.png'},
    {'name': 'Vijay Antony', 'image': 'assets/vijay_antony.png'},
    {'name': 'Harris Jayaraj', 'image': 'assets/harris_jayaraj.png'},
  ];

  String _getArtistPicture(String artistName, String fallbackImageUrl) {
    final String cleanArtist = artistName
        .toLowerCase()
        .replaceAll(' ', '')
        .replaceAll('.', '');

    final Map<String, String> artistImages = {
      'arrahman': 'assets/ar_rahman.png',
      'anirudh': 'assets/anirudh.jpg',
      'yuvansankar': 'assets/yuvan.jpg',
      'yuvanshankar': 'assets/yuvan.jpg',
      'deva':
          'https://i.pinimg.com/1200x/ed/ae/19/edae1927b2094577b713a011432c2856.jpg',
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
    return 'assets/logo.png';
  }

  ImageProvider _getSongImageProvider(Map<String, dynamic> song) {
    final String? img = song['img'];
    final String artist = song['artist'] ?? '';
    final String imagePath = (img != null && img.isNotEmpty)
        ? img
        : _getArtistPicture(artist, '');

    if (imagePath.startsWith('assets/')) {
      return AssetImage(imagePath);
    }
    return CachedNetworkImageProvider(imagePath);
  }

  ImageProvider _getImageProvider(String path) {
    if (path.startsWith('assets/')) {
      return AssetImage(path);
    }
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return CachedNetworkImageProvider(path);
    }
    return FileImage(File(path));
  }

  void _showMagicOutcomeDialog({
    required String title,
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          message,
          style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onAction();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE5B3B3),
              foregroundColor: const Color(0xFF1E1E24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(
              actionLabel,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showMagicSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Color(0xFFE5B3B3), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E1E24),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _triggerShuffleMagic() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 40),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E1E24), Color(0xFF2C2C35)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 50,
                  height: 50,
                  child: CircularProgressIndicator(
                    strokeWidth: 3.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFFE5B3B3),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Casting Shuffle Magic... 🪄',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Reading your musical stars...',
                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        );
      },
    );

    Future.delayed(const Duration(milliseconds: 1600), () {
      if (!mounted) return;
      Navigator.pop(context); // close loading dialog

      final int fateIndex = DateTime.now().microsecondsSinceEpoch % 4;

      if (fateIndex == 0 && _allSongs.isNotEmpty) {
        // Outcome 1: Play random hot song
        final shuffled = List<Map<String, dynamic>>.from(_allSongs)..shuffle();
        final song = shuffled.first;
        AudioService().playSong(song, playlistContext: _allSongs);

        _showMagicOutcomeDialog(
          title: "Instant Magic Play! 📻",
          message:
              "Fate selected the hit track:\n\"${song['title']}\" by ${song['artist']}",
          actionLabel: "OPEN PLAYER",
          onAction: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const PlayerScreen()),
            );
          },
        );
      } else if (fateIndex == 1) {
        // Outcome 2: Open curated playlist
        final bool pickArtist = DateTime.now().microsecondsSinceEpoch % 2 == 0;
        if (pickArtist && _artists.isNotEmpty) {
          final shuffledArtists = List<Map<String, String>>.from(_artists)
            ..shuffle();
          final randomArtist = shuffledArtists.first;
          _showArtistSongs(randomArtist['name']!, randomArtist['image']!);
          _showMagicSnackbar(
            "✨ Magic selected: Curated playlist for ${randomArtist['name']}!",
          );
        } else {
          final shuffledGenres = List<Map<String, dynamic>>.from(_genreCards)
            ..shuffle();
          final randomGenre = shuffledGenres.first;
          _showGenreSongs(
            randomGenre['genre']!,
            randomGenre['label']!,
            randomGenre['gradient'] as Gradient,
          );
          _showMagicSnackbar(
            "✨ Magic selected: Explore ${randomGenre['label']} Hits!",
          );
        }
      } else if (fateIndex == 2 && _artists.isNotEmpty) {
        // Outcome 3: Start Artist Radio
        final shuffledArtists = List<Map<String, String>>.from(_artists)
          ..shuffle();
        final artist = shuffledArtists.first;
        final String artistName = artist['name']!;

        final artistSongs = _allSongs.where((song) {
          final songArtist = (song['artist']?.toString() ?? '')
              .toLowerCase()
              .replaceAll(' ', '')
              .replaceAll('.', '');
          final queryArtist = artistName
              .toLowerCase()
              .replaceAll(' ', '')
              .replaceAll('.', '');
          return songArtist.contains(queryArtist) ||
              queryArtist.contains(songArtist);
        }).toList();

        if (artistSongs.isNotEmpty) {
          final shuffledSongs = List<Map<String, dynamic>>.from(artistSongs)
            ..shuffle();
          final song = shuffledSongs.first;
          AudioService().playSong(song, playlistContext: shuffledSongs);

          _showMagicOutcomeDialog(
            title: "Artist Radio Activated! 📻",
            message:
                "Fate started the magic Radio Mix for $artistName.\nPlaying \"${song['title']}\"!",
            actionLabel: "OPEN PLAYER",
            onAction: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const PlayerScreen()),
              );
            },
          );
        } else {
          final shuffled = List<Map<String, dynamic>>.from(_allSongs)
            ..shuffle();
          final song = shuffled.first;
          AudioService().playSong(song);
          _showMagicSnackbar("✨ Magic Play: ${song['title']}");
        }
      } else {
        // Outcome 4: Switch to Vibe Stats tab
        setState(() {
          _currentIndex = 3; // Switch to Vibe Stats tab
        });
        _showMagicSnackbar("🔮 Magic routed you to your Vibe Stats!");
      }
    });
  }

  void _magicTogglePlay() {
    final currentSong = AudioService().currentSongNotifier.value;
    if (currentSong != null) {
      AudioService().togglePlay();
    } else if (_magicPlaylist.isNotEmpty) {
      AudioService().playSong(
        _magicPlaylist.first,
        playlistContext: _magicPlaylist,
      );
    }
  }

  void _magicNextSong() {
    final currentSong = AudioService().currentSongNotifier.value;
    if (currentSong == null) {
      if (_magicPlaylist.isNotEmpty) {
        AudioService().playSong(
          _magicPlaylist.first,
          playlistContext: _magicPlaylist,
        );
      }
      return;
    }

    final idx = _magicPlaylist.indexWhere(
      (s) => s['id'] == currentSong['id'] || s['title'] == currentSong['title'],
    );
    if (idx != -1) {
      final nextIdx = (idx + 1) % _magicPlaylist.length;
      AudioService().playSong(
        _magicPlaylist[nextIdx],
        playlistContext: _magicPlaylist,
      );
    } else {
      AudioService().nextSong();
    }
  }

  void _magicPreviousSong() {
    final currentSong = AudioService().currentSongNotifier.value;
    if (currentSong == null) {
      if (_magicPlaylist.isNotEmpty) {
        AudioService().playSong(
          _magicPlaylist.first,
          playlistContext: _magicPlaylist,
        );
      }
      return;
    }

    final idx = _magicPlaylist.indexWhere(
      (s) => s['id'] == currentSong['id'] || s['title'] == currentSong['title'],
    );
    if (idx != -1) {
      final prevIdx = (idx - 1 + _magicPlaylist.length) % _magicPlaylist.length;
      AudioService().playSong(
        _magicPlaylist[prevIdx],
        playlistContext: _magicPlaylist,
      );
    } else {
      AudioService().previousSong();
    }
  }

  void _showAllShuffledSongsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return ValueListenableBuilder<Map<String, dynamic>?>(
              valueListenable: AudioService().currentSongNotifier,
              builder: (context, currentSong, child) {
                return Column(
                  children: [
                    // Drag handle
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF2994A),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.auto_awesome,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Magic Shuffle Mix',
                                  style: GoogleFonts.outfit(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF1E1E24),
                                  ),
                                ),
                                Text(
                                  '${_magicPlaylist.length} Songs Shuffled',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(),
                    // Songs list
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: _magicPlaylist.length,
                        itemBuilder: (context, index) {
                          final song = _magicPlaylist[index];
                          final bool isCurrent =
                              currentSong != null &&
                              (currentSong['id'] == song['id'] ||
                                  currentSong['title'] == song['title']);
                          return ListTile(
                            leading: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E1E24),
                                borderRadius: BorderRadius.circular(6),
                                image: DecorationImage(
                                  image: _getSongImageProvider(song),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            title: Text(
                              song['title']!,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isCurrent
                                    ? const Color(0xFFF2994A)
                                    : const Color(0xFF1E1E24),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              song['artist']!,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: isCurrent
                                    ? const Color(
                                        0xFFF2994A,
                                      ).withValues(alpha: 0.8)
                                    : Colors.black54,
                              ),
                            ),
                            trailing: isCurrent
                                ? const Icon(
                                    Icons.volume_up_rounded,
                                    color: Color(0xFFF2994A),
                                  )
                                : const Icon(
                                    Icons.play_arrow,
                                    color: Color(0xFF1E1E24),
                                  ),
                            onTap: () {
                              Navigator.pop(context); // close sheet
                              AudioService().playSong(
                                song,
                                playlistContext: _magicPlaylist,
                              ); // play song
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
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _loadSongs() async {
    final assetBundle = DefaultAssetBundle.of(context);
    try {
      final String jsonString = await assetBundle.loadString(
        'assets/tamil_songs.json',
      );
      final List<dynamic> jsonList = json.decode(jsonString);
      setState(() {
        _allSongs = jsonList
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        final shuffled = List<Map<String, dynamic>>.from(_allSongs)..shuffle();
        _recentlyPlayed = shuffled.take(15).toList();
        _magicPlaylist = List<Map<String, dynamic>>.from(_allSongs)..shuffle();
        _isLoadingSongs = false;
      });
    } catch (e) {
      debugPrint("Error loading songs from assets: $e");
      setState(() {
        _isLoadingSongs = false;
      });
    }
  }

  Future<File> _getPlaylistsFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/playlists.json');
  }

  Future<void> _savePlaylists() async {
    try {
      final file = await _getPlaylistsFile();
      final String jsonStr = json.encode(_userPlaylists);
      await file.writeAsString(jsonStr);
    } catch (e) {
      debugPrint("Error saving playlists: $e");
    }
  }

  Future<void> _loadPlaylists() async {
    try {
      final file = await _getPlaylistsFile();
      if (await file.exists()) {
        final String jsonStr = await file.readAsString();
        final List<dynamic> decoded = json.decode(jsonStr);
        setState(() {
          _userPlaylists.clear();
          _userPlaylists.addAll(
            decoded.map((item) => Map<String, dynamic>.from(item)).toList(),
          );
        });
      }
    } catch (e) {
      debugPrint("Error loading saved playlists: $e");
    }
  }

  Future<File> _getStatsFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/listening_stats.json');
  }

  Future<void> _saveWeeklyStats() async {
    try {
      final file = await _getStatsFile();
      final Map<String, dynamic> dataToSave = {
        'weekly': _weeklyPlayStats,
        'heatmap': _heatmapPlayStats,
      };
      await file.writeAsString(json.encode(dataToSave));
    } catch (e) {
      debugPrint("Error saving listening stats: $e");
    }
  }

  Future<void> _loadWeeklyStats() async {
    try {
      final file = await _getStatsFile();
      if (await file.exists()) {
        final decoded = json.decode(await file.readAsString());
        if (decoded is Map) {
          setState(() {
            if (decoded.containsKey('weekly')) {
              _weeklyPlayStats = (decoded['weekly'] as Map).map(
                (key, value) =>
                    MapEntry(key.toString(), int.parse(value.toString())),
              );
            } else {
              // Legacy format fallback
              _weeklyPlayStats = decoded.map(
                (key, value) =>
                    MapEntry(key.toString(), int.parse(value.toString())),
              );
            }
            if (decoded.containsKey('heatmap')) {
              _heatmapPlayStats = (decoded['heatmap'] as Map).map(
                (key, value) =>
                    MapEntry(key.toString(), int.parse(value.toString())),
              );
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Error loading listening stats: $e");
    }
  }

  void _incrementTodayPlayCount() {
    final DateTime now = DateTime.now();
    final List<String> days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final String today = days[now.weekday - 1];

    // Determine time block
    final int hour = now.hour;
    String timeBlock = 'Night';
    if (hour >= 6 && hour < 12) {
      timeBlock = 'Morning';
    } else if (hour >= 12 && hour < 18) {
      timeBlock = 'Afternoon';
    } else if (hour >= 18 && hour < 24) {
      timeBlock = 'Evening';
    }

    setState(() {
      _weeklyPlayStats[today] = (_weeklyPlayStats[today] ?? 0) + 1;
      final String key = '$today-$timeBlock';
      _heatmapPlayStats[key] = (_heatmapPlayStats[key] ?? 0) + 1;
    });
    _saveWeeklyStats();
  }

  @override
  void initState() {
    super.initState();
    debugPrint('HomeScreen: initState called');
    _requestPermissions();
    _loadSongs();
    _loadPlaylists();
    _loadWeeklyStats();
    _loadProfileImage();
    AudioService().currentSongNotifier.addListener(_onCurrentSongChanged);
    _recentlyPlayedController = PageController(
      initialPage: 1,
      viewportFraction: 0.55,
    );
    _recentlyPlayedController.addListener(() {
      setState(() {
        _currentPage = _recentlyPlayedController.page ?? 1.0;
      });
    });
  }

  Future<void> _requestPermissions() async {
    try {
      if (await Permission.notification.isDenied) {
        await Permission.notification.request();
      }
    } catch (e) {
      debugPrint("Error requesting notification permission: $e");
    }
  }

  void _onCurrentSongChanged() {
    final song = AudioService().currentSongNotifier.value;
    if (song != null) {
      final genre = _getSongGenre(song);
      _genrePlayCounts[genre] = (_genrePlayCounts[genre] ?? 0) + 1;
      _incrementTodayPlayCount();
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    AudioService().currentSongNotifier.removeListener(_onCurrentSongChanged);
    _recentlyPlayedController.dispose();
    super.dispose();
  }

  void _showArtistSongs(String artistName, String artistImage) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ArtistDetailsScreen(
          artistName: artistName,
          artistImage: artistImage,
          allSongs: _allSongs,
        ),
      ),
    );
  }

  void _playGenreMix(String genreName, String displayName) {
    final genreSongs = _allSongs.where((song) {
      return _getSongGenre(song) == genreName;
    }).toList();
    if (genreSongs.isNotEmpty) {
      final shuffled = List<Map<String, dynamic>>.from(genreSongs)..shuffle();
      AudioService().playSong(shuffled.first, playlistContext: shuffled);
      _showMagicSnackbar("✨ Playing: $displayName Mix!");
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (context) => const PlayerScreen()));
    } else {
      _showMagicSnackbar("No songs available in $displayName right now.");
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 17) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }

  @override
  Widget build(BuildContext context) {
    // If we’re still loading the JSON (or it failed), show a simple spinner.
    if (_isLoadingSongs) {
      return Scaffold(
        backgroundColor: const Color(0xFFF4F5F7),
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E1E24)),
          ),
        ),
      );
    }

    // If the song list is empty after loading, give a friendly hint.
    if (_allSongs.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFF4F5F7),
        body: Center(
          child: Text(
            'No songs found. Check that assets/tamil_songs.json is present and listed in pubspec.yaml.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 14, color: Colors.black54),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      body: Stack(
        children: [
          // Main scrollable contents using IndexedStack to preserve state
          Positioned.fill(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                _buildHomeDashboard(),
                _buildSearchTab(),
                _buildCreateTab(),
                _buildVibeStatsTab(),
              ],
            ),
          ),

          // 1. Bottom Navigation Bar
          Align(
            alignment: Alignment.bottomCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SafeArea(
                  top: false,
                  child: Container(
                    margin: const EdgeInsets.only(
                      left: 18.0,
                      right: 18.0,
                      bottom: 12.0,
                      top: 4.0,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(36),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(_navItems.length, (index) {
                        final isSelected = _currentIndex == index;
                        final item = _navItems[index];
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _currentIndex = index;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                            padding: EdgeInsets.symmetric(
                              horizontal: isSelected ? 16.0 : 12.0,
                              vertical: 10.0,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF1E1E24)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  item['icon'] as IconData,
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF1E1E24),
                                  size: 22,
                                ),
                                if (isSelected) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    item['label'] as String,
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Floating Mini Music Player (Draggable/Bubble mode)
          FloatingMiniPlayer(getSongImageProvider: _getSongImageProvider),
        ],
      ),
    );
  }

  // Home Dashboard Tab Content
  Widget _buildHomeDashboard() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(
        top: 56.0,
        left: 16.0,
        right: 16.0,
        bottom: 150.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _getGreeting(),
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E1E24),
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      FeatherIcons.bell,
                      color: Color(0xFF1E1E24),
                      size: 20,
                    ),
                    onPressed: () {},
                  ),

                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context)
                          .push(
                            MaterialPageRoute(
                              builder: (context) => ProfileScreen(
                                playlistsCount: _userPlaylists.length,
                                favoritesCount: AudioService()
                                    .likedSongsNotifier
                                    .value
                                    .length,
                                weeklyPlayStats: _weeklyPlayStats,
                              ),
                            ),
                          )
                          .then((_) => _loadProfileImage());
                    },
                    child: _buildProfileAvatar(radius: 15, iconSize: 14),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Hello Melophile Greeting Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E1E24), Color(0xFF2C2C35)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hello Melophile',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Ready to explore some amazing tunes today?',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.music_note_rounded,
                    color: Color(0xFFE5B3B3),
                    size: 24,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 1. Artists Section is now at the top
          Text(
            'Artists you love',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E1E24),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 98,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _artists.length,
              itemBuilder: (context, index) {
                final artist = _artists[index];
                return GestureDetector(
                  onTap: () {
                    _showArtistSongs(artist['name']!, artist['image']!);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 18.0),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 35,
                          backgroundImage: _getImageProvider(artist['image']!),
                          backgroundColor: Colors.grey.shade200,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          artist['name']!,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1E1E24),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // 2. Recently Played is under the Artists Section
          Text(
            'Recently Played',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E1E24),
            ),
          ),
          const SizedBox(height: 16),
          _isLoadingSongs
              ? const SizedBox(
                  height: 260,
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF1E1E24)),
                  ),
                )
              : SizedBox(
                  height: 230,
                  child: PageView.builder(
                    controller: _recentlyPlayedController,
                    itemCount: _recentlyPlayed.length,
                    clipBehavior: Clip.none,
                    physics: const BouncingScrollPhysics(),
                    itemBuilder: (context, index) {
                      final album = _recentlyPlayed[index];

                      final double difference = index - _currentPage;
                      final double scale = (1.0 - (difference.abs() * 0.18))
                          .clamp(0.8, 1.0);
                      final double rotation = (difference * -0.32).clamp(
                        -0.45,
                        0.45,
                      );
                      final double translationX = difference * -24.0;

                      return GestureDetector(
                        onTap: () {
                          AudioService().playSong(
                            album,
                            playlistContext: _recentlyPlayed,
                          );
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const PlayerScreen(),
                            ),
                          );
                        },
                        child: Transform(
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.001)
                            ..multiply(
                              Matrix4.translationValues(translationX, 0.0, 0.0),
                            )
                            ..rotateY(rotation)
                            ..multiply(
                              Matrix4.diagonal3Values(scale, scale, 1.0),
                            ),
                          alignment: Alignment.center,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AspectRatio(
                                  aspectRatio: 1.0,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E1E24),
                                      borderRadius: BorderRadius.circular(12),
                                      image: DecorationImage(
                                        image: _getSongImageProvider(album),
                                        fit: BoxFit.cover,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.12,
                                          ),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Positioned(
                                          bottom: 8,
                                          right: 8,
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.black54,
                                            ),
                                            child: const Icon(
                                              Icons.play_arrow,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  album['title']!,
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF1E1E24),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  album['artist']!,
                                  style: GoogleFonts.inter(
                                    color: Colors.black54,
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

          const SizedBox(height: 12),

          // 3. Explore Genres section
          Text(
            'Explore Genres',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E1E24),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _genreCards.length,
              itemBuilder: (context, index) {
                final card = _genreCards[index];
                return GestureDetector(
                  onTap: () {
                    _showGenreSongs(
                      card['genre']!,
                      card['label']!,
                      card['gradient'] as Gradient,
                    );
                  },
                  child: Container(
                    width: 150,
                    margin: const EdgeInsets.only(right: 14.0),
                    decoration: BoxDecoration(
                      gradient: card['image'] == null
                          ? card['gradient'] as Gradient
                          : null,
                      image: card['image'] != null
                          ? DecorationImage(
                              image: _getImageProvider(card['image'] as String),
                              fit: BoxFit.cover,
                            )
                          : null,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: (card['glow'] as Color).withValues(
                            alpha: 0.15,
                          ),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        children: [
                          // Dark-glass overlay
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.3),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12),
                                width: 1.0,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          // Text label aligned to the top-left
                          Padding(
                            padding: const EdgeInsets.all(14.0),
                            child: Align(
                              alignment: Alignment.topLeft,
                              child: Text(
                                card['label']!,
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  letterSpacing: 0.5,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.3,
                                      ),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // Magic Shuffle section heading
          Text(
            'Magic Shuffle',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E1E24),
            ),
          ),
          const SizedBox(height: 16),

          // New Orange Shuffle Magic Widget (Matches user screenshot)
          ValueListenableBuilder<Map<String, dynamic>?>(
            valueListenable: AudioService().currentSongNotifier,
            builder: (context, currentSong, child) {
              return ValueListenableBuilder<bool>(
                valueListenable: AudioService().isPlayingNotifier,
                builder: (context, isPlaying, child) {
                  // Determine if the current playing song is in our magic mix to display it,
                  // otherwise show the first song in our magic mix as a placeholder.
                  final Map<String, dynamic> songToShow =
                      (currentSong != null &&
                          _magicPlaylist.any(
                            (s) =>
                                s['id'] == currentSong['id'] ||
                                s['title'] == currentSong['title'],
                          ))
                      ? currentSong
                      : (_magicPlaylist.isNotEmpty
                            ? _magicPlaylist.first
                            : {
                                'title': 'Shuffle Magic Mix',
                                'artist': 'Play to start magic',
                                'img': 'assets/logo.png',
                              });

                  final bool isActuallyPlaying =
                      isPlaying &&
                      currentSong != null &&
                      (currentSong['id'] == songToShow['id'] ||
                          currentSong['title'] == songToShow['title']);

                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(
                        0xFFF2994A,
                      ), // Vibrant orange color matching the mockup
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFFF2994A,
                          ).withValues(alpha: 0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Upper row: Album Art, Info, and Logo
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Rounded album art (tap to trigger a surprise Magic spell!)
                            GestureDetector(
                              onTap: _triggerShuffleMagic,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: SizedBox(
                                  width: 72,
                                  height: 72,
                                  child: Container(
                                    color: Colors.white12,
                                    child: Image(
                                      image: _getSongImageProvider(songToShow),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Title & artist info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    songToShow['title'] ?? 'Shuffle Magic Mix',
                                    style: GoogleFonts.outfit(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    songToShow['artist'] ??
                                        'Click play to start magic',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: Colors.white.withValues(
                                        alpha: 0.9,
                                      ),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Spotify-like Logo icon
                            Container(
                              width: 32,
                              height: 32,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons
                                      .wifi_tethering_rounded, // Resembles the soundwaves/logo
                                  color: Color(0xFFF2994A),
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Lower row: Previous, Play/Pause, Next, and More options
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Previous song button
                            IconButton(
                              icon: const Icon(
                                Icons.skip_previous_rounded,
                                color: Colors.white,
                              ),
                              iconSize: 32,
                              onPressed: () {
                                _magicPreviousSong();
                              },
                            ),
                            const SizedBox(width: 12),
                            // White circle Play/Pause button
                            GestureDetector(
                              onTap: () {
                                _magicTogglePlay();
                              },
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                ),
                                child: Center(
                                  child: Icon(
                                    isActuallyPlaying
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    color: const Color(0xFFF2994A),
                                    size: 28,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Next song button
                            IconButton(
                              icon: const Icon(
                                Icons.skip_next_rounded,
                                color: Colors.white,
                              ),
                              iconSize: 32,
                              onPressed: () {
                                _magicNextSong();
                              },
                            ),
                            const Spacer(),
                            // More option button (shows bottom sheet of all songs)
                            TextButton.icon(
                              onPressed: () {
                                _showAllShuffledSongsSheet();
                              },
                              icon: const Icon(
                                Icons.playlist_play_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                              label: Text(
                                'More',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.15,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),

          const SizedBox(height: 28),

          // Daily Mix section heading
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daily Mix',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E1E24),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Based on your recent vibes',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
              const Icon(
                Icons.bolt_rounded,
                color: Color(0xFFF2994A),
                size: 24,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Dynamic Daily Mix cards
          SizedBox(
            height: 190,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _topGenres.length,
              itemBuilder: (context, index) {
                final card = _topGenres[index];
                final String genreName = card['genre']!;
                final String displayName = card['label']!;
                final String imagePath = card['image']!;

                // Get artist names list in this genre to put as a description snippet
                final genreSongs = _allSongs
                    .where((song) => _getSongGenre(song) == genreName)
                    .toList();
                final Set<String> artists = genreSongs
                    .map((s) => (s['artist'] ?? '').toString())
                    .toSet();
                final String artistsDesc = artists.isNotEmpty
                    ? 'Including ${artists.take(3).join(", ")}'
                    : 'A unique mix curated for you';

                return Container(
                  width: 145,
                  margin: const EdgeInsets.only(right: 16),
                  child: GestureDetector(
                    onTap: () => _playGenreMix(genreName, displayName),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Stack for card art, gradient, and play button overlay
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: (card['glow'] as Color).withValues(
                                    alpha: 0.15,
                                  ),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Stack(
                                children: [
                                  // Background image
                                  Positioned.fill(
                                    child: Image(
                                      image: _getImageProvider(imagePath),
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              Container(
                                                color: const Color(0xFF1E1E24),
                                                child: const Icon(
                                                  Icons.music_note,
                                                  color: Colors.white24,
                                                  size: 40,
                                                ),
                                              ),
                                    ),
                                  ),
                                  // Gradient tint overlay
                                  Positioned.fill(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.black.withValues(alpha: 0.1),
                                            Colors.black.withValues(alpha: 0.7),
                                          ],
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Album/Mix Label
                                  Positioned(
                                    bottom: 12,
                                    left: 12,
                                    right: 12,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          displayName,
                                          style: GoogleFonts.outfit(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                            letterSpacing: 0.5,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Daily Mix ${index + 1}',
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white60,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Tiny glass play button on top right
                                  Positioned(
                                    top: 10,
                                    right: 10,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white.withValues(
                                          alpha: 0.25,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.play_arrow_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Subtitles
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Text(
                            artistsDesc,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.black54,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Spotify-like Search Tab View
  Widget _buildSearchTab() {
    final query = _searchQuery.toLowerCase();
    final List<Map<String, dynamic>> results;
    if (query.isEmpty) {
      results = [];
    } else {
      final matchedMovies = _allSongs
          .where(
            (song) =>
                (song['movie'] ?? '').toString().toLowerCase().contains(query),
          )
          .map((song) => (song['movie'] ?? '').toString())
          .toSet();

      final moviesOfMatchedSongs = _allSongs
          .where((song) {
            final title = (song['title'] ?? '').toString().toLowerCase();
            final artist = (song['artist'] ?? '').toString().toLowerCase();
            return title.contains(query) || artist.contains(query);
          })
          .map((song) => (song['movie'] ?? '').toString())
          .where((m) => m.isNotEmpty)
          .toSet();

      final allTargetMovies = {...matchedMovies, ...moviesOfMatchedSongs};

      results = _allSongs
          .where(
            (song) =>
                allTargetMovies.contains((song['movie'] ?? '').toString()),
          )
          .toList();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 56.0, left: 16.0, right: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Search',
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E1E24),
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.of(context)
                      .push(
                        MaterialPageRoute(
                          builder: (context) => ProfileScreen(
                            playlistsCount: _userPlaylists.length,
                            favoritesCount:
                                AudioService().likedSongsNotifier.value.length,
                            weeklyPlayStats: _weeklyPlayStats,
                          ),
                        ),
                      )
                      .then((_) => _loadProfileImage());
                },
                child: _buildProfileAvatar(radius: 15, iconSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            style: GoogleFonts.inter(color: const Color(0xFF1E1E24)),
            onChanged: (val) {
              setState(() {
                _searchQuery = val.trim();
              });
            },
            decoration: InputDecoration(
              hintText: 'What do you want to listen to?',
              hintStyle: GoogleFonts.inter(color: Colors.black38, fontSize: 14),
              prefixIcon: const Icon(
                FeatherIcons.search,
                color: Colors.black45,
                size: 20,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 16.0),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.black12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF1E1E24),
                  width: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _searchQuery.isNotEmpty
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Search Results',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E1E24),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: results.isEmpty
                            ? Center(
                                child: Text(
                                  'No matching songs found',
                                  style: GoogleFonts.inter(
                                    color: Colors.black54,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.only(bottom: 150.0),
                                itemCount: results.length,
                                itemBuilder: (context, index) {
                                  final song = results[index];
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.03,
                                          ),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: ListTile(
                                      leading: Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          image: DecorationImage(
                                            image: _getSongImageProvider(song),
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                      title: Text(
                                        song['title'] ?? '',
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF1E1E24),
                                        ),
                                      ),
                                      subtitle: Text(
                                        '${song['artist'] ?? ''}${song['movie'] != null && song['movie'].toString().isNotEmpty ? ' • ${song['movie']}' : ''}',
                                        style: GoogleFonts.inter(
                                          color: Colors.black54,
                                          fontSize: 12,
                                        ),
                                      ),
                                      trailing: const Icon(
                                        Icons.play_arrow_rounded,
                                        color: Color(0xFF1E1E24),
                                      ),
                                      onTap: () {
                                        AudioService().playSong(
                                          song,
                                          playlistContext: results,
                                        );
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const PlayerScreen(),
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          FeatherIcons.search,
                          size: 48,
                          color: Colors.black26,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Search for songs or artists',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // Playlist Manager / Create Tab View
  Widget _buildCreateTab() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(
        top: 56.0,
        left: 16.0,
        right: 16.0,
        bottom: 150.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Playlists',
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E1E24),
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.of(context)
                      .push(
                        MaterialPageRoute(
                          builder: (context) => ProfileScreen(
                            playlistsCount: _userPlaylists.length,
                            favoritesCount:
                                AudioService().likedSongsNotifier.value.length,
                            weeklyPlayStats: _weeklyPlayStats,
                          ),
                        ),
                      )
                      .then((_) => _loadProfileImage());
                },
                child: _buildProfileAvatar(radius: 15, iconSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _showCreatePlaylistDialog,
              icon: const Icon(
                FeatherIcons.plus,
                color: Colors.white,
                size: 18,
              ),
              label: Text(
                'CREATE NEW PLAYLIST',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: Colors.white,
                  fontSize: 13,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E1E24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Your Collection',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E1E24),
            ),
          ),
          const SizedBox(height: 16),
          ValueListenableBuilder<List<Map<String, dynamic>>>(
            valueListenable: AudioService().likedSongsNotifier,
            builder: (context, likedSongs, child) {
              final int totalItems = 1 + _userPlaylists.length;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.8,
                ),
                itemCount: totalItems,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    // Liked Songs card
                    return GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => PlaylistDetailScreen(
                              playlist: {
                                'name': 'Liked Songs',
                                'description': '',
                                'image': '',
                                'isLikedSongs': true,
                              },
                              allSongs: _allSongs,
                              onPlaylistUpdated: (_) {},
                            ),
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Container(
                                width: double.infinity,
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(0xFFE5B3B3),
                                      Color(0xFFF7D1D1),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(12),
                                  ),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.favorite_rounded,
                                    color: Colors.white,
                                    size: 40,
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(10.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Liked Songs',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF1E1E24),
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${likedSongs.length} ${likedSongs.length == 1 ? "song" : "songs"}',
                                    style: GoogleFonts.inter(
                                      color: Colors.black54,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  } else {
                    // Created Playlist card
                    final playlistIndex = index - 1;
                    final playlist = _userPlaylists[playlistIndex];
                    final String coverUrl =
                        playlist['image'] ?? 'assets/logo.png';
                    final String pName = playlist['name'] ?? 'My Playlist';
                    final int songCount =
                        (playlist['songs'] as List?)?.length ?? 0;

                    return GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => PlaylistDetailScreen(
                              playlist: playlist,
                              allSongs: _allSongs,
                              onPlaylistUpdated: (updatedPlaylist) {
                                setState(() {
                                  _userPlaylists[playlistIndex] =
                                      updatedPlaylist;
                                });
                                _savePlaylists();
                              },
                            ),
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(12),
                                      ),
                                      child: Image(
                                        image: _getImageProvider(coverUrl),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 6,
                                    right: 6,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _userPlaylists.removeAt(
                                            playlistIndex,
                                          );
                                        });
                                        _savePlaylists();
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(5),
                                        decoration: const BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          FeatherIcons.trash2,
                                          color: Colors.white,
                                          size: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(10.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    pName,
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF1E1E24),
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '$songCount ${songCount == 1 ? "song" : "songs"}',
                                    style: GoogleFonts.inter(
                                      color: Colors.black54,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                },
              );
            },
          ),
        ],
      ),
    );
  }

  void _showCreatePlaylistDialog() async {
    final count = _userPlaylists.length + 1;
    final remainder10 = count % 10;
    final remainder100 = count % 100;
    String suffix = 'th';
    if (remainder10 == 1 && remainder100 != 11) {
      suffix = 'st';
    } else if (remainder10 == 2 && remainder100 != 12) {
      suffix = 'nd';
    } else if (remainder10 == 3 && remainder100 != 13) {
      suffix = 'rd';
    }
    final proposedName = '$count$suffix Playlist';

    final Map<String, dynamic>? playlistData = await Navigator.of(context)
        .push<Map<String, dynamic>>(
          MaterialPageRoute(
            builder: (context) =>
                CreatePlaylistScreen(proposedName: proposedName),
          ),
        );

    if (playlistData != null) {
      final String name = playlistData['name'] ?? proposedName;
      final String desc = playlistData['description'] ?? '';
      final String img = playlistData['image'] ?? '';

      final newPlaylist = {
        'name': name,
        'image': img.isNotEmpty
            ? img
            : 'https://i.pinimg.com/736x/a2/e1/9b/a2e19b8849b293d05267b209d00b05b4.jpg',
        'description': desc,
        'songs': <Map<String, dynamic>>[],
      };

      setState(() {
        _userPlaylists.add(newPlaylist);
      });
      _savePlaylists();

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PlaylistDetailScreen(
              playlist: newPlaylist,
              allSongs: _allSongs,
              onPlaylistUpdated: (updatedPlaylist) {
                setState(() {
                  final idx = _userPlaylists.indexOf(newPlaylist);
                  if (idx != -1) {
                    _userPlaylists[idx] = updatedPlaylist;
                  }
                });
                _savePlaylists();
              },
            ),
          ),
        );
      }
    }
  }

  Widget _buildVibeStatsTab() {
    int maxCount = 1;
    int totalPlays = 0;
    String peakDay = 'None';
    int peakCount = 0;

    _weeklyPlayStats.forEach((day, count) {
      totalPlays += count;
      if (count > peakCount) {
        peakCount = count;
        peakDay = day;
      }
      if (count > maxCount) {
        maxCount = count;
      }
    });

    final Map<String, String> fullDayNames = {
      'Mon': 'Monday',
      'Tue': 'Tuesday',
      'Wed': 'Wednesday',
      'Thu': 'Thursday',
      'Fri': 'Friday',
      'Sat': 'Saturday',
      'Sun': 'Sunday',
    };

    // Calculate dynamic listener tier
    String listenerTier = 'Starter';
    IconData tierIcon = Icons.bubble_chart_rounded;
    if (totalPlays >= 50) {
      listenerTier = 'Vibe Master';
      tierIcon = Icons.military_tech_rounded;
    } else if (totalPlays >= 20) {
      listenerTier = 'Music Lover';
      tierIcon = Icons.favorite_rounded;
    } else if (totalPlays >= 5) {
      listenerTier = 'Explorer';
      tierIcon = Icons.explore_rounded;
    }

    final List<String> days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(
        top: 56.0,
        left: 16.0,
        right: 16.0,
        bottom: 150.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Vibe Stats',
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E1E24),
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.of(context)
                      .push(
                        MaterialPageRoute(
                          builder: (context) => ProfileScreen(
                            playlistsCount: _userPlaylists.length,
                            favoritesCount:
                                AudioService().likedSongsNotifier.value.length,
                            weeklyPlayStats: _weeklyPlayStats,
                          ),
                        ),
                      )
                      .then((_) => _loadProfileImage());
                },
                child: _buildProfileAvatar(radius: 15, iconSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Stats Row
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.headphones_rounded,
                        color: Color(0xFF1E1E24),
                        size: 24,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Total Plays',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$totalPlays songs',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          color: const Color(0xFF1E1E24),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(tierIcon, color: const Color(0xFF1E1E24), size: 24),
                      const SizedBox(height: 12),
                      Text(
                        'Vibe Tier',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        listenerTier,
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          color: const Color(0xFF1E1E24),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Peak Vibe Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E1E24), Color(0xFF333344)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.bolt_rounded, color: Colors.amber, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PEAK VIBE DAY',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.white60,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        peakDay == 'None'
                            ? 'No tracks played yet'
                            : 'Your energy peaks on ${fullDayNames[peakDay]}s!',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Weekly Goal tracker with standard base limits
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Daily Activity',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E1E24),
                ),
              ),
              Text(
                'Weekly Overview',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: Colors.black45,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: days.map((day) {
                final int count = _weeklyPlayStats[day] ?? 0;
                // Scale bar width dynamically based on maximum weekly count (relative scale)
                final double percentage = count / (maxCount > 0 ? maxCount : 1);

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 44,
                        child: Text(
                          day,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1E1E24),
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Stack(
                          children: [
                            Container(
                              height: 12,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F1F4),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: percentage == 0 ? 0.01 : percentage,
                              child: Container(
                                height: 12,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF1E1E24),
                                      Color(0xFF6F7285),
                                    ],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 75,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              count == 1 ? '1 song' : '$count songs',
                              style: GoogleFonts.inter(
                                color: Colors.black87,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class FloatingMiniPlayer extends StatefulWidget {
  final ImageProvider Function(Map<String, dynamic>) getSongImageProvider;

  const FloatingMiniPlayer({super.key, required this.getSongImageProvider});

  @override
  State<FloatingMiniPlayer> createState() => _FloatingMiniPlayerState();
}

class _FloatingMiniPlayerState extends State<FloatingMiniPlayer>
    with SingleTickerProviderStateMixin {
  bool _isBubbleMode = false;
  Offset _playerPosition = Offset.zero;
  bool _isDragging = false;

  late AnimationController _snapController;
  late Animation<Offset> _snapAnimation;
  Offset _snapStart = Offset.zero;
  Offset _snapTarget = Offset.zero;

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _snapAnimation = _snapController
        .drive(CurveTween(curve: Curves.easeOutCubic))
        .drive(Tween<Offset>(begin: Offset.zero, end: Offset.zero));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_playerPosition == Offset.zero &&
        !_isDragging &&
        !_snapController.isAnimating) {
      final size = MediaQuery.of(context).size;
      _playerPosition = Offset(size.width - 76.0, size.height / 2 - 30.0);
    }
  }

  @override
  void dispose() {
    _snapController.dispose();
    super.dispose();
  }

  void _snapTo(Offset target) {
    _snapStart = _playerPosition;
    _snapTarget = target;
    _snapAnimation = _snapController
        .drive(CurveTween(curve: Curves.easeOutCubic))
        .drive(Tween<Offset>(begin: _snapStart, end: _snapTarget));
    _snapController.reset();
    _snapController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: AudioService().currentSongNotifier,
      builder: (context, currentSong, child) {
        if (currentSong == null) return const SizedBox.shrink();

        final String title = currentSong['title'] ?? 'Unknown';
        final String artist = currentSong['artist'] ?? 'Unknown';

        return AnimatedBuilder(
          animation: _snapController,
          builder: (context, child) {
            final position = _snapController.isAnimating
                ? _snapAnimation.value
                : _playerPosition;

            if (_isBubbleMode) {
              return Positioned(
                left: position.dx,
                top: position.dy,
                width: 60,
                height: 60,
                child: GestureDetector(
                  onPanStart: (details) {
                    _snapController.stop();
                    setState(() {
                      _isDragging = true;
                    });
                  },
                  onPanUpdate: (details) {
                    setState(() {
                      _playerPosition += details.delta;
                    });
                  },
                  onPanEnd: (details) {
                    double targetX = 16.0;
                    if (_playerPosition.dx + 30 > size.width / 2) {
                      targetX = size.width - 76.0;
                    }
                    final double targetY = _playerPosition.dy.clamp(
                      60.0,
                      size.height - 160.0,
                    );
                    setState(() {
                      _playerPosition = Offset(targetX, targetY);
                      _isDragging = false;
                    });
                    _snapTo(Offset(targetX, targetY));
                  },
                  onTap: () {
                    setState(() {
                      _isBubbleMode = false;
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      image: DecorationImage(
                        image: widget.getSongImageProvider(currentSong),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              );
            } else {
              return Positioned(
                left: 0,
                right: 0,
                bottom: 84,
                child: GestureDetector(
                  onPanStart: (details) {
                    _snapController.stop();
                    setState(() {
                      _playerPosition = Offset(
                        details.globalPosition.dx - 30,
                        details.globalPosition.dy - 30,
                      );
                      _isDragging = true;
                      _isBubbleMode = true;
                    });
                  },
                  onPanUpdate: (details) {
                    setState(() {
                      _playerPosition += details.delta;
                    });
                  },
                  onPanEnd: (details) {
                    double targetX = 16.0;
                    if (_playerPosition.dx + 30 > size.width / 2) {
                      targetX = size.width - 76.0;
                    }
                    final double targetY = _playerPosition.dy.clamp(
                      60.0,
                      size.height - 160.0,
                    );
                    setState(() {
                      _playerPosition = Offset(targetX, targetY);
                      _isDragging = false;
                    });
                    _snapTo(Offset(targetX, targetY));
                  },
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const PlayerScreen(),
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12.0),
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E24),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade800,
                                borderRadius: BorderRadius.circular(12),
                                image: DecorationImage(
                                  image: widget.getSongImageProvider(
                                    currentSong,
                                  ),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              title,
                                              style: GoogleFonts.inter(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              artist,
                                              style: GoogleFonts.inter(
                                                color: Colors.white70,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          ClipOval(
                                            child: Image.asset(
                                              'assets/logo.png',
                                              width: 14,
                                              height: 14,
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (
                                                    context,
                                                    error,
                                                    stackTrace,
                                                  ) => const Icon(
                                                    Icons.music_note,
                                                    size: 14,
                                                    color: Colors.white70,
                                                  ),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Hotify',
                                            style: GoogleFonts.inter(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 11,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      ValueListenableBuilder<
                                        List<Map<String, dynamic>>
                                      >(
                                        valueListenable:
                                            AudioService().likedSongsNotifier,
                                        builder: (context, likedSongs, child) {
                                          final bool isLiked = AudioService()
                                              .isSongLiked(currentSong);
                                          return GestureDetector(
                                            onTap: () {
                                              AudioService().toggleLikeSong(
                                                currentSong,
                                              );
                                            },
                                            child: Icon(
                                              isLiked
                                                  ? Icons.favorite
                                                  : Icons.favorite_border,
                                              color: isLiked
                                                  ? Colors.redAccent
                                                  : Colors.white70,
                                              size: 20,
                                            ),
                                          );
                                        },
                                      ),
                                      const SizedBox(width: 16),
                                      GestureDetector(
                                        onTap: () {
                                          AudioService().previousSong();
                                        },
                                        child: const Icon(
                                          Icons.skip_previous_rounded,
                                          color: Colors.white,
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      ValueListenableBuilder<bool>(
                                        valueListenable:
                                            AudioService().isPlayingNotifier,
                                        builder: (context, isPlaying, child) {
                                          return ValueListenableBuilder<bool>(
                                            valueListenable: AudioService()
                                                .isLoadingNotifier,
                                            builder: (context, isLoading, child) {
                                              return GestureDetector(
                                                onTap: () {
                                                  AudioService().togglePlay();
                                                },
                                                child: Container(
                                                  width: 32,
                                                  height: 32,
                                                  decoration:
                                                      const BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        color: Colors.white,
                                                      ),
                                                  child: Center(
                                                    child: isLoading
                                                        ? const SizedBox(
                                                            width: 14,
                                                            height: 14,
                                                            child:
                                                                CircularProgressIndicator(
                                                                  strokeWidth:
                                                                      1.5,
                                                                  color: Colors
                                                                      .black87,
                                                                ),
                                                          )
                                                        : Icon(
                                                            isPlaying
                                                                ? Icons
                                                                      .pause_rounded
                                                                : Icons
                                                                      .play_arrow_rounded,
                                                            color: const Color(
                                                              0xFF1E1E24,
                                                            ),
                                                            size: 20,
                                                          ),
                                                  ),
                                                ),
                                              );
                                            },
                                          );
                                        },
                                      ),
                                      const SizedBox(width: 16),
                                      GestureDetector(
                                        onTap: () {
                                          AudioService().nextSong();
                                        },
                                        child: const Icon(
                                          Icons.skip_next_rounded,
                                          color: Colors.white,
                                          size: 22,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ValueListenableBuilder<Duration>(
                          valueListenable: AudioService().positionNotifier,
                          builder: (context, position, child) {
                            return ValueListenableBuilder<Duration>(
                              valueListenable: AudioService().durationNotifier,
                              builder: (context, duration, child) {
                                final posMs = position.inMilliseconds
                                    .toDouble();
                                final durMs = duration.inMilliseconds
                                    .toDouble();
                                final double progress = (durMs > 0)
                                    ? (posMs / durMs).clamp(0.0, 1.0)
                                    : 0.0;
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                          Color(0xFFE5B3B3),
                                        ),
                                    backgroundColor: Colors.white12,
                                    minHeight: 2.0,
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
          },
        );
      },
    );
  }
}
