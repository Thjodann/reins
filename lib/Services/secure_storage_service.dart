import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';

/// Secure key-value storage wrapper for sensitive credentials.
class SecureStorageService {
  static const _openAiApiKeyStorageKey = 'openai_api_key';
  static const _macOsKeychainGroup = 'reins-keychain';
  final FlutterSecureStorage _secureStorage;
  String? _sessionOpenAiApiKey;
  bool _isUsingSessionFallback = false;

  /// True when secure keychain access is unavailable and session-only storage is used.
  bool get isUsingSessionFallback => _isUsingSessionFallback;

  SecureStorageService({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              mOptions: MacOsOptions(
                groupId: _macOsKeychainGroup,
              ),
            );

  /// Reads the currently stored OpenAI API key.
  Future<String?> readOpenAiApiKey() async {
    try {
      final persistedKey = await _secureStorage.read(key: _openAiApiKeyStorageKey);
      if (persistedKey != null && persistedKey.trim().isNotEmpty) {
        _sessionOpenAiApiKey = persistedKey.trim();
      }
      return persistedKey ?? _sessionOpenAiApiKey;
    } on PlatformException catch (error) {
      _isUsingSessionFallback = true;
      _debugPrintSecureStorageError(error);
      return _sessionOpenAiApiKey;
    }
  }

  /// Persists the OpenAI API key in platform secure storage.
  Future<void> writeOpenAiApiKey(String apiKey) async {
    final trimmedKey = apiKey.trim();
    _sessionOpenAiApiKey = trimmedKey;
    try {
      await _secureStorage.write(
        key: _openAiApiKeyStorageKey,
        value: trimmedKey,
      );
      _isUsingSessionFallback = false;
    } on PlatformException catch (error) {
      _isUsingSessionFallback = true;
      _debugPrintSecureStorageError(error);
    }
  }

  /// Deletes the stored OpenAI API key.
  Future<void> deleteOpenAiApiKey() async {
    _sessionOpenAiApiKey = null;
    try {
      await _secureStorage.delete(key: _openAiApiKeyStorageKey);
      _isUsingSessionFallback = false;
    } on PlatformException catch (error) {
      _isUsingSessionFallback = true;
      _debugPrintSecureStorageError(error);
    }
  }

  void _debugPrintSecureStorageError(PlatformException error) {
    final message = error.message ?? 'Secure storage unavailable.';
    // ignore: avoid_print
    print('Secure storage unavailable, using session fallback: $message');
  }
}
