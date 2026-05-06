import 'dart:async';

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

import '../models/api_summary_models.dart';
import '../models/booking_admin_model.dart';
import '../models/filter_preferences_model.dart';
import '../providers/app_preferences_provider.dart';
import '../services/api_service.dart';
import '../utils/app_formatters.dart';

enum ReportPeriod { last7Days, last30Days, thisMonth, custom, all }

class RankingEntry {
  final String label;
  final int value;
  const RankingEntry({required this.label, required this.value});
}

class ReportsAdminProvider extends ChangeNotifier {
  ReportsAdminProvider({
    required int schoolId,
    required AppPreferencesProvider preferences,
  })  : _schoolId = schoolId,
        _preferences = preferences;

  final int _schoolId;
  final AppPreferencesProvider _preferences;
  final _logger = Logger();

  static const String _filtersPreferenceKey = 'reports_admin_filters_v1';
  static const int _pageSize = 15;
  static const int _exportPageSize = 100;

  // loading state
  bool isLoading = true;
  bool isLoadingMore = false;
  String? loadError;

  // data
  List<BookingAdminModel> detailedBookings = [];
  bool hasMorePages = false;
  int currentPage = 1;

  // stats
  int totalBookingsCount = 0;
  int overallBookingsCount = 0;
  int scheduledCount = 0;
  int completedCount = 0;
  int cancelledCount = 0;
  int uniqueTeachersCount = 0;
  int uniqueResourcesCount = 0;
  int uniqueClassGroupsCount = 0;
  int uniqueSubjectsCount = 0;
  int totalReservedLessons = 0;
  double averageLessonsPerBooking = 0;
  String busiestWeekdayLabel = 'Sem dados';

  // filter options
  List<String> teacherOptions = [];
  List<String> resourceOptions = [];
  List<String> classGroupOptions = [];
  List<String> statusOptions = [];

  // rankings
  List<RankingEntry> teacherRanking = const [];
  List<RankingEntry> resourceRanking = const [];
  List<RankingEntry> subjectRanking = const [];
  List<RankingEntry> classGroupRanking = const [];

  // active filters
  ReportPeriod selectedPeriod = ReportPeriod.all;
  DateTimeRange? customRange;
  String? selectedTeacher;
  String? selectedResource;
  String? selectedClassGroup;
  String? selectedStatus;

  // computed
  double get cancellationRate {
    if (totalBookingsCount == 0) return 0;
    return (cancelledCount / totalBookingsCount) * 100;
  }

  int get activeFilterCount {
    return [selectedTeacher, selectedResource, selectedClassGroup, selectedStatus]
        .where((v) => v != null)
        .length;
  }

  bool get _hasCustomPreferences {
    return selectedPeriod != ReportPeriod.all ||
        customRange != null ||
        selectedTeacher != null ||
        selectedResource != null ||
        selectedClassGroup != null ||
        selectedStatus != null;
  }

