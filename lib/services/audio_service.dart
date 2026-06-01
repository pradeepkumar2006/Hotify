import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart' as audio_service_pkg;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

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

    player.positionStream.listen((pos) {
      positionNotifier.value = pos;
    });

    player.durationStream.listen((dur) {
      durationNotifier.value = dur ?? Duration.zero;
    });
  }

  final AudioPlayer player = AudioPlayer();
  
  final ValueNotifier<Map<String, dynamic>?> currentSongNotifier = ValueNotifier<Map<String, dynamic>?>(null);
  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<Duration> positionNotifier = ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<Duration> durationNotifier = ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<bool> isLoadingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<List<Map<String, dynamic>>> likedSongsNotifier = ValueNotifier<List<Map<String, dynamic>>>([]);

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
          likedSongsNotifier.value = decoded.map((item) => Map<String, dynamic>.from(item)).toList();
        }
      }
    } catch (e) {
      debugPrint("Error loading liked songs: $e");
    }
  }

  bool isSongLiked(Map<String, dynamic> song) {
    return likedSongsNotifier.value.any((s) => s['id'] == song['id'] || s['title'] == song['title']);
  }

  void toggleLikeSong(Map<String, dynamic> song) {
    final list = List<Map<String, dynamic>>.from(likedSongsNotifier.value);
    final idx = list.indexWhere((s) => s['id'] == song['id'] || s['title'] == song['title']);
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
    debugPrint('🔔 audio_service initialized – notification should now appear');
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

    playbackState.add(audio_service_pkg.PlaybackState(
      controls: [
        audio_service_pkg.MediaControl.skipToPrevious,
        playing ? audio_service_pkg.MediaControl.pause : audio_service_pkg.MediaControl.play,
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
    ));
  }

  Future<void> playSong(Map<String, dynamic> song, {List<Map<String, dynamic>>? playlistContext}) async {
    if (playlistContext != null && playlistContext.isNotEmpty) {
      _playlist = playlistContext;
      _currentIndex = _playlist.indexWhere((s) => s['id'] == song['id'] || s['title'] == song['title']);
    } else {
      // Check if song is already in the current playlist
      final idx = _playlist.indexWhere((s) => s['id'] == song['id'] || s['title'] == song['title']);
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
    
    try {
      // 1. Search for song on JioSaavn API to get streamable MP3 URL
      final String query = "${song['title']} ${song['artist']}";
      final String searchUrl = "https://saavnapi-nine.vercel.app/song/?query=${Uri.encodeComponent(query)}";
      
      final response = await http.get(Uri.parse(searchUrl));
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is List && decoded.isNotEmpty) {
          final bestMatch = decoded[0];
          final String? audioUrl = bestMatch['media_url'];
          
          if (audioUrl != null && audioUrl.isNotEmpty) {
            // Set the audio source and play
            await setMediaItem(song);
            await player.setUrl(audioUrl);
            player.play();
            isLoadingNotifier.value = false;
            return;
          }
        }
      }
      
      throw Exception("Could not find streamable link for $query on JioSaavn");
    } catch (e) {
      isLoadingNotifier.value = false;
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
  Future<void> setMediaItem(Map<String, dynamic> song) async {
    final mediaItem = audio_service_pkg.MediaItem(
      id: song['id']?.toString() ?? '',
      title: song['title'] ?? '',
      artist: song['artist'] ?? '',
      artUri: song['cover'] != null ? Uri.parse(song['cover']) : null,
      duration: song['duration'] != null ? Duration(milliseconds: song['duration']) : Duration.zero,
    );
    this.mediaItem.add(mediaItem);
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
}
