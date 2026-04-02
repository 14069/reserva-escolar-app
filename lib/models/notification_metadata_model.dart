import '../utils/json_utils.dart';

class NotificationMetadataModel {
  const NotificationMetadataModel({
    this.bookingId,
    this.resourceId,
    this.userId,
    this.classGroupId,
    this.subjectId,
    this.bookingDate,
    this.resourceName,
    this.userName,
    this.classGroupName,
    this.subjectName,
    this.purpose,
    this.rawData = const {},
  });

  final int? bookingId;
  final int? resourceId;
  final int? userId;
  final int? classGroupId;
  final int? subjectId;
  final String? bookingDate;
  final String? resourceName;
  final String? userName;
  final String? classGroupName;
  final String? subjectName;
  final String? purpose;
  final Map<String, dynamic> rawData;

  bool get hasDisplayDetails =>
      (resourceName ?? '').isNotEmpty ||
      (classGroupName ?? '').isNotEmpty ||
      (subjectName ?? '').isNotEmpty ||
      (bookingDate ?? '').isNotEmpty ||
      (purpose ?? '').isNotEmpty;

  factory NotificationMetadataModel.fromJson(Map<String, dynamic> json) {
    return NotificationMetadataModel(
      bookingId: parseJsonIntOrNull(json['booking_id']),
      resourceId: parseJsonIntOrNull(json['resource_id']),
      userId: parseJsonIntOrNull(json['user_id']),
      classGroupId: parseJsonIntOrNull(json['class_group_id']),
      subjectId: parseJsonIntOrNull(json['subject_id']),
      bookingDate: parseJsonStringOrNull(json['booking_date']),
      resourceName: parseJsonStringOrNull(json['resource_name']),
      userName: parseJsonStringOrNull(json['user_name']),
      classGroupName: parseJsonStringOrNull(json['class_group_name']),
      subjectName: parseJsonStringOrNull(json['subject_name']),
      purpose: parseJsonStringOrNull(json['purpose']),
      rawData: Map<String, dynamic>.from(json),
    );
  }

  Map<String, dynamic> toJson() {
    return Map<String, dynamic>.from(rawData)..addAll({
      'booking_id': bookingId,
      'resource_id': resourceId,
      'user_id': userId,
      'class_group_id': classGroupId,
      'subject_id': subjectId,
      'booking_date': bookingDate,
      'resource_name': resourceName,
      'user_name': userName,
      'class_group_name': classGroupName,
      'subject_name': subjectName,
      'purpose': purpose,
    });
  }
}