  DateTimeRange? resolveRange() {
    final now = DateUtils.dateOnly(DateTime.now());
    switch (selectedPeriod) {
      case ReportPeriod.last7Days:
        return DateTimeRange(start: now.subtract(const Duration(days: 6)), end: now);
      case ReportPeriod.last30Days:
        return DateTimeRange(start: now.subtract(const Duration(days: 29)), end: now);
      case ReportPeriod.thisMonth:
        return DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);
      case ReportPeriod.custom:
        return customRange;
      case ReportPeriod.all:
        return null;
    }
  }

  String get rangeLabel {
    final range = resolveRange();
    if (range == null) return 'Todo o histórico';
    return '${AppFormatters.formatDate(range.start)} a ${AppFormatters.formatDate(range.end)}';
  }

  String? get _dateFrom {
    final range = resolveRange();
    if (range == null) return null;
    return AppFormatters.formatApiDate(DateUtils.dateOnly(range.start));
  }

  String? get _dateTo {
    final range = resolveRange();
    if (range == null) return null;
    return AppFormatters.formatApiDate(DateUtils.dateOnly(range.end));
  }

  // init
  Future<void> initialize() async {
    final savedFilters = await _preferences.getObjectPreference(
      _filtersPreferenceKey,
      ReportsFiltersPreference.fromJson,
    );

    if (savedFilters != null) {
      final restoredPeriod = ReportPeriod.values.firstWhere(
        (p) => p.name == savedFilters.selectedPeriod,
        orElse: () => ReportPeriod.all,
      );
      final restoredStart = DateTime.tryParse(savedFilters.customRangeStart ?? '');
      final restoredEnd = DateTime.tryParse(savedFilters.customRangeEnd ?? '');

      selectedPeriod = restoredPeriod;
      customRange = restoredPeriod == ReportPeriod.custom &&
              restoredStart != null &&
              restoredEnd != null
          ? DateTimeRange(
              start: DateUtils.dateOnly(restoredStart),
              end: DateUtils.dateOnly(restoredEnd),
            )
          : null;
      selectedTeacher = savedFilters.selectedTeacher;
      selectedResource = savedFilters.selectedResource;
      selectedClassGroup = savedFilters.selectedClassGroup;
      selectedStatus = savedFilters.selectedStatus;
      notifyListeners();
    }

    await loadReport();
  }

  // filter setters
  void selectPeriod(ReportPeriod period) {
    selectedPeriod = period;
    notifyListeners();
    loadReport();
  }

  void setCustomRange(DateTimeRange range) {
    customRange = range;
    selectedPeriod = ReportPeriod.custom;
    notifyListeners();
    loadReport();
  }

  void setTeacher(String? value) {
    selectedTeacher = value;
    notifyListeners();
    loadReport();
  }

  void setResource(String? value) {
    selectedResource = value;
    notifyListeners();
    loadReport();
  }

  void setClassGroup(String? value) {
    selectedClassGroup = value;
    notifyListeners();
    loadReport();
  }

  void setStatus(String? value) {
    selectedStatus = value;
    notifyListeners();
    loadReport();
  }

  void clearAdvancedFilters() {
    selectedTeacher = null;
    selectedResource = null;
    selectedClassGroup = null;
    selectedStatus = null;
    notifyListeners();
    loadReport();
  }

  // data loading
  Future<void> loadReport({bool loadMore = false}) async {
    if (!loadMore) unawaited(_persistFilters());

    final nextPage = loadMore ? currentPage + 1 : 1;
    isLoading = !loadMore;
    isLoadingMore = loadMore;
    if (!loadMore) loadError = null;
    notifyListeners();

    try {
      final response = await ApiService.getAllBookingsPage(
        schoolId: _schoolId,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        page: nextPage,
        pageSize: _pageSize,
        teacher: selectedTeacher,
        resource: selectedResource,
        classGroup: selectedClassGroup,
        status: selectedStatus,
        sort: 'date_desc',
      );

      if (response.success) {
        final summary = response.summary;
        final meta = response.meta;

        detailedBookings = loadMore
            ? [...detailedBookings, ...response.items]
            : response.items;
        currentPage = nextPage;
        hasMorePages = meta.hasNextPage;
        totalBookingsCount =
            meta.total == 0 ? response.items.length : meta.total;
        overallBookingsCount = summary?.overallCount ?? totalBookingsCount;
        scheduledCount = summary?.scheduledCount ?? 0;
        completedCount = summary?.completedCount ?? 0;
        cancelledCount = summary?.cancelledCount ?? 0;
        uniqueTeachersCount = summary?.uniqueTeachersCount ?? 0;
        uniqueResourcesCount = summary?.uniqueResourcesCount ?? 0;
        uniqueClassGroupsCount = summary?.uniqueClassGroupsCount ?? 0;
        uniqueSubjectsCount = summary?.uniqueSubjectsCount ?? 0;
        totalReservedLessons = summary?.totalReservedLessons ?? 0;
        averageLessonsPerBooking = summary?.averageLessonsPerBooking ?? 0;
        busiestWeekdayLabel = _resolveBusiestWeekday(summary);
        teacherOptions = _mergeOption(summary?.teacherOptions ?? const [], selectedTeacher);
        resourceOptions = _mergeOption(summary?.resourceOptions ?? const [], selectedResource);
        classGroupOptions = _mergeOption(summary?.classGroupOptions ?? const [], selectedClassGroup);
        statusOptions = _mergeOption(summary?.statusOptions ?? const [], selectedStatus);
        teacherRanking = _toRanking(summary?.teacherRanking);
        resourceRanking = _toRanking(summary?.resourceRanking);
        classGroupRanking = _toRanking(summary?.classGroupRanking);
        subjectRanking = _toRanking(summary?.subjectRanking);
        loadError = null;
      } else {
        loadError = response.message ?? 'Não foi possível carregar os relatórios.';
      }
    } catch (e) {
      _logger.e('loadReport error: $e');
      loadError = 'Não foi possível carregar os relatórios.';
    }

    isLoading = false;
    isLoadingMore = false;
    notifyListeners();
  }

  Future<List<BookingAdminModel>> loadAllForExport() async {
    final exported = <BookingAdminModel>[];
    var page = 1;
    var hasNextPage = true;

    while (hasNextPage) {
      final response = await ApiService.getAllBookingsPage(
        schoolId: _schoolId,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        page: page,
        pageSize: _exportPageSize,
        teacher: selectedTeacher,
        resource: selectedResource,
        classGroup: selectedClassGroup,
        status: selectedStatus,
        sort: 'date_desc',
      );

      if (!response.success) {
        throw Exception(response.message ?? 'Não foi possível exportar.');
      }

      exported.addAll(response.items);
      hasNextPage = response.meta.hasNextPage;
      page += 1;
      if (response.items.isEmpty) hasNextPage = false;
    }

    return exported;
  }

  // private helpers
  Future<void> _persistFilters() async {
    if (!_hasCustomPreferences) {
      await _preferences.removePreference(_filtersPreferenceKey);
      return;
    }
    await _preferences.setObjectPreference(
      _filtersPreferenceKey,
      ReportsFiltersPreference(
        selectedPeriod: selectedPeriod.name,
        customRangeStart: customRange?.start.toIso8601String(),
        customRangeEnd: customRange?.end.toIso8601String(),
        selectedTeacher: selectedTeacher,
        selectedResource: selectedResource,
        selectedClassGroup: selectedClassGroup,
        selectedStatus: selectedStatus,
      ),
      (value) => value.toJson(),
    );
  }

  String _resolveBusiestWeekday(BookingSummaryModel? summary) {
    final value = summary?.busiestWeekdayLabel.trim() ?? '';
    return value.isEmpty ? 'Sem dados' : value;
  }

  List<RankingEntry> _toRanking(List<RankingEntryModel>? entries) {
    if (entries == null || entries.isEmpty) return const [];
    return entries
        .where((e) => e.label.trim().isNotEmpty)
        .map((e) => RankingEntry(label: e.label, value: e.value))
        .toList(growable: false);
  }

  List<String> _mergeOption(List<String> options, String? selected) {
    final merged = [...options];
    if (selected != null && selected.isNotEmpty && !merged.contains(selected)) {
      merged.add(selected);
      merged.sort();
    }
    return merged;
  }
}
