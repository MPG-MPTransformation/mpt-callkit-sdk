import 'package:encrypt/encrypt.dart';
import 'package:mpt_callkit/logger/mpt_callkit_logger.dart';

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
      MptCallkitLogger.instance.logMessage("Attempting to decrypt: $encrypted");
      MptCallkitLogger.instance.logMessage("Input length: ${encrypted.length}");

      final key = Key.fromUtf8(MptAESHelper.key);
      final iv = IV.allZerosOfLength(16);
      final encrypter =
          Encrypter(AES(key, mode: AESMode.cbc, padding: 'PKCS7'));
      final decrypted =
          encrypter.decrypt(Encrypted.fromBase64(encrypted), iv: iv);
      MptCallkitLogger.instance
          .logMessage("Decrypted successfully: $decrypted");
      return decrypted;
    } catch (e) {
      MptCallkitLogger.instance.logMessage("Error in AES decryption: $e");
      MptCallkitLogger.instance.logMessage("Input data: $encrypted");
      // Return original string if decryption fails
      // This might be a temporary workaround
      throw Exception("AES decryption failed: $e");
    }
  }
}
