import 'dart:math';

class FuzzyMatcher {
  FuzzyMatcher._();

  // Transliteration dictionary for Tamil and variant spellings
  static final Map<String, String> _transliterationMap = {
    'vaanam': 'vanam',
    'vaan': 'vanam',
    'kadhal': 'kaadhal',
    'kathal': 'kaadhal',
    'kaathal': 'kaadhal',
    'nenjame': 'nenje',
    'marandhu': 'maranthu',
    'kannaana': 'kanana',
    'kanmani': 'kanmaniye',
    'safar': 'travel',
    'payanam': 'travel',
    'banger': 'party',
    'urakkam': 'sleep',
    'thookam': 'sleep',
    // Tamil script to standard transliterated forms
    'வானம்': 'vanam',
    'காதல்': 'kaadhal',
    'நெஞ்சமே': 'nenjame',
    'பயணம்': 'travel',
    'தூக்கம்': 'sleep',
    'பாடல்கள்': 'songs',
    'பாட்டு': 'songs',
    'தமிழ்': 'tamil',
  };

  /// Normalizes string: lowercase, strips accents, removes punctuation, handles Tamil script transliteration,
  /// collapses common variants (th -> t, zh -> l, double vowels -> single vowel)
  static String normalize(String input) {
    if (input.isEmpty) return '';
    var text = input.toLowerCase().trim();

    // Remove standard accent marks
    const withAccents = 'áàảãạăắằẳẵặâấầẩẫậéèẻẽẹêếềểễệíìỉĩịóòỏõọôốồổỗộơớờởỡợúùủũụưứừửữựýỳỷỹỵđ';
    const withoutAccents = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
    for (int i = 0; i < withAccents.length; i++) {
      text = text.replaceAll(withAccents[i], withoutAccents[i]);
    }

    // Replace Tamil script keywords with transliterated equivalents
    _transliterationMap.forEach((tamilWord, engWord) {
      if (text.contains(tamilWord)) {
        text = text.replaceAll(tamilWord, ' $engWord ');
      }
    });

    // Remove punctuation & symbols
    text = text.replaceAll(RegExp(r'''[.,\/#!$%\^&\*;:{}=\-_`~()?'"\[\]|<>]'''), ' ');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Standardize common phonetic variants (zh -> l, th -> t, aa -> a, ee -> e, oo -> o)
    return _applyPhoneticVariants(text);
  }

  static String _applyPhoneticVariants(String input) {
    return input
        .replaceAll('zh', 'l')
        .replaceAll('th', 't')
        .replaceAll('aa', 'a')
        .replaceAll('ee', 'i')
        .replaceAll('oo', 'u');
  }

  /// Calculates Damerau-Levenshtein edit distance between two strings
  static int editDistance(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    final len1 = s1.length;
    final len2 = s2.length;
    final d = List.generate(len1 + 1, (_) => List.filled(len2 + 1, 0));

    for (int i = 0; i <= len1; i++) {
      d[i][0] = i;
    }
    for (int j = 0; j <= len2; j++) {
      d[0][j] = j;
    }

    for (int i = 1; i <= len1; i++) {
      for (int j = 1; j <= len2; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        d[i][j] = min(
          min(d[i - 1][j] + 1, d[i][j - 1] + 1),
          d[i - 1][j - 1] + cost,
        );

        if (i > 1 && j > 1 && s1[i - 1] == s2[j - 2] && s1[i - 2] == s2[j - 1]) {
          d[i][j] = min(d[i][j], d[i - 2][j - 2] + cost);
        }
      }
    }
    return d[len1][len2];
  }

  /// Calculates Levenshtein normalized similarity (0.0 to 1.0)
  static double editSimilarity(String s1, String s2) {
    final maxLen = max(s1.length, s2.length);
    if (maxLen == 0) return 1.0;
    final dist = editDistance(s1, s2);
    return max(0.0, 1.0 - (dist / maxLen));
  }

