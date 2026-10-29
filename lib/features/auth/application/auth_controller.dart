import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/storage/prefs.dart';
import '../../../core/storage/secure_store.dart';
import '../data/auth_repository.dart';
import '../domain/user.dart';

class AuthController extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    final token = await ref.read(secureStoreProvider).readToken();
    if (token == null) return const SignedOut();
    try {
      final user = await ref.read(authRepositoryProvider).me();
      _remember(user);
      return Authenticated(user);
    } on UnauthorizedFailure {
      await ref.read(secureStoreProvider).clear();
      return const SignedOut(sessionExpired: true);
    } on AppFailure {
      // Offline, or /auth/me isn't on the backend yet: keep the session and
      // let the first real request decide. A 401 there signs the user out.
      return Authenticated(_cachedUser());
    }
  }

  /// Returns null on success, or the failure to show on the login screen.
  Future<AppFailure?> signIn(String email, String password) async {
    try {
      final result = await ref.read(authRepositoryProvider).login(
            email: email,
            password: password,
            deviceName: await _deviceName(),
          );
      await ref.read(secureStoreProvider).writeToken(result.token);
      final user = result.user ?? User(name: 'Admin', email: email);
      _remember(user);
      state = AsyncData(Authenticated(user));
      return null;
    } on AppFailure catch (f) {
      return f;
    } on FormatException {
      return const ServerFailure();
    }
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).logout();
    await ref.read(secureStoreProvider).clear();
    state = const AsyncData(SignedOut());
  }

  /// Called by the network layer on any 401.
  Future<void> onUnauthorized() async {
    if (state.value is! Authenticated) return;
    await ref.read(secureStoreProvider).clear();
    state = const AsyncData(SignedOut(sessionExpired: true));
  }

  void _remember(User u) {
    final prefs = ref.read(sharedPrefsProvider);
    prefs.setString(PrefKeys.userName, u.name);
    prefs.setString(PrefKeys.userEmail, u.email);
  }

  User _cachedUser() {
    final prefs = ref.read(sharedPrefsProvider);
    return User(
      name: prefs.getString(PrefKeys.userName) ?? 'Admin',
      email: prefs.getString(PrefKeys.userEmail) ?? '',
    );
  }

  Future<String> _deviceName() async {
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isIOS) return 'iOS_${(await info.iosInfo).utsname.machine}';
      if (Platform.isAndroid) {
        final a = await info.androidInfo;
        return 'Android_${a.manufacturer}_${a.model}'.replaceAll(' ', '_');
      }
    } catch (_) {}
    return 'Flutter_${Platform.operatingSystem}';
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, AuthState>(AuthController.new);
