import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api.dart';
import '../../../core/network/dio_provider.dart';
export '../../../core/network/dio_provider.dart' show apiProvider;
import '../../../core/utils/json.dart';
import '../domain/user.dart';

class AuthRepository {
  const AuthRepository(this._api);
  final Api _api;

  /// Returns the token and, when the API includes it, the user.
  Future<({String token, User? user})> login({
    required String email,
    required String password,
    required String deviceName,
  }) async {
    final data = await _api.post('/auth/login', {
      'email': email,
      'password': password,
      'device_name': deviceName,
    });
    final map = J.map(data) ?? const <String, dynamic>{};
    final token = J.str(map['token']) ?? J.str(map['access_token']) ?? (data is String ? data : null);
    if (token == null) throw const FormatException('Login response had no token');
    final userJson = J.map(map['user']);
    return (token: token, user: userJson == null ? null : User.fromJson(userJson));
  }

  /// `GET /auth/me`. Not on the backend yet; callers handle NotFoundFailure.
  Future<User> me() async {
    final data = await _api.getData('/auth/me');
    final map = J.map(data) ?? const <String, dynamic>{};
    return User.fromJson(J.map(map['user']) ?? map);
  }

  /// `POST /auth/logout`. Not on the backend yet; failures are ignored.
  Future<void> logout() async {
    try {
      await _api.post('/auth/logout', const <String, Object?>{});
    } catch (_) {}
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository(ref.watch(apiProvider)));