  /// Calculates character n-gram / trigram similarity (0.0 to 1.0)
  static double trigramSimilarity(String s1, String s2) {
    if (s1 == s2) return 1.0;
    if (s1.length < 2 || s2.length < 2) {
      return s1.contains(s2) || s2.contains(s1) ? 0.7 : 0.0;
    }

    final grams1 = _getTrigrams(s1);
    final grams2 = _getTrigrams(s2);

    int intersection = 0;
    final g2List = List<String>.from(grams2);
    for (final g in grams1) {
      final idx = g2List.indexOf(g);
      if (idx >= 0) {
        intersection++;
        g2List.removeAt(idx);
      }
    }

    final total = grams1.length + grams2.length;
    if (total == 0) return 0.0;
    return (2.0 * intersection) / total;
  }

  static List<String> _getTrigrams(String s) {
    final padded = '  $s ';
    final list = <String>[];
    for (int i = 0; i < padded.length - 2; i++) {
      list.add(padded.substring(i, i + 3));
    }
    return list;
  }

  /// Calculates token-order-independent matching score (e.g. "kadhal en" matches "en kadhal")
  static double tokenOrderIndependentScore(String queryNorm, String targetNorm) {
    final qTokens = queryNorm.split(' ').where((t) => t.isNotEmpty).toList();
    final tTokens = targetNorm.split(' ').where((t) => t.isNotEmpty).toList();

    if (qTokens.isEmpty || tTokens.isEmpty) return 0.0;

    double matchedWeight = 0.0;
    for (final q in qTokens) {
      double bestTokenMatch = 0.0;
      for (final t in tTokens) {
        if (q == t) {
          bestTokenMatch = 1.0;
          break;
        } else if (t.startsWith(q)) {
          bestTokenMatch = max(bestTokenMatch, 0.9);
        } else if (t.contains(q)) {
          bestTokenMatch = max(bestTokenMatch, 0.8);
        } else {
          final sim = editSimilarity(q, t);
          if (sim >= 0.7) {
            bestTokenMatch = max(bestTokenMatch, sim * 0.85);
          }
        }
      }
      matchedWeight += bestTokenMatch;
    }

    return matchedWeight / qTokens.length;
  }

  /// Calculates comprehensive fuzzy match score (0.0 to 1.0)
  static double computeCombinedFuzzyScore(String rawQuery, String rawTarget) {
    final qNorm = normalize(rawQuery);
    final tNorm = normalize(rawTarget);

    if (qNorm.isEmpty || tNorm.isEmpty) return 0.0;
    if (qNorm == tNorm) return 1.0;
    if (tNorm.startsWith(qNorm)) return 0.95;
    if (tNorm.contains(qNorm)) return 0.88;

    final tokenScore = tokenOrderIndependentScore(qNorm, tNorm);
    final trigramScore = trigramSimilarity(qNorm, tNorm);
    final editSim = editSimilarity(qNorm, tNorm);

    // Weighted blend of token-independence, n-gram, and edit distance
    final score = (tokenScore * 0.5) + (trigramScore * 0.3) + (editSim * 0.2);
    return score.clamp(0.0, 1.0);
  }

  /// Generates "Did you mean..." spelling suggestions based on catalog candidate terms
  static String? findSpellingSuggestion(String query, Iterable<String> candidatePool) {
    final qNorm = normalize(query);
    if (qNorm.length < 3) return null;

    String? bestCandidate;
    double bestScore = 0.65; // Minimum similarity threshold to suggest

    for (final candidate in candidatePool) {
      final cNorm = normalize(candidate);
      if (cNorm == qNorm) continue; // Already exact

      final sim = trigramSimilarity(qNorm, cNorm);
      final editSim = editSimilarity(qNorm, cNorm);
      final combined = (sim * 0.6) + (editSim * 0.4);

      if (combined > bestScore) {
        bestScore = combined;
        bestCandidate = candidate;
      }
    }

    return bestCandidate;
  }
}
