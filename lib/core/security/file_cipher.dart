import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

class FileCipher {
  static const int nonceLength = 16;
  static const int macLength = 32; // HMAC-SHA256 generates 32 bytes

  final AesCtr _algorithm = AesCtr.with256bits(macAlgorithm: Hmac.sha256());

  List<int> generateNonce() {
    final Random random = Random.secure();
    return List<int>.generate(nonceLength, (_) => random.nextInt(256));
  }

  /// Encrypts raw bytes and prepends [nonce (16B)] + [mac (32B)] + [ciphertext]
  Future<List<int>> encryptBytes({
    required List<int> cleartext,
    required SecretKey key,
  }) async {
    final List<int> nonce = generateNonce();
    final SecretBox secretBox = await _algorithm.encrypt(
      cleartext,
      secretKey: key,
      nonce: nonce,
    );

    final Uint8List output = Uint8List(nonceLength + macLength + secretBox.cipherText.length);
    output.setRange(0, nonceLength, nonce);
    output.setRange(nonceLength, nonceLength + macLength, secretBox.mac.bytes);
    output.setRange(nonceLength + macLength, output.length, secretBox.cipherText);

    return output;
  }

  /// Decrypts bytes verifying HMAC-SHA256 integrity
  Future<List<int>> decryptBytes({
    required List<int> payload,
    required SecretKey key,
  }) async {
    if (payload.length < nonceLength + macLength) {
      throw const FormatException('Payload is too short to be valid encrypted audio.');
    }

    final List<int> nonce = payload.sublist(0, nonceLength);
    final List<int> macBytes = payload.sublist(nonceLength, nonceLength + macLength);
    final List<int> cipherText = payload.sublist(nonceLength + macLength);

    final SecretBox secretBox = SecretBox(
      cipherText,
      nonce: nonce,
      mac: Mac(macBytes),
    );

    return await _algorithm.decrypt(
      secretBox,
      secretKey: key,
    );
  }

  /// Encrypts a source file to an opaque target file
  Future<void> encryptFile({
    required File inputFile,
    required File outputFile,
    required SecretKey key,
  }) async {
    final Uint8List bytes = await inputFile.readAsBytes();
    final List<int> encrypted = await encryptBytes(cleartext: bytes, key: key);
    await outputFile.writeAsBytes(encrypted, flush: true);
  }
}
