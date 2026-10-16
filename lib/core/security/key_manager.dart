import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cryptography/cryptography.dart';
import 'dart:convert';

class KeyManager {
  static const String _keyStorageAlias = 'wavely_aes_master_key_v1';
  final FlutterSecureStorage _storage;

  KeyManager({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage(
          aOptions: AndroidOptions(
            encryptedSharedPreferences: true,
          ),
          iOptions: IOSOptions(
            accessibility: KeychainAccessibility.first_unlock,
          ),
        );

  Future<SecretKey> getOrCreateMasterKey() async {
    final String? existingBase64 = await _storage.read(key: _keyStorageAlias);
    if (existingBase64 != null && existingBase64.isNotEmpty) {
      final List<int> keyBytes = base64Decode(existingBase64);
      return SecretKey(keyBytes);
    }

    // Generate fresh 256-bit (32 bytes) master key
    final AesCtr algorithm = AesCtr.with256bits(macAlgorithm: Hmac.sha256());
    final SecretKey newKey = await algorithm.newSecretKey();
    final List<int> rawBytes = await newKey.extractBytes();
    
    await _storage.write(
      key: _keyStorageAlias,
      value: base64Encode(rawBytes),
    );

    return newKey;
  }

  Future<void> clearKeys() async {
    await _storage.delete(key: _keyStorageAlias);
  }
}
