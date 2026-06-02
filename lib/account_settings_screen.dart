import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  // Mock states for toggles
  bool _autoplaySongs = true;
  bool _explicitContent = false;
  bool _crossfade = false;
  bool _gaplessPlayback = true;
  bool _normalizeVolume = true;
  bool _wifiOnly = true;
  
  bool _newSongAlerts = true;
  bool _playlistUpdates = true;
  bool _artistUpdates = true;
  bool _appNotifications = true;
  
  bool _privateListening = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        leading: IconButton(
          icon: Icon(FeatherIcons.arrowLeft, color: Theme.of(context).iconTheme.color),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Account Settings',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            _buildSectionHeader('Preferences'),
            _buildSettingsTile(
              icon: FeatherIcons.globe,
              title: 'Language',
              subtitle: 'English',
              onTap: () {},
            ),
            _buildSettingsTile(
              icon: FeatherIcons.moon,
              title: 'Theme',
              subtitle: 'System',
              onTap: () {},
            ),
            _buildSettingsTile(
              icon: FeatherIcons.volume2,
              title: 'Audio Quality',
              subtitle: 'Standard Quality',
              onTap: () {},
            ),
            _buildSwitchTile(
              icon: FeatherIcons.playCircle,
              title: 'Autoplay Songs',
              value: _autoplaySongs,
              onChanged: (val) => setState(() => _autoplaySongs = val),
            ),
            _buildSwitchTile(
              icon: FeatherIcons.alertTriangle,
              title: 'Explicit Content Filter',
              value: _explicitContent,
              onChanged: (val) => setState(() => _explicitContent = val),
            ),
            
            const SizedBox(height: 24),
            _buildSectionHeader('Playback Settings'),
            _buildSwitchTile(
              icon: FeatherIcons.sliders,
              title: 'Crossfade Songs',
              value: _crossfade,
              onChanged: (val) => setState(() => _crossfade = val),
            ),
            _buildSwitchTile(
              icon: FeatherIcons.fastForward,
              title: 'Gapless Playback',
              value: _gaplessPlayback,
              onChanged: (val) => setState(() => _gaplessPlayback = val),
            ),
            _buildSwitchTile(
              icon: FeatherIcons.barChart2,
              title: 'Normalize Volume',
              value: _normalizeVolume,
              onChanged: (val) => setState(() => _normalizeVolume = val),
            ),
            _buildSwitchTile(
              icon: FeatherIcons.wifi,
              title: 'Download Over Wi-Fi Only',
              value: _wifiOnly,
              onChanged: (val) => setState(() => _wifiOnly = val),
            ),

            const SizedBox(height: 24),
            _buildSectionHeader('Notifications'),
            _buildSwitchTile(
              icon: FeatherIcons.music,
              title: 'New Song Alerts',
              value: _newSongAlerts,
              onChanged: (val) => setState(() => _newSongAlerts = val),
            ),
            _buildSwitchTile(
              icon: FeatherIcons.list,
              title: 'Playlist Updates',
              value: _playlistUpdates,
              onChanged: (val) => setState(() => _playlistUpdates = val),
            ),
            _buildSwitchTile(
              icon: FeatherIcons.userCheck,
              title: 'Artist Updates',
              value: _artistUpdates,
              onChanged: (val) => setState(() => _artistUpdates = val),
            ),
            _buildSwitchTile(
              icon: FeatherIcons.bell,
              title: 'App Notifications',
              value: _appNotifications,
              onChanged: (val) => setState(() => _appNotifications = val),
            ),

            const SizedBox(height: 24),
            _buildSectionHeader('Privacy & Security'),
            _buildSwitchTile(
              icon: FeatherIcons.eyeOff,
              title: 'Private Listening Mode',
              value: _privateListening,
              onChanged: (val) => setState(() => _privateListening = val),
            ),
            _buildSettingsTile(
              icon: FeatherIcons.smartphone,
              title: 'Manage Connected Devices',
              onTap: () {},
            ),
            _buildSettingsTile(
              icon: FeatherIcons.activity,
              title: 'Login Activity',
              onTap: () {},
            ),
            _buildSettingsTile(
              icon: FeatherIcons.lock,
              title: 'Two-Factor Authentication',
              subtitle: 'Future Upgrade',
              onTap: () {},
            ),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 24, right: 24, bottom: 12),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Icon(icon, color: Theme.of(context).iconTheme.color, size: 22),
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).textTheme.bodyLarge?.color,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
              ),
            )
          : null,
      trailing: Icon(FeatherIcons.chevronRight, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3), size: 18),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      value: value,
      onChanged: onChanged,
      activeColor: Theme.of(context).colorScheme.primary,
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).textTheme.bodyLarge?.color,
        ),
      ),
      secondary: Icon(icon, color: Theme.of(context).iconTheme.color, size: 22),
    );
  }
}
