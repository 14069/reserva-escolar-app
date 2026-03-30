import '../utils/json_utils.dart';

class BookingAdminModel {
  final int id;
  final String bookingDate;
  final String purpose;
  final String status;
  final String? cancelledAt;
  final String? completedAt;
  final String? completedByName;
  final String? completionFeedback;
  final String resourceName;
  final String userName;
  final String classGroupName;
  final String subjectName;
  final List<BookingLessonModel> lessons;

  BookingAdminModel({
    required this.id,
    required this.bookingDate,
    required this.purpose,
    required this.status,
    this.cancelledAt,
    this.completedAt,
    this.completedByName,
    this.completionFeedback,
    required this.resourceName,
    required this.userName,
    required this.classGroupName,
    required this.subjectName,
    required this.lessons,
  });

  factory BookingAdminModel.fromJson(Map<String, dynamic> json) {
    final lessonsData = parseJsonObjectList(json['lessons']);

    return BookingAdminModel(
      id: parseJsonInt(json['id']),
      bookingDate: parseJsonString(json['booking_date']),
      purpose: parseJsonString(json['purpose']),
      status: parseJsonString(json['status']),
      cancelledAt: parseJsonStringOrNull(json['cancelled_at']),
      completedAt: parseJsonStringOrNull(json['completed_at']),
      completedByName: parseJsonStringOrNull(json['completed_by_name']),
      completionFeedback: parseJsonStringOrNull(json['completion_feedback']),
      resourceName: parseJsonString(json['resource_name']),
      userName: parseJsonString(json['user_name']),
      classGroupName: parseJsonString(json['class_group_name']),
      subjectName: parseJsonString(json['subject_name']),
      lessons: lessonsData.map((e) => BookingLessonModel.fromJson(e)).toList(),
    );
  }

  BookingAdminModel copyWith({
    int? id,
    String? bookingDate,
    String? purpose,
    String? status,
    Object? cancelledAt = _bookingAdminModelSentinel,
    Object? completedAt = _bookingAdminModelSentinel,
    Object? completedByName = _bookingAdminModelSentinel,
    Object? completionFeedback = _bookingAdminModelSentinel,
    String? resourceName,
    String? userName,
    String? classGroupName,
    String? subjectName,
    List<BookingLessonModel>? lessons,
  }) {
    return BookingAdminModel(
      id: id ?? this.id,
      bookingDate: bookingDate ?? this.bookingDate,
      purpose: purpose ?? this.purpose,
      status: status ?? this.status,
      cancelledAt: identical(cancelledAt, _bookingAdminModelSentinel)
          ? this.cancelledAt
          : cancelledAt as String?,
      completedAt: identical(completedAt, _bookingAdminModelSentinel)
          ? this.completedAt
          : completedAt as String?,
      completedByName: identical(completedByName, _bookingAdminModelSentinel)
          ? this.completedByName
          : completedByName as String?,
      completionFeedback:
          identical(completionFeedback, _bookingAdminModelSentinel)
          ? this.completionFeedback
          : completionFeedback as String?,
      resourceName: resourceName ?? this.resourceName,
      userName: userName ?? this.userName,
      classGroupName: classGroupName ?? this.classGroupName,
      subjectName: subjectName ?? this.subjectName,
      lessons: lessons ?? this.lessons,
    );
  }
}

const Object _bookingAdminModelSentinel = Object();

class BookingLessonModel {
  final int id;
  final int lessonNumber;
  final String label;

  BookingLessonModel({
    required this.id,
    required this.lessonNumber,
    required this.label,
  });

  factory BookingLessonModel.fromJson(Map<String, dynamic> json) {
    return BookingLessonModel(
      id: parseJsonInt(json['id']),
      lessonNumber: parseJsonInt(json['lesson_number']),
      label: parseJsonString(json['label']),
    );
  }
}
