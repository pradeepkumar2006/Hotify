import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:screenshot/screenshot.dart';
import 'login_screen.dart';
import 'utils/theme_notifier.dart';
import 'help_support_screen.dart';
import 'dart:math';
import 'services/audio_service.dart';
import 'services/download_service.dart';

class ProfileScreen extends StatefulWidget {
  final int playlistsCount;
  final int favoritesCount;
  final Map<String, int> weeklyPlayStats;

  const ProfileScreen({
    super.key,
    required this.playlistsCount,
    required this.favoritesCount,
    required this.weeklyPlayStats,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();

  String? _profileImagePath;
  int _playlistCount = 0;
  int _favoriteCount = 0;
  String _listeningMinutesStr = '0';
  String _audioQuality = 'Standard Quality';
  String _downloadQuality = 'Standard';
  bool _gaplessPlayback = false;
  String _cacheSize = "Calculating...";
  String _downloadsSize = "Calculating...";

  @override
  void initState() {
    super.initState();
    _loadProfileData();
    _setActivityStats();
    _calculateStorage();
  }

  Future<void> _calculateStorage() async {
    final tempDir = await getTemporaryDirectory();
    int tempSize = await _getDirSize(tempDir);
    int mp3Size = await DownloadService().getTotalDownloadsSize();

    if (mounted) {
      setState(() {
        _cacheSize = _formatBytes(tempSize);
        _downloadsSize = _formatBytes(mp3Size);
      });
    }
  }

  Future<int> _getDirSize(Directory dir) async {
    int size = 0;
    try {
      if (await dir.exists()) {
        dir.listSync(recursive: true).forEach((file) {
          if (file is File) size += file.lengthSync();
        });
      }
    } catch (_) {}
    return size;
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }

  Future<void> _clearCache() async {
    final tempDir = await getTemporaryDirectory();
    try {
      if (await tempDir.exists()) {
        tempDir.listSync(recursive: true).forEach((file) {
          if (file is File) file.deleteSync();
        });
      }
      await _calculateStorage();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cache cleared successfully!')));
    } catch (_) {}
  }

  Future<void> _clearDownloads() async {
    await DownloadService().clearAllDownloads();
    await _calculateStorage();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('All downloaded songs wiped!')));
  }

  void _resetHistory() {
    AudioService().recentSongsNotifier.value = [];
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Listening history reset!')));
  }

