import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

class CreatePlaylistScreen extends StatefulWidget {
  final String proposedName;

  const CreatePlaylistScreen({
    super.key,
    required this.proposedName,
  });

  @override
  State<CreatePlaylistScreen> createState() => _CreatePlaylistScreenState();
}

class _CreatePlaylistScreenState extends State<CreatePlaylistScreen> {
  late final TextEditingController _nameController;
  final TextEditingController _descriptionController = TextEditingController();
  String? _imagePath;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.proposedName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _imagePath = image.path;
        });
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2C2C2C), Color(0xFF121212)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                Text(
                  'Create Playlist',
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 40),
                // Tap to pick image (profile picture cover)
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white30, width: 1),
                      image: _imagePath != null
                          ? DecorationImage(
                              image: FileImage(File(_imagePath!)),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: _imagePath == null
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate_outlined,
                                color: Colors.white70,
                                size: 36,
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Add Photo',
                                style: TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                            ],
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 40),
                // Name Input
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'PLAYLIST NAME',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white60,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                TextField(
                  controller: _nameController,
                  cursorColor: Colors.white,
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  decoration: const InputDecoration(
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white30),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white70),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Description Input
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'PLAYLIST DESCRIPTION',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white60,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                TextField(
                  controller: _descriptionController,
                  cursorColor: Colors.white,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: Colors.white,
                  ),
                  decoration: const InputDecoration(
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white30),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white70),
                    ),
                    hintText: 'Add a description...',
                    hintStyle: TextStyle(color: Colors.white30, fontSize: 15),
                  ),
                ),
                const SizedBox(height: 56),
                // Row buttons Cancel / Create
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Cancel button
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white54),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    // Create button
                    GestureDetector(
                      onTap: () {
                        final name = _nameController.text.trim();
                        final desc = _descriptionController.text.trim();
                        if (name.isNotEmpty) {
                          Navigator.pop(context, {
                            'name': name,
                            'description': desc.isNotEmpty ? desc : '',
                            'image': _imagePath ?? '',
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white, // Sleek solid white matching the theme
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Text(
                          'Create',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF121212),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
