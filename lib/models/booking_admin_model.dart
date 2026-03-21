import '../utils/json_utils.dart';

class BookingAdminModel {
  final int id;
  final String bookingDate;
  final String purpose;
  final String status;
  final String? cancelledAt;
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
      resourceName: parseJsonString(json['resource_name']),
      userName: parseJsonString(json['user_name']),
      classGroupName: parseJsonString(json['class_group_name']),
      subjectName: parseJsonString(json['subject_name']),
      lessons: lessonsData
          .map((e) => BookingLessonModel.fromJson(e))
          .toList(),
    );
  }
}

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
