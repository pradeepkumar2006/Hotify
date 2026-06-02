import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

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
          'Help & Support',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Section
            _buildSectionHeader(context, 'Welcome', FeatherIcons.smile),
            _buildParagraph(context, "Welcome to our Music App! We're here to help you enjoy the best music experience."),
            const SizedBox(height: 32),

            // FAQ Section
            _buildSectionHeader(context, 'Frequently Asked Questions', FeatherIcons.helpCircle),
            _buildFaqItem(
              context,
              'How do I create a playlist?',
              'Go to Create Playlist and tap the + button to create your own playlist.',
            ),
            _buildFaqItem(
              context,
              'How do I search for songs?',
              'Use the Search tab and enter the song, artist, album, or movie name.',
            ),
            _buildFaqItem(
              context,
              'How do I report a problem?',
              'Use the Contact Support section below and send us your feedback.',
            ),
            _buildFaqItem(
              context,
              'Why is a song not playing?',
              'Check your internet connection and try again.',
            ),
            const SizedBox(height: 32),

            // Contact Support
            _buildSectionHeader(context, 'Contact Support', FeatherIcons.mail),
            _buildParagraph(context, 'If you have any issues, suggestions, or feedback, contact us:'),
            const SizedBox(height: 12),
            _buildInfoRow(context, FeatherIcons.atSign, 'Email:', 'astraardency@gmail.com'),
            const SizedBox(height: 12),
            _buildInfoRow(context, FeatherIcons.messageSquare, 'Feedback:', 'We value your suggestions and continuously improve the app based on user feedback.'),
            const SizedBox(height: 32),

            // App Info
            _buildSectionHeader(context, 'App Information', FeatherIcons.info),
            _buildInfoRow(context, FeatherIcons.tag, 'Version:', '1.0.0'),
            const SizedBox(height: 12),
            _buildInfoRow(context, FeatherIcons.smartphone, 'Platform:', 'Android & iOS'),
            const SizedBox(height: 32),

            // Creators
            _buildSectionHeader(context, 'Creators', FeatherIcons.users),
            Text(
              'Developed By',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            _buildCreatorBadge(context, 'Pradeep Kumar'),
            _buildCreatorBadge(context, 'Prathos'),
            const SizedBox(height: 16),
            _buildParagraph(context, 'Passionate developers dedicated to creating a seamless and enjoyable music experience for everyone.'),
            const SizedBox(height: 32),

            // Thank You
            Center(
              child: Column(
                children: [
                  Icon(FeatherIcons.heart, color: Colors.redAccent, size: 40),
                  const SizedBox(height: 16),
                  Text(
                    'Thank You',
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Thank you for using our Music App. Your support motivates us to build better features and provide the best music experience.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      height: 1.5,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Enjoy the Music! 🎧',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24),
          const SizedBox(width: 12),
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParagraph(BuildContext context, String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 14,
        height: 1.5,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
      ),
    );
  }

  Widget _buildFaqItem(BuildContext context, String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            answer,
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.5,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4), size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.5,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
              children: [
                TextSpan(text: '$label ', style: const TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(
                  text: value,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCreatorBadge(BuildContext context, String name) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(FeatherIcons.user, size: 14, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            name,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
