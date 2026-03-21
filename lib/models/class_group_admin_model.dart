import '../utils/json_utils.dart';

class ClassGroupAdminModel {
  final int id;
  final int schoolId;
  final String name;
  final int active;
  final String createdAt;

  ClassGroupAdminModel({
    required this.id,
    required this.schoolId,
    required this.name,
    required this.active,
    required this.createdAt,
  });

  factory ClassGroupAdminModel.fromJson(Map<String, dynamic> json) {
    return ClassGroupAdminModel(
      id: parseJsonInt(json['id']),
      schoolId: parseJsonInt(json['school_id']),
      name: parseJsonString(json['name']),
      active: parseJsonInt(json['active']),
      createdAt: parseJsonString(json['created_at']),
    );
  }
}
