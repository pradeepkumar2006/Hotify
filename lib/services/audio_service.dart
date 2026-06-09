import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart' as audio_service_pkg;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'download_service.dart';
import 'song_matcher.dart';

class AudioService extends audio_service_pkg.BaseAudioHandler {
  // Singleton pattern
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal() {
    // Set up player stream listeners immediately in constructor
    // so they work regardless of whether init() is awaited
    player.playerStateStream.listen((state) {
      isPlayingNotifier.value = state.playing;
      _broadcastPlaybackState();

      // Auto play next song when current song completes
      if (state.processingState == ProcessingState.completed) {
        nextSong();
      }
    });

    // Throttle position updates to once per second — the progress bar only
    // needs 1Hz resolution for a smooth, non-janky experience.
    // just_audio fires ~5Hz by default; reducing this cuts ~80% of slider rebuilds.
    Duration lastPosition = Duration.zero;
    player.positionStream.listen((pos) {
      // Only update if position changed by ≥ 500ms to avoid micro-rebuilds
      if ((pos - lastPosition).abs() >= const Duration(milliseconds: 500)) {
        lastPosition = pos;
        positionNotifier.value = pos;
      }
    });

    player.durationStream.listen((dur) {
      durationNotifier.value = dur ?? Duration.zero;
    });
  }

  final AudioPlayer player = AudioPlayer();

  final ValueNotifier<Map<String, dynamic>?> currentSongNotifier =
      ValueNotifier<Map<String, dynamic>?>(null);
  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<Duration> positionNotifier = ValueNotifier<Duration>(
    Duration.zero,
  );
  final ValueNotifier<Duration> durationNotifier = ValueNotifier<Duration>(
    Duration.zero,
  );
  final ValueNotifier<bool> isLoadingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<List<Map<String, dynamic>>> likedSongsNotifier =
      ValueNotifier<List<Map<String, dynamic>>>([]);
  final ValueNotifier<List<Map<String, dynamic>>> recentSongsNotifier =
      ValueNotifier<List<Map<String, dynamic>>>([]);
  final ValueNotifier<List<Map<String, dynamic>>> userPlaylistsNotifier =
      ValueNotifier<List<Map<String, dynamic>>>([]);
  final ValueNotifier<String?> errorNotifier = ValueNotifier<String?>(null);

  bool _initialized = false;

  List<Map<String, dynamic>> _playlist = [];
  int _currentIndex = -1;

  List<Map<String, dynamic>> get playlist => _playlist;
  int get currentIndex => _currentIndex;

