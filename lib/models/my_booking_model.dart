import '../utils/json_utils.dart';

class MyBookingModel {
  final int id;
  final String bookingDate;
  final String purpose;
  final String status;
  final String? cancelledAt;
  final String? completedAt;
  final String? completedByName;
  final String? completionFeedback;
  final String resourceName;
  final String classGroupName;
  final String subjectName;
  final List<MyBookingLessonModel> lessons;

  MyBookingModel({
    required this.id,
    required this.bookingDate,
    required this.purpose,
    required this.status,
    this.cancelledAt,
    this.completedAt,
    this.completedByName,
    this.completionFeedback,
    required this.resourceName,
    required this.classGroupName,
    required this.subjectName,
    required this.lessons,
  });

  factory MyBookingModel.fromJson(Map<String, dynamic> json) {
    final lessonsData = parseJsonObjectList(json['lessons']);

    return MyBookingModel(
      id: parseJsonInt(json['id']),
      bookingDate: parseJsonString(json['booking_date']),
      purpose: parseJsonString(json['purpose']),
      status: parseJsonString(json['status']),
      cancelledAt: parseJsonStringOrNull(json['cancelled_at']),
      completedAt: parseJsonStringOrNull(json['completed_at']),
      completedByName: parseJsonStringOrNull(json['completed_by_name']),
      completionFeedback: parseJsonStringOrNull(json['completion_feedback']),
      resourceName: parseJsonString(json['resource_name']),
      classGroupName: parseJsonString(json['class_group_name']),
      subjectName: parseJsonString(json['subject_name']),
      lessons: lessonsData
          .map((e) => MyBookingLessonModel.fromJson(e))
          .toList(),
    );
  }

  MyBookingModel copyWith({
    int? id,
    String? bookingDate,
    String? purpose,
    String? status,
    Object? cancelledAt = _myBookingModelSentinel,
    Object? completedAt = _myBookingModelSentinel,
    Object? completedByName = _myBookingModelSentinel,
    Object? completionFeedback = _myBookingModelSentinel,
    String? resourceName,
    String? classGroupName,
    String? subjectName,
    List<MyBookingLessonModel>? lessons,
  }) {
    return MyBookingModel(
      id: id ?? this.id,
      bookingDate: bookingDate ?? this.bookingDate,
      purpose: purpose ?? this.purpose,
      status: status ?? this.status,
      cancelledAt: identical(cancelledAt, _myBookingModelSentinel)
          ? this.cancelledAt
          : cancelledAt as String?,
      completedAt: identical(completedAt, _myBookingModelSentinel)
          ? this.completedAt
          : completedAt as String?,
      completedByName: identical(completedByName, _myBookingModelSentinel)
          ? this.completedByName
          : completedByName as String?,
      completionFeedback: identical(completionFeedback, _myBookingModelSentinel)
          ? this.completionFeedback
          : completionFeedback as String?,
      resourceName: resourceName ?? this.resourceName,
      classGroupName: classGroupName ?? this.classGroupName,
      subjectName: subjectName ?? this.subjectName,
      lessons: lessons ?? this.lessons,
    );
  }
}

const Object _myBookingModelSentinel = Object();

class MyBookingLessonModel {
  final int id;
  final int lessonNumber;
  final String label;

  MyBookingLessonModel({
    required this.id,
    required this.lessonNumber,
    required this.label,
  });

  factory MyBookingLessonModel.fromJson(Map<String, dynamic> json) {
    return MyBookingLessonModel(
      id: parseJsonInt(json['id']),
      lessonNumber: parseJsonInt(json['lesson_number']),
      label: parseJsonString(json['label']),
    );
  }
}
