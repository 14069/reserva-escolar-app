import '../utils/json_utils.dart';

class BookingAdminFiltersPreference {
  const BookingAdminFiltersPreference({
    this.selectedDate,
    this.search = '',
    this.selectedTeacher,
    this.selectedResource,
    this.selectedClassGroup,
    this.selectedStatus,
    this.selectedSort = 'date_desc',
  });

  final String? selectedDate;
  final String search;
  final String? selectedTeacher;
  final String? selectedResource;
  final String? selectedClassGroup;
  final String? selectedStatus;
  final String selectedSort;

  factory BookingAdminFiltersPreference.fromJson(Map<String, dynamic> json) {
    return BookingAdminFiltersPreference(
      selectedDate: parseJsonStringOrNull(json['selected_date']),
      search: parseJsonString(json['search']),
      selectedTeacher: parseJsonStringOrNull(json['selected_teacher']),
      selectedResource: parseJsonStringOrNull(json['selected_resource']),
      selectedClassGroup: parseJsonStringOrNull(json['selected_class_group']),
      selectedStatus: parseJsonStringOrNull(json['selected_status']),
      selectedSort: parseJsonString(
        json['selected_sort'],
        defaultValue: 'date_desc',
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'selected_date': selectedDate,
      'search': search,
      'selected_teacher': selectedTeacher,
      'selected_resource': selectedResource,
      'selected_class_group': selectedClassGroup,
      'selected_status': selectedStatus,
      'selected_sort': selectedSort,
    };
  }
}

class MyBookingsFiltersPreference {
  const MyBookingsFiltersPreference({
    this.search = '',
    this.selectedStatus,
    this.selectedSort = 'date_desc',
  });

  final String search;
  final String? selectedStatus;
  final String selectedSort;

  factory MyBookingsFiltersPreference.fromJson(Map<String, dynamic> json) {
    return MyBookingsFiltersPreference(
      search: parseJsonString(json['search']),
      selectedStatus: parseJsonStringOrNull(json['selected_status']),
      selectedSort: parseJsonString(
        json['selected_sort'],
        defaultValue: 'date_desc',
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'search': search,
      'selected_status': selectedStatus,
      'selected_sort': selectedSort,
    };
  }
}

class ReportsFiltersPreference {
  const ReportsFiltersPreference({
    this.selectedPeriod = 'all',
    this.customRangeStart,
    this.customRangeEnd,
    this.selectedTeacher,
    this.selectedResource,
    this.selectedClassGroup,
    this.selectedStatus,
  });

  final String selectedPeriod;
  final String? customRangeStart;
  final String? customRangeEnd;
  final String? selectedTeacher;
  final String? selectedResource;
  final String? selectedClassGroup;
  final String? selectedStatus;

  factory ReportsFiltersPreference.fromJson(Map<String, dynamic> json) {
    return ReportsFiltersPreference(
      selectedPeriod: parseJsonString(
        json['selected_period'],
        defaultValue: 'all',
      ),
      customRangeStart: parseJsonStringOrNull(json['custom_range_start']),
      customRangeEnd: parseJsonStringOrNull(json['custom_range_end']),
      selectedTeacher: parseJsonStringOrNull(json['selected_teacher']),
      selectedResource: parseJsonStringOrNull(json['selected_resource']),
      selectedClassGroup: parseJsonStringOrNull(json['selected_class_group']),
      selectedStatus: parseJsonStringOrNull(json['selected_status']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'selected_period': selectedPeriod,
      'custom_range_start': customRangeStart,
      'custom_range_end': customRangeEnd,
      'selected_teacher': selectedTeacher,
      'selected_resource': selectedResource,
      'selected_class_group': selectedClassGroup,
      'selected_status': selectedStatus,
    };
  }
}
