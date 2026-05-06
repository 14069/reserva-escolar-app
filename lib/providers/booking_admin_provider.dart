import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

import '../models/booking_admin_model.dart';
import '../models/filter_preferences_model.dart';
import '../providers/app_preferences_provider.dart';
import '../services/api_service.dart';
import '../utils/app_formatters.dart';

sealed class BookingActionOutcome {}

class BookingActionSuccess extends BookingActionOutcome {
  final String message;
  BookingActionSuccess(this.message);
}

class BookingActionFailure extends BookingActionOutcome {
  final String message;
  BookingActionFailure(this.message);
}

class BookingAdminProvider extends ChangeNotifier {
  BookingAdminProvider({
    required int schoolId,
    required int userId,
    required String userName,
    required AppPreferencesProvider preferences,
  })  : _schoolId = schoolId,
        _userId = userId,
        _userName = userName,
        _preferences = preferences;

  final int _schoolId;
  final int _userId;
  final String _userName;
  final AppPreferencesProvider _preferences;
  final _logger = Logger();

  static const String _filtersPreferenceKey = 'booking_admin_filters_v1';
  static const int _pageSize = 20;
  static const List<String> sortValues = [
    'date_desc',
    'date_asc',
    'teacher_asc',
    'resource_asc',
  ];

  // list state
  bool isLoading = true;
  bool isLoadingMore = false;
  bool hasMorePages = false;
  int currentPage = 1;
  int totalBookingsCount = 0;
  int totalScheduledCount = 0;
  int totalCompletedCount = 0;
  int totalCompletedTodayCount = 0;
  int totalCancelledCount = 0;
  List<BookingAdminModel> bookings = [];
  String? loadError;

  // filter options
  List<String> availableTeacherOptions = [];
  List<String> availableResourceOptions = [];
  List<String> availableClassGroupOptions = [];
  List<String> availableStatusOptions = const [
    'scheduled',
    'completed',
    'cancelled',
  ];

  // active filters
  DateTime? selectedDate;
  String? selectedTeacher;
  String? selectedResource;
  String? selectedClassGroup;
  String? selectedStatus;
  String selectedSort = 'date_desc';
  String search = '';

  // highlight state
  final Map<int, String> _recentActionByBookingId = {};
  Map<int, String> get recentActionByBookingId =>
      UnmodifiableMapView(_recentActionByBookingId);
  final Map<int, Timer> _highlightTimers = {};

  // computed
  int get activeFilterCount {
    int count = 0;
    if (selectedDate != null) count++;
    if (search.trim().isNotEmpty) count++;
    if (selectedTeacher != null) count++;
    if (selectedResource != null) count++;
    if (selectedClassGroup != null) count++;
    if (selectedStatus != null) count++;
    return count;
  }

  bool get _hasCustomPreferences {
    return selectedDate != null ||
        search.trim().isNotEmpty ||
        selectedTeacher != null ||
        selectedResource != null ||
        selectedClassGroup != null ||
        selectedStatus != null ||
        selectedSort != 'date_desc';
  }

  bool canCompleteBooking(BookingAdminModel booking) {
    if (booking.status != 'scheduled') return false;
    final bookingDate = DateTime.tryParse(booking.bookingDate);
    if (bookingDate == null) return false;
    return !DateUtils.dateOnly(bookingDate).isAfter(DateUtils.dateOnly(DateTime.now()));
  }

  // init
  Future<void> initialize() async {
    final savedFilters = await _preferences.getObjectPreference(
      _filtersPreferenceKey,
      BookingAdminFiltersPreference.fromJson,
    );

    if (savedFilters != null) {
      final restoredDate = DateTime.tryParse(savedFilters.selectedDate ?? '');
      selectedDate = restoredDate == null
          ? null
          : DateUtils.dateOnly(restoredDate);
      selectedTeacher = savedFilters.selectedTeacher;
      selectedResource = savedFilters.selectedResource;
      selectedClassGroup = savedFilters.selectedClassGroup;
      selectedStatus = savedFilters.selectedStatus;
      selectedSort = sortValues.contains(savedFilters.selectedSort)
          ? savedFilters.selectedSort
          : 'date_desc';
      search = savedFilters.search;
      notifyListeners();
    }

    unawaited(_loadFilterOptions());
    await loadBookings();
  }

