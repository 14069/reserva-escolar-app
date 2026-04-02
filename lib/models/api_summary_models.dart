import '../utils/json_utils.dart';

class NotificationFeedSummary {
  const NotificationFeedSummary({required this.unreadCount});

  final int unreadCount;

  factory NotificationFeedSummary.fromJson(Map<String, dynamic> json) {
    return NotificationFeedSummary(
      unreadCount: parseJsonInt(json['unread_count']),
    );
  }
}

class RankingEntryModel {
  const RankingEntryModel({
    required this.label,
    required this.value,
  });

  final String label;
  final int value;

  factory RankingEntryModel.fromJson(Map<String, dynamic> json) {
    return RankingEntryModel(
      label: parseJsonString(json['label']),
      value: parseJsonInt(json['value']),
    );
  }
}

class BookingSummaryModel {
  const BookingSummaryModel({
    required this.overallCount,
    required this.scheduledCount,
    required this.completedCount,
    required this.completedTodayCount,
    required this.cancelledCount,
    required this.uniqueTeachersCount,
    required this.uniqueResourcesCount,
    required this.uniqueClassGroupsCount,
    required this.uniqueSubjectsCount,
    required this.totalReservedLessons,
    required this.averageLessonsPerBooking,
    required this.busiestWeekdayLabel,
    required this.teacherOptions,
    required this.resourceOptions,
    required this.classGroupOptions,
    required this.statusOptions,
    required this.teacherRanking,
    required this.resourceRanking,
    required this.classGroupRanking,
    required this.subjectRanking,
  });

  final int overallCount;
  final int scheduledCount;
  final int completedCount;
  final int completedTodayCount;
  final int cancelledCount;
  final int uniqueTeachersCount;
  final int uniqueResourcesCount;
  final int uniqueClassGroupsCount;
  final int uniqueSubjectsCount;
  final int totalReservedLessons;
  final double averageLessonsPerBooking;
  final String busiestWeekdayLabel;
  final List<String> teacherOptions;
  final List<String> resourceOptions;
  final List<String> classGroupOptions;
  final List<String> statusOptions;
  final List<RankingEntryModel> teacherRanking;
  final List<RankingEntryModel> resourceRanking;
  final List<RankingEntryModel> classGroupRanking;
  final List<RankingEntryModel> subjectRanking;

  factory BookingSummaryModel.fromJson(Map<String, dynamic> json) {
    return BookingSummaryModel(
      overallCount: parseJsonInt(json['overall_count']),
      scheduledCount: parseJsonInt(json['scheduled_count']),
      completedCount: parseJsonInt(json['completed_count']),
      completedTodayCount: parseJsonInt(json['completed_today_count']),
      cancelledCount: parseJsonInt(json['cancelled_count']),
      uniqueTeachersCount: parseJsonInt(json['unique_teachers_count']),
      uniqueResourcesCount: parseJsonInt(json['unique_resources_count']),
      uniqueClassGroupsCount: parseJsonInt(json['unique_class_groups_count']),
      uniqueSubjectsCount: parseJsonInt(json['unique_subjects_count']),
      totalReservedLessons: parseJsonInt(json['total_reserved_lessons']),
      averageLessonsPerBooking: _parseJsonDouble(
        json['average_lessons_per_booking'],
      ),
      busiestWeekdayLabel: parseJsonString(
        json['busiest_weekday_label'],
        defaultValue: 'Sem dados',
      ),
      teacherOptions: _parseStringList(json['teacher_options']),
      resourceOptions: _parseStringList(json['resource_options']),
      classGroupOptions: _parseStringList(json['class_group_options']),
      statusOptions: _parseStringList(json['status_options']),
      teacherRanking: _parseRankingList(json['teacher_ranking']),
      resourceRanking: _parseRankingList(json['resource_ranking']),
      classGroupRanking: _parseRankingList(json['class_group_ranking']),
      subjectRanking: _parseRankingList(json['subject_ranking']),
    );
  }
}

double _parseJsonDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

List<String> _parseStringList(dynamic value) {
  if (value is! List) return const [];

  final items = value
      .map((item) => item?.toString().trim() ?? '')
      .where((item) => item.isNotEmpty)
      .toSet()
      .toList()
    ..sort((a, b) => a.compareTo(b));

  return List<String>.unmodifiable(items);
}

List<RankingEntryModel> _parseRankingList(dynamic value) {
  if (value is! List) return const [];

  return value
      .whereType<Map>()
      .map((item) => RankingEntryModel.fromJson(item.cast<String, dynamic>()))
      .toList(growable: false);
}