  Future<void> _deleteAccount() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text('Delete Account?', style: GoogleFonts.outfit(color: Colors.white)),
        content: Text('This action cannot be undone. All your playlists, favorites, and history will be lost.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (Firebase.apps.isNotEmpty) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          try {
            await user.delete();
          } catch (e) {
             debugPrint("Could not delete from firebase: $e");
          }
        }
      }
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  void _setActivityStats() {
    int totalPlays = 0;
    widget.weeklyPlayStats.forEach((key, value) {
      totalPlays += value;
    });
    
    // Assume average song played is 3 minutes
    final int totalMinutes = totalPlays * 3;
    String minutesStr = totalMinutes.toString();
    if (totalMinutes >= 1000) {
      minutesStr = '${(totalMinutes / 1000).toStringAsFixed(1)}k';
    }
    
    setState(() {
      _playlistCount = widget.playlistsCount;
      _favoriteCount = widget.favoritesCount;
      _listeningMinutesStr = minutesStr;
    });
  }

  Future<File> _getProfileFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/profile_info.json');
  }

  Future<void> _loadProfileData() async {
    try {
      if (kIsWeb) return; // File system not supported on web
      final file = await _getProfileFile();
      if (await file.exists()) {
        final decoded = json.decode(await file.readAsString());
        if (decoded is Map) {
          setState(() {
            if (decoded.containsKey('profileImagePath')) {
              _profileImagePath = decoded['profileImagePath'];
            }
            if (decoded.containsKey('audioQuality')) _audioQuality = decoded['audioQuality'];
            if (decoded.containsKey('downloadQuality')) _downloadQuality = decoded['downloadQuality'];
            if (decoded.containsKey('gaplessPlayback')) _gaplessPlayback = decoded['gaplessPlayback'];
          });
        }
      }
    } catch (e) {
      debugPrint("Error loading profile info: $e");
    }
  }

  Future<void> _saveProfileData(String path) async {
    try {
      if (kIsWeb) return; // File system not supported on web
      final file = await _getProfileFile();
      await file.writeAsString(json.encode({
        'profileImagePath': _profileImagePath,
        'audioQuality': _audioQuality,
        'downloadQuality': _downloadQuality,
        'gaplessPlayback': _gaplessPlayback,
      }));
    } catch (e) {
      debugPrint("Error saving profile info: $e");
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        String savedPath = pickedFile.path;
        if (!kIsWeb) {
          // On mobile/desktop, copy file to app directory for permanent storage
          final directory = await getApplicationDocumentsDirectory();
          final File imageFile = File(pickedFile.path);
          final String extension = pickedFile.path.split('.').last;
          final String targetPath = '${directory.path}/profile_avatar.$extension';
          final File localImage = await imageFile.copy(targetPath);
          savedPath = localImage.path;
        }
        setState(() {
          _profileImagePath = savedPath;
        });
        await _saveProfileData(savedPath);
        
        // Also update firebase if user is logged in
        final User? currentUser = Firebase.apps.isNotEmpty ? FirebaseAuth.instance.currentUser : null;
        if (currentUser != null) {
          try {
            await currentUser.updatePhotoURL(savedPath);
          } catch (firebaseErr) {
            debugPrint("Could not update firebase photoUrl: $firebaseErr");
          }
        }
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  ImageProvider? _getAvatarProvider() {
    if (_profileImagePath == null || _profileImagePath!.isEmpty) {
      // Check if firebase user has photoUrl
      final User? currentUser = Firebase.apps.isNotEmpty ? FirebaseAuth.instance.currentUser : null;
      if (currentUser?.photoURL != null && currentUser!.photoURL!.isNotEmpty) {
        final String photoUrl = currentUser.photoURL!;
        if (photoUrl.startsWith('http') || photoUrl.startsWith('blob:')) {
          return NetworkImage(photoUrl);
        } else if (!kIsWeb) {
          return FileImage(File(photoUrl));
        }
      }
      return null;
    }
    
    if (kIsWeb || _profileImagePath!.startsWith('http') || _profileImagePath!.startsWith('blob:')) {
      return NetworkImage(_profileImagePath!);
    } else {
      return FileImage(File(_profileImagePath!));
    }
  }

  Widget _buildAvatarWidget() {
    final provider = _getAvatarProvider();
    if (provider != null) {
      return Image(
        image: provider,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Icon(
            FeatherIcons.user,
            size: 48,
            color: Color(0xFF1E1E24),
          );
        },
      );
    }
    return Icon(
      FeatherIcons.user,
      size: 48,
      color: Color(0xFF1E1E24),
    );
  }

  void _showImageSourceActionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Change Profile Image',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              SizedBox(height: 20),
              ListTile(
                leading: Icon(Icons.photo_library_rounded, color: Theme.of(context).iconTheme.color),
                title: Text('Choose from Gallery', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Icon(Icons.camera_alt_rounded, color: Theme.of(context).iconTheme.color),
                title: Text('Take a Photo', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? currentUser = Firebase.apps.isNotEmpty ? FirebaseAuth.instance.currentUser : null;
    final String displayName = currentUser?.displayName ?? 'Music Lover';
    final String email = currentUser?.email ?? 'music@vibeflow.com';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(FeatherIcons.arrowLeft, color: Theme.of(context).iconTheme.color),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Profile',
          style: GoogleFonts.outfit(
            color: Theme.of(context).textTheme.bodyLarge?.color,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Avatar card
            Center(
              child: Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 115,
                        height: 115,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).colorScheme.surface,
                          border: Border.all(color: Colors.grey.withValues(alpha: 0.2), width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 12,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(4),
                        child: ClipOval(
                          child: Container(
                            color: Theme.of(context).colorScheme.secondary,
                            child: _buildAvatarWidget(),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _showImageSourceActionSheet,
                          child: Container(
                            height: 34,
                            width: 34,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1E24),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.camera_alt_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Text(
                    displayName,
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    email,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
                    ),
                  ),
                  SizedBox(height: 12),
                  // Premium Tag
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'PREMIUM MEMBER',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Theme.of(context).colorScheme.onSecondary,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 36),

            // Statistics Section
            Text(
              'Your Activity',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    value: _playlistCount.toString(),
                    label: 'Playlists',
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    value: _favoriteCount.toString(),
                    label: 'Favorites',
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    value: _listeningMinutesStr,
                    label: 'Minutes',
                  ),
                ),
              ],
            ),
            SizedBox(height: 36),

            // 1. Audio & Data Usage
            _buildSectionHeader('AUDIO & DATA'),
            Container(
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  _buildListTile(
                    icon: FeatherIcons.radio,
                    title: 'Streaming Quality',
                    onTap: _showAudioQualityBottomSheet,
                    trailing: Text(_audioQuality, style: GoogleFonts.inter(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54))),
                  ),
                  Divider(height: 1, indent: 56, color: Colors.grey.withValues(alpha: 0.2)),
                  _buildListTile(
                    icon: FeatherIcons.downloadCloud,
                    title: 'Download Quality',
                    onTap: _showDownloadQualityBottomSheet,
                    trailing: Text(_downloadQuality, style: GoogleFonts.inter(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54))),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),

            // 2. Storage Management
            _buildSectionHeader('STORAGE'),
            Container(
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  _buildListTile(
                    icon: FeatherIcons.trash2,
                    title: 'Clear Cache',
                    onTap: _clearCache,
                    trailing: Text(_cacheSize, style: GoogleFonts.inter(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54))),
                  ),
                  Divider(height: 1, indent: 56, color: Colors.grey.withValues(alpha: 0.2)),
                  _buildListTile(
                    icon: FeatherIcons.folderMinus,
                    title: 'Clear Downloaded Songs',
                    onTap: _clearDownloads,
                    trailing: Text(_downloadsSize, style: GoogleFonts.inter(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54))),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),

            // 3. Playback Preferences
            _buildSectionHeader('PLAYBACK'),
            Container(
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(FeatherIcons.fastForward, color: Theme.of(context).iconTheme.color, size: 20),
                    title: Text('Gapless Playback', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Theme.of(context).textTheme.bodyLarge?.color)),
                    trailing: Switch(
                      value: _gaplessPlayback,
                      onChanged: (val) async {
                        setState(() => _gaplessPlayback = val);
                        await _saveProfileData(_profileImagePath ?? '');
                      },
                      activeThumbColor: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  Divider(height: 1, indent: 56, color: Colors.grey.withValues(alpha: 0.2)),
                  _buildListTile(
                    icon: FeatherIcons.refreshCcw,
                    title: 'Reset Listening History',
                    onTap: _resetHistory,
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),

            // 4. App Personalization
            _buildSectionHeader('PERSONALIZATION'),
            Container(
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  ValueListenableBuilder<ThemeMode>(
                    valueListenable: themeNotifier,
                    builder: (context, themeMode, _) {
                      return ListTile(
                        leading: Icon(FeatherIcons.moon, color: Theme.of(context).iconTheme.color, size: 20),
                        title: Text('Dark Mode', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Theme.of(context).textTheme.bodyLarge?.color)),
                        trailing: Switch(
                          value: themeMode == ThemeMode.dark,
                          onChanged: (_) => toggleTheme(),
                          activeThumbColor: Theme.of(context).colorScheme.primary,
                        ),
                      );
                    },
                  ),
                  Divider(height: 1, indent: 56, color: Colors.grey.withValues(alpha: 0.2)),
                  _buildColorPicker(),
                  Divider(height: 1, indent: 56, color: Colors.grey.withValues(alpha: 0.2)),
                  _buildListTile(
                    icon: FeatherIcons.smartphone,
                    title: 'Change App Icon',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('App Icon selection coming soon!')));
                    },
                  ),
                  Divider(height: 1, indent: 56, color: Colors.grey.withValues(alpha: 0.2)),
                  _buildListTile(
                    icon: FeatherIcons.clock,
                    title: 'Sleep Timer',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sleep timer coming soon!')));
                    },
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),

            // 5. Help & Support
            _buildSectionHeader('SUPPORT'),
            Container(
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(16)),
              child: _buildListTile(
                icon: FeatherIcons.helpCircle,
                title: 'Help & Support',
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const HelpSupportScreen()));
                },
              ),
            ),
            SizedBox(height: 40),
            
            // Share My Stats Button
            Center(
              child: ValueListenableBuilder<Color>(
                valueListenable: accentColorNotifier,
                builder: (context, accentColor, _) => ElevatedButton.icon(
                  onPressed: _shareMyStats,
                  icon: Icon(FeatherIcons.instagram, size: 18),
                  label: Text('Share My Stats', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.black,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ),
            ),
            SizedBox(height: 40),

            // Logout Button
            OutlinedButton(
              onPressed: () async {
                if (Firebase.apps.isNotEmpty) await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
                }
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.redAccent, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                foregroundColor: Colors.redAccent,
              ),
              child: Text('LOG OUT', style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            ),
            SizedBox(height: 16),
            
            // Delete Account Button
            TextButton(
              onPressed: _deleteAccount,
              child: Text('DELETE ACCOUNT', style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.redAccent.withValues(alpha: 0.7), letterSpacing: 1.2)),
            ),
            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildColorPicker() {
    final colors = [
      Color(0xFFE5B3B3), // Peach
      Color(0xFF00FFCC), // Neon Green
      Color(0xFF00A2FF), // Ocean Blue
      Color(0xFF8A2BE2), // Deep Purple
    ];
    return ValueListenableBuilder<Color>(
      valueListenable: accentColorNotifier,
      builder: (context, currentAccent, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Accent Color', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Theme.of(context).textTheme.bodyLarge?.color)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: colors.map((color) {
                  final isSelected = currentAccent == color;
                  return GestureDetector(
                    onTap: () {
                      updateAccentColor(color);
                    },
                    child: Container(
                      margin: EdgeInsets.only(left: 12),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected ? Border.all(color: Colors.white, width: 2) : Border.all(color: Colors.black12, width: 1),
                        boxShadow: isSelected ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8)] : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _shareMyStats() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generating story...')));
      
      final image = await _screenshotController.captureFromWidget(
        _buildShareStoryWidget(),
        delay: const Duration(milliseconds: 100),
      );
      
      final directory = await getTemporaryDirectory();
      final imagePath = await File('${directory.path}/my_stats.png').create();
      await imagePath.writeAsBytes(image);
      
      await SharePlus.instance.share(ShareParams(
        files: [XFile(imagePath.path)],
        text: 'Check out my listening stats on Vibeflow! 🎵',
      ));
    } catch (e) {
      debugPrint('Error sharing stats: $e');
    }
  }

  Widget _buildShareStoryWidget() {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          width: 360,
          height: 640,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFF1E1E24), accentColorNotifier.value.withValues(alpha: 0.5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_profileImagePath != null && _profileImagePath!.isNotEmpty)
                ClipOval(child: Image.file(File(_profileImagePath!), width: 100, height: 100, fit: BoxFit.cover))
              else
                CircleAvatar(radius: 50, backgroundColor: Colors.white24, child: Icon(Icons.person, size: 50, color: Colors.white)),
              SizedBox(height: 24),
              Text('MY VIBEFLOW VIBE', style: GoogleFonts.montserrat(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2)),
              SizedBox(height: 40),
              _buildStoryStat('MINUTES PLAYED', _listeningMinutesStr),
              SizedBox(height: 24),
              _buildStoryStat('FAVORITES', _favoriteCount.toString()),
              SizedBox(height: 24),
              _buildStoryStat('PLAYLISTS', _playlistCount.toString()),
              SizedBox(height: 40),
              Text('🔥 Vibeflow Open Audio 🔥', style: GoogleFonts.inter(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStoryStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.outfit(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white)),
        Text(label, style: GoogleFonts.inter(fontSize: 14, color: Colors.white70, letterSpacing: 1.5)),
      ],
    );
  }

  Widget _buildStatCard({
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: Theme.of(context).iconTheme.color, size: 20),
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).textTheme.bodyLarge?.color,
        ),
      ),
      trailing: trailing ?? Icon(FeatherIcons.chevronRight, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.26), size: 16),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    );
  }

  void _showAudioQualityBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Audio Quality',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              SizedBox(height: 16),
              _buildQualityOption('Low Quality', 'Data saver mode (96 kbps)'),
              _buildQualityOption('Standard Quality', 'Balanced mode (160 kbps)'),
              _buildQualityOption('High Quality', 'Best audio experience (320 kbps)'),
            ],
          ),
        );
      },
    );
  }

  void _showDownloadQualityBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Download Quality',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              SizedBox(height: 16),
              _buildQualityOption('Standard', 'Good quality, saves storage', true),
              _buildQualityOption('Extreme', 'Highest quality, uses more space', true),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQualityOption(String quality, String description, [bool isDownload = false]) {
    return ListTile(
      onTap: () async {
        setState(() {
          if (isDownload) {
            _downloadQuality = quality;
          } else {
            _audioQuality = quality;
          }
        });
        await _saveProfileData(_profileImagePath ?? '');
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${isDownload ? "Download" : "Audio"} quality set to $quality'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      },
      contentPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      title: Text(
        quality,
        style: GoogleFonts.inter(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).textTheme.bodyLarge?.color,
        ),
      ),
      subtitle: Text(
        description,
        style: GoogleFonts.inter(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
        ),
      ),
      trailing: (isDownload ? _downloadQuality : _audioQuality) == quality
          ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
          : null,
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8, left: 16),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
