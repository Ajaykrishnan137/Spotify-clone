import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/song_model.dart';
import '../../../core/utils/result.dart';

class SupabaseSongsRepository {
  Future<Result<String>> getSignedAudioUrl(String storagePath) async {
    try {
      if (storagePath.startsWith('http://') || storagePath.startsWith('https://')) {
        return Success(storagePath);
      }
      return Success(storagePath);
    } catch (e) {
      return Failure('Failed to get audio URL: $e');
    }
  }
}
