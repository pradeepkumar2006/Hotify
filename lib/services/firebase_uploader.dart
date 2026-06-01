import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

class FirebaseUploader {
  static Future<void> uploadSongs(BuildContext context) async {
    try {
      final jsonString = await rootBundle.loadString('assets/tamil_songs.json');
      final List<dynamic> songs = json.decode(jsonString);

      final CollectionReference songsCollection = FirebaseFirestore.instance.collection('songs');

      // Upload in batches of 500 (Firestore batch limit)
      WriteBatch batch = FirebaseFirestore.instance.batch();
      int count = 0;

      for (var song in songs) {
        final Map<String, dynamic> songMap = Map<String, dynamic>.from(song);
        final String docId = songMap['id']?.toString() ?? UniqueKey().toString();
        final docRef = songsCollection.doc(docId);

        batch.set(docRef, {
          'id': songMap['id'],
          'title': songMap['title'],
          'artist': songMap['artist'],
          'img': songMap['img'],
          'src': songMap['src'],
          'uploadedAt': FieldValue.serverTimestamp(),
        });

        count++;

        if (count % 500 == 0) {
          await batch.commit();
          batch = FirebaseFirestore.instance.batch();
          debugPrint('Uploaded $count songs...');
        }
      }

      if (count % 500 != 0) {
        await batch.commit();
      }

      debugPrint('Successfully uploaded all $count songs to Firestore!');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully uploaded all $count songs to Firestore!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error uploading songs: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading songs: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  static Future<String?> uploadArtistImage(String assetPath) async {
    try {
      final byteData = await rootBundle.load(assetPath);
      final bytes = byteData.buffer.asUint8List();
      final storageRef = FirebaseStorage.instance.ref().child('artists/sai_abhyankkar.png');
      final uploadTask = await storageRef.putData(bytes);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      debugPrint("Successfully uploaded artist image. URL: $downloadUrl");
      return downloadUrl;
    } catch (e) {
      debugPrint("Error uploading artist image: $e");
      return null;
    }
  }
}
