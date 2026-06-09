// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'lib/services/song_matcher.dart';

void main() async {
  final songs = [
    {
      "title": "Why This Kolaveri Di (Rockstar Studio Archive Layer 5)",
      "movie": "3",
      "artist": "Anirudh Ravichander",
      "singer": "Dhanush",
      "language": "Tamil"
    },
    {
      "title": "Vellai Pookal (Isai Puyal Album Vault Cut 96)",
      "movie": "Kannathil Muthamittal",
      "artist": "A.R. Rahman",
      "singer": "A.R. Rahman",
      "language": "Tamil"
    },
    {
      "title": "Kala Kalakkum (Extended Beat Drop)",
      "movie": "Guntur Kaaram (Tamil Dubbed)",
      "artist": "Thaman S",
      "singer": "Asal Kolaru",
      "language": "Tamil"
    },
    {
      "title": "Katchi Sera",
      "movie": "",
      "artist": "Sai Abhyankkar",
      "singer": "Sai Abhyankkar",
      "language": "Tamil"
    },
    {
      "title": "Anbe Aaruyire (Isai Puyal Album Vault Cut 97)",
      "movie": "Jeans",
      "artist": "A.R. Rahman",
      "singer": "Hariharan, Kavita Krishnamurthy",
      "language": "Tamil"
    }
  ];

  for (final song in songs) {
    String cleanTitle = SongMatcher.cleanString(song['title']!);
    String cleanMovie = SongMatcher.cleanString(song['movie']!);
    String cleanArtist = SongMatcher.cleanString(song['artist']!);
    String expectedLanguage = (song['language'] ?? 'tamil').toString().toLowerCase();

    String specificQuery = "";
    if (cleanMovie.isNotEmpty) {
      specificQuery = "$cleanTitle $cleanMovie".trim();
    }
    String fallbackQuery = "$cleanTitle $cleanArtist".trim();
    String simpleQuery = cleanTitle.trim();

    List<String> queriesToTry = [specificQuery, fallbackQuery, simpleQuery]
        .where((q) => q.isNotEmpty).toSet().toList();
    
    dynamic finalMatch;
    print("\n--- Searching for: '${song['title']}' ---");
    print("Cleaned search params: Title='$cleanTitle', Movie='$cleanMovie', Artist='$cleanArtist'");

    for (String query in queriesToTry) {
      final String searchUrl = "https://saavnapi-nine.vercel.app/song/?query=${Uri.encodeComponent(query)}";
      try {
        final response = await http.get(Uri.parse(searchUrl));
        if (response.statusCode == 200) {
          final decoded = json.decode(response.body);
          List<dynamic> results = [];
          if (decoded is List) {
            results = decoded;
          } else if (decoded is Map && decoded['value'] is List) {
            results = decoded['value'];
          }
          
          if (results.isNotEmpty) {
            print("API Results for query '$query':");
            for (var r in results) {
              print("  - Title: '${r['song'] ?? r['title']}', Movie: '${r['album'] ?? r['movie']}', Artist: '${r['primary_artists'] ?? r['artist']}', Lang: '${r['language']}'");
            }
            finalMatch = SongMatcher.findBestMatch(
              results,
              targetTitle: song['title']!,
              targetMovie: song['movie']!,
              targetArtist: song['artist']!,
              targetSinger: song['singer']!,
              expectedLanguage: expectedLanguage,
            );
            if (finalMatch != null) {
              print("Matched on query '$query': ${finalMatch['song']} (${finalMatch['language']}) from '${finalMatch['album']}' by ${finalMatch['primary_artists']}");
              break;
            }
          }
        }
      } catch (e) {
        print("Error: $e");
      }
    }

    if (finalMatch != null) {
      print("FINAL RESULT: ${finalMatch['song']} (${finalMatch['language']}) by ${finalMatch['primary_artists']} from movie '${finalMatch['album']}'");
    } else {
      print("FINAL RESULT: NOTHING FOUND");
    }
  }
}
