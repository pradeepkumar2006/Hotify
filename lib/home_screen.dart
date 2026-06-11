import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // includes compute + kIsWeb
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'widgets/musical_galaxy.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'profile_screen.dart';
import 'services/audio_service.dart';
import 'player_screen.dart';
import 'utils/theme_notifier.dart';
import 'package:image_picker/image_picker.dart';
import 'artist_details_screen.dart';
import 'playlist_detail_screen.dart';

import 'offline_music_screen.dart';
import 'init_status.dart';
import 'crossover_details_screen.dart';
import 'magic_shuffle_screen.dart';
import 'weekly_wrapped_screen.dart';


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
  Map<String, int> _eraPlayCounts = {};
  Map<String, int> _songPlayCounts = {};

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
        backgroundColor: Theme.of(context).colorScheme.primary,
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.primary,
      child: Icon(FeatherIcons.user, color: Theme.of(context).colorScheme.surface, size: iconSize),
    );
  }

  late PageController _recentlyPlayedController;

  // Track genre play counts for dynamic Daily Mix generation
  final Map<String, int> _genrePlayCounts = {
    'Melody / Romance': 5,
    'Kuthu / Dance': 4,
    'Lofi / Chill': 3,
    'Classical / Instrumental': 2,
    'SAD': 1,
  };
  
  Map<String, int> _artistPlayCounts = {};



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

  ];

  final List<Map<String, dynamic>> _crossoverCards = const [
    {
      'id': 'crossover_1',
      'label': '2010 & Below',
      'image': 'assets/crossover_1.png',
      'minYear': 0,
      'maxYear': 2010,
    },
    {
      'id': 'crossover_2',
      'label': '2011 - 2015',
      'image': 'assets/crossover_2.png',
      'minYear': 2011,
      'maxYear': 2015,
    },
    {
      'id': 'crossover_3',
      'label': '2016 - 2020',
      'image': 'assets/crossover_3.png',
      'minYear': 2016,
      'maxYear': 2020,
    },
    {
      'id': 'crossover_4',
      'label': '2021 - 2026',
      'image': 'assets/crossover_4.png',
      'minYear': 2021,
      'maxYear': 2026,
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
    final genreSongs = _genreSongsCache[genreName] ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
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
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
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
                        child: Center(
                          child: Icon(
                            Icons.music_note_rounded,
                            color: Theme.of(context).colorScheme.surface,
                            size: 28,
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: GoogleFonts.outfit(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            Text(
                              '${genreSongs.length} Songs in Library',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(),
                // Songs list
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    cacheExtent: 1000,
                    itemCount: genreSongs.length,
                    itemBuilder: (context, index) {
                      final song = genreSongs[index];
                      return ListTile(
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(6),
                            image: DecorationImage(
                              image: _getResizedSongImageProvider(song, width: 80, height: 80),
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
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
                          ),
                        ),
                        trailing: Icon(
                          Icons.play_arrow,
                          color: Theme.of(context).colorScheme.primary,
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

  void _showCrossoverSongs({
    required int minYear,
    required int maxYear,
    required String displayName,
    required String bgImage,
  }) {
    final genreSongs = _allSongs.where((song) {
      final language = (song['language'] ?? '').toString().toLowerCase();
      if (language != 'english') return false;

      final yearVal = int.tryParse(song['year']?.toString() ?? '');
      if (yearVal == null) return false;
      return yearVal >= minYear && yearVal <= maxYear;
    }).toList();

    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => CrossoverDetailsScreen(
          crossoverLabel: displayName,
          crossoverImage: bgImage,
          crossoverSongs: genreSongs,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 150),
        reverseTransitionDuration: const Duration(milliseconds: 100),
      ),
    );
  }

  List<Map<String, dynamic>> _allSongs = [];
  List<Map<String, dynamic>> _magicPlaylist = [];
  bool _isLoadingSongs = true;

  // Pre-computed movie → songs map — built ONCE when songs load,
  // never recomputed on every search keystroke.
  Map<String, List<Map<String, dynamic>>> _moviePlaylists = {};
  Map<String, List<Map<String, dynamic>>> _artistSongsMap = {};
  Map<String, List<Map<String, dynamic>>> _genreSongsCache = {};
  Map<String, String> _genreArtistsDescCache = {};

  // Debounce timer for search — prevents 16k-song filter from running
  // on every keypress; fires only after user stops typing for 300ms.
  Timer? _searchDebounce;
  String _debouncedQuery = '';
  List<Map<String, dynamic>> _jioSaavnSearchResults = [];

  // Cached artist list — built ONCE after songs load, never rebuilt on scroll
  List<Map<String, String>> _artists = [];


  // Static const — never rebuilt, allocated once for lifetime of the app
  static const Map<String, String> _artistImages = {
    // A. R. Rahman
    'arrahman': 'assets/ar_rahman.png',
    'rahman': 'assets/ar_rahman.png',
    // Anirudh Ravichander
    'anirudh': 'assets/anirudh.jpg',
    // Yuvan Shankar Raja
    'yuvanshankarraja': 'assets/yuvan.jpg',
    'yuvansankar': 'assets/yuvan.jpg',
    'yuvan': 'assets/yuvan.jpg',
    // Deva
    'deva':
        'assets/deva.jpg',
    // Hiphop Tamizha
    'hiphopaadhi': 'assets/hiphop_tamizha.png',
    'hiphopta': 'assets/hiphop_tamizha.png',
    'hiphop': 'assets/hiphop_tamizha.png',
    // GV Prakash Kumar
    'gvprakash': 'assets/gv_prakash.jpg',
    'gvprakashkumar': 'assets/gv_prakash.jpg',
    // Sai Abhyankkar
    'saiabhyankkar': 'assets/sai_abhyankkar.png',
    'saiabhyankar': 'assets/sai_abhyankkar.png',
    // Srikanth Deva
    'srikanthdeva': 'assets/srikanth_deva.png',
    // Vijay Antony
    'vijayantony': 'assets/vijay_antony.png',
    // Harris Jayaraj
    'harrisjayaraj': 'assets/harris_jayaraj.png',
    // DSP / Devi Sri Prasad
    'dsp': 'assets/dsp.png',
    'devissriprasad': 'assets/dsp.png',
    'devisriprasad': 'assets/dsp.png',
    // D. Imman
    'dimman': 'assets/imman.png',
    'imman': 'assets/imman.png',
    // S. N. Arunagiri
    'snarunagiri': 'assets/sn_arunagiri.png',
    'arunagiri': 'assets/sn_arunagiri.png',
    // Ilaiyaraaja
    'ilaiyaraaja': 'assets/ilaiyaraaja.png',
    'ilayaraja': 'assets/ilaiyaraaja.png',
    // Karthik Raja
    'karthikraja': 'assets/karthik_raja.png',
    // M. S. Viswanathan
    'msviswanathan': 'assets/msv.png',
    'viswanathan': 'assets/msv.png',
    // Various Composers
    'variouscomposers': 'assets/various_composers.png',
  };

  String _getArtistPicture(String artistName, String fallbackImageUrl) {
    final String cleanArtist = artistName
        .toLowerCase()
        .replaceAll(' ', '')
        .replaceAll('.', '');

    for (final entry in _artistImages.entries) {
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
    // ALWAYS use the artist's picture for the mini player and widgets.
    String imagePath = _getArtistPicture(artist, song['img'] ?? '');

    // If path points to a local asset that might not exist or is invalid
    if (imagePath.startsWith('assets/') &&
        !imagePath.endsWith('.jpg') &&
        !imagePath.endsWith('.jpeg') &&
        !imagePath.endsWith('.png')) {
      imagePath = _getArtistPicture(artist, song['img'] ?? '');
    }

    if (imagePath.startsWith('assets/')) {
      return AssetImage(imagePath);
    }
    return CachedNetworkImageProvider(imagePath);
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

  ImageProvider _getResizedSongImageProvider(Map<String, dynamic> song, {int? width, int? height}) {
    final provider = _getSongImageProvider(song);
    if (width != null || height != null) {
      return ResizeImage(provider, width: width, height: height);
    }
    return provider;
  }

  ImageProvider _getResizedImageProvider(String path, {int? width, int? height}) {
    final provider = _getImageProvider(path);
    if (width != null || height != null) {
      return ResizeImage(provider, width: width, height: height);
    }
    return provider;
  }



  // Off-thread JSON parser — keeps UI thread free
  static List<Map<String, dynamic>> _parseJson(String jsonString) {
    final List<dynamic> jsonList = json.decode(jsonString);
    final allSongs = jsonList.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    
    // Case-insensitive keywords to filter out remix, theme, and instrumental songs
    final filterKeywords = [
      'remix',
      'theme',
      'instrumental',
      'instru',
      'bgm',
      'score',
      'loop',
      'cut',
      'layer',
      'stem',
      'teaser',
      'trailer',
    ];

    return allSongs.where((song) {
      final title = (song['title'] ?? '').toString().toLowerCase();
      final genre = (song['genre'] ?? '').toString().toLowerCase();
      
      for (final kw in filterKeywords) {
        if (title.contains(kw) || genre.contains(kw)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  List<Map<String, String>> _buildArtistsList(List<Map<String, dynamic>> songs) {
    final seen = <String>{};
    final list = <Map<String, String>>[];
    for (final song in songs) {
      final name = (song['artist'] ?? '').toString().trim();
      if (name.isEmpty || name == 'Unknown Composer') continue;

      // Skip English artists as requested (they are covered in Crossover Vibes cards)
      final language = (song['language'] ?? '').toString().toLowerCase();
      if (language == 'english') continue;

      if (seen.contains(name)) continue;
      seen.add(name);

      final image = _getArtistPicture(name, '');
      // If the artist doesn't have a dedicated photo (meaning it resolves to various_composers or ui-avatars),
      // we do not add them individually. They are grouped under "Various Composers".
      if (!image.startsWith('assets/') || image == 'assets/various_composers.png') {
        continue;
      }

      list.add({
        'name': name,
        'image': image,
      });
    }

    // Always add "Various Composers" at the end of the list
    list.add({
      'name': 'Various Composers',
      'image': 'assets/various_composers.png',
    });

    return list;
  }

  void _setupSongs(List<Map<String, dynamic>> songs) {
    // Filter for Suggested Songs (mostly Anirudh, Hiphop Tamizha, Yuvan)
    final allowedComposers = ['anirudh', 'hiphop tamizha', 'hip hop', 'yuvan'];
    final suggestedPool = songs.where((song) {
      final artist = (song['artist'] ?? '').toString().toLowerCase();
      if (artist.contains('various composers') || artist.contains('unknown composer')) {
        return false;
      }
      return allowedComposers.any((c) => artist.contains(c));
    }).toList();
    
    // Fallback if not enough songs found
    if (suggestedPool.length < 15) {
      suggestedPool.addAll(songs.where((song) {
        final artist = (song['artist'] ?? '').toString().toLowerCase();
        return !artist.contains('various composers') && !artist.contains('unknown composer') && !suggestedPool.contains(song);
      }));
    }
    
    suggestedPool.shuffle();

    // Generate Magic Playlist (80/20 Rule: 80% Familiar, 20% Discovery)
    final likedSongs = AudioService().likedSongsNotifier.value;
    final List<Map<String, dynamic>> familiarPool = likedSongs.isNotEmpty 
        ? List.from(likedSongs) 
        : List.from(songs); // fallback to all songs if no liked songs
    familiarPool.shuffle();

    final discoveryPool = suggestedPool.where((song) {
      return !likedSongs.any((l) => l['id'] == song['id']);
    }).toList();
    if (discoveryPool.isEmpty) {
      discoveryPool.addAll(songs); // fallback
    }
    discoveryPool.shuffle();

    List<Map<String, dynamic>> newMagicPlaylist = [];
    int totalTarget = 50; 
    int targetFamiliar = (totalTarget * 0.8).toInt();
    int targetDiscovery = totalTarget - targetFamiliar;

    newMagicPlaylist.addAll(familiarPool.take(targetFamiliar));
    newMagicPlaylist.addAll(discoveryPool.take(targetDiscovery));
    newMagicPlaylist.shuffle(); // mix them up nicely!

    setState(() {
      _allSongs = songs;
      _magicPlaylist = newMagicPlaylist;
      _artists = _buildArtistsList(songs); // cached once
      
      // Pre-compute the movie → songs lookup map ONCE so search is instant
      _moviePlaylists = {};
      for (final song in songs) {
        final movie = (song['movie'] ?? '').toString();
        if (movie.isNotEmpty) {
          _moviePlaylists.putIfAbsent(movie, () => []).add(song);
        }
      }

      // Pre-compute artist → songs lookup map ONCE on startup
      _artistSongsMap = {};
      for (final artist in _artists) {
        final name = artist['name']!;
        final queryArtist = name.toLowerCase().replaceAll(' ', '').replaceAll('.', '');
        
        final list = songs.where((song) {
          if (queryArtist == 'variouscomposers') {
            return song['img'] == 'assets/various_composers.png';
          }

          final songArtist = (song['artist']?.toString() ?? '')
              .toLowerCase()
              .replaceAll(' ', '').replaceAll('.', '');

          if (songArtist.contains(queryArtist) || queryArtist.contains(songArtist)) {
            return true;
          } else if (queryArtist.contains('yuvan') && songArtist.contains('yuvan')) {
            return true;
          } else if (queryArtist.contains('hiphop') && songArtist.contains('hiphop')) {
            return true;
          }
          return false;
        }).toList();
        
        _artistSongsMap[name] = list;
      }

      // Pre-compute genre → songs and artists description ONCE on startup
      _genreSongsCache = {};
      _genreArtistsDescCache = {};
      for (final card in _genreCards) {
        final genreName = card['genre']!;
        final genreSongs = songs.where((s) => _getSongGenre(s) == genreName).toList();
        _genreSongsCache[genreName] = genreSongs;
        
        final Set<String> artists = genreSongs
            .map((s) => (s['artist'] ?? '').toString())
            .where((artist) => artist.isNotEmpty)
            .toSet();
        _genreArtistsDescCache[genreName] = artists.isNotEmpty
            ? 'Including ${artists.take(3).join(", ")}'
            : 'A unique mix curated for you';
      }

      _isLoadingSongs = false;
    });
  }

  Future<void> _loadSongs() async {
    if (preloadedSongs.isNotEmpty) {
      debugPrint('HomeScreen: Using preloaded songs.');
      _setupSongs(preloadedSongs);
      return;
    }

    final assetBundle = DefaultAssetBundle.of(context);
    try {
      final String jsonString = await assetBundle.loadString(
        'assets/tamil_songs.json',
      );
      final songs = await compute(_parseJson, jsonString);
      
      List<Map<String, dynamic>> englishSongs = [];
      try {
        final String englishJson = await assetBundle.loadString('assets/english_songs.json');
        englishSongs = await compute(_parseJson, englishJson);
      } catch (e) {
        debugPrint("Error loading english songs (non-fatal): $e");
      }
      
      final combined = [...songs, ...englishSongs];
      _setupSongs(combined);
    } catch (e) {
      debugPrint("Error loading songs from assets: $e");
      setState(() {
        _isLoadingSongs = false;
      });
    }
  }


  Future<void> _savePlaylists() async {
    await AudioService().saveUserPlaylists(_userPlaylists);
  }

  Future<void> _loadPlaylists() async {
    // Loaded by AudioService, trigger sync
    _onPlaylistsChanged();
  }

  void _onPlaylistsChanged() {
    if (mounted) {
      setState(() {
        _userPlaylists.clear();
        _userPlaylists.addAll(AudioService().userPlaylistsNotifier.value);
      });
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
        'artists': _artistPlayCounts,
        'eras': _eraPlayCounts,
        'songs': _songPlayCounts,
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
            if (decoded.containsKey('artists')) {
              _artistPlayCounts = (decoded['artists'] as Map).map(
                (key, value) =>
                    MapEntry(key.toString(), int.parse(value.toString())),
              );
            }
            if (decoded.containsKey('eras')) {
              _eraPlayCounts = (decoded['eras'] as Map).map(
                (key, value) =>
                    MapEntry(key.toString(), int.parse(value.toString())),
              );
            }
            if (decoded.containsKey('songs')) {
              _songPlayCounts = (decoded['songs'] as Map).map(
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
    AudioService().userPlaylistsNotifier.addListener(_onPlaylistsChanged);
    AudioService().errorNotifier.addListener(_handleAudioError);
    _recentlyPlayedController = PageController(
      initialPage: 1,
      viewportFraction: 0.55,
    );
    // Use a direct notifier so only the carousel rebuilds, not the whole screen
    _recentlyPlayedController.addListener(_onCarouselScroll);
  }


  void _handleAudioError() {
    final error = AudioService().errorNotifier.value;
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  error,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // Separated listener — updates only the carousel page notifier, not whole state
  final ValueNotifier<double> _currentPageNotifier = ValueNotifier<double>(1.0);
  void _onCarouselScroll() {
    _currentPageNotifier.value = _recentlyPlayedController.page ?? 1.0;
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
      // Update counts without triggering a full rebuild — mini player uses ValueListenableBuilder
      _genrePlayCounts[genre] = (_genrePlayCounts[genre] ?? 0) + 1;
      
      final String artist = song['artist'] ?? 'Unknown Artist';
      if (artist != 'Unknown Artist') {
        _artistPlayCounts[artist] = (_artistPlayCounts[artist] ?? 0) + 1;
      }
      
      final String songId = song['id']?.toString() ?? song['title']?.toString() ?? 'Unknown Song';
      if (songId != 'Unknown Song') {
        _songPlayCounts[songId] = (_songPlayCounts[songId] ?? 0) + 1;
      }

      final yearStr = song['year']?.toString() ?? '';
      final year = int.tryParse(yearStr);
      if (year != null) {
        String era = '';
        if (year <= 2000) {
          era = '90s & Below';
        } else if (year <= 2010) {
          era = '2000s';
        } else if (year <= 2020) {
          era = '2010s';
        } else {
          era = '2020s';
        }
        _eraPlayCounts[era] = (_eraPlayCounts[era] ?? 0) + 1;
      }

      // Increment play stats (this calls setState internally, but only for stats)
      _incrementTodayPlayCount();
    }
    // DO NOT call setState({}) here — the mini player is driven by ValueListenableBuilder
    // and doesn't need a full rebuild of HomeScreen.
  }

  @override
  void dispose() {
    AudioService().currentSongNotifier.removeListener(_onCurrentSongChanged);
    AudioService().userPlaylistsNotifier.removeListener(_onPlaylistsChanged);
    AudioService().errorNotifier.removeListener(_handleAudioError);
    _recentlyPlayedController.removeListener(_onCarouselScroll);
    _recentlyPlayedController.dispose();
    _currentPageNotifier.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }
  void _showGalaxyArtistSongs(String artistName, String artistImage) {
    final lowerArtistName = artistName.toLowerCase();
    
    final likedArtistSongs = _allSongs.where((song) {
      final artist = (song['artist'] ?? '').toString().toLowerCase();
      
      // Some names like "A.R. Rahman" might be "ar rahman" in songs, so we do a generous check
      bool match = artist.contains(lowerArtistName);
      if (lowerArtistName == 'a.r. rahman') match = match || artist.contains('rahman');
      if (lowerArtistName == 'g.v. prakash') match = match || artist.contains('prakash');
      
      return match && AudioService().isSongLiked(song);
    }).toList();

    if (likedArtistSongs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("You haven't added any $artistName magic to your galaxy yet. Go heart some tracks!"),
          backgroundColor: Theme.of(context).colorScheme.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PlaylistDetailScreen(
          playlist: {
            'name': '$artistName Favorites',
            'image': artistImage,
            'description': 'Your personal collection of $artistName hits.',
            'songs': likedArtistSongs,
          },
          allSongs: _allSongs,
          onPlaylistUpdated: (p) {},
        ),
      ),
    );
  }

  void _showArtistSongs(String artistName, String artistImage) {
    final artistSongs = _artistSongsMap[artistName] ?? [];
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => ArtistDetailsScreen(
          artistName: artistName,
          artistImage: artistImage,
          artistSongs: artistSongs,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 150),
        reverseTransitionDuration: const Duration(milliseconds: 100),
      ),
    );
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
    // If the song list is empty after loading, give a friendly hint.
    if (!_isLoadingSongs && _allSongs.isEmpty) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: Text(
            'No songs found. Check that assets/tamil_songs.json is present and listed in pubspec.yaml.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 14, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54)),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Main scrollable contents using IndexedStack to preserve state
          // RepaintBoundary isolates each tab so only the visible tab repaints
          Positioned.fill(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                RepaintBoundary(child: _buildHomeDashboard()),
                RepaintBoundary(child: _buildSearchTab()),
                RepaintBoundary(child: _buildCreateTab()),
                RepaintBoundary(child: _buildVibeStatsTab()),
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
                      color: Theme.of(context).colorScheme.surface,
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
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  item['icon'] as IconData,
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.surface
                                      : Theme.of(context).colorScheme.primary,
                                  size: 22,
                                ),
                                if (isSelected) ...[
                                  SizedBox(width: 8),
                                  Text(
                                    item['label'] as String,
                                    style: GoogleFonts.inter(
                                      color: Theme.of(context).colorScheme.surface,
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
          FloatingMiniPlayer(
            getSongImageProvider: (song) => _getResizedSongImageProvider(song, width: 120, height: 120),
          ),
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
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              Row(
                children: [

                  IconButton(
                    icon: Icon(
                      FeatherIcons.download,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const OfflineMusicScreen(),
                        ),
                      );
                    },
                  ),
                  SizedBox(width: 4),
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

          SizedBox(height: 16),

          // Hello Melophile Greeting Card
          GestureDetector(
            onTap: () => AudioService().playTts("Hello Melophile"),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF1E1E24), const Color(0xFF2C2C35)],
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
                        SizedBox(height: 4),
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
                    child: ValueListenableBuilder<Color>(
                      valueListenable: accentColorNotifier,
                      builder: (context, accent, _) => Icon(
                        Icons.music_note_rounded,
                        color: accent,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 24),

          // 1. Artists Section is now at the top
          Text(
            'Artists you love',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          SizedBox(height: 12),
          _isLoadingSongs
              ? const SizedBox(height: 110)
              : SizedBox(
                  height: 110, // Slightly increased height for padding
                  child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              cacheExtent: 500,
              itemCount: _artists.length,
              itemBuilder: (context, index) {
                final artist = _artists[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 18.0, left: 4.0), // Padding for ripple
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      splashColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                      highlightColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      onTap: () {
                        // Tiny delay to allow ripple to show before heavy navigation
                        Future.delayed(const Duration(milliseconds: 50), () {
                          _showArtistSongs(artist['name']!, artist['image']!);
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Column(
                          children: [
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: CircleAvatar(
                                  radius: 35,
                                  backgroundImage: _getResizedImageProvider(artist['image']!, width: 250, height: 250),
                                  backgroundColor: Colors.grey.shade900,
                                ),
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              artist['name']!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // Cross-Over Vibes Section
          Text(
            'Cross-Over Vibes',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              cacheExtent: 500,
              itemCount: _crossoverCards.length,
              itemBuilder: (context, index) {
                final card = _crossoverCards[index];
                return GestureDetector(
                  onTap: () {
                    _showCrossoverSongs(
                      minYear: card['minYear'] as int,
                      maxYear: card['maxYear'] as int,
                      displayName: card['label'] as String,
                      bgImage: card['image'] as String,
                    );
                  },
                  child: Container(
                    width: 150,
                    margin: const EdgeInsets.only(right: 14.0),
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: ResizeImage(AssetImage(card['image']!), width: 200, height: 200),
                        fit: BoxFit.cover,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // 2. Recently Played is under the Artists Section
          Text(
            'Recently Played',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          SizedBox(height: 16),
          _isLoadingSongs
              ? const SizedBox(height: 200)
              : ValueListenableBuilder<List<Map<String, dynamic>>>(
                  valueListenable: AudioService().recentSongsNotifier,
                  builder: (context, recentSongs, child) {
                    if (recentSongs.isEmpty) {
                      return SizedBox(
                        height: 200,
                        child: Center(
                          child: Text(
                            'Play some songs to see your history here!',
                            style: GoogleFonts.inter(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
                            ),
                          ),
                        ),
                      );
                    }
                    return SizedBox(
                      height: 200,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        cacheExtent: 500,
                        itemCount: recentSongs.length,
                        clipBehavior: Clip.none,
                        physics: const BouncingScrollPhysics(),
                        itemBuilder: (context, index) {
                          final album = recentSongs[index];
                          
                          return Container(
                            width: 150,
                            margin: const EdgeInsets.only(right: 14.0),
                            child: GestureDetector(
                              onTap: () {
                                AudioService().playSong(
                                  album,
                                  playlistContext: recentSongs,
                                );
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const PlayerScreen(),
                                  ),
                                );
                              },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(16),
                              image: DecorationImage(
                                image: _getResizedSongImageProvider(album, width: 300, height: 400),
                                fit: BoxFit.cover,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.12),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.fromLTRB(12, 24, 12, 12),
                                    decoration: BoxDecoration(
                                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
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
                                          album['title']!,
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
                                          album['composer'] ?? album['artist']!,
                                          style: GoogleFonts.inter(
                                            color: Colors.white70,
                                            fontSize: 11,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.black.withValues(alpha: 0.4),
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
                      );
                    },
                  ),
                );
              },
            ),

          SizedBox(height: 12),

          // 3. Explore Genres section
          Text(
            'Explore Genres',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              cacheExtent: 500,
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
                              image: _getResizedImageProvider(card['image'] as String, width: 200, height: 200),
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
                                  color: Theme.of(context).colorScheme.surface,
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

          SizedBox(height: 24),

          // Magic Shuffle section heading
          Text(
            'Magic Shuffle',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          SizedBox(height: 16),

          // New Orange Shuffle Magic Widget (Matches user screenshot)
          GestureDetector(
            onTap: () {
              if (_magicPlaylist.isEmpty) return;
              // Ensure we don't have anything currently buffering from homescreen
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => MagicShuffleScreen(initialSongs: _magicPlaylist),
                ),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFEADDFF), Color(0xFFD0BCFF)], // Light pastel magical purple
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD0BCFF).withValues(alpha: 0.5),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(FeatherIcons.zap, color: Color(0xFF6750A4), size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Enter the Magic',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF21005D), // Dark purple
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Swipe through a customized mix of gems',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFF4F378B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(FeatherIcons.chevronRight, color: Color(0xFF4F378B)),
                ],
              ),
            ),
          ),
          
          SizedBox(height: 32),

          // Musical Galaxy View
          MusicalGalaxyView(
            onArtistTap: (name, image) => _showGalaxyArtistSongs(name, image),
          ),

          SizedBox(height: 24),
        ],
      ),
    );
  }

  // Spotify-like Search Tab View
  Widget _buildSearchTab() {
    final query = _debouncedQuery; // use pre-debounced query
    // Use pre-computed map — no more O(n) scan on every keystroke!
    final List<String> matchedMovieNames = [];
    final List<Map<String, dynamic>> matchedSongs = [];

    if (query.isNotEmpty) {
      matchedMovieNames.addAll(
        _moviePlaylists.keys.where((m) => m.toLowerCase().contains(query)).toList()
          ..sort((a, b) => a.compareTo(b))
      );

      matchedSongs.addAll(_allSongs.where((song) {
        final title = (song['title'] ?? '').toString().toLowerCase();
        final artist = (song['artist'] ?? '').toString().toLowerCase();
        return title.contains(query) || artist.contains(query);
      }));
      
      final existingIds = matchedSongs.map((s) => s['id'].toString()).toSet();
      for (var js in _jioSaavnSearchResults) {
        if (!existingIds.contains(js['id'].toString())) {
          matchedSongs.add(js);
        }
      }
    }

    final int totalResults = matchedMovieNames.length + matchedSongs.length;

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
                  color: Theme.of(context).colorScheme.primary,
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
          SizedBox(height: 20),
          TextField(
            style: GoogleFonts.inter(color: Theme.of(context).colorScheme.primary),
          onChanged: (val) {
              // Debounce: wait 300ms after last keystroke before filtering 16k songs
              _searchDebounce?.cancel();
              _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
                setState(() {
                  _searchQuery = val.trim();
                  _debouncedQuery = _searchQuery.toLowerCase();
                });
                
                if (_debouncedQuery.isNotEmpty) {
                  final jioSaavnResults = await AudioService().searchJioSaavn(_debouncedQuery);
                  if (mounted && _searchQuery == val.trim()) {
                    setState(() {
                      _jioSaavnSearchResults = jioSaavnResults;
                    });
                  }
                } else {
                  if (mounted) {
                    setState(() {
                      _jioSaavnSearchResults = [];
                    });
                  }
                }
              });
            },
            decoration: InputDecoration(
              hintText: 'What do you want to listen to?',
              hintStyle: GoogleFonts.inter(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38), fontSize: 14),
              prefixIcon: Icon(
                FeatherIcons.search,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                size: 20,
              ),
              filled: true,
              fillColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2A2A30) : Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 16.0),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 1.5,
                ),
              ),
            ),
          ),
          SizedBox(height: 20),
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
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      SizedBox(height: 12),
                      Expanded(
                        child: totalResults == 0
                            ? Center(
                                child: Text(
                                  'No matching songs or movies found',
                                  style: GoogleFonts.inter(
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
                                  ),
                                ),
                              )
                            : ListView.builder(
                                physics: const BouncingScrollPhysics(),
                                cacheExtent: 1000,
                                padding: const EdgeInsets.only(bottom: 150.0),
                                itemCount: totalResults,
                                itemBuilder: (context, index) {
                                  if (index < matchedMovieNames.length) {
                                    // Movie Playlist Item
                                    final movieName = matchedMovieNames[index];
                                    final songs = _moviePlaylists[movieName]!;
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.surface,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.03),
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
                                            borderRadius: BorderRadius.circular(8),
                                            image: DecorationImage(
                                              image: _getResizedSongImageProvider(songs.first, width: 80, height: 80),
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                        title: Text(
                                          movieName,
                                          style: GoogleFonts.inter(
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context).colorScheme.primary,
                                          ),
                                        ),
                                        subtitle: Text(
                                          'Movie Playlist • ${songs.length} songs',
                                          style: GoogleFonts.inter(
                                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
                                            fontSize: 12,
                                          ),
                                        ),
                                        trailing: Icon(
                                          Icons.arrow_forward_ios_rounded,
                                          size: 16,
                                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                                        ),
                                        onTap: () {
                                          FocusScope.of(context).unfocus();
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (context) => PlaylistDetailScreen(
                                                playlist: {
                                                  'name': movieName,
                                                  'image': songs.first['img'] ?? '',
                                                  'description': 'Songs from $movieName',
                                                  'songs': songs,
                                                },
                                                allSongs: _allSongs,
                                                onPlaylistUpdated: (p) {},
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    );
                                  } else {
                                    // Individual Song Item
                                    final song = matchedSongs[index - matchedMovieNames.length];
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.surface,
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
                                            borderRadius: BorderRadius.circular(8),
                                            image: DecorationImage(
                                              image: _getResizedSongImageProvider(song, width: 80, height: 80),
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                        title: Text(
                                          song['title'] ?? '',
                                          style: GoogleFonts.inter(
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context).colorScheme.primary,
                                          ),
                                        ),
                                        subtitle: Text(
                                          '${song['artist'] ?? ''}${song['movie'] != null && song['movie'].toString().isNotEmpty ? ' • ${song['movie']}' : ''}',
                                          style: GoogleFonts.inter(
                                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
                                            fontSize: 12,
                                          ),
                                        ),
                                        trailing: Icon(
                                          Icons.play_arrow_rounded,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                        onTap: () {
                                          FocusScope.of(context).unfocus();
                                          AudioService().playSong(
                                            song,
                                            playlistContext: matchedSongs,
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
                                  }
                                },
                              ),
                      ),
                    ],
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          FeatherIcons.search,
                          size: 48,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.26),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Search for songs or artists',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
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
                  color: Theme.of(context).colorScheme.primary,
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
          SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _showCreatePlaylistDialog,
              icon: Icon(
                FeatherIcons.plus,
                color: Theme.of(context).colorScheme.surface,
                size: 18,
              ),
              label: Text(
                'CREATE NEW PLAYLIST',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: Theme.of(context).colorScheme.surface,
                  fontSize: 13,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
            ),
          ),
          SizedBox(height: 28),
          Text(
            'Your Collection',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          SizedBox(height: 16),
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
                          color: Theme.of(context).colorScheme.surface,
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
                              child: ValueListenableBuilder<Color>(
                                valueListenable: accentColorNotifier,
                                builder: (context, accent, _) => Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        accent,
                                        accent.withValues(alpha: 0.5),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(12),
                                    ),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.favorite_rounded,
                                      color: Theme.of(context).colorScheme.surface,
                                      size: 40,
                                    ),
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
                                      color: Theme.of(context).colorScheme.primary,
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: 3),
                                  Text(
                                    '${likedSongs.length} ${likedSongs.length == 1 ? "song" : "songs"}',
                                    style: GoogleFonts.inter(
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
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
                        playlist['image'] ?? 'assets/default_playlist.png';
                    final String pName = playlist['name'] ?? 'My Playlist';
                    final String pDesc = playlist['description'] ?? '';
                    final int songCount =
                        (playlist['songs'] as List?)?.length ?? 0;


                    return GestureDetector(
                      onTap: () {
                        Map<String, dynamic> currentPlaylist = playlist;
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => PlaylistDetailScreen(
                              playlist: currentPlaylist,
                              allSongs: _allSongs,
                              onPlaylistUpdated: (updatedPlaylist) {
                                setState(() {
                                  final idx = _userPlaylists.indexOf(currentPlaylist);
                                  if (idx != -1) {
                                    _userPlaylists[idx] = updatedPlaylist;
                                    currentPlaylist = updatedPlaylist;
                                  }
                                });
                                _savePlaylists();
                              },
                            ),
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
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
                                        errorBuilder: (context, error, stackTrace) => Image.asset(
                                          'assets/logo.png',
                                          fit: BoxFit.cover,
                                        ),
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
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          FeatherIcons.trash2,
                                          color: Theme.of(context).colorScheme.surface,
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
                                      color: Theme.of(context).colorScheme.primary,
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (pDesc.isNotEmpty) ...[
                                    SizedBox(height: 2),
                                    Text(
                                      pDesc,
                                      style: GoogleFonts.inter(
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                        fontSize: 11,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                  SizedBox(height: 3),
                                  Text(
                                    '$songCount ${songCount == 1 ? "song" : "songs"}',
                                    style: GoogleFonts.inter(
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
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

  void _showCreatePlaylistDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    String? imagePath;
    final picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Color(0xFF121212),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Create Playlist',
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: () async {
                              try {
                                final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                                if (image != null) {
                                  setModalState(() {
                                    imagePath = image.path;
                                  });
                                }
                              } catch (e) {
                                debugPrint("Error picking image: $e");
                              }
                            },
                            child: Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                color: Colors.white12,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white30, width: 1),
                                image: imagePath != null
                                    ? DecorationImage(
                                        image: FileImage(File(imagePath!)),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: imagePath == null
                                  ? Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(FeatherIcons.camera, color: Colors.white54, size: 32),
                                        const SizedBox(height: 8),
                                        Text('Add Photo', style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
                                      ],
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 40),
                          TextFormField(
                            controller: nameController,
                            cursorColor: Colors.white,
                            style: GoogleFonts.inter(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w600),
                            decoration: const InputDecoration(
                              labelText: 'Playlist Name',
                              labelStyle: TextStyle(color: Colors.white54),
                              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
                              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white70)),
                            ),
                          ),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: descController,
                            cursorColor: Colors.white,
                            style: GoogleFonts.inter(fontSize: 16, color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Description (optional)',
                              labelStyle: TextStyle(color: Colors.white54),
                              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
                              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white70)),
                            ),
                          ),
                          const SizedBox(height: 50),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: () {
                                final name = nameController.text.trim();
                                if (name.isEmpty) return;
                                
                                final Map<String, dynamic> newPlaylist = <String, dynamic>{
                                  'name': name,
                                  'image': imagePath != null && imagePath!.isNotEmpty ? imagePath : 'assets/default_playlist.png',
                                  'description': descController.text.trim(),
                                  'songs': <Map<String, dynamic>>[],
                                };

                                setState(() {
                                  _userPlaylists.add(newPlaylist);
                                });
                                _savePlaylists();
                                
                                Navigator.pop(context); // Close modal
                                
                                // Navigate to the new playlist directly
                                if (mounted) {
                                  Map<String, dynamic> currentPlaylist = newPlaylist;
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => PlaylistDetailScreen(
                                        playlist: currentPlaylist,
                                        allSongs: _allSongs,
                                        onPlaylistUpdated: (updatedPlaylist) {
                                          setState(() {
                                            final idx = _userPlaylists.indexOf(currentPlaylist);
                                            if (idx != -1) {
                                              _userPlaylists[idx] = updatedPlaylist;
                                              currentPlaylist = updatedPlaylist;
                                            }
                                          });
                                          _savePlaylists();
                                        },
                                      ),
                                    ),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                              ),
                              child: Text(
                                'CREATE PLAYLIST',
                                style: GoogleFonts.montserrat(
                                  color: Theme.of(context).colorScheme.onPrimary,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.inter(color: Colors.white54, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
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
                  color: Theme.of(context).colorScheme.primary,
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
          SizedBox(height: 24),

          // Stats Row
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
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
                      Icon(
                        Icons.headphones_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 24,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Total Plays',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '$totalPlays songs',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
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
                      Icon(tierIcon, color: Theme.of(context).colorScheme.primary, size: 24),
                      SizedBox(height: 12),
                      Text(
                        'Vibe Tier',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        listenerTier,
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 24),

          // Peak Vibe Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Theme.of(context).colorScheme.primary, Color(0xFF333344)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.bolt_rounded, color: Colors.amber, size: 32),
                SizedBox(width: 16),
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
                      SizedBox(height: 2),
                      Text(
                        peakDay == 'None'
                            ? 'No tracks played yet'
                            : 'Your energy peaks on ${fullDayNames[peakDay]}s!',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          color: Theme.of(context).colorScheme.surface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 24),


          _buildNewWeeklyChart(),
          SizedBox(height: 24),
          _buildTopArtistObsession(),
          SizedBox(height: 24),
          _buildEraJourney(),
          SizedBox(height: 24),
          _buildWeeklyRecapButton(),
        ],
      ),
    );
  }



  Widget _buildNewWeeklyChart() {
    int maxPlay = 1;
    _weeklyPlayStats.forEach((key, value) {
      if (value > maxPlay) maxPlay = value;
    });

    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weekly Overview',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          SizedBox(height: 24),
          SizedBox(
            height: 120,
            child: Stack(
              children: [
                Positioned(
                  top: 50,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 1,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: days.map((day) {
                    final value = _weeklyPlayStats[day] ?? 0;
                    final double barHeight = (value / maxPlay) * 90;
                    final h = barHeight > 10 ? barHeight : 10.0;

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          width: 24,
                          height: h,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0xFF00E5FF),
                                Color(0xFF1DE9B6),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          day[0],
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopArtistObsession() {
    if (_artistPlayCounts.isEmpty) {
      return SizedBox.shrink(); // Don't show if no data yet
    }

    // Sort artists by play count
    final sortedArtists = _artistPlayCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Show top 10 artists or all if less than 10
    final displayArtists = sortedArtists.take(10).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Artist Obsessions',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        SizedBox(height: 16),
        SizedBox(
          height: 340,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: displayArtists.length,
            itemBuilder: (context, index) {
              final entry = displayArtists[index];
              final topArtist = entry.key;
              final maxPlays = entry.value;

              String imageAsset = 'assets/logo.png';
              final lowerArtist = topArtist.toLowerCase();
              if (lowerArtist.contains('anirudh')) {
                imageAsset = 'assets/anirudh.jpg';
              } else if (lowerArtist.contains('ar rahman') || lowerArtist.contains('a.r. rahman')) {
                imageAsset = 'assets/ar_rahman.png';
              } else if (lowerArtist.contains('yuvan')) {
                imageAsset = 'assets/yuvan.jpg';
              } else if (lowerArtist.contains('vijay antony')) {
                imageAsset = 'assets/vijay_antony.png';
              } else if (lowerArtist.contains('hiphop')) {
                imageAsset = 'assets/hiphop_tamizha.png';
              } else if (lowerArtist.contains('harris')) {
                imageAsset = 'assets/harris_jayaraj.png';
              } else if (lowerArtist.contains('gv prakash') || lowerArtist.contains('g.v. prakash')) {
                imageAsset = 'assets/gv_prakash.jpg';
              } else if (lowerArtist.contains('srikanth')) {
                imageAsset = 'assets/srikanth_deva.png';
              } else if (lowerArtist.contains('sai abhyankkar')) {
                imageAsset = 'assets/sai_abhyankkar.png';
              } else if (lowerArtist.contains('dsp') || lowerArtist.contains('devi sri prasad')) {
                imageAsset = 'assets/dsp.png';
              } else if (lowerArtist.contains('imman')) {
                imageAsset = 'assets/imman.png';
              } else if (lowerArtist.contains('arunagiri')) {
                imageAsset = 'assets/sn_arunagiri.png';
              } else if (lowerArtist.contains('ilaiyaraaja') || lowerArtist.contains('raja')) {
                imageAsset = 'assets/ilaiyaraaja.png';
              } else if (lowerArtist.contains('karthik raja')) {
                imageAsset = 'assets/karthik_raja.png';
              } else {
                for (var a in _artists) {
                  if (a['name'] == topArtist) {
                    imageAsset = a['image']!;
                    break;
                  }
                }
              }

              return Container(
                width: 280,
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      '#${index + 1} Top Artist',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    SizedBox(height: 24),
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
                            blurRadius: 20,
                            spreadRadius: 4,
                          ),
                        ],
                        image: DecorationImage(
                          image: AssetImage(imageAsset),
                          fit: BoxFit.cover,
                        ),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.surface,
                          width: 3,
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      topArtist,
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Played $maxPlays times',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEraJourney() {
    if (_eraPlayCounts.isEmpty) return SizedBox.shrink();

    int totalEraPlays = 0;
    String topEra = '';
    int topEraCount = 0;

    _eraPlayCounts.forEach((era, count) {
      totalEraPlays += count;
      if (count > topEraCount) {
        topEraCount = count;
        topEra = era;
      }
    });

    if (totalEraPlays == 0) return SizedBox.shrink();

    String title = "Music Era Journey";
    String description = "Listening across time";

    if (topEra == '90s & Below') {
      description = "Classic Soul (Mostly 90s & Before)";
    } else if (topEra == '2000s') {
      description = "You belong in the 2000s (Yuvan/Harris vibes)";
    } else if (topEra == '2010s') {
      description = "2010s Groove (Anirudh & Santhosh Narayanan hits)";
    } else if (topEra == '2020s') {
      description = "Modern Trendsetter (2020+ Bangers)";
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        SizedBox(height: 8),
        Text(
          description,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  children: [
                    if ((_eraPlayCounts['90s & Below'] ?? 0) > 0)
                      Expanded(
                        flex: _eraPlayCounts['90s & Below'] ?? 0,
                        child: Container(height: 12, color: Color(0xFFD4AF37)),
                      ),
                    if ((_eraPlayCounts['2000s'] ?? 0) > 0)
                      Expanded(
                        flex: _eraPlayCounts['2000s'] ?? 0,
                        child: Container(height: 12, color: Color(0xFFFF5E62)),
                      ),
                    if ((_eraPlayCounts['2010s'] ?? 0) > 0)
                      Expanded(
                        flex: _eraPlayCounts['2010s'] ?? 0,
                        child: Container(height: 12, color: Color(0xFF8CA6FC)),
                      ),
                    if ((_eraPlayCounts['2020s'] ?? 0) > 0)
                      Expanded(
                        flex: _eraPlayCounts['2020s'] ?? 0,
                        child: Container(height: 12, color: Color(0xFFE899A8)),
                      ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              // Legend
              Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _buildEraLegend('90s & Below', Color(0xFFD4AF37)),
                  _buildEraLegend('2000s', Color(0xFFFF5E62)),
                  _buildEraLegend('2010s', Color(0xFF8CA6FC)),
                  _buildEraLegend('2020s', Color(0xFFE899A8)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEraLegend(String label, Color color) {
    int count = _eraPlayCounts[label] ?? 0;
    if (count == 0) return SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyRecapButton() {
    return GestureDetector(
      onTap: () {
        int totalPlays = 0;
        _weeklyPlayStats.forEach((_, count) => totalPlays += count);

        String topArtist = 'Unknown';
        int topArtistCount = 0;
        _artistPlayCounts.forEach((artist, count) {
          if (count > topArtistCount) {
            topArtistCount = count;
            topArtist = artist;
          }
        });

        String topSongId = '';
        int topSongCount = 0;
        _songPlayCounts.forEach((id, count) {
          if (count > topSongCount) {
            topSongCount = count;
            topSongId = id;
          }
        });

        Map<String, dynamic>? topSong;
        if (topSongId.isNotEmpty) {
          try {
            topSong = _allSongs.firstWhere((s) => s['id']?.toString() == topSongId || s['title']?.toString() == topSongId);
          } catch (e) {
            topSong = null;
          }
        }

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => WeeklyWrappedScreen(
              totalPlays: totalPlays,
              topArtist: topArtist,
              topSong: topSong,
            ),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF833AB4), Color(0xFFFD1D1D), Color(0xFFF56040)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Color(0xFFFD1D1D).withValues(alpha: 0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Play My Weekly Recap',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Your personal story of the week',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.8),
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
              return Align(
                alignment: Alignment.topLeft,
                child: Transform.translate(
                  offset: position,
                  child: SizedBox(
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
                  ),
                ),
              );
            } else {
              return Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 84.0),
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
                      color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2A2A30) : Theme.of(context).colorScheme.primary,
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
                            SizedBox(width: 14),
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
                                            SizedBox(height: 2),
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
                                                  ) => Icon(
                                                    Icons.music_note,
                                                    size: 14,
                                                    color: Colors.white70,
                                                  ),
                                            ),
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'Vibeflow',
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
                                  SizedBox(height: 6),
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
                                      SizedBox(width: 16),
                                      GestureDetector(
                                        onTap: () {
                                          AudioService().previousSong();
                                        },
                                        child: Icon(
                                          Icons.skip_previous_rounded,
                                          color: Colors.white,
                                          size: 22,
                                        ),
                                      ),
                                      SizedBox(width: 16),
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
                                                      BoxDecoration(
                                                        shape: BoxShape.circle,
                                                          color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Theme.of(context).colorScheme.surface,
                                                      ),
                                                  child: Center(
                                                    child: isLoading
                                                        ? SizedBox(
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
                                      SizedBox(width: 16),
                                      GestureDetector(
                                        onTap: () {
                                          AudioService().nextSong();
                                        },
                                        child: Icon(
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
                        SizedBox(height: 8),
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
                                  child: ValueListenableBuilder<Color>(
                                    valueListenable: accentColorNotifier,
                                    builder: (context, accent, _) => LinearProgressIndicator(
                                      value: progress,
                                      valueColor: AlwaysStoppedAnimation<Color>(accent),
                                      backgroundColor: Colors.white12,
                                      minHeight: 2.0,
                                    ),
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
              ),
            );
          }
          },
        );
      },
    );
  }
}
