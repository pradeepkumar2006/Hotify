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
import 'login_screen.dart';
import 'utils/theme_notifier.dart';
import 'help_support_screen.dart';
import 'account_settings_screen.dart';

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
  String? _profileImagePath;
  int _playlistCount = 0;
  int _favoriteCount = 0;
  String _listeningMinutesStr = '0';
  String _audioQuality = 'Standard Quality';

  @override
  void initState() {
    super.initState();
    _loadProfileData();
    _setActivityStats();
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
            if (decoded.containsKey('audioQuality')) {
              _audioQuality = decoded['audioQuality'];
            }
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
    final String email = currentUser?.email ?? 'music@hotify.com';

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

            // Profile Actions List
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
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
                children: [
                  ValueListenableBuilder<ThemeMode>(
                    valueListenable: themeNotifier,
                    builder: (context, themeMode, _) {
                      return ListTile(
                        leading: Icon(FeatherIcons.moon, color: Theme.of(context).iconTheme.color, size: 20),
                        title: Text(
                          'Dark Mode',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                        trailing: Switch(
                          value: themeMode == ThemeMode.dark,
                          onChanged: (value) {
                            toggleTheme();
                          },
                          activeColor: Theme.of(context).colorScheme.primary,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                      );
                    },
                  ),
                  Divider(height: 1, indent: 56, color: Colors.grey.withValues(alpha: 0.2)),
                  _buildListTile(
                    icon: FeatherIcons.settings,
                    title: 'Account Settings',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AccountSettingsScreen(),
                        ),
                      );
                    },
                  ),
                  Divider(height: 1, indent: 56, color: Colors.grey.withValues(alpha: 0.2)),
                  _buildListTile(
                    icon: FeatherIcons.bell,
                    title: 'Notification Preferences',
                    onTap: () {},
                  ),
                  Divider(height: 1, indent: 56, color: Colors.grey.withValues(alpha: 0.2)),
                  _buildListTile(
                    icon: FeatherIcons.volume2,
                    title: 'Audio Quality',
                    onTap: _showAudioQualityBottomSheet,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _audioQuality,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(FeatherIcons.chevronRight, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.26), size: 16),
                      ],
                    ),
                  ),
                  Divider(height: 1, indent: 56, color: Colors.grey.withValues(alpha: 0.2)),
                  _buildListTile(
                    icon: FeatherIcons.helpCircle,
                    title: 'Help & Support',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HelpSupportScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            SizedBox(height: 40),

            // Logout Button
            OutlinedButton(
              onPressed: () async {
                if (Firebase.apps.isNotEmpty) {
                  await FirebaseAuth.instance.signOut();
                }
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.redAccent, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                foregroundColor: Colors.redAccent,
              ),
              child: Text(
                'LOG OUT',
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            SizedBox(height: 24),
          ],
        ),
      ),
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

  Widget _buildQualityOption(String quality, String description) {
    return ListTile(
      onTap: () async {
        setState(() {
          _audioQuality = quality;
        });
        await _saveProfileData(_profileImagePath ?? '');
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Audio quality set to $quality'),
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
      trailing: _audioQuality == quality
          ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
          : null,
    );
  }


}
