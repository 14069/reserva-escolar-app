import 'school_summary_model.dart';

class PlatformSchoolStats {
  final int total;
  final int active;
  final int suspended;
  final int newThisMonth;

  const PlatformSchoolStats({
    required this.total,
    required this.active,
    required this.suspended,
    required this.newThisMonth,
  });

  factory PlatformSchoolStats.fromJson(Map<String, dynamic> json) {
    return PlatformSchoolStats(
      total: (json['total'] as num?)?.toInt() ?? 0,
      active: (json['active'] as num?)?.toInt() ?? 0,
      suspended: (json['suspended'] as num?)?.toInt() ?? 0,
      newThisMonth: (json['new_this_month'] as num?)?.toInt() ?? 0,
    );
  }
}

class PlatformUserStats {
  final int total;
  final int teachers;
  final int technicians;

  const PlatformUserStats({
    required this.total,
    required this.teachers,
    required this.technicians,
  });

  factory PlatformUserStats.fromJson(Map<String, dynamic> json) {
    return PlatformUserStats(
      total: (json['total'] as num?)?.toInt() ?? 0,
      teachers: (json['teachers'] as num?)?.toInt() ?? 0,
      technicians: (json['technicians'] as num?)?.toInt() ?? 0,
    );
  }
}

class PlatformBookingStats {
  final int total;
  final int thisMonth;
  final int pending;
  final int completed;
  final int cancelled;

  const PlatformBookingStats({
    required this.total,
    required this.thisMonth,
    required this.pending,
    required this.completed,
    required this.cancelled,
  });

  factory PlatformBookingStats.fromJson(Map<String, dynamic> json) {
    return PlatformBookingStats(
      total: (json['total'] as num?)?.toInt() ?? 0,
      thisMonth: (json['this_month'] as num?)?.toInt() ?? 0,
      pending: (json['pending'] as num?)?.toInt() ?? 0,
      completed: (json['completed'] as num?)?.toInt() ?? 0,
      cancelled: (json['cancelled'] as num?)?.toInt() ?? 0,
    );
  }
}

class PlatformMetricsModel {
  final PlatformSchoolStats schools;
  final PlatformUserStats users;
  final PlatformBookingStats bookings;
  final List<SchoolSummaryModel> recentSchools;

  const PlatformMetricsModel({
    required this.schools,
    required this.users,
    required this.bookings,
    required this.recentSchools,
  });

  factory PlatformMetricsModel.fromJson(Map<String, dynamic> json) {
    final raw = json['recent_schools'];
    final recentSchools = raw is List
        ? raw.whereType<Map<String, dynamic>>().map(SchoolSummaryModel.fromJson).toList()
        : <SchoolSummaryModel>[];

    return PlatformMetricsModel(
      schools: PlatformSchoolStats.fromJson(
        json['schools'] as Map<String, dynamic>? ?? {},
      ),
      users: PlatformUserStats.fromJson(
        json['users'] as Map<String, dynamic>? ?? {},
      ),
      bookings: PlatformBookingStats.fromJson(
        json['bookings'] as Map<String, dynamic>? ?? {},
      ),
      recentSchools: recentSchools,
    );
  }
}