  // filter setters
  void updateSearch(String value) {
    search = value;
    // caller handles debounce and triggers loadBookings
  }

  void setDate(DateTime date) {
    selectedDate = date;
    notifyListeners();
    loadBookings();
  }

  void clearDate() {
    selectedDate = null;
    notifyListeners();
    loadBookings();
  }

  void setSort(String value) {
    selectedSort = value;
    notifyListeners();
    loadBookings();
  }

  void setTeacher(String? value) {
    selectedTeacher = value;
    notifyListeners();
    loadBookings();
  }

  void setResource(String? value) {
    selectedResource = value;
    notifyListeners();
    loadBookings();
  }

  void setClassGroup(String? value) {
    selectedClassGroup = value;
    notifyListeners();
    loadBookings();
  }

  void setStatus(String? value) {
    selectedStatus = value;
    notifyListeners();
    loadBookings();
  }

  void clearAllFilters() {
    selectedDate = null;
    search = '';
    selectedTeacher = null;
    selectedResource = null;
    selectedClassGroup = null;
    selectedStatus = null;
    notifyListeners();
    loadBookings();
  }

  // data loading
  Future<void> loadBookings({
    bool loadMore = false,
    int retryAttempt = 0,
  }) async {
    if (!loadMore) unawaited(_persistFilters());

    isLoading = loadMore ? isLoading : true;
    isLoadingMore = loadMore;
    if (!loadMore && retryAttempt == 0) loadError = null;
    notifyListeners();

    try {
      final nextPage = loadMore ? currentPage + 1 : 1;
      final response = await ApiService.getAllBookingsPage(
        schoolId: _schoolId,
        bookingDate: selectedDate != null ? _formatDate(selectedDate!) : null,
        page: nextPage,
        pageSize: _pageSize,
        search: search,
        status: selectedStatus,
        teacher: selectedTeacher,
        resource: selectedResource,
        classGroup: selectedClassGroup,
        sort: selectedSort,
        includeFullSummary: false,
      );

      if (response.success) {
        final fetchedBookings = response.items;
        final summary = response.summary;
        final meta = response.meta;

        final mergedTeacherOptions = _mergeOptions(
          _sortedOptions(summary?.teacherOptions ?? const []),
          availableTeacherOptions,
        );
        final mergedResourceOptions = _mergeOptions(
          _sortedOptions(summary?.resourceOptions ?? const []),
          availableResourceOptions,
        );
        final mergedClassGroupOptions = _mergeOptions(
          _sortedOptions(summary?.classGroupOptions ?? const []),
          availableClassGroupOptions,
        );
        final mergedStatusOptions = _mergeOptions(
          _sortedOptions(summary?.statusOptions ?? const []),
          availableStatusOptions,
        );

        final normalizedTeacher = _normalize(selectedTeacher, mergedTeacherOptions);
        final normalizedResource = _normalize(selectedResource, mergedResourceOptions);
        final normalizedClassGroup = _normalize(selectedClassGroup, mergedClassGroupOptions);
        final normalizedStatus = _normalize(selectedStatus, mergedStatusOptions);

        final shouldReload = !loadMore &&
            (normalizedTeacher != selectedTeacher ||
                normalizedResource != selectedResource ||
                normalizedClassGroup != selectedClassGroup ||
                normalizedStatus != selectedStatus);

        bookings = loadMore ? [...bookings, ...fetchedBookings] : fetchedBookings;
        currentPage = nextPage;
        totalBookingsCount = meta.total == 0 ? bookings.length : meta.total;
        totalScheduledCount = summary?.scheduledCount ??
            bookings.where((b) => b.status == 'scheduled').length;
        totalCompletedCount = summary?.completedCount ??
            bookings.where((b) => b.status == 'completed').length;
        totalCompletedTodayCount = summary?.completedTodayCount ??
            bookings
                .where((b) =>
                    b.status == 'completed' &&
                    (b.completedAt ?? '').startsWith(_formatDate(DateTime.now())))
                .length;
        totalCancelledCount = summary?.cancelledCount ??
            bookings.where((b) => b.status == 'cancelled').length;
        hasMorePages = meta.hasNextPage;
        availableTeacherOptions = mergedTeacherOptions;
        availableResourceOptions = mergedResourceOptions;
        availableClassGroupOptions = mergedClassGroupOptions;
        availableStatusOptions = mergedStatusOptions;
        selectedTeacher = normalizedTeacher;
        selectedResource = normalizedResource;
        selectedClassGroup = normalizedClassGroup;
        selectedStatus = normalizedStatus;
        loadError = null;

        if (shouldReload) {
          currentPage = 1;
          hasMorePages = false;
          unawaited(loadBookings());
        }

        if (!loadMore &&
            (availableTeacherOptions.isEmpty ||
                availableResourceOptions.isEmpty ||
                availableClassGroupOptions.isEmpty)) {
          unawaited(_loadFilterOptions());
        }
      } else {
        loadError = response.message ?? 'Não foi possível carregar os agendamentos.';

        if (!loadMore && retryAttempt < 1) {
          unawaited(Future<void>.delayed(
            const Duration(milliseconds: 900),
            () => loadBookings(loadMore: false, retryAttempt: retryAttempt + 1),
          ));
        }
      }
    } catch (e) {
      _logger.e('loadBookings error: $e');
      loadError = 'Não foi possível carregar os agendamentos.';

      if (!loadMore && retryAttempt < 1) {
        unawaited(Future<void>.delayed(
          const Duration(milliseconds: 900),
          () => loadBookings(loadMore: false, retryAttempt: retryAttempt + 1),
        ));
      }
    }

    isLoading = false;
    isLoadingMore = false;
    notifyListeners();
  }

