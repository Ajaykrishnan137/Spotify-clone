import 'package:flutter_test/flutter_test.dart';
import 'package:wavely/core/services/query_intent_engine.dart';
import 'package:wavely/core/services/fuzzy_matcher.dart';

void main() {
  group('Artist Query Variant & Strict Detection Tests', () {
    test('"haris jeyaraj", "harris jayaraj", "ஹாரிஸ் ஜெயராஜ்", and "hariss jeyaraj" resolve to Harris Jayaraj', () {
      final variants = [
        'haris jeyaraj',
        'harris jayaraj',
        'ஹாரிஸ் ஜெயராஜ்',
        'hariss jeyaraj',
        'harris jeyaraj',
        'haris jayaraj',
        'Haris Jayaraj',
        'Harris Jayaraj',
      ];

      for (final query in variants) {
        final intent = QueryIntentEngine.analyzeQuery(query);
        expect(intent.type, QueryIntentType.artistStrictQuery, reason: 'Failed for query: $query');
        expect(intent.matchedArtistName, 'Harris Jayaraj', reason: 'Failed canonical artist for: $query');
      }
    });

    test('Tamil script variants resolve to canonical artists', () {
      expect(QueryIntentEngine.analyzeQuery('பிரதீப் குமார்').matchedArtistName, 'Pradeep Kumar');
      expect(QueryIntentEngine.analyzeQuery('சித் ஸ்ரீராம்').matchedArtistName, 'Sid Sriram');
      expect(QueryIntentEngine.analyzeQuery('சாய் அபயங்கர்').matchedArtistName, 'Sai Abhyankkar');
      expect(QueryIntentEngine.analyzeQuery('அனிருத்').matchedArtistName, 'Anirudh Ravichander');
      expect(QueryIntentEngine.analyzeQuery('ஏ. ஆர். ரகுமான்').matchedArtistName, 'A. R. Rahman');
    });

    test('Strict artist matching does not match title, album, or unrelated artists', () {
      // QueryIntentEngine should not classify general titles or mood playlists as strict artist query
      final sleepIntent = QueryIntentEngine.analyzeQuery('sleep songs');
      expect(sleepIntent.type, QueryIntentType.playlistType);

      final travelIntent = QueryIntentEngine.analyzeQuery('travelling songs');
      expect(travelIntent.type, QueryIntentType.playlistType);

      final specificSongIntent = QueryIntentEngine.analyzeQuery('Moongil Thottam');
      expect(specificSongIntent.type, QueryIntentType.specificSongOrTitle);
    });
  });
}
