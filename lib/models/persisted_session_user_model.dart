import '../utils/json_utils.dart';
import 'user_model.dart';

class PersistedSessionUserModel {
  const PersistedSessionUserModel({
    required this.id,
    required this.schoolId,
    required this.name,
    required this.email,
    required this.role,
    required this.schoolName,
    required this.schoolCode,
    required this.authTokenExpiresAt,
  });

  final int id;
  final int schoolId;
  final String name;
  final String email;
  final String role;
  final String schoolName;
  final String schoolCode;
  final String authTokenExpiresAt;

  factory PersistedSessionUserModel.fromJson(Map<String, dynamic> json) {
    return PersistedSessionUserModel(
      id: parseJsonInt(json['id']),
      schoolId: parseJsonInt(json['school_id']),
      name: parseJsonString(json['name']),
      email: parseJsonString(json['email']),
      role: parseJsonString(json['role']),
      schoolName: parseJsonString(json['school_name']),
      schoolCode: parseJsonString(json['school_code']),
      authTokenExpiresAt: parseJsonString(json['api_token_expires_at']),
    );
  }

  factory PersistedSessionUserModel.fromUser(UserModel user) {
    return PersistedSessionUserModel(
      id: user.id,
      schoolId: user.schoolId,
      name: user.name,
      email: user.email,
      role: user.role,
      schoolName: user.schoolName,
      schoolCode: user.schoolCode,
      authTokenExpiresAt: user.authTokenExpiresAt,
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
      'api_token_expires_at': authTokenExpiresAt,
    };
  }

  UserModel toUser({required String authToken}) {
    return UserModel(
      id: id,
      schoolId: schoolId,
      name: name,
      email: email,
      role: role,
      schoolName: schoolName,
      schoolCode: schoolCode,
      authToken: authToken,
      authTokenExpiresAt: authTokenExpiresAt,
    );
  }
}
