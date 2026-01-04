import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _chunkSizeKey = 'chunk_size';
  static const int _defaultChunkSize = 256;
  static const int _maxChunkSize = 2048;
  static const int _minChunkSize = 100;

  /// Get the current chunk size setting
  static Future<int> getChunkSize() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_chunkSizeKey) ?? _defaultChunkSize;
  }

  /// Set the chunk size setting
  static Future<bool> setChunkSize(int size) async {
    if (size < _minChunkSize || size > _maxChunkSize) {
      return false;
    }
    final prefs = await SharedPreferences.getInstance();
    return await prefs.setInt(_chunkSizeKey, size);
  }

  /// Get the minimum allowed chunk size
  static int get minChunkSize => _minChunkSize;

  /// Get the maximum allowed chunk size
  static int get maxChunkSize => _maxChunkSize;

  /// Get the default chunk size
  static int get defaultChunkSize => _defaultChunkSize;
}

