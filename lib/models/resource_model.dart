import '../utils/json_utils.dart';

class ResourceModel {
  final int id;
  final String name;
  final int active;
  final int categoryId;
  final String categoryName;

  ResourceModel({
    required this.id,
    required this.name,
    required this.active,
    required this.categoryId,
    required this.categoryName,
  });

  factory ResourceModel.fromJson(Map<String, dynamic> json) {
    return ResourceModel(
      id: parseJsonInt(json['id']),
      name: parseJsonString(json['name']),
      active: parseJsonInt(json['active']),
      categoryId: parseJsonInt(json['category_id']),
      categoryName: parseJsonString(json['category_name']),
    );
  }
}
