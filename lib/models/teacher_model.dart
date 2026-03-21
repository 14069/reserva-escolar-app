import '../utils/json_utils.dart';

class TeacherModel {
  final int id;
  final int schoolId;
  final String name;
  final String email;
  final String role;
  final int active;
  final String createdAt;

  TeacherModel({
    required this.id,
    required this.schoolId,
    required this.name,
    required this.email,
    required this.role,
    required this.active,
    required this.createdAt,
  });

  factory TeacherModel.fromJson(Map<String, dynamic> json) {
    return TeacherModel(
      id: parseJsonInt(json['id']),
      schoolId: parseJsonInt(json['school_id']),
      name: parseJsonString(json['name']),
      email: parseJsonString(json['email']),
      role: parseJsonString(json['role']),
      active: parseJsonInt(json['active']),
      createdAt: parseJsonString(json['created_at']),
    );
  }
}
