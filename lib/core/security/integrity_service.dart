import 'dart:io';
import 'package:cryptography/cryptography.dart';

class IntegrityService {
  final Sha256 _sha256 = Sha256();

  /// Computes SHA-256 hash of a file
  Future<String> computeFileSha256(File file) async {
    final List<int> bytes = await file.readAsBytes();
    final Hash hash = await _sha256.hash(bytes);
    return hash.bytes.map((int b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Verifies file against an expected hash
  Future<bool> verifyFileHash(File file, String expectedHash) async {
    if (expectedHash.isEmpty) return true; // Bypass if no server hash specified
    final String actualHash = await computeFileSha256(file);
    return actualHash.toLowerCase() == expectedHash.toLowerCase();
  }
}
