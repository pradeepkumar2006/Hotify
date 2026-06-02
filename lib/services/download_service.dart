import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class DownloadService {
  // Singleton pattern
  static final DownloadService _instance = DownloadService._internal();
  factory DownloadService() => _instance;
  DownloadService._internal();

  bool _initialized = false;
  
  // Stores the list of downloaded song metadata
  final ValueNotifier<List<Map<String, dynamic>>> downloadedSongsNotifier = ValueNotifier([]);
  
  // Tracks which song IDs are currently downloading to show progress in UI
  final ValueNotifier<Set<String>> downloadingIdsNotifier = ValueNotifier({});

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await _loadDownloads();
  }

  Future<File> _getDownloadsMetadataFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/downloads_metadata.json');
  }

  Future<void> _loadDownloads() async {
    try {
      if (kIsWeb) return;
      final file = await _getDownloadsMetadataFile();
      if (await file.exists()) {
        final decoded = json.decode(await file.readAsString());
        if (decoded is List) {
          downloadedSongsNotifier.value = decoded.map((item) => Map<String, dynamic>.from(item)).toList();
        }
      }
    } catch (e) {
      debugPrint("Error loading downloads metadata: $e");
    }
  }

  Future<void> _saveDownloads(List<Map<String, dynamic>> list) async {
    try {
      if (kIsWeb) return;
      final file = await _getDownloadsMetadataFile();
      await file.writeAsString(json.encode(list));
    } catch (e) {
      debugPrint("Error saving downloads metadata: $e");
    }
  }

  bool isDownloaded(Map<String, dynamic> song) {
    return downloadedSongsNotifier.value.any((s) => s['id'] == song['id'] || s['title'] == song['title']);
  }

  bool isDownloading(Map<String, dynamic> song) {
    return downloadingIdsNotifier.value.contains(song['id'] ?? song['title']);
  }

  /// Returns the local file path if downloaded, else null
  String? getDownloadedSongPath(Map<String, dynamic> song) {
    final list = downloadedSongsNotifier.value;
    final found = list.firstWhere(
      (s) => s['id'] == song['id'] || s['title'] == song['title'],
      orElse: () => {},
    );
    return found.isNotEmpty ? found['localPath'] as String? : null;
  }

  Future<void> downloadSong(Map<String, dynamic> song) async {
    if (kIsWeb) return;
    if (isDownloaded(song)) return; // Already downloaded
    
    final songId = song['id'] ?? song['title'] ?? DateTime.now().millisecondsSinceEpoch.toString();
    
    if (downloadingIdsNotifier.value.contains(songId)) return; // Already downloading

    // Add to downloading set
    final newSet = Set<String>.from(downloadingIdsNotifier.value);
    newSet.add(songId);
    downloadingIdsNotifier.value = newSet;

    try {
      // 1. Resolve JioSaavn URL
      final String query = "${song['title']} ${song['artist']}";
      final String searchUrl = "https://saavnapi-nine.vercel.app/song/?query=${Uri.encodeComponent(query)}";
      
      final response = await http.get(Uri.parse(searchUrl));
      if (response.statusCode != 200) {
        throw Exception("Failed to search JioSaavn");
      }
      
      final decoded = json.decode(response.body);
      if (decoded is! List || decoded.isEmpty) {
        throw Exception("No results on JioSaavn");
      }

      final bestMatch = decoded[0];
      final String? audioUrl = bestMatch['media_url'];
      final String? albumArtUrl = bestMatch['image'] as String?;

      if (audioUrl == null || audioUrl.isEmpty) {
        throw Exception("No media_url found");
      }

      // 2. Download the MP3 file
      final audioResponse = await http.get(Uri.parse(audioUrl));
      if (audioResponse.statusCode != 200) {
        throw Exception("Failed to download MP3 file");
      }

      // 3. Save to local storage
      final directory = await getApplicationDocumentsDirectory();
      // Clean filename
      final String safeTitle = (song['title'] ?? 'Unknown').replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final File localAudioFile = File('${directory.path}/$safeTitle\_$songId.mp3');
      await localAudioFile.writeAsBytes(audioResponse.bodyBytes);

      // 4. Update metadata and save
      final Map<String, dynamic> downloadedSong = Map.from(song);
      downloadedSong['localPath'] = localAudioFile.path;
      if (albumArtUrl != null) {
        downloadedSong['downloaded_cover'] = albumArtUrl; // In case we want to cache the image URL too
      }

      final list = List<Map<String, dynamic>>.from(downloadedSongsNotifier.value);
      list.add(downloadedSong);
      downloadedSongsNotifier.value = list;
      await _saveDownloads(list);

    } catch (e) {
      debugPrint("Error downloading song: $e");
      // Could show a toast or error here
    } finally {
      // Remove from downloading set
      final updatedSet = Set<String>.from(downloadingIdsNotifier.value);
      updatedSet.remove(songId);
      downloadingIdsNotifier.value = updatedSet;
    }
  }

  Future<void> deleteDownload(Map<String, dynamic> song) async {
    try {
      final list = List<Map<String, dynamic>>.from(downloadedSongsNotifier.value);
      final idx = list.indexWhere((s) => s['id'] == song['id'] || s['title'] == song['title']);
      
      if (idx != -1) {
        final removedSong = list[idx];
        final String? localPath = removedSong['localPath'];
        
        if (localPath != null) {
          final file = File(localPath);
          if (await file.exists()) {
            await file.delete();
          }
        }
        
        list.removeAt(idx);
        downloadedSongsNotifier.value = list;
        await _saveDownloads(list);
      }
    } catch (e) {
      debugPrint("Error deleting download: $e");
    }
  }
}
