import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/random/fortuna_random.dart';
import 'dart:math';

class EncryptionService {
  static const _secureKeyStorageKey = 'hive_encryption_key';
  final _secureStorage = const FlutterSecureStorage();
  
  encrypt.Encrypter? _encrypter;
  encrypt.IV? _iv;

  EncryptionService._();
  
  static final EncryptionService _instance = EncryptionService._();
  factory EncryptionService() => _instance;

  Future<void> initialize() async {
    if (_encrypter != null) return; 

    final key = await _getOrGenerateKey();
    _iv = encrypt.IV.fromLength(16); 
    _encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
  }

  Future<encrypt.Key> _getOrGenerateKey() async {
    String? base64Key = await _secureStorage.read(key: _secureKeyStorageKey);
    
    if (base64Key == null) {
      print("No encryption key found. Generating a new one...");
      final key = _generateSecureRandomKey();
      base64Key = base64Encode(key.bytes);
      await _secureStorage.write(key: _secureKeyStorageKey, value: base64Key);
      return key;
    } else {
      print("Loaded existing encryption key from secure storage.");
      return encrypt.Key.fromBase64(base64Key);
    }
  }

  encrypt.Key _generateSecureRandomKey() {
    final secureRandom = FortunaRandom();
    final seedSource = Random.secure();
    final seeds = <int>[];
    for (int i = 0; i < 32; i++) {
      seeds.add(seedSource.nextInt(255));
    }
    secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));
    return encrypt.Key(secureRandom.nextBytes(32));
  }
  
  static Future<List<int>> getEncryptionKey() async {
    await _instance.initialize();
    final keyString = await _instance._secureStorage.read(key: _secureKeyStorageKey);
    return base64Decode(keyString!);
  }

  String encryptData(String plainText) {
    if (_encrypter == null || plainText.isEmpty) return plainText;
    try {
      return _encrypter!.encrypt(plainText, iv: _iv).base64;
    } catch (e) {
      print("Encryption failed: $e");
      return plainText;
    }
  }

  String decryptData(String encryptedText) {
    if (_encrypter == null || encryptedText.isEmpty) return encryptedText;
    try {
      final encryptedObject = encrypt.Encrypted.from64(encryptedText);
      return _encrypter!.decrypt(encryptedObject, iv: _iv);
    } catch (e) {
      print("Decryption failed: $e");
      return encryptedText;
    }
  }
}