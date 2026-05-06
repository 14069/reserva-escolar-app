import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

import '../models/filter_preferences_model.dart';
import '../models/my_booking_model.dart';
import '../providers/app_preferences_provider.dart';
import '../services/api_service.dart';
import '../utils/app_formatters.dart';

sealed class MyBookingActionOutcome {}

class MyBookingActionSuccess extends MyBookingActionOutcome {
  final String message;
  MyBookingActionSuccess(this.message);
}

class MyBookingActionFailure extends MyBookingActionOutcome {
  final String message;
  MyBookingActionFailure(this.message);
}

class MyBookingsProvider extends ChangeNotifier {
  MyBookingsProvider({
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

  static const String _filtersPreferenceKey = 'my_bookings_filters_v1';
  static const int _pageSize = 20;
  static const List<String> sortValues = [
    'date_desc',
    'date_asc',
    'resource_asc',
    'status',
  ];

  // loading state
  bool isLoading = true;
  bool isLoadingMore = false;
  bool hasMorePages = false;
  int currentPage = 1;
  String? loadError;

  // data
  List<MyBookingModel> bookings = [];
  int totalBookingsCount = 0;
  int totalScheduledCount = 0;
  int totalCompletedCount = 0;
  int totalCancelledCount = 0;

  // filters
  String? selectedStatus;
  String selectedSort = 'date_desc';
  String search = '';

  // highlight
  final Map<int, String> _recentActionByBookingId = {};
  final Map<int, Timer> _highlightTimers = {};

  Map<int, String> get recentActionByBookingId =>
      UnmodifiableMapView(_recentActionByBookingId);

  int get activeFilterCount {
    return [
      if (search.trim().isNotEmpty) search,
      selectedStatus,
    ].length;
  }

  bool get _hasCustomPreferences {
    return search.trim().isNotEmpty ||
        selectedStatus != null ||
        selectedSort != 'date_desc';
  }

  bool canCompleteBooking(MyBookingModel booking) {
    if (booking.status != 'scheduled') return false;
    final bookingDate = DateTime.tryParse(booking.bookingDate);
    if (bookingDate == null) return false;
    final today = DateUtils.dateOnly(DateTime.now());
    return !DateUtils.dateOnly(bookingDate).isAfter(today);
  }

  Future<void> initialize() async {
    final savedFilters = await _preferences.getObjectPreference(
      _filtersPreferenceKey,
      MyBookingsFiltersPreference.fromJson,
    );

    if (savedFilters != null) {
      selectedStatus = savedFilters.selectedStatus;
      selectedSort = sortValues.contains(savedFilters.selectedSort)
          ? savedFilters.selectedSort
          : 'date_desc';
      search = savedFilters.search;
      notifyListeners();
    }

    await loadBookings();
  }

  void updateSearch(String value) {
    search = value;
  }

  void setStatus(String? value) {
    selectedStatus = value;
    notifyListeners();
    loadBookings();
  }

  void setSort(String value) {
    selectedSort = value;
    notifyListeners();
    loadBookings();
  }

  void clearFilters() {
    selectedStatus = null;
    selectedSort = 'date_desc';
    search = '';
    notifyListeners();
    loadBookings();
  }

  Future<void> loadBookings({bool loadMore = false}) async {
    if (!loadMore) unawaited(_persistFilters());

    final nextPage = loadMore ? currentPage + 1 : 1;
    isLoading = !loadMore;
    isLoadingMore = loadMore;
    if (!loadMore) loadError = null;
    notifyListeners();

    try {
      final response = await ApiService.getMyBookingsPage(
        schoolId: _schoolId,
        userId: _userId,
        page: nextPage,
        pageSize: _pageSize,
        search: search,
        status: selectedStatus,
        sort: selectedSort,
      );

      if (response.success) {
        final fetched = response.items;
        final summary = response.summary;
        final meta = response.meta;

        bookings = loadMore ? [...bookings, ...fetched] : fetched;
        currentPage = nextPage;
        hasMorePages = meta.hasNextPage;
        totalBookingsCount = meta.total == 0 ? bookings.length : meta.total;
        totalScheduledCount = summary?.scheduledCount ??
            bookings.where((b) => b.status == 'scheduled').length;
        totalCompletedCount = summary?.completedCount ??
            bookings.where((b) => b.status == 'completed').length;
        totalCancelledCount = summary?.cancelledCount ??
            bookings.where((b) => b.status == 'cancelled').length;
        loadError = null;
      } else {
        loadError = 'Não foi possível carregar os agendamentos.';
      }
    } catch (e) {
      _logger.e('loadBookings error: $e');
      loadError = 'Não foi possível carregar os agendamentos.';
    }

    isLoading = false;
    isLoadingMore = false;
    notifyListeners();
  }

  Future<MyBookingActionOutcome> performCancel(MyBookingModel booking) async {
    final response = await ApiService.cancelBookingResult(
      schoolId: _schoolId,
      bookingId: booking.id,
      userId: _userId,
    );

    if (response.success) {
      _markCancelledLocally(booking);
      unawaited(loadBookings());
      return MyBookingActionSuccess('Agendamento cancelado com sucesso.');
    }
    return MyBookingActionFailure(
      response.message ?? 'Não foi possível cancelar o agendamento.',
    );
  }

  Future<MyBookingActionOutcome> performComplete(
    MyBookingModel booking, {
    required String? feedback,
  }) async {
    final response = await ApiService.completeBookingResult(
      schoolId: _schoolId,
      bookingId: booking.id,
      userId: _userId,
      completionFeedback: feedback ?? '',
    );

    if (response.success) {
      _markCompletedLocally(booking, feedback);
      unawaited(loadBookings());
      final hasFeedback = (feedback?.trim() ?? '').isNotEmpty;
      return MyBookingActionSuccess(
        hasFeedback
            ? 'Agendamento finalizado e feedback salvo.'
            : 'Agendamento finalizado com sucesso.',
      );
    }
    return MyBookingActionFailure(
      response.message ?? 'Não foi possível finalizar o agendamento.',
    );
  }

  void _markCancelledLocally(MyBookingModel booking) {
    final updatedBooking = booking.copyWith(
      status: 'cancelled',
      cancelledAt: AppFormatters.formatApiTimestamp(DateTime.now()),
    );

    final nextBookings = [...bookings];
    final index = nextBookings.indexWhere((item) => item.id == booking.id);
    if (index == -1) return;

    if (selectedStatus == 'scheduled') {
      nextBookings.removeAt(index);
    } else {
      nextBookings[index] = updatedBooking;
    }

    bookings = nextBookings;
    totalScheduledCount = (totalScheduledCount - 1).clamp(0, totalScheduledCount);
    totalCancelledCount += 1;
    totalBookingsCount = nextBookings.length;
    _triggerHighlight(booking.id, 'cancelled');
    notifyListeners();
  }

  void _markCompletedLocally(MyBookingModel booking, String? feedback) {
    final trimmedFeedback = feedback?.trim();
    final updatedBooking = booking.copyWith(
      status: 'completed',
      completedAt: AppFormatters.formatApiTimestamp(DateTime.now()),
      completedByName: _userName,
      completionFeedback: trimmedFeedback == null || trimmedFeedback.isEmpty
          ? null
          : trimmedFeedback,
    );

    final nextBookings = [...bookings];
    final index = nextBookings.indexWhere((item) => item.id == booking.id);
    if (index == -1) return;

    if (selectedStatus == 'scheduled') {
      nextBookings.removeAt(index);
    } else {
      nextBookings[index] = updatedBooking;
    }

    bookings = nextBookings;
    totalScheduledCount = (totalScheduledCount - 1).clamp(0, totalScheduledCount);
    totalCompletedCount += 1;
    totalBookingsCount = nextBookings.length;
    _triggerHighlight(booking.id, 'completed');
    notifyListeners();
  }

  void _triggerHighlight(int bookingId, String action) {
    _highlightTimers.remove(bookingId)?.cancel();
    _recentActionByBookingId[bookingId] = action;
    _highlightTimers[bookingId] = Timer(const Duration(seconds: 2), () {
      _recentActionByBookingId.remove(bookingId);
      _highlightTimers.remove(bookingId);
      notifyListeners();
    });
  }

  Future<void> _persistFilters() async {
    if (!_hasCustomPreferences) {
      await _preferences.removePreference(_filtersPreferenceKey);
      return;
    }
    await _preferences.setObjectPreference(
      _filtersPreferenceKey,
      MyBookingsFiltersPreference(
        search: search.trim(),
        selectedStatus: selectedStatus,
        selectedSort: selectedSort,
      ),
      (value) => value.toJson(),
    );
  }

  @override
  void dispose() {
    for (final timer in _highlightTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }
}
