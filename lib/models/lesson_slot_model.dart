import '../utils/json_utils.dart';

class LessonSlotModel {
  final int id;
  final int? schoolId;
  final int lessonNumber;
  final String label;
  final String? startTime;
  final String? endTime;
  final int active;
  final String? createdAt;

  LessonSlotModel({
    required this.id,
    this.schoolId,
    required this.lessonNumber,
    required this.label,
    this.startTime,
    this.endTime,
    this.active = 1,
    this.createdAt,
  });

  factory LessonSlotModel.fromJson(Map<String, dynamic> json) {
    return LessonSlotModel(
      id: parseJsonInt(json['id']),
      schoolId: parseJsonIntOrNull(json['school_id']),
      lessonNumber: parseJsonInt(json['lesson_number']),
      label: parseJsonString(json['label']),
      startTime: parseJsonStringOrNull(json['start_time']),
      endTime: parseJsonStringOrNull(json['end_time']),
      active: parseJsonInt(json['active'], defaultValue: 1),
      createdAt: parseJsonStringOrNull(json['created_at']),
    );
  }
}