  Future<File> _getLikedFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/liked_songs.json');
  }

  Future<void> _saveLiked(List<Map<String, dynamic>> list) async {
    try {
      final file = await _getLikedFile();
      await file.writeAsString(json.encode(list));
    } catch (e) {
      debugPrint("Error saving liked songs: $e");
    }
  }

  Future<void> _loadLiked() async {
    try {
      final file = await _getLikedFile();
      if (await file.exists()) {
        final decoded = json.decode(await file.readAsString());
        if (decoded is List) {
          likedSongsNotifier.value = decoded
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
        }
      }
    } catch (e) {
      debugPrint("Error loading liked songs: $e");
    }
  }

  Future<File> _getRecentFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/recent_songs.json');
  }

  Future<void> _saveRecent() async {
    try {
      final file = await _getRecentFile();
      await file.writeAsString(json.encode(recentSongsNotifier.value));
    } catch (e) {
      debugPrint("Error saving recent songs: $e");
    }
  }

  Future<void> _loadRecent() async {
    try {
      final file = await _getRecentFile();
      if (await file.exists()) {
        final decoded = json.decode(await file.readAsString());
        if (decoded is List) {
          recentSongsNotifier.value = decoded
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
        }
      }
    } catch (e) {
      debugPrint("Error loading recent songs: $e");
    }
  }

  void _addRecentSong(Map<String, dynamic> song) {
    final list = List<Map<String, dynamic>>.from(recentSongsNotifier.value);
    list.removeWhere((s) => s['id'] == song['id'] || s['title'] == song['title']);
    list.insert(0, song);
    if (list.length > 20) {
      list.removeLast();
    }
    recentSongsNotifier.value = list;
    _saveRecent();
  }

  Future<File> _getUserPlaylistsFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/playlists.json');
  }

  Future<void> saveUserPlaylists(List<Map<String, dynamic>> playlists) async {
    userPlaylistsNotifier.value = List.from(playlists);
    try {
      final file = await _getUserPlaylistsFile();
      await file.writeAsString(json.encode(playlists));
    } catch (e) {
      debugPrint("Error saving custom playlists: $e");
    }
  }

  Future<void> loadUserPlaylists() async {
    try {
      final file = await _getUserPlaylistsFile();
      if (await file.exists()) {
        final decoded = json.decode(await file.readAsString());
        if (decoded is List) {
          userPlaylistsNotifier.value = decoded
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
        }
      }
    } catch (e) {
      debugPrint("Error loading custom playlists: $e");
    }
  }

  bool isSongLiked(Map<String, dynamic> song) {
    return likedSongsNotifier.value.any(
      (s) => s['id'] == song['id'] || s['title'] == song['title'],
    );
  }

  void toggleLikeSong(Map<String, dynamic> song) {
    final list = List<Map<String, dynamic>>.from(likedSongsNotifier.value);
    final idx = list.indexWhere(
      (s) => s['id'] == song['id'] || s['title'] == song['title'],
    );
    if (idx != -1) {
      list.removeAt(idx);
    } else {
      list.add(song);
    }
    likedSongsNotifier.value = list;
    _saveLiked(list);
  }

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    _loadLiked();
    _loadRecent();
    await loadUserPlaylists();
    await DownloadService().init();
    // Initialise audio_service with notification config – MUST be awaited
    await audio_service_pkg.AudioService.init(
      builder: () => this,
      config: audio_service_pkg.AudioServiceConfig(
        androidNotificationChannelId: 'media_playback_channel',
        androidNotificationChannelName: 'Media Playback',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
        androidShowNotificationBadge: true,
        androidNotificationIcon: 'mipmap/ic_launcher',
      ),
    );
    debugPrint('audio_service initialized – notification should now appear');
  }

  /// Broadcasts the current playback state to the audio_service notification
  void _broadcastPlaybackState() {
    final playing = player.playing;
    final processingState = player.processingState;

    // Map just_audio ProcessingState to audio_service AudioProcessingState
    audio_service_pkg.AudioProcessingState audioProcessingState;
    switch (processingState) {
      case ProcessingState.idle:
        audioProcessingState = audio_service_pkg.AudioProcessingState.idle;
        break;
      case ProcessingState.loading:
        audioProcessingState = audio_service_pkg.AudioProcessingState.loading;
        break;
      case ProcessingState.buffering:
        audioProcessingState = audio_service_pkg.AudioProcessingState.buffering;
        break;
      case ProcessingState.ready:
        audioProcessingState = audio_service_pkg.AudioProcessingState.ready;
        break;
      case ProcessingState.completed:
        audioProcessingState = audio_service_pkg.AudioProcessingState.completed;
        break;
    }

    playbackState.add(
      audio_service_pkg.PlaybackState(
        controls: [
          audio_service_pkg.MediaControl.skipToPrevious,
          playing
              ? audio_service_pkg.MediaControl.pause
              : audio_service_pkg.MediaControl.play,
          audio_service_pkg.MediaControl.skipToNext,
        ],
        systemActions: const {
          audio_service_pkg.MediaAction.seek,
          audio_service_pkg.MediaAction.seekForward,
          audio_service_pkg.MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: audioProcessingState,
        playing: playing,
        updatePosition: player.position,
        bufferedPosition: player.bufferedPosition,
        speed: player.speed,
      ),
    );
  }

  Future<void> playSong(
    Map<String, dynamic> song, {
    List<Map<String, dynamic>>? playlistContext,
  }) async {
    if (playlistContext != null && playlistContext.isNotEmpty) {
      _playlist = playlistContext;
      _currentIndex = _playlist.indexWhere(
        (s) => s['id'] == song['id'] || s['title'] == song['title'],
      );
    } else {
      // Check if song is already in the current playlist
      final idx = _playlist.indexWhere(
        (s) => s['id'] == song['id'] || s['title'] == song['title'],
      );
      if (idx != -1) {
        _currentIndex = idx;
      } else {
        // Fallback: single item playlist
        _playlist = [song];
        _currentIndex = 0;
      }
    }

    currentSongNotifier.value = song;
    isLoadingNotifier.value = true;
    errorNotifier.value = null;

    _addRecentSong(song);

    try {
      // Check if song is downloaded
      final String? localPath = DownloadService().getDownloadedSongPath(song);
      if (localPath != null && File(localPath).existsSync()) {
        debugPrint("Playing downloaded song from local path: $localPath");
        await player.setFilePath(localPath);
        player.play();
        isLoadingNotifier.value = false;

        // Update notification metadata
        await setMediaItem(
          song,
          artUrl: song['downloaded_cover'] ?? song['img'],
        );
        return;
      }

      // 1. Search for song on JioSaavn API to get streamable MP3 URL
      String cleanTitle = SongMatcher.cleanString(song['title'] ?? '');
      String cleanMovie = SongMatcher.cleanString(song['movie'] ?? '');
      String cleanArtist = SongMatcher.cleanString(
        song['composer'] ?? song['artist'] ?? '',
      );

      String specificQuery = "";
      if (cleanMovie.isNotEmpty) {
        specificQuery = "$cleanTitle $cleanMovie".trim();
      }
      String fallbackQuery = "$cleanTitle $cleanArtist".trim();
      String simpleQuery = cleanTitle.trim();

      List<String> queriesToTry = [
        specificQuery,
        fallbackQuery,
        simpleQuery,
      ].where((q) => q.isNotEmpty).toSet().toList();

      dynamic bestMatch;
      dynamic firstFallbackResult;
      String expectedLanguage = (song['language'] ?? 'tamil')
          .toString()
          .toLowerCase();

      for (String query in queriesToTry) {
        final String searchUrl =
            "https://saavnapi-nine.vercel.app/song/?query=${Uri.encodeComponent(query)}";
        try {
          final response = await http.get(Uri.parse(searchUrl));
          if (response.statusCode == 200) {
            final decoded = json.decode(response.body);
            List<dynamic> results = [];
            if (decoded is List) {
              results = decoded;
            } else if (decoded is Map && decoded['value'] is List) {
              results = decoded['value'];
            }

            if (results.isNotEmpty) {
              firstFallbackResult ??= results.first;
              bestMatch = SongMatcher.findBestMatch(
                results,
                targetTitle: song['title'] ?? '',
                targetMovie: song['movie'] ?? '',
                targetArtist: song['artist'] ?? '',
                targetSinger: song['singer'] ?? song['singers'] ?? '',
                expectedLanguage: expectedLanguage,
              );
              if (bestMatch != null) {
                break; // Found a strict/good similarity match!
              }
            }
          }
        } catch (e) {
          debugPrint("Search error for query $query: $e");
        }
      }

      bestMatch ??= firstFallbackResult;

      if (bestMatch != null) {
        final String? audioUrl = bestMatch['media_url'];
        final String? albumArtUrl = bestMatch['image'] as String?;
        final songDuration = bestMatch['duration'] != null
            ? Duration(
                seconds: int.tryParse(bestMatch['duration'].toString()) ?? 0,
              )
            : Duration.zero;

        if (audioUrl != null && audioUrl.isNotEmpty) {
          await setMediaItem(
            song,
            artUrl: albumArtUrl,
            songDuration: songDuration,
          );
          await player.setUrl(audioUrl);
          player.play();
          isLoadingNotifier.value = false;
          return;
        }
      }

      throw Exception(
        "Could not find streamable link for ${song['title']} on JioSaavn",
      );
    } catch (e) {
      isLoadingNotifier.value = false;
      errorNotifier.value =
          "Could not play: '${song['title']}' (No clean match found)";
      debugPrint("Audio play error: $e");
    }
  }

  void nextSong() {
    if (_playlist.isEmpty || _currentIndex == -1) return;
    _currentIndex = (_currentIndex + 1) % _playlist.length;
    playSong(_playlist[_currentIndex]);
  }

  void previousSong() {
    if (_playlist.isEmpty || _currentIndex == -1) return;
    _currentIndex = (_currentIndex - 1 + _playlist.length) % _playlist.length;
    playSong(_playlist[_currentIndex]);
  }

  void togglePlay() {
    if (player.playing) {
      player.pause();
    } else {
      player.play();
    }
  }

  @override
  Future<void> seek(Duration position) async {
    player.seek(position);
  }

  void dispose() {
    player.dispose();
  }

  // Helper to update media item for notification
  Future<void> setMediaItem(
    Map<String, dynamic> song, {
    String? artUrl,
    Duration? songDuration,
  }) async {
    final baseItem = audio_service_pkg.MediaItem(
      id: song['id']?.toString() ?? '',
      title: song['title'] ?? '',
      artist: song['artist'] ?? '',
      duration: songDuration ??
          (song['duration'] != null
              ? Duration(milliseconds: song['duration'])
              : Duration.zero),
    );
    
    // Publish immediately without artUri to prevent Java-side ANR
    mediaItem.add(baseItem);

    // Asynchronously fetch artwork in Dart (which is safe)
    String? imageUrl = artUrl;
    if (imageUrl == null || imageUrl.isEmpty) {
      if (song['cover'] != null && song['cover'].toString().startsWith('http')) {
        imageUrl = song['cover'];
      }
    }

    if (imageUrl != null && imageUrl.isNotEmpty) {
      try {
        final directory = await getTemporaryDirectory();
        final file = File('${directory.path}/cover_${song['id'] ?? DateTime.now().millisecondsSinceEpoch}.jpg');
        
        if (!file.existsSync()) {
          final response = await http.get(Uri.parse(imageUrl));
          if (response.statusCode == 200) {
            await file.writeAsBytes(response.bodyBytes);
          }
        }
        
        if (file.existsSync()) {
          // Update the notification with the local file URI (no blocking!)
          mediaItem.add(baseItem.copyWith(artUri: Uri.file(file.path)));
        }
      } catch (e) {
        debugPrint("Error fetching artwork: $e");
      }
    }
  }

  // Implement required AudioHandler methods
  @override
  Future<void> play() async {
    await player.play();
  }

  @override
  Future<void> pause() async {
    await player.pause();
  }

  @override
  Future<void> stop() async {
    await player.stop();
    await super.stop();
  }

  @override
  Future<void> skipToNext() async {
    nextSong();
  }

  @override
  Future<void> skipToPrevious() async {
    previousSong();
  }

  /// Called when the user swipes the app away from recents.
  /// Stops playback and removes the notification automatically.
  @override
  Future<void> onTaskRemoved() async {
    await player.stop();
    await super.stop();
  }

  bool _isTtsPlaying = false;

  /// Plays a text-to-speech message using a temporary AudioPlayer.
  /// Pauses the main player if it's currently playing, and resumes it once done.
  Future<void> playTts(String text) async {
    if (_isTtsPlaying) return;
    _isTtsPlaying = true;

    AudioPlayer? ttsPlayer;
    try {
      ttsPlayer = AudioPlayer();

      final bool wasPlaying = player.playing;
      if (wasPlaying) {
        await player.pause();
      }

      if (text.toLowerCase() == "hello melophile") {
        // Load and play the pre-generated offline Siri voice asset
        await ttsPlayer.setAsset('assets/hello_melophile_siri.mp3');
      } else {
        // Fallback to online voice streaming
        final String ttsUrl =
            'https://translate.google.com/translate_tts?ie=UTF-8&tl=en&client=tw-ob&q=${Uri.encodeComponent(text)}';
        await ttsPlayer.setUrl(ttsUrl);
      }

      await ttsPlayer.play();

      if (wasPlaying) {
        await player.play();
      }
    } catch (e) {
      debugPrint("Error playing TTS: $e");
    } finally {
      if (ttsPlayer != null) {
        await ttsPlayer.dispose();
      }
      _isTtsPlaying = false;
    }
  }

  Future<List<Map<String, dynamic>>> searchJioSaavn(String query) async {
    if (query.trim().isEmpty) return [];
    
    final String searchUrl = "https://saavnapi-nine.vercel.app/song/?query=${Uri.encodeComponent(query)}";
    try {
      final response = await http.get(Uri.parse(searchUrl));
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        List<dynamic> results = [];
        if (decoded is List) {
          results = decoded;
        } else if (decoded is Map && decoded['value'] is List) {
          results = decoded['value'];
        }

        return results.map((result) {
          return {
            'id': result['id']?.toString() ?? '',
            'title': result['song'] ?? result['title'] ?? 'Unknown Title',
            'artist': result['primary_artists'] ?? result['singers'] ?? 'Unknown Artist',
            'movie': result['album'] ?? '',
            'img': result['image'] ?? '',
            'src': result['media_url'] ?? '',
            'language': result['language'] ?? 'hindi',
            'year': result['year']?.toString() ?? '',
            'duration': int.tryParse(result['duration']?.toString() ?? '0') ?? 0,
          };
        }).toList();
      }
    } catch (e) {
      debugPrint("Search error: $e");
    }
    return [];
  }
}
