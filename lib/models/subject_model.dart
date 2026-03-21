import '../utils/json_utils.dart';

class SubjectModel {
  final int id;
  final String name;
  final int active;

  SubjectModel({
    required this.id,
    required this.name,
    required this.active,
  });

  factory SubjectModel.fromJson(Map<String, dynamic> json) {
    return SubjectModel(
      id: parseJsonInt(json['id']),
      name: parseJsonString(json['name']),
      active: parseJsonInt(json['active']),
    );
  }
}
