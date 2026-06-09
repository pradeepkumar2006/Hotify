import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'services/audio_service.dart';
import 'services/download_service.dart';
import 'player_screen.dart';

class OfflineMusicScreen extends StatefulWidget {
  const OfflineMusicScreen({super.key});

  @override
  State<OfflineMusicScreen> createState() => _OfflineMusicScreenState();
}

class _OfflineMusicScreenState extends State<OfflineMusicScreen> {
  ImageProvider _getImageProvider(Map<String, dynamic> song) {
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
    if (song['downloaded_cover'] != null && song['downloaded_cover'].isNotEmpty) {
      return CachedNetworkImageProvider(song['downloaded_cover']);
    } else if (song['img'] != null && song['img'].isNotEmpty) {
      return CachedNetworkImageProvider(song['img']);
    }
    return const AssetImage('assets/logo.png'); // fallback
  }

  void _playSong(Map<String, dynamic> song, List<Map<String, dynamic>> contextPlaylist) {
    AudioService().playSong(song, playlistContext: contextPlaylist);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const PlayerScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(FeatherIcons.arrowLeft, color: Theme.of(context).iconTheme.color),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Offline Music',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        centerTitle: true,
      ),
      body: ValueListenableBuilder<List<Map<String, dynamic>>>(
        valueListenable: DownloadService().downloadedSongsNotifier,
        builder: (context, downloadedSongs, child) {
          if (downloadedSongs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(FeatherIcons.downloadCloud, size: 64, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text(
                    'No downloaded songs yet.',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Download songs to listen offline!',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            physics: const BouncingScrollPhysics(),
            cacheExtent: 1000,
            padding: const EdgeInsets.only(top: 8, bottom: 80),
            itemCount: downloadedSongs.length,
            itemBuilder: (context, index) {
              final song = downloadedSongs[index];
              final title = song['title'] ?? 'Unknown';
              final artist = song['artist'] ?? 'Unknown';

              return Dismissible(
                key: ValueKey(song['id'] ?? title),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 24.0),
                  color: Colors.redAccent,
                  child: const Icon(FeatherIcons.trash2, color: Colors.white),
                ),
                onDismissed: (direction) {
                  DownloadService().deleteDownload(song);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("$title removed from downloads"), duration: const Duration(seconds: 2)),
                  );
                },
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      image: DecorationImage(
                        image: ResizeImage(_getImageProvider(song), width: 100, height: 100),
                        fit: BoxFit.cover,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  title: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  subtitle: Text(
                    artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  trailing: Icon(
                    Icons.download_done_rounded,
                    color: Colors.greenAccent,
                    size: 20,
                  ),
                  onTap: () => _playSong(song, downloadedSongs),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
