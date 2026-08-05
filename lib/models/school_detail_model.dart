class SchoolDetailMetrics {
  final int totalBookings;
  final int bookingsThisMonth;
  final int bookingsPending;
  final int bookingsCompleted;
  final int bookingsCancelled;
  final int activeResources;
  final int totalResources;
  final int totalTeachers;
  final int totalTechnicians;
  final int activeClassGroups;
  final int activeSubjects;
  final int activeLessonSlots;

  const SchoolDetailMetrics({
    required this.totalBookings,
    required this.bookingsThisMonth,
    required this.bookingsPending,
    required this.bookingsCompleted,
    required this.bookingsCancelled,
    required this.activeResources,
    required this.totalResources,
    required this.totalTeachers,
    required this.totalTechnicians,
    required this.activeClassGroups,
    required this.activeSubjects,
    required this.activeLessonSlots,
  });

  factory SchoolDetailMetrics.fromJson(Map<String, dynamic> json) {
    return SchoolDetailMetrics(
      totalBookings: (json['total_bookings'] as num?)?.toInt() ?? 0,
      bookingsThisMonth: (json['bookings_this_month'] as num?)?.toInt() ?? 0,
      bookingsPending: (json['bookings_pending'] as num?)?.toInt() ?? 0,
      bookingsCompleted: (json['bookings_completed'] as num?)?.toInt() ?? 0,
      bookingsCancelled: (json['bookings_cancelled'] as num?)?.toInt() ?? 0,
      activeResources: (json['active_resources'] as num?)?.toInt() ?? 0,
      totalResources: (json['total_resources'] as num?)?.toInt() ?? 0,
      totalTeachers: (json['total_teachers'] as num?)?.toInt() ?? 0,
      totalTechnicians: (json['total_technicians'] as num?)?.toInt() ?? 0,
      activeClassGroups: (json['active_class_groups'] as num?)?.toInt() ?? 0,
      activeSubjects: (json['active_subjects'] as num?)?.toInt() ?? 0,
      activeLessonSlots: (json['active_lesson_slots'] as num?)?.toInt() ?? 0,
    );
  }
}

class SchoolDetailModel {
  final int id;
  final String schoolName;
  final String schoolCode;
  final bool active;
  final String? createdAt;
  final SchoolDetailMetrics metrics;

  const SchoolDetailModel({
    required this.id,
    required this.schoolName,
    required this.schoolCode,
    required this.active,
    this.createdAt,
    required this.metrics,
  });

  factory SchoolDetailModel.fromJson(Map<String, dynamic> json) {
    return SchoolDetailModel(
      id: json['id'] as int,
      schoolName: json['school_name'] as String,
      schoolCode: json['school_code'] as String,
      active: json['active'] as bool? ?? true,
      createdAt: json['created_at'] as String?,
      metrics: SchoolDetailMetrics.fromJson(
        json['metrics'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  SchoolDetailModel copyWith({bool? active}) {
    return SchoolDetailModel(
      id: id,
      schoolName: schoolName,
      schoolCode: schoolCode,
      active: active ?? this.active,
      createdAt: createdAt,
      metrics: metrics,
    );
  }
}
