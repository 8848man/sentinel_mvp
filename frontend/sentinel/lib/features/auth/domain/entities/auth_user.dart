import 'package:flutter/foundation.dart';

@immutable
class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.accessToken,
    required this.refreshToken,
  });

  final String id;
  final String email;
  final String accessToken;
  final String refreshToken;
}
