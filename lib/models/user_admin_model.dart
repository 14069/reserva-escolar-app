import '../utils/json_utils.dart';

class UserAdminModel {
  final int id;
  final String name;
  final String email;
  final String role;
  final String createdAt;

  UserAdminModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.createdAt,
  });

  factory UserAdminModel.fromJson(Map<String, dynamic> json) {
    return UserAdminModel(
      id: parseJsonInt(json['id']),
      name: parseJsonString(json['name']),
      email: parseJsonString(json['email']),
      role: parseJsonString(json['role']),
      createdAt: parseJsonString(json['created_at']),
    );
  }
}
