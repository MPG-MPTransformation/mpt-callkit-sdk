import 'package:flutter/material.dart';

class MptCallkitLogger {
  // Private constructor để ngăn tạo instance từ bên ngoài
  MptCallkitLogger._();

  // Static instance (Singleton)
  static final MptCallkitLogger _instance = MptCallkitLogger._();

  // Getter để lấy instance (optional, nếu cần)
  static MptCallkitLogger get instance => _instance;

  // Static method để log - có thể dùng trong cả static và non-static methods
  static void log(String message) {
    print(message);
    debugPrint(message);
  }

  // Non-static method vẫn giữ lại (backward compatibility)
  void logMessage(String message) {
    log(message);
  }
}
