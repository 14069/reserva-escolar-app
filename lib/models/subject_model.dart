import '../utils/json_utils.dart';

class SubjectModel {
  final int id;
  final int? schoolId;
  final String name;
  final int active;
  final String? createdAt;

  SubjectModel({
    required this.id,
    this.schoolId,
    required this.name,
    required this.active,
    this.createdAt,
  });

  factory SubjectModel.fromJson(Map<String, dynamic> json) {
    return SubjectModel(
      id: parseJsonInt(json['id']),
      schoolId: parseJsonIntOrNull(json['school_id']),
      name: parseJsonString(json['name']),
      active: parseJsonInt(json['active']),
      createdAt: parseJsonStringOrNull(json['created_at']),
    );
  }
}
