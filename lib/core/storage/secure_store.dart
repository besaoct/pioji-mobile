import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The Sanctum token lives only here: Keychain on iOS, Keystore on Android.
class SecureStore {
  SecureStore([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
            );

  final FlutterSecureStorage _storage;
  static const _tokenKey = 'auth_token';
  String? _cached;

  Future<String?> readToken() async => _cached ??= await _storage.read(key: _tokenKey);

  Future<void> writeToken(String token) async {
    _cached = token;
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<void> clear() async {
    _cached = null;
    await _storage.delete(key: _tokenKey);
  }
}

final secureStoreProvider = Provider<SecureStore>((ref) => SecureStore());
