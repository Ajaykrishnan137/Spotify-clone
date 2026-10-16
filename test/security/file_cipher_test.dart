import 'package:flutter_test/flutter_test.dart';
import 'package:cryptography/cryptography.dart';
import 'package:wavely/core/security/file_cipher.dart';

void main() {
  group('FileCipher Tests', () {
    final cipher = FileCipher();

    test('Encrypt and Decrypt round trip produces original cleartext', () async {
      final algorithm = AesCtr.with256bits(macAlgorithm: Hmac.sha256());
      final key = await algorithm.newSecretKey();
      final cleartext = 'Wavely high-fidelity audio stream chunk data bytes'.codeUnits;

      final encrypted = await cipher.encryptBytes(
        cleartext: cleartext,
        key: key,
      );

      // Verify payload includes nonce (16) + mac (32) + ciphertext
      expect(encrypted.length, cleartext.length + 16 + 32);

      final decrypted = await cipher.decryptBytes(
        payload: encrypted,
        key: key,
      );

      expect(decrypted, cleartext);
    });

    test('Tampering with ciphertext fails HMAC integrity verification', () async {
      final algorithm = AesCtr.with256bits(macAlgorithm: Hmac.sha256());
      final key = await algorithm.newSecretKey();
      final cleartext = 'Sensitive protected audio payload'.codeUnits;

      final encrypted = await cipher.encryptBytes(
        cleartext: cleartext,
        key: key,
      );

      // Tamper with a byte in the ciphertext body
      final tampered = List<int>.from(encrypted);
      tampered[tampered.length - 1] ^= 0xFF;

      expect(
        () async => await cipher.decryptBytes(payload: tampered, key: key),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });
  });
}
