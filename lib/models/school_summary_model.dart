class SchoolSummaryModel {
  final int id;
  final String schoolName;
  final String schoolCode;
  final bool active;
  final int usersCount;
  final String? createdAt;

  const SchoolSummaryModel({
    required this.id,
    required this.schoolName,
    required this.schoolCode,
    required this.active,
    required this.usersCount,
    this.createdAt,
  });

  factory SchoolSummaryModel.fromJson(Map<String, dynamic> json) {
    return SchoolSummaryModel(
      id: json['id'] as int,
      schoolName: json['school_name'] as String,
      schoolCode: json['school_code'] as String,
      active: json['active'] as bool? ?? true,
      usersCount: (json['users_count'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] as String?,
    );
  }
}
