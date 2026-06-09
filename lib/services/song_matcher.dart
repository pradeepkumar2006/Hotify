
class SongMatcher {
  /// Cleans a string by removing contents in parentheses and square brackets
  /// and replacing multiple whitespaces.
  static String cleanString(String text) {
    // Remove content within parentheses like (From "...") or (Extended Beat Drop)
    String cleaned = text.replaceAll(RegExp(r'\([^)]*\)'), '');
    // Remove content within square brackets
    cleaned = cleaned.replaceAll(RegExp(r'\[[^\]]*\]'), '');
    // Replace special characters and extra spaces
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleaned;
  }

  /// Calculates the Levenshtein distance between two strings.
  static int calculateLevenshteinDistance(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    List<int> v0 = List<int>.filled(s2.length + 1, 0);
    List<int> v1 = List<int>.filled(s2.length + 1, 0);

    for (int i = 0; i <= s2.length; i++) {
      v0[i] = i;
    }

    for (int i = 0; i < s1.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < s2.length; j++) {
        int cost = (s1[i] == s2[j]) ? 0 : 1;
        int del = v1[j] + 1; // deletion
        int ins = v0[j + 1] + 1; // insertion
        int sub = v0[j] + cost; // substitution
        int min = del < ins ? del : ins;
        v1[j + 1] = min < sub ? min : sub;
      }
      for (int j = 0; j <= s2.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v1[s2.length];
  }

  /// Returns character similarity score between 0.0 (totally different) and 1.0 (identical).
  static double getSimilarity(String s1, String s2) {
    String cleanS1 = s1.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    String cleanS2 = s2.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (cleanS1.isEmpty && cleanS2.isEmpty) return 1.0;
    if (cleanS1.isEmpty || cleanS2.isEmpty) return 0.0;
    if (cleanS1 == cleanS2) return 1.0;

    int distance = calculateLevenshteinDistance(cleanS1, cleanS2);
    int maxLength = cleanS1.length > cleanS2.length ? cleanS1.length : cleanS2.length;
    return 1.0 - (distance / maxLength);
  }

  /// Checks if there is any overlapping artist/singer between the target and returned names.
  static bool hasArtistOverlap(String targetArtists, String rArtists) {
    if (targetArtists.isEmpty || rArtists.isEmpty) return false;
    
    // Split target artists by comma and clean them
    final List<String> targets = targetArtists
        .split(',')
        .map((a) => cleanString(a).toLowerCase().replaceAll(' ', ''))
        .where((a) => a.isNotEmpty)
        .toList();
        
    final String rArtistsClean = cleanString(rArtists).toLowerCase().replaceAll(' ', '');
    
    for (final t in targets) {
      if (t.length > 2 && rArtistsClean.contains(t)) {
        return true;
      }
    }
    return false;
  }

  /// Finds the best matched song from search results based on cleaned titles, movies, and artists.
  static Map<String, dynamic>? findBestMatch(
    List<dynamic> results, {
    required String targetTitle,
    required String targetMovie,
    required String targetArtist,
    required String targetSinger,
    required String expectedLanguage,
  }) {
    if (results.isEmpty) return null;

    final String targetTitleClean = cleanString(targetTitle).toLowerCase();
    final String targetMovieClean = cleanString(targetMovie).toLowerCase();
    final String targetArtistClean = cleanString(targetArtist).toLowerCase();

    dynamic bestMatch;
    double bestScore = -1.0;

    for (final r in results) {
      if (r is! Map) continue;
      final Map<String, dynamic> songMap = Map<String, dynamic>.from(r);

      final String rTitle = (songMap['song'] ?? songMap['title'] ?? '').toString();
      final String rMovie = (songMap['album'] ?? songMap['movie'] ?? '').toString();
      final String rArtist = (songMap['primary_artists'] ?? songMap['artist'] ?? songMap['singers'] ?? '').toString();
      final String rLanguage = (songMap['language'] ?? '').toString().toLowerCase();
      final String rSingers = (songMap['singers'] ?? songMap['singer'] ?? '').toString();

      final String rTitleClean = cleanString(rTitle).toLowerCase();
      final String rMovieClean = cleanString(rMovie).toLowerCase();
      final String rArtistClean = cleanString(rArtist).toLowerCase();

      // 1. Title similarity check
      double titleScore = getSimilarity(targetTitleClean, rTitleClean);
      
      bool isTitleValid = titleScore >= 0.75;
      if (!isTitleValid) {
        // Fallback: substring matching with a length ratio threshold (e.g. for shortened titles)
        final bool isSubstring = targetTitleClean.contains(rTitleClean) || rTitleClean.contains(targetTitleClean);
        if (isSubstring) {
          final int len1 = targetTitleClean.length;
          final int len2 = rTitleClean.length;
          final double ratio = len1 < len2 ? len1 / len2 : len2 / len1;
          if (ratio >= 0.65) {
            isTitleValid = true;
          }
        }
      }

      // STRICT GATE 1: If title is not valid, it is a completely different song!
      if (!isTitleValid) {
        continue;
      }

      // STRICT GATE 2: Language restriction
      // If we expect Tamil/English and the API returns Hindi/Telugu etc, discard it.
      final bool langMatches = rLanguage == expectedLanguage;
      if (expectedLanguage.isNotEmpty && rLanguage.isNotEmpty && !langMatches) {
        if (expectedLanguage == 'tamil' && rLanguage != 'tamil') continue;
        if (expectedLanguage == 'english' && rLanguage != 'english') continue;
      }

      // 3. Movie similarity (if target has movie)
      double movieScore = 0.0;
      if (targetMovieClean.isNotEmpty) {
        movieScore = getSimilarity(targetMovieClean, rMovieClean);
      } else {
        movieScore = 0.5; // neutral
      }

      // STRICT GATE 2:
      // If a movie name is specified in our database, and the returned album/movie name
      // does not match (movieScore < 0.5), we reject it unless the returned album
      // is clearly a compilation/hits collection rather than a different movie.
      if (targetMovieClean.isNotEmpty && movieScore < 0.5) {
        final String rMovieLower = rMovie.toLowerCase();
        final bool isCompilation = rMovieLower.contains("hits") ||
            rMovieLower.contains("best of") ||
            rMovieLower.contains("collection") ||
            rMovieLower.contains("essential") ||
            rMovieLower.contains("playlist") ||
            rMovieLower.contains("mix") ||
            rMovieLower.contains("greatest") ||
            rMovieLower.contains("workout") ||
            rMovieLower.contains("selection") ||
            rMovieLower.contains("remix") ||
            rMovieLower.contains("compilation") ||
            rMovieLower.contains("anthology") ||
            rMovieLower.contains("tribute") ||
            rMovieLower.contains("vol");
            
        if (!isCompilation) {
          continue; // Reject different movie albums
        }

        // If it is a compilation, we still require singer overlap to ensure it is the correct song!
        if (targetSinger.isNotEmpty) {
          final String rAllArtists = "$rArtist, $rSingers, ${songMap['singers'] ?? ''}, ${songMap['singer'] ?? ''}";
          if (!hasArtistOverlap(targetSinger, rAllArtists)) {
            continue; // Reject if no singer overlap
          }
        }
      }

      // 4. Artist similarity
      double artistScore = 0.0;
      if (targetArtistClean.isNotEmpty) {
        if (rArtistClean.contains(targetArtistClean) || targetArtistClean.contains(rArtistClean)) {
          artistScore = 1.0;
        } else {
          artistScore = getSimilarity(targetArtistClean, rArtistClean);
        }
      } else {
        artistScore = 0.5; // neutral
      }

      // Calculate overall match score
      double score = titleScore * 0.5 + movieScore * 0.2 + artistScore * 0.1;

      if (langMatches) {
        score += 0.2; // Boost score if language matches
      }

      if (score > bestScore) {
        bestScore = score;
        bestMatch = songMap;
      }
    }

    if (bestMatch == null && results.isNotEmpty) {
      // Fallback: If strict gates rejected everything, just pick the result with the highest title similarity.
      double relaxedBestScore = -1.0;
      for (final r in results) {
        if (r is! Map) continue;
        final Map<String, dynamic> songMap = Map<String, dynamic>.from(r);
        
        // Ensure language matches even in fallback
        final String rLang = (songMap['language'] ?? '').toString().toLowerCase();
        if (expectedLanguage.isNotEmpty && rLang.isNotEmpty && rLang != expectedLanguage) {
          if (expectedLanguage == 'tamil' && rLang != 'tamil') continue;
          if (expectedLanguage == 'english' && rLang != 'english') continue;
        }

        final String rTitle = (songMap['song'] ?? songMap['title'] ?? '').toString();
        final double titleScore = getSimilarity(targetTitleClean, cleanString(rTitle).toLowerCase());
        
        // Also give a tiny boost if artists overlap
        final String rArtist = (songMap['primary_artists'] ?? songMap['artist'] ?? songMap['singers'] ?? '').toString();
        double artistBoost = 0.0;
        if (targetArtistClean.isNotEmpty && cleanString(rArtist).toLowerCase().contains(targetArtistClean)) {
          artistBoost = 0.1;
        }

        final double finalScore = titleScore + artistBoost;
        if (finalScore > relaxedBestScore) {
          relaxedBestScore = finalScore;
          bestMatch = songMap;
        }
      }
    }

    return bestMatch;
  }
}
