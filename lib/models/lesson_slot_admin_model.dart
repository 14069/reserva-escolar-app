import '../utils/json_utils.dart';

class LessonSlotAdminModel {
  final int id;
  final int schoolId;
  final int lessonNumber;
  final String label;
  final String? startTime;
  final String? endTime;
  final int active;
  final String createdAt;

  LessonSlotAdminModel({
    required this.id,
    required this.schoolId,
    required this.lessonNumber,
    required this.label,
    this.startTime,
    this.endTime,
    required this.active,
    required this.createdAt,
  });

  factory LessonSlotAdminModel.fromJson(Map<String, dynamic> json) {
    return LessonSlotAdminModel(
      id: parseJsonInt(json['id']),
      schoolId: parseJsonInt(json['school_id']),
      lessonNumber: parseJsonInt(json['lesson_number']),
      label: parseJsonString(json['label']),
      startTime: parseJsonStringOrNull(json['start_time']),
      endTime: parseJsonStringOrNull(json['end_time']),
      active: parseJsonInt(json['active']),
      createdAt: parseJsonString(json['created_at']),
    );
  }
}
