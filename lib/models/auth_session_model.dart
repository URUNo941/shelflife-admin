import 'user_model.dart';

class AuthSessionModel {
  const AuthSessionModel({required this.token, required this.user});

  final String token;
  final UserModel user;

  factory AuthSessionModel.fromJson(Map<String, dynamic> json) {
    return AuthSessionModel(
      token: json['token'] as String,
      user: UserModel.fromJson(
        Map<String, dynamic>.from(json['user'] as Map),
      ),
    );
  }
}
