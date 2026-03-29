import '../utils/json_utils.dart';

class UserModel {
  final int id;
  final int schoolId;
  final String name;
  final String email;
  final String role;
  final String schoolName;
  final String schoolCode;
  final String authToken;
  final String authTokenExpiresAt;

  UserModel({
    required this.id,
    required this.schoolId,
    required this.name,
    required this.email,
    required this.role,
    required this.schoolName,
    required this.schoolCode,
    required this.authToken,
    required this.authTokenExpiresAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: parseJsonInt(json['id']),
      schoolId: parseJsonInt(json['school_id']),
      name: parseJsonString(json['name']),
      email: parseJsonString(json['email']),
      role: parseJsonString(json['role']),
      schoolName: parseJsonString(json['school_name']),
      schoolCode: parseJsonString(json['school_code']),
      authToken: parseJsonString(json['api_token']),
      authTokenExpiresAt: parseJsonString(json['api_token_expires_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'school_id': schoolId,
      'name': name,
      'email': email,
      'role': role,
      'school_name': schoolName,
      'school_code': schoolCode,
      'api_token': authToken,
      'api_token_expires_at': authTokenExpiresAt,
    };
  }

  bool get isTechnician => role == 'technician';

  String get roleLabel {
    switch (role) {
      case 'technician':
        return 'Tecnico';
      case 'teacher':
        return 'Professor';
      default:
        return role.isEmpty ? 'Nao informado' : role;
    }
  }
}
