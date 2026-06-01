import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';

class AudioService {
  // Singleton pattern
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioPlayer player = AudioPlayer();
  
  final ValueNotifier<Map<String, dynamic>?> currentSongNotifier = ValueNotifier<Map<String, dynamic>?>(null);
  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<Duration> positionNotifier = ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<Duration> durationNotifier = ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<bool> isLoadingNotifier = ValueNotifier<bool>(false);

  bool _initialized = false;
  
  List<Map<String, dynamic>> _playlist = [];
  int _currentIndex = -1;

  List<Map<String, dynamic>> get playlist => _playlist;
  int get currentIndex => _currentIndex;

  void init() {
    if (_initialized) return;
    _initialized = true;
    
    player.playerStateStream.listen((state) {
      isPlayingNotifier.value = state.playing;
      
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

  void seek(Duration position) {
    player.seek(position);
  }

  void dispose() {
    player.dispose();
  }
}
