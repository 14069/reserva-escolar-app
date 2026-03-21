import '../utils/json_utils.dart';

class ClassGroupModel {
  final int id;
  final String name;
  final int active;

  ClassGroupModel({
    required this.id,
    required this.name,
    required this.active,
  });

  factory ClassGroupModel.fromJson(Map<String, dynamic> json) {
    return ClassGroupModel(
      id: parseJsonInt(json['id']),
      name: parseJsonString(json['name']),
      active: parseJsonInt(json['active']),
    );
  }
}
