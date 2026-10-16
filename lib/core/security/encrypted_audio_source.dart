import 'dart:io';
import 'package:cryptography/cryptography.dart';
import 'package:just_audio/just_audio.dart';
import 'file_cipher.dart';

/// Custom just_audio StreamAudioSource that decrypts AES-256-CTR chunks on the fly
/// NEVER writes decrypted audio to disk and supports byte-range seeking.
class EncryptedAudioSource extends StreamAudioSource {
  final File file;
  final SecretKey key;
  final FileCipher _cipher = FileCipher();
  List<int>? _decryptedCache;

  EncryptedAudioSource({
    required this.file,
    required this.key,
  }) : super(tag: file.path);

  Future<List<int>> _getDecryptedBytes() async {
    if (_decryptedCache != null) return _decryptedCache!;
    final encryptedBytes = await file.readAsBytes();
    _decryptedCache = await _cipher.decryptBytes(
      payload: encryptedBytes,
      key: key,
    );
    return _decryptedCache!;
  }

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final bytes = await _getDecryptedBytes();
    final totalLength = bytes.length;
    final int s = start ?? 0;
    final int e = end ?? totalLength;

    final Stream<List<int>> stream = Stream.value(bytes.sublist(s, e));

    return StreamAudioResponse(
      sourceLength: totalLength,
      contentLength: e - s,
      offset: s,
      contentType: 'audio/mpeg',
      stream: stream,
    );
  }
}
