import 'dart:async';

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';

import '../models/booking_admin_model.dart';
import '../providers/app_preferences_provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/csv_export_service.dart';
import '../services/pdf_export_service.dart';
import '../utils/app_formatters.dart';
import '../widgets/admin_ui.dart';

class BookingAdminScreen extends StatefulWidget {
  const BookingAdminScreen({super.key});

  @override
  State<BookingAdminScreen> createState() => _BookingAdminScreenState();
}

class _BookingAdminScreenState extends State<BookingAdminScreen> {
  static const String _filtersPreferenceKey = 'booking_admin_filters_v1';
  static const int _pageSize = 20;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

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
  final Map<int, String> _recentActionByBookingId = {};
  final Map<int, Timer> _highlightTimers = {};
  List<String> availableTeacherOptions = [];
  List<String> availableResourceOptions = [];
  List<String> availableClassGroupOptions = [];
  List<String> availableStatusOptions = const [
    'scheduled',
    'completed',
    'cancelled',
  ];
  DateTime? selectedDate;
  String? selectedTeacher;
  String? selectedResource;
  String? selectedClassGroup;
  String? selectedStatus;
  String selectedSort = 'date_desc';
  Timer? _searchDebounce;
  bool _isRestoringFilters = false;

  List<BookingAdminModel> get filteredBookings => bookings;

  int get scheduledCount => totalScheduledCount;

  int get cancelledCount => totalCancelledCount;

  int get completedCount => totalCompletedCount;

  int get completedTodayCount => totalCompletedTodayCount;

  int get activeFilterCount {
    final filters = [
      if (selectedDate != null) selectedDate,
      if (_searchController.text.trim().isNotEmpty) _searchController.text,
      selectedTeacher,
      selectedResource,
      selectedClassGroup,
      selectedStatus,
    ];
    return filters.length;
  }

  List<String> get teacherOptions => availableTeacherOptions;

  List<String> get resourceOptions => availableResourceOptions;

  List<String> get classGroupOptions => availableClassGroupOptions;

  List<String> get statusOptions => availableStatusOptions;

  List<AdminActiveFilterItem> get activeFilterItems {
    final items = <AdminActiveFilterItem>[];

    if (selectedDate != null) {
      items.add(
        AdminActiveFilterItem(
          label: 'Data: ${formatDisplayDate(formatDate(selectedDate!))}',
          onRemove: () {
            setState(() {
              selectedDate = null;
            });
            loadBookings();
          },
        ),
      );
    }

    if (_searchController.text.trim().isNotEmpty) {
      items.add(
        AdminActiveFilterItem(
          label: 'Busca: ${_searchController.text.trim()}',
          onRemove: () {
            setState(() {
              _searchController.clear();
            });
            loadBookings();
          },
        ),
      );
    }

    if (selectedTeacher != null) {
      items.add(
        AdminActiveFilterItem(
          label: 'Professor: $selectedTeacher',
          onRemove: () {
            setState(() {
              selectedTeacher = null;
            });
            loadBookings();
          },
        ),
      );
    }

    if (selectedResource != null) {
      items.add(
        AdminActiveFilterItem(
          label: 'Recurso: $selectedResource',
          onRemove: () {
            setState(() {
              selectedResource = null;
            });
            loadBookings();
          },
        ),
      );
    }

    if (selectedClassGroup != null) {
      items.add(
        AdminActiveFilterItem(
          label: 'Turma: $selectedClassGroup',
          onRemove: () {
            setState(() {
              selectedClassGroup = null;
            });
            loadBookings();
          },
        ),
      );
    }

    if (selectedStatus != null) {
      items.add(
        AdminActiveFilterItem(
          label: 'Status: ${statusLabel(selectedStatus!)}',
          onRemove: () {
            setState(() {
              selectedStatus = null;
            });
            loadBookings();
          },
        ),
      );
    }

    return items;
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    for (final timer in _highlightTimers.values) {
      timer.cancel();
    }
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
    _restoreFiltersAndLoad();
  }

