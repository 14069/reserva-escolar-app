import '../utils/json_utils.dart';

class LessonSlotModel {
  final int id;
  final int lessonNumber;
  final String label;
  final String? startTime;
  final String? endTime;

  LessonSlotModel({
    required this.id,
    required this.lessonNumber,
    required this.label,
    this.startTime,
    this.endTime,
  });

  factory LessonSlotModel.fromJson(Map<String, dynamic> json) {
    return LessonSlotModel(
      id: parseJsonInt(json['id']),
      lessonNumber: parseJsonInt(json['lesson_number']),
      label: parseJsonString(json['label']),
      startTime: parseJsonStringOrNull(json['start_time']),
      endTime: parseJsonStringOrNull(json['end_time']),
    );
  }
}
