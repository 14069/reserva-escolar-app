import '../utils/json_utils.dart';

class ClassGroupModel {
  final int id;
  final int? schoolId;
  final String name;
  final int active;
  final String? createdAt;

  ClassGroupModel({
    required this.id,
    this.schoolId,
    required this.name,
    required this.active,
    this.createdAt,
  });

  factory ClassGroupModel.fromJson(Map<String, dynamic> json) {
    return ClassGroupModel(
      id: parseJsonInt(json['id']),
      schoolId: parseJsonIntOrNull(json['school_id']),
      name: parseJsonString(json['name']),
      active: parseJsonInt(json['active']),
      createdAt: parseJsonStringOrNull(json['created_at']),
    );
  }
}
