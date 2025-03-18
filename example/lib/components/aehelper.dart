import 'package:encrypt/encrypt.dart';

class AESHelper {
  static const String key = '01234567896868686868012345678968';

  static String encryptAesB64(String plainText) {
    final key = Key.fromUtf8(AESHelper.key);
    final iv = IV.allZerosOfLength(16);
    final encrypter = Encrypter(AES(key));
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    return encrypted.base64;
  }

  static String decryptAesB64(String encrypted) {
    final key = Key.fromUtf8(AESHelper.key);
    final iv = IV.allZerosOfLength(16);
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc, padding: 'PKCS7'));
    final decrypted =
        encrypter.decrypt(Encrypted.fromBase64(encrypted), iv: iv);
    // print("Decrypted: $decrypted");
    return decrypted;
  }
}
