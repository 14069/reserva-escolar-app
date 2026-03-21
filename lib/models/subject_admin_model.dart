import '../utils/json_utils.dart';

class SubjectAdminModel {
  final int id;
  final int schoolId;
  final String name;
  final int active;
  final String createdAt;

  SubjectAdminModel({
    required this.id,
    required this.schoolId,
    required this.name,
    required this.active,
    required this.createdAt,
  });

  factory SubjectAdminModel.fromJson(Map<String, dynamic> json) {
    return SubjectAdminModel(
      id: parseJsonInt(json['id']),
      schoolId: parseJsonInt(json['school_id']),
      name: parseJsonString(json['name']),
      active: parseJsonInt(json['active']),
      createdAt: parseJsonString(json['created_at']),
    );
  }
}