  // actions
  Future<BookingActionOutcome> performCancel(BookingAdminModel booking) async {
    final response = await ApiService.cancelBookingResult(
      schoolId: _schoolId,
      bookingId: booking.id,
      userId: _userId,
    );

    if (response.success) {
      _markAsCancelled(booking);
      unawaited(loadBookings());
      return BookingActionSuccess('Agendamento cancelado com sucesso.');
    }

    return BookingActionFailure(
      response.message ?? 'Não foi possível cancelar o agendamento.',
    );
  }

  Future<BookingActionOutcome> performComplete(
    BookingAdminModel booking, {
    required String? feedback,
  }) async {
    final response = await ApiService.completeBookingResult(
      schoolId: _schoolId,
      bookingId: booking.id,
      userId: _userId,
      completionFeedback: feedback,
    );

    if (response.success) {
      _markAsCompleted(booking, feedback);
      unawaited(loadBookings());
      final hasFeedback = feedback?.trim().isNotEmpty ?? false;
      return BookingActionSuccess(
        hasFeedback
            ? 'Agendamento finalizado e feedback salvo.'
            : 'Agendamento finalizado com sucesso.',
      );
    }

    return BookingActionFailure(
      response.message ?? 'Não foi possível finalizar o agendamento.',
    );
  }

  // private helpers
  Future<void> _loadFilterOptions() async {
    try {
      final teacherFuture = ApiService.getTeachersPage(
        schoolId: _schoolId,
        pageSize: 100,
        sort: 'name_asc',
      );
      final resourceFuture = ApiService.getResourcesAdminPage(
        schoolId: _schoolId,
        pageSize: 100,
        sort: 'name_asc',
      );
      final classGroupFuture = ApiService.getClassGroupsAdminPage(
        schoolId: _schoolId,
        pageSize: 100,
        sort: 'name_asc',
      );

      final teacherResp = await teacherFuture;
      final resourceResp = await resourceFuture;
      final classGroupResp = await classGroupFuture;

      availableTeacherOptions = _mergeOptions(
        availableTeacherOptions,
        _sortedOptions(teacherResp.items.map((i) => i.name)),
      );
      availableResourceOptions = _mergeOptions(
        availableResourceOptions,
        _sortedOptions(resourceResp.items.map((i) => i.name)),
      );
      availableClassGroupOptions = _mergeOptions(
        availableClassGroupOptions,
        _sortedOptions(classGroupResp.items.map((i) => i.name)),
      );
      availableStatusOptions = _mergeOptions(
        availableStatusOptions,
        const ['scheduled', 'completed', 'cancelled'],
      );
      notifyListeners();
    } catch (_) {
      // keep current options on failure
    }
  }