  void _handleSearchChanged() {
    if (_isRestoringFilters) return;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      loadBookings();
    });
  }

  Future<void> _restoreFiltersAndLoad() async {
    final preferences = context.read<AppPreferencesProvider>();
    final savedFilters = await preferences.getJsonPreference(
      _filtersPreferenceKey,
    );

    if (!mounted) return;

    _isRestoringFilters = true;
    if (savedFilters != null) {
      final restoredSearch = savedFilters['search']?.toString() ?? '';
      final restoredDate = DateTime.tryParse(
        savedFilters['selected_date']?.toString() ?? '',
      );

      setState(() {
        selectedDate = restoredDate == null
            ? null
            : DateUtils.dateOnly(restoredDate);
        selectedTeacher = _normalizeSavedValue(
          savedFilters['selected_teacher'],
        );
        selectedResource = _normalizeSavedValue(
          savedFilters['selected_resource'],
        );
        selectedClassGroup = _normalizeSavedValue(
          savedFilters['selected_class_group'],
        );
        selectedStatus = _normalizeSavedValue(savedFilters['selected_status']);
        selectedSort =
            _bookingSortValues.contains(savedFilters['selected_sort'])
            ? savedFilters['selected_sort'].toString()
            : 'date_desc';
      });
      _searchController.text = restoredSearch;
    }
    _isRestoringFilters = false;

    unawaited(_loadFilterOptions());
    loadBookings();
  }

  static const List<String> _bookingSortValues = [
    'date_desc',
    'date_asc',
    'teacher_asc',
    'resource_asc',
  ];

  String? _normalizeSavedValue(dynamic value) {
    final normalized = value?.toString().trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  bool get _hasCustomPreferences {
    return selectedDate != null ||
        _searchController.text.trim().isNotEmpty ||
        selectedTeacher != null ||
        selectedResource != null ||
        selectedClassGroup != null ||
        selectedStatus != null ||
        selectedSort != 'date_desc';
  }

  Future<void> _persistFilters() async {
    final preferences = context.read<AppPreferencesProvider>();
    if (!_hasCustomPreferences) {
      await preferences.removePreference(_filtersPreferenceKey);
      return;
    }

    await preferences.setJsonPreference(_filtersPreferenceKey, {
      'selected_date': selectedDate == null ? null : formatDate(selectedDate!),
      'search': _searchController.text.trim(),
      'selected_teacher': selectedTeacher,
      'selected_resource': selectedResource,
      'selected_class_group': selectedClassGroup,
      'selected_status': selectedStatus,
      'selected_sort': selectedSort,
    });
  }

  String formatDate(DateTime date) {
    return AppFormatters.formatApiDate(date);
  }

  String formatLessons(List<BookingLessonModel> lessons) {
    if (lessons.isEmpty) return 'Sem aulas';
    return lessons.map((lesson) => lesson.label).join(', ');
  }

  String formatDisplayDate(String value) {
    return AppFormatters.formatDateString(value);
  }

  List<String> _sortedOptions(Iterable<String> values) {
    final items =
        values
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort((a, b) => a.compareTo(b));
    return items;
  }

  List<String> _mergeOptions(
    Iterable<String> primary,
    Iterable<String> fallback,
  ) {
    return _sortedOptions([...primary, ...fallback]);
  }

  Future<void> _loadFilterOptions() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    try {
      final responses = await Future.wait([
        ApiService.getTeachers(
          schoolId: user.schoolId,
          pageSize: 100,
          sort: 'name_asc',
        ),
        ApiService.getResourcesAdmin(
          schoolId: user.schoolId,
          pageSize: 100,
          sort: 'name_asc',
        ),
        ApiService.getClassGroupsAdmin(
          schoolId: user.schoolId,
          pageSize: 100,
          sort: 'name_asc',
        ),
      ]);

      if (!mounted) return;

      final teacherData = (responses[0]['data'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>();
      final resourceData = (responses[1]['data'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>();
      final classGroupData =
          (responses[2]['data'] as List<dynamic>? ?? const [])
              .cast<Map<String, dynamic>>();

      final teacherNames = _sortedOptions(
        teacherData.map((item) => item['name']?.toString() ?? ''),
      );
      final resourceNames = _sortedOptions(
        resourceData.map((item) => item['name']?.toString() ?? ''),
      );
      final classGroupNames = _sortedOptions(
        classGroupData.map((item) => item['name']?.toString() ?? ''),
      );

      setState(() {
        availableTeacherOptions = _mergeOptions(
          availableTeacherOptions,
          teacherNames,
        );
        availableResourceOptions = _mergeOptions(
          availableResourceOptions,
          resourceNames,
        );
        availableClassGroupOptions = _mergeOptions(
          availableClassGroupOptions,
          classGroupNames,
        );
        availableStatusOptions = _mergeOptions(availableStatusOptions, const [
          'scheduled',
          'completed',
          'cancelled',
        ]);
      });
    } catch (_) {
      // Keep the current options when background loading fails.
    }
  }

  String statusLabel(String value) {
    switch (value) {
      case 'scheduled':
        return 'Agendado';
      case 'completed':
        return 'Finalizado';
      case 'cancelled':
        return 'Cancelado';
      default:
        return value;
    }
  }

  String sortLabel(String value) {
    switch (value) {
      case 'date_asc':
        return 'Data mais antiga';
      case 'teacher_asc':
        return 'Professor (A-Z)';
      case 'resource_asc':
        return 'Recurso (A-Z)';
      case 'date_desc':
      default:
        return 'Data mais recente';
    }
  }

  void clearAdvancedFilters() {
    setState(() {
      selectedDate = null;
      _searchController.clear();
      selectedTeacher = null;
      selectedResource = null;
      selectedClassGroup = null;
      selectedStatus = null;
    });
    loadBookings();
  }

  List<List<Object?>> _bookingExportRows() {
    return filteredBookings
        .map(
          (booking) => [
            formatDisplayDate(booking.bookingDate),
            statusLabel(booking.status),
            booking.userName,
            booking.resourceName,
            booking.classGroupName,
            booking.subjectName,
            booking.purpose,
            formatLessons(booking.lessons),
            booking.lessons.length,
            booking.completedAt ?? '',
            booking.completedByName ?? '',
            booking.cancelledAt ?? '',
          ],
        )
        .toList();
  }

  Future<void> _exportBookingsCsv() async {
    final result = await CsvExportService.exportRows(
      filePrefix: 'agendamentos_admin',
      title: 'Agendamentos administrativos',
      subject: 'Agendamentos administrativos',
      shareText: 'Exportação CSV dos agendamentos administrativos.',
      headers: const [
        'Data',
        'Status',
        'Professor',
        'Recurso',
        'Turma',
        'Disciplina',
        'Finalidade',
        'Aulas',
        'Quantidade de aulas',
        'Finalizado em',
        'Finalizado por',
        'Cancelado em',
      ],
      rows: _bookingExportRows(),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));
  }

  Future<void> _exportBookingsPdf() async {
    final result = await PdfExportService.exportTable(
      filePrefix: 'agendamentos_admin',
      title: 'Agendamentos administrativos',
      subject: 'Agendamentos administrativos',
      shareText: 'Exportação PDF dos agendamentos administrativos.',
      headers: const [
        'Data',
        'Status',
        'Professor',
        'Recurso',
        'Turma',
        'Disciplina',
        'Finalidade',
        'Aulas',
        'Quantidade de aulas',
        'Finalizado em',
        'Finalizado por',
        'Cancelado em',
      ],
      rows: _bookingExportRows(),
      landscape: true,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));
  }

  Future<void> pickDate() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );

    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
      loadBookings();
    }
  }

  Future<void> loadBookings({
    bool loadMore = false,
    int retryAttempt = 0,
  }) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    final logger = Logger();
    if (user == null) return;

    if (!loadMore) {
      unawaited(_persistFilters());
    }

    setState(() {
      if (loadMore) {
        isLoadingMore = true;
      } else {
        isLoading = true;
        if (retryAttempt == 0) {
          loadError = null;
        }
      }
    });

    try {
      final nextPage = loadMore ? currentPage + 1 : 1;
      final response = await ApiService.getAllBookings(
        schoolId: user.schoolId,
        bookingDate: selectedDate != null ? formatDate(selectedDate!) : null,
        page: nextPage,
        pageSize: _pageSize,
        search: _searchController.text,
        status: selectedStatus,
        teacher: selectedTeacher,
        resource: selectedResource,
        classGroup: selectedClassGroup,
        sort: selectedSort,
        includeFullSummary: false,
      );

      if (response['success'] == true) {
        final List data = response['data'];
        final fetchedBookings = data
            .map((e) => BookingAdminModel.fromJson(e))
            .toList();
        final meta = response['meta'] as Map<String, dynamic>? ?? const {};
        final summary = meta['summary'] as Map<String, dynamic>? ?? const {};
        final nextTeacherOptions = _sortedOptions(
          (summary['teacher_options'] as List<dynamic>? ?? const [])
              .cast<String>(),
        );
        final nextResourceOptions = _sortedOptions(
          (summary['resource_options'] as List<dynamic>? ?? const [])
              .cast<String>(),
        );
        final nextClassGroupOptions = _sortedOptions(
          (summary['class_group_options'] as List<dynamic>? ?? const [])
              .cast<String>(),
        );
        final nextStatusOptions = _sortedOptions(
          (summary['status_options'] as List<dynamic>? ?? const [])
              .cast<String>(),
        );
        final mergedTeacherOptions = _mergeOptions(
          nextTeacherOptions,
          availableTeacherOptions,
        );
        final mergedResourceOptions = _mergeOptions(
          nextResourceOptions,
          availableResourceOptions,
        );
        final mergedClassGroupOptions = _mergeOptions(
          nextClassGroupOptions,
          availableClassGroupOptions,
        );
        final mergedStatusOptions = _mergeOptions(
          nextStatusOptions,
          availableStatusOptions,
        );

        final normalizedSelectedTeacher =
            selectedTeacher != null &&
                !mergedTeacherOptions.contains(selectedTeacher)
            ? null
            : selectedTeacher;
        final normalizedSelectedResource =
            selectedResource != null &&
                !mergedResourceOptions.contains(selectedResource)
            ? null
            : selectedResource;
        final normalizedSelectedClassGroup =
            selectedClassGroup != null &&
                !mergedClassGroupOptions.contains(selectedClassGroup)
            ? null
            : selectedClassGroup;
        final normalizedSelectedStatus =
            selectedStatus != null &&
                !mergedStatusOptions.contains(selectedStatus)
            ? null
            : selectedStatus;
        final shouldReloadWithoutInvalidFilters =
            !loadMore &&
            (normalizedSelectedTeacher != selectedTeacher ||
                normalizedSelectedResource != selectedResource ||
                normalizedSelectedClassGroup != selectedClassGroup ||
                normalizedSelectedStatus != selectedStatus);

        bookings = loadMore
            ? [...bookings, ...fetchedBookings]
            : fetchedBookings;
        currentPage = nextPage;
        totalBookingsCount =
            (meta['total'] as num?)?.toInt() ?? bookings.length;
        totalScheduledCount =
            (summary['scheduled_count'] as num?)?.toInt() ??
            bookings.where((booking) => booking.status == 'scheduled').length;
        totalCompletedCount =
            (summary['completed_count'] as num?)?.toInt() ??
            bookings.where((booking) => booking.status == 'completed').length;
        totalCompletedTodayCount =
            (summary['completed_today_count'] as num?)?.toInt() ??
            bookings
                .where(
                  (booking) =>
                      booking.status == 'completed' &&
                      (booking.completedAt ?? '').startsWith(
                        formatDate(DateTime.now()),
                      ),
                )
                .length;
        totalCancelledCount =
            (summary['cancelled_count'] as num?)?.toInt() ??
            bookings.where((booking) => booking.status == 'cancelled').length;
        hasMorePages = meta['has_next_page'] == true;
        availableTeacherOptions = mergedTeacherOptions;
        availableResourceOptions = mergedResourceOptions;
        availableClassGroupOptions = mergedClassGroupOptions;
        availableStatusOptions = mergedStatusOptions;
        selectedTeacher = normalizedSelectedTeacher;
        selectedResource = normalizedSelectedResource;
        selectedClassGroup = normalizedSelectedClassGroup;
        selectedStatus = normalizedSelectedStatus;

        if (shouldReloadWithoutInvalidFilters) {
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

        loadError = null;
      } else {
        loadError =
            response['message']?.toString() ??
            'Não foi possível carregar os agendamentos.';

        if (!loadMore && retryAttempt < 1) {
          unawaited(
            Future<void>.delayed(
              const Duration(milliseconds: 900),
              () =>
                  loadBookings(loadMore: false, retryAttempt: retryAttempt + 1),
            ),
          );
        }
      }
    } catch (e) {
      logger.i('ERRO AO CARREGAR AGENDAMENTOS ADMIN: $e');
      loadError = 'Não foi possível carregar os agendamentos.';

      if (!loadMore && retryAttempt < 1) {
        unawaited(
          Future<void>.delayed(
            const Duration(milliseconds: 900),
            () => loadBookings(loadMore: false, retryAttempt: retryAttempt + 1),
          ),
        );
      }
    }

    if (!mounted) return;

    setState(() {
      isLoading = false;
      isLoadingMore = false;
    });
  }

  Future<void> cancelBooking(BookingAdminModel booking) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AdminConfirmDialog(
          title: 'Cancelar agendamento',
          message:
              'Deseja cancelar o agendamento de ${booking.resourceName} para ${booking.userName}? Essa ação libera o horário para novas reservas.',
          icon: Icons.cancel_outlined,
          confirmLabel: 'Cancelar reserva',
          cancelLabel: 'Voltar',
        );
      },
    );

    if (confirm != true) return;

    final response = await ApiService.cancelBooking(
      schoolId: user.schoolId,
      bookingId: booking.id,
      userId: user.id,
    );

    if (!mounted) return;

    if (response['success'] == true) {
      _showActionSnackBar(
        'Agendamento cancelado com sucesso.',
        icon: Icons.cancel_outlined,
      );
      _markBookingAsCancelledLocally(booking);
      unawaited(loadBookings());
    } else {
      _showActionSnackBar(
        response['message'] ?? 'Não foi possível cancelar o agendamento.',
        icon: Icons.error_outline,
        isError: true,
      );
    }
  }

  bool _canCompleteBooking(BookingAdminModel booking) {
    if (booking.status != 'scheduled') return false;
    final bookingDate = DateTime.tryParse(booking.bookingDate);
    if (bookingDate == null) return false;
    final today = DateUtils.dateOnly(DateTime.now());
    return !DateUtils.dateOnly(bookingDate).isAfter(today);
  }

  String _currentTimestampLabel() {
    final now = DateTime.now();

    String twoDigits(int value) => value.toString().padLeft(2, '0');

    return '${now.year}-${twoDigits(now.month)}-${twoDigits(now.day)} '
        '${twoDigits(now.hour)}:${twoDigits(now.minute)}:${twoDigits(now.second)}';
  }

  void _markBookingAsCompletedLocally(
    BookingAdminModel booking,
    AuthProvider authProvider,
    String? completionFeedback,
  ) {
    final user = authProvider.user;
    if (user == null) return;

    final trimmedFeedback = completionFeedback?.trim();
    final updatedBooking = booking.copyWith(
      status: 'completed',
      completedAt: _currentTimestampLabel(),
      completedByName: user.name,
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

    setState(() {
      bookings = nextBookings;
      totalScheduledCount = (totalScheduledCount - 1).clamp(
        0,
        totalScheduledCount,
      );
      totalCompletedCount += 1;
      if (booking.bookingDate == formatDate(DateTime.now())) {
        totalCompletedTodayCount += 1;
      }
      totalBookingsCount = nextBookings.length;
    });

    _highlightBookingAction(booking.id, 'completed');
  }

  void _markBookingAsCancelledLocally(BookingAdminModel booking) {
    final updatedBooking = booking.copyWith(
      status: 'cancelled',
      cancelledAt: _currentTimestampLabel(),
    );

    final nextBookings = [...bookings];
    final index = nextBookings.indexWhere((item) => item.id == booking.id);
    if (index == -1) return;

    if (selectedStatus == 'scheduled') {
      nextBookings.removeAt(index);
    } else {
      nextBookings[index] = updatedBooking;
    }

    setState(() {
      bookings = nextBookings;
      totalScheduledCount = (totalScheduledCount - 1).clamp(
        0,
        totalScheduledCount,
      );
      totalCancelledCount += 1;
      totalBookingsCount = nextBookings.length;
    });

    _highlightBookingAction(booking.id, 'cancelled');
  }

  void _highlightBookingAction(int bookingId, String action) {
    _highlightTimers.remove(bookingId)?.cancel();

    if (!mounted) return;

    setState(() {
      _recentActionByBookingId[bookingId] = action;
    });

    _highlightTimers[bookingId] = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;

      setState(() {
        _recentActionByBookingId.remove(bookingId);
      });
      _highlightTimers.remove(bookingId);
    });
  }

  void _showActionSnackBar(
    String message, {
    required IconData icon,
    bool isError = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = isError
        ? colorScheme.error
        : const Color(0xFF1D7A6D);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: backgroundColor,
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildRecentActionBadge(String? recentAction) {
    if (recentAction == null) return null;

    final isCompleted = recentAction == 'completed';
    final backgroundColor = isCompleted
        ? const Color(0xFFE3F6EE)
        : const Color(0xFFFDE8E8);
    final foregroundColor = isCompleted
        ? const Color(0xFF166A5C)
        : const Color(0xFF9F2F2F);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      opacity: 1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: foregroundColor.withValues(alpha: 0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isCompleted ? Icons.task_alt_outlined : Icons.cancel_outlined,
              size: 14,
              color: foregroundColor,
            ),
            const SizedBox(width: 6),
            Text(
              isCompleted ? 'Finalizado agora' : 'Cancelado agora',
              style: TextStyle(
                color: foregroundColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> completeBooking(BookingAdminModel booking) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) return;

    final completionFeedback = await showDialog<String>(
      context: context,
      builder: (context) {
        return BookingCompletionDialog(
          title: 'Finalizar agendamento',
          subtitle:
              'Confirme o uso de ${booking.resourceName} por ${booking.userName} e registre, se necessário, o estado do recurso.',
          confirmLabel: 'Marcar como finalizado',
          cancelLabel: 'Voltar',
        );
      },
    );

    if (completionFeedback == null) return;

    final response = await ApiService.completeBooking(
      schoolId: user.schoolId,
      bookingId: booking.id,
      userId: user.id,
      completionFeedback: completionFeedback,
    );

    if (!mounted) return;

    if (response['success'] == true) {
      final hasFeedback = completionFeedback.trim().isNotEmpty;
      _showActionSnackBar(
        hasFeedback
            ? 'Agendamento finalizado e feedback salvo.'
            : 'Agendamento finalizado com sucesso.',
        icon: Icons.task_alt_outlined,
      );
      _markBookingAsCompletedLocally(booking, authProvider, completionFeedback);
      unawaited(loadBookings());
    } else {
      _showActionSnackBar(
        response['message'] ?? 'Não foi possível finalizar o agendamento.',
        icon: Icons.error_outline,
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user!;
    final isCompact = MediaQuery.of(context).size.width < 380;
    final showBlockingLoader = isLoading && filteredBookings.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isCompact ? 'Agendamentos' : 'Agendamentos - ${user.schoolName}',
        ),
        actions: [
          AdminExportMenuButton(
            onExportCsv: _exportBookingsCsv,
            onExportPdf: _exportBookingsPdf,
          ),
        ],
      ),
      body: showBlockingLoader
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadBookings,
              child: Scrollbar(
                controller: _scrollController,
                child: ListView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  cacheExtent: 900,
                  padding: EdgeInsets.fromLTRB(
                    isCompact ? 14 : 16,
                    8,
                    isCompact ? 14 : 16,
                    24,
                  ),
                  children: [
                    if (isLoading) const AdminInlineLoadingIndicator(),
                    const AdminHeaderCard(
                      title: 'Painel de agendamentos',
                      subtitle:
                          'Acompanhe reservas da escola, filtre por data e cancele agendamentos quando necessário.',
                      icon: Icons.assignment_outlined,
                    ),
                    const SizedBox(height: 16),
                    AdminStatsPanel(
                      children: [
                        AdminStatCard(
                          label: activeFilterCount > 0 ? 'Exibidos' : 'Total',
                          value: totalBookingsCount.toString(),
                          icon: Icons.assignment_outlined,
                          accentColor: const Color(0xFFB54747),
                        ),
                        AdminStatCard(
                          label: 'Agendados',
                          value: scheduledCount.toString(),
                          icon: Icons.check_circle_outline,
                          accentColor: const Color(0xFF1D7A6D),
                        ),
                        AdminStatCard(
                          label: 'Finalizados',
                          value: completedCount.toString(),
                          icon: Icons.task_alt_outlined,
                          accentColor: const Color(0xFF315FA8),
                        ),
                        AdminStatCard(
                          label: 'Finalizadas hoje',
                          value: completedTodayCount.toString(),
                          icon: Icons.today_outlined,
                          accentColor: const Color(0xFF8A6A10),
                        ),
                        AdminStatCard(
                          label: 'Cancelados',
                          value: cancelledCount.toString(),
                          icon: Icons.cancel_outlined,
                          accentColor: const Color(0xFFB54747),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: pickDate,
                                icon: const Icon(Icons.calendar_month),
                                label: Text(
                                  selectedDate == null
                                      ? 'Filtrar por data'
                                      : formatDisplayDate(
                                          formatDate(selectedDate!),
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (selectedDate != null)
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    selectedDate = null;
                                  });
                                  loadBookings();
                                },
                                icon: const Icon(Icons.clear),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Busca e filtros',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                                if (activeFilterCount > 0)
                                  TextButton.icon(
                                    onPressed: clearAdvancedFilters,
                                    icon: const Icon(
                                      Icons.filter_alt_off_outlined,
                                    ),
                                    label: const Text('Limpar'),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                labelText: 'Buscar agendamento',
                                hintText:
                                    'Professor, recurso, turma, disciplina ou finalidade',
                                prefixIcon: const Icon(Icons.search_rounded),
                                suffixIcon:
                                    _searchController.text.trim().isEmpty
                                    ? null
                                    : IconButton(
                                        tooltip: 'Limpar busca',
                                        onPressed: () =>
                                            _searchController.clear(),
                                        icon: const Icon(Icons.close_rounded),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                SizedBox(
                                  width: 260,
                                  child: _BookingDropdownFilter(
                                    label: 'Ordenar por',
                                    value: selectedSort,
                                    items: const [
                                      'date_desc',
                                      'date_asc',
                                      'teacher_asc',
                                      'resource_asc',
                                    ],
                                    itemLabelBuilder: sortLabel,
                                    onChanged: (value) {
                                      if (value == null) return;
                                      setState(() {
                                        selectedSort = value;
                                      });
                                      loadBookings();
                                    },
                                  ),
                                ),
                                SizedBox(
                                  width: 260,
                                  child: _BookingDropdownFilter(
                                    label: 'Professor',
                                    value: selectedTeacher,
                                    items: teacherOptions,
                                    onChanged: (value) {
                                      setState(() {
                                        selectedTeacher = value;
                                      });
                                      loadBookings();
                                    },
                                  ),
                                ),
                                SizedBox(
                                  width: 260,
                                  child: _BookingDropdownFilter(
                                    label: 'Recurso',
                                    value: selectedResource,
                                    items: resourceOptions,
                                    onChanged: (value) {
                                      setState(() {
                                        selectedResource = value;
                                      });
                                      loadBookings();
                                    },
                                  ),
                                ),
                                SizedBox(
                                  width: 260,
                                  child: _BookingDropdownFilter(
                                    label: 'Turma',
                                    value: selectedClassGroup,
                                    items: classGroupOptions,
                                    onChanged: (value) {
                                      setState(() {
                                        selectedClassGroup = value;
                                      });
                                      loadBookings();
                                    },
                                  ),
                                ),
                                SizedBox(
                                  width: 260,
                                  child: _BookingDropdownFilter(
                                    label: 'Status',
                                    value: selectedStatus,
                                    items: statusOptions,
                                    itemLabelBuilder: statusLabel,
                                    onChanged: (value) {
                                      setState(() {
                                        selectedStatus = value;
                                      });
                                      loadBookings();
                                    },
                                  ),
                                ),
                              ],
                            ),
                            if (activeFilterItems.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              AdminActiveFiltersWrap(items: activeFilterItems),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (totalBookingsCount == 0 && activeFilterCount == 0)
                      if (loadError != null)
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Não foi possível carregar os agendamentos.',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 8),
                                Text(loadError!),
                                const SizedBox(height: 14),
                                FilledButton.icon(
                                  onPressed: () => loadBookings(),
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Tentar novamente'),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        const AdminEmptyState(
                          icon: Icons.assignment_outlined,
                          title: 'Nenhum agendamento encontrado.',
                          message:
                              'Quando houver reservas na escola, elas aparecerão aqui para acompanhamento e suporte.',
                        )
                    else if (filteredBookings.isEmpty)
                      const AdminEmptyState(
                        icon: Icons.filter_alt_off_outlined,
                        title: 'Nenhum resultado para os filtros aplicados.',
                        message:
                            'Tente limpar alguns filtros ou ajustar a busca para encontrar outros agendamentos.',
                      )
                    else
                      AdminPaginatedList<BookingAdminModel>(
                        items: filteredBookings,
                        resetKey:
                            '$currentPage|$selectedSort|${selectedDate?.toIso8601String() ?? ''}|${selectedTeacher ?? ''}|${selectedResource ?? ''}|${selectedClassGroup ?? ''}|${selectedStatus ?? ''}|${_searchController.text.trim().toLowerCase()}',
                        summaryLabel: 'agendamentos',
                        totalCount: totalBookingsCount,
                        hasMoreExternal: hasMorePages,
                        isLoadingMore: isLoadingMore,
                        onLoadMore: () => loadBookings(loadMore: true),
                        itemBuilder: (context, booking) {
                          final isScheduled = booking.status == 'scheduled';
                          final isCompleted = booking.status == 'completed';
                          final recentAction =
                              _recentActionByBookingId[booking.id];
                          final accentColor = isScheduled
                              ? const Color(0xFF1D7A6D)
                              : isCompleted
                              ? const Color(0xFF315FA8)
                              : const Color(0xFFB54747);
                          final highlightColor = recentAction == 'completed'
                              ? const Color(0xFF1D7A6D)
                              : recentAction == 'cancelled'
                              ? const Color(0xFFB54747)
                              : Colors.transparent;

                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 320),
                            curve: Curves.easeOut,
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: highlightColor.withValues(
                                  alpha: recentAction == null ? 0 : 0.42,
                                ),
                                width: recentAction == null ? 0 : 2,
                              ),
                              boxShadow: recentAction == null
                                  ? const []
                                  : [
                                      BoxShadow(
                                        color: highlightColor.withValues(
                                          alpha: 0.18,
                                        ),
                                        blurRadius: 18,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                            ),
                            child: AdminEntityCard(
                              icon: isScheduled
                                  ? Icons.event_available_outlined
                                  : isCompleted
                                  ? Icons.task_alt_outlined
                                  : Icons.event_busy_outlined,
                              accentColor: accentColor,
                              title: booking.resourceName,
                              subtitle: 'Professor: ${booking.userName}',
                              badge: AdminStatusBadge(
                                label: statusLabel(booking.status),
                                accentColor: accentColor,
                              ),
                              trailing: _buildRecentActionBadge(recentAction),
                              details: [
                                AdminDetailRow(
                                  icon: Icons.calendar_today_outlined,
                                  label: 'Data',
                                  value: formatDisplayDate(booking.bookingDate),
                                ),
                                AdminDetailRow(
                                  icon: Icons.groups_outlined,
                                  label: 'Turma',
                                  value: booking.classGroupName,
                                ),
                                AdminDetailRow(
                                  icon: Icons.menu_book_outlined,
                                  label: 'Disciplina',
                                  value: booking.subjectName,
                                ),
                                AdminDetailRow(
                                  icon: Icons.schedule,
                                  label: 'Aulas',
                                  value: formatLessons(booking.lessons),
                                ),
                                AdminDetailRow(
                                  icon: Icons.edit_note,
                                  label: 'Finalidade',
                                  value: booking.purpose.isEmpty
                                      ? 'Não informada'
                                      : booking.purpose,
                                ),
                                if ((booking.completedAt ?? '').isNotEmpty)
                                  AdminDetailRow(
                                    icon: Icons.event_available_outlined,
                                    label: 'Finalizado em',
                                    value: booking.completedAt!,
                                  ),
                                if ((booking.completedByName ?? '').isNotEmpty)
                                  AdminDetailRow(
                                    icon: Icons.person_outline_rounded,
                                    label: 'Finalizado por',
                                    value: booking.completedByName!,
                                  ),
                                if ((booking.completionFeedback ?? '')
                                    .isNotEmpty)
                                  AdminDetailRow(
                                    icon: Icons.rate_review_outlined,
                                    label: 'Feedback do uso',
                                    value: booking.completionFeedback!,
                                  ),
                                if ((booking.cancelledAt ?? '').isNotEmpty)
                                  AdminDetailRow(
                                    icon: Icons.cancel_outlined,
                                    label: 'Cancelado em',
                                    value: booking.cancelledAt!,
                                  ),
                              ],
                              footerActions: isScheduled
                                  ? [
                                      if (_canCompleteBooking(booking))
                                        FilledButton.icon(
                                          onPressed: () =>
                                              completeBooking(booking),
                                          icon: const Icon(
                                            Icons.task_alt_outlined,
                                          ),
                                          label: const Text('Finalizar'),
                                        ),
                                      OutlinedButton.icon(
                                        onPressed: () => cancelBooking(booking),
                                        icon: const Icon(Icons.cancel_outlined),
                                        label: const Text('Cancelar'),
                                      ),
                                    ]
                                  : const [],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _BookingDropdownFilter extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final String Function(String value)? itemLabelBuilder;

  const _BookingDropdownFilter({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.itemLabelBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: value == null
            ? null
            : IconButton(
                tooltip: 'Limpar filtro',
                onPressed: () => onChanged(null),
                icon: const Icon(Icons.close_rounded),
              ),
      ),
      items: [
        const DropdownMenuItem<String>(value: null, child: Text('Todos')),
        ...items.map((item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(
              itemLabelBuilder != null ? itemLabelBuilder!(item) : item,
              overflow: TextOverflow.ellipsis,
            ),
          );
        }),
      ],
      onChanged: onChanged,
    );
  }
}
