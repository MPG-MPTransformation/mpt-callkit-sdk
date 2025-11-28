import 'package:encrypt/encrypt.dart';
import 'package:flutter/material.dart' show debugPrint;

class MptAESHelper {
  static const String key = '01234567896868686868012345678968';

  static String encryptAesB64(String plainText) {
    final key = Key.fromUtf8(MptAESHelper.key);
    final iv = IV.allZerosOfLength(16);
    final encrypter = Encrypter(AES(key));
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    return encrypted.base64;
  }

  static String decryptAesB64(String encrypted) {
    try {
      debugPrint("Attempting to decrypt: $encrypted");
      debugPrint("Input length: ${encrypted.length}");

      final key = Key.fromUtf8(MptAESHelper.key);
      final iv = IV.allZerosOfLength(16);
      final encrypter =
          Encrypter(AES(key, mode: AESMode.cbc, padding: 'PKCS7'));
      final decrypted =
          encrypter.decrypt(Encrypted.fromBase64(encrypted), iv: iv);
      debugPrint("Decrypted successfully: $decrypted");
      return decrypted;
    } catch (e) {
      debugPrint("Error in AES decryption: $e");
      debugPrint("Input data: $encrypted");
      // Return original string if decryption fails
      // This might be a temporary workaround
      throw Exception("AES decryption failed: $e");
    }
  }
}