  Future<void> _persistFilters() async {
    if (!_hasCustomPreferences) {
      await _preferences.removePreference(_filtersPreferenceKey);
      return;
    }
    await _preferences.setObjectPreference(
      _filtersPreferenceKey,
      BookingAdminFiltersPreference(
        selectedDate: selectedDate == null ? null : _formatDate(selectedDate!),
        search: search.trim(),
        selectedTeacher: selectedTeacher,
        selectedResource: selectedResource,
        selectedClassGroup: selectedClassGroup,
        selectedStatus: selectedStatus,
        selectedSort: selectedSort,
      ),
      (value) => value.toJson(),
    );
  }

  void _markAsCancelled(BookingAdminModel booking) {
    final updated = booking.copyWith(
      status: 'cancelled',
      cancelledAt: _currentTimestamp(),
    );
    final next = [...bookings];
    final index = next.indexWhere((b) => b.id == booking.id);
    if (index == -1) return;

    if (selectedStatus == 'scheduled') {
      next.removeAt(index);
    } else {
      next[index] = updated;
    }

    bookings = next;
    totalScheduledCount = (totalScheduledCount - 1).clamp(0, totalScheduledCount);
    totalCancelledCount += 1;
    totalBookingsCount = next.length;
    notifyListeners();
    _triggerHighlight(booking.id, 'cancelled');
  }

  void _markAsCompleted(BookingAdminModel booking, String? feedback) {
    final trimmed = feedback?.trim();
    final updated = booking.copyWith(
      status: 'completed',
      completedAt: _currentTimestamp(),
      completedByName: _userName,
      completionFeedback: (trimmed == null || trimmed.isEmpty) ? null : trimmed,
    );
    final next = [...bookings];
    final index = next.indexWhere((b) => b.id == booking.id);
    if (index == -1) return;

    if (selectedStatus == 'scheduled') {
      next.removeAt(index);
    } else {
      next[index] = updated;
    }

    bookings = next;
    totalScheduledCount = (totalScheduledCount - 1).clamp(0, totalScheduledCount);
    totalCompletedCount += 1;
    if (booking.bookingDate == _formatDate(DateTime.now())) {
      totalCompletedTodayCount += 1;
    }
    totalBookingsCount = next.length;
    notifyListeners();
    _triggerHighlight(booking.id, 'completed');
  }

  void _triggerHighlight(int bookingId, String action) {
    _highlightTimers.remove(bookingId)?.cancel();
    _recentActionByBookingId[bookingId] = action;
    notifyListeners();

    _highlightTimers[bookingId] = Timer(const Duration(seconds: 2), () {
      _recentActionByBookingId.remove(bookingId);
      _highlightTimers.remove(bookingId);
      notifyListeners();
    });
  }

  String _formatDate(DateTime date) => AppFormatters.formatApiDate(date);

  String _currentTimestamp() {
    final now = DateTime.now();
    String p(int v) => v.toString().padLeft(2, '0');
    return '${now.year}-${p(now.month)}-${p(now.day)} ${p(now.hour)}:${p(now.minute)}:${p(now.second)}';
  }

  List<String> _sortedOptions(Iterable<String> values) {
    return values
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.compareTo(b));
  }

  List<String> _mergeOptions(Iterable<String> a, Iterable<String> b) {
    return _sortedOptions([...a, ...b]);
  }

  String? _normalize(String? value, List<String> options) {
    if (value == null) return null;
    return options.contains(value) ? value : null;
  }

  @override
  void dispose() {
    for (final timer in _highlightTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }
}
