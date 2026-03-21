import '../utils/json_utils.dart';

class BookingModel {
  final int id;
  final String bookingDate;
  final String startTime;
  final String endTime;
  final String purpose;
  final String subject;
  final String classGroup;
  final String status;
  final String? cancelledAt;
  final int resourceId;
  final String resourceName;
  final String resourceType;
  final int? userId;
  final String? userName;

  BookingModel({
    required this.id,
    required this.bookingDate,
    required this.startTime,
    required this.endTime,
    required this.purpose,
    required this.subject,
    required this.classGroup,
    required this.status,
    this.cancelledAt,
    required this.resourceId,
    required this.resourceName,
    required this.resourceType,
    this.userId,
    this.userName,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    return BookingModel(
      id: parseJsonInt(json['id']),
      bookingDate: parseJsonString(json['booking_date']),
      startTime: parseJsonString(json['start_time']),
      endTime: parseJsonString(json['end_time']),
      purpose: parseJsonString(json['purpose']),
      subject: parseJsonString(json['subject']),
      classGroup: parseJsonString(json['class_group']),
      status: parseJsonString(json['status'], defaultValue: 'scheduled'),
      cancelledAt: parseJsonStringOrNull(json['cancelled_at']),
      resourceId: parseJsonInt(json['resource_id']),
      resourceName: parseJsonString(json['resource_name']),
      resourceType: parseJsonString(json['resource_type']),
      userId: parseJsonIntOrNull(json['user_id']),
      userName: parseJsonStringOrNull(json['user_name']),
    );
  }
}
