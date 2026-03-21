import '../utils/json_utils.dart';

class ResourceCategoryModel {
  final int id;
  final String name;

  ResourceCategoryModel({
    required this.id,
    required this.name,
  });

  factory ResourceCategoryModel.fromJson(Map<String, dynamic> json) {
    return ResourceCategoryModel(
      id: parseJsonInt(json['id']),
      name: parseJsonString(json['name']),
    );
  }
}
