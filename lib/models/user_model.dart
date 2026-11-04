class UserModel {
  const UserModel({
    required this.userId,
    required this.username,
    required this.role,
    this.createdAt,
    this.updatedAt,
  });

  final int userId;
  final String username;
  final String role;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userId: int.parse(json['user_id'].toString()),
      username: json['username'] as String,
      role: json['role'] as String,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'].toString()),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'].toString()),
    );
  }
}
