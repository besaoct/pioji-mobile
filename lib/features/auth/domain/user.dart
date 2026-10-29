import '../../../core/utils/json.dart';

class User {
  const User({this.id, required this.name, required this.email});

  final int? id;
  final String name;
  final String email;

  factory User.fromJson(Map<String, dynamic> j) => User(
        id: J.integer(j['id']),
        name: J.str(j['name']) ?? 'Admin',
        email: J.str(j['email']) ?? '',
      );

  String get initial => name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
}

sealed class AuthState {
  const AuthState();
}

class Authenticated extends AuthState {
  const Authenticated(this.user);
  final User user;
}

class SignedOut extends AuthState {
  const SignedOut({this.sessionExpired = false});
  final bool sessionExpired;
}
