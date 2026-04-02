import 'dart:async';

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';

import '../models/filter_preferences_model.dart';
import '../models/my_booking_model.dart';
import '../providers/app_preferences_provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/csv_export_service.dart';
import '../services/pdf_export_service.dart';
import '../utils/app_formatters.dart';
import '../widgets/admin_ui.dart';

class MyBookingsV2Screen extends StatefulWidget {
  const MyBookingsV2Screen({super.key});

  @override
  State<MyBookingsV2Screen> createState() => _MyBookingsV2ScreenState();
}

class _MyBookingsV2ScreenState extends State<MyBookingsV2Screen> {
  static const String _filtersPreferenceKey = 'my_bookings_filters_v1';
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
  int totalCancelledCount = 0;
  List<MyBookingModel> bookings = [];
  final Map<int, String> _recentActionByBookingId = {};
  final Map<int, Timer> _highlightTimers = {};
  String? selectedStatus;
  String selectedSort = 'date_desc';
  Timer? _searchDebounce;
  bool _isRestoringFilters = false;

  List<MyBookingModel> get filteredBookings => bookings;

  int get activeFilterCount {
    return [
      if (_searchController.text.trim().isNotEmpty) _searchController.text,
      selectedStatus,
    ].length;
  }

  List<AdminActiveFilterItem> get activeFilterItems {
    final items = <AdminActiveFilterItem>[];

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
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
    _restoreFiltersAndLoad();
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
    final savedFilters = await preferences.getObjectPreference(
      _filtersPreferenceKey,
      MyBookingsFiltersPreference.fromJson,
    );

    if (!mounted) return;

    _isRestoringFilters = true;
    if (savedFilters != null) {
      setState(() {
        selectedStatus = savedFilters.selectedStatus;
        selectedSort = _myBookingSortValues.contains(savedFilters.selectedSort)
            ? savedFilters.selectedSort
            : 'date_desc';
      });
      _searchController.text = savedFilters.search;
    }
    _isRestoringFilters = false;

    loadBookings();
  }

  static const List<String> _myBookingSortValues = [
    'date_desc',
    'date_asc',
    'resource_asc',
    'status',
  ];

  bool get _hasCustomPreferences {
    return _searchController.text.trim().isNotEmpty ||
        selectedStatus != null ||
        selectedSort != 'date_desc';
  }

  Future<void> _persistFilters() async {
    final preferences = context.read<AppPreferencesProvider>();
    if (!_hasCustomPreferences) {
      await preferences.removePreference(_filtersPreferenceKey);
      return;
    }

    await preferences.setObjectPreference(
      _filtersPreferenceKey,
      MyBookingsFiltersPreference(
        search: _searchController.text.trim(),
        selectedStatus: selectedStatus,
        selectedSort: selectedSort,
      ),
      (value) => value.toJson(),
    );
  }

  String formatLessons(List<MyBookingLessonModel> lessons) {
    if (lessons.isEmpty) return 'Sem aulas';
    return lessons.map((lesson) => lesson.label).join(', ');
  }

  String formatDisplayDate(String value) {
    return AppFormatters.formatDateString(value);
  }

  int get scheduledCount {
    return totalScheduledCount;
  }

  int get cancelledCount {
    return totalCancelledCount;
  }

  int get completedCount {
    return totalCompletedCount;
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
      case 'resource_asc':
        return 'Recurso (A-Z)';
      case 'status':
        return 'Status';
      case 'date_desc':
      default:
        return 'Data mais recente';
    }
  }

  void clearFilters() {
    setState(() {
      _searchController.clear();
      selectedStatus = null;
    });
    loadBookings();
  }

  List<List<Object?>> _myBookingExportRows() {
    return filteredBookings
        .map(
          (booking) => [
            formatDisplayDate(booking.bookingDate),
            statusLabel(booking.status),
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
      filePrefix: 'meus_agendamentos',
      title: 'Meus agendamentos',
      subject: 'Meus agendamentos',
      shareText: 'Exportação CSV dos seus agendamentos.',
      headers: const [
        'Data',
        'Status',
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
      rows: _myBookingExportRows(),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));
  }

  Future<void> _exportBookingsPdf() async {
    final result = await PdfExportService.exportTable(
      filePrefix: 'meus_agendamentos',
      title: 'Meus agendamentos',
      subject: 'Meus agendamentos',
      shareText: 'Exportação PDF dos seus agendamentos.',
      headers: const [
        'Data',
        'Status',
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
      rows: _myBookingExportRows(),
      landscape: true,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));
  }

  Future<void> loadBookings({bool loadMore = false}) async {
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
      }
    });

    try {
      final nextPage = loadMore ? currentPage + 1 : 1;
      final response = await ApiService.getMyBookingsPage(
        schoolId: user.schoolId,
        userId: user.id,
        page: nextPage,
        pageSize: _pageSize,
        search: _searchController.text,
        status: selectedStatus,
        sort: selectedSort,
      );

      if (response.success) {
        final fetchedBookings = response.items;
        final summary = response.summary;
        bookings = loadMore
            ? [...bookings, ...fetchedBookings]
            : fetchedBookings;
        currentPage = nextPage;
        totalBookingsCount = response.total == 0
            ? bookings.length
            : response.total;
        totalScheduledCount =
            summary?.scheduledCount ??
            bookings.where((booking) => booking.status == 'scheduled').length;
        totalCompletedCount =
            summary?.completedCount ??
            bookings.where((booking) => booking.status == 'completed').length;
        totalCancelledCount =
            summary?.cancelledCount ??
            bookings.where((booking) => booking.status == 'cancelled').length;
        hasMorePages = response.hasNextPage;
      }
    } catch (e) {
      logger.i('ERRO AO CARREGAR MEUS AGENDAMENTOS: $e');
    }

    if (!mounted) return;

    setState(() {
      isLoading = false;
      isLoadingMore = false;
    });
  }

  Future<void> cancelBooking(MyBookingModel booking) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AdminConfirmDialog(
          title: 'Cancelar agendamento',
          message:
              'Deseja cancelar o agendamento de ${booking.resourceName}? Essa ação libera o horário para novas reservas.',
          icon: Icons.cancel_outlined,
          confirmLabel: 'Cancelar reserva',
          cancelLabel: 'Voltar',
        );
      },
    );

    if (confirm != true) return;

    final response = await ApiService.cancelBookingResult(
      schoolId: user.schoolId,
      bookingId: booking.id,
      userId: user.id,
    );

    if (!mounted) return;

    if (response.success) {
      _showActionSnackBar(
        'Agendamento cancelado com sucesso.',
        icon: Icons.cancel_outlined,
      );
      _markBookingAsCancelledLocally(booking);
      unawaited(loadBookings());
    } else {
      _showActionSnackBar(
        response.message ?? 'Não foi possível cancelar o agendamento.',
        icon: Icons.error_outline,
        isError: true,
      );
    }
  }

  bool _canCompleteBooking(MyBookingModel booking) {
    if (booking.status != 'scheduled') return false;
    final bookingDate = DateTime.tryParse(booking.bookingDate);
    if (bookingDate == null) return false;
    final today = DateUtils.dateOnly(DateTime.now());
    return !DateUtils.dateOnly(bookingDate).isAfter(today);
  }

  String _currentTimestampLabel() {
    return AppFormatters.formatApiTimestamp(DateTime.now());
  }

  void _markBookingAsCompletedLocally(
    MyBookingModel booking,
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
      totalBookingsCount = nextBookings.length;
    });

    _highlightBookingAction(booking.id, 'completed');
  }

  void _markBookingAsCancelledLocally(MyBookingModel booking) {
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

  Future<void> completeBooking(MyBookingModel booking) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) return;

    final completionFeedback = await showDialog<String>(
      context: context,
      builder: (context) {
        return BookingCompletionDialog(
          title: 'Finalizar agendamento',
          subtitle:
              'Confirme o uso de ${booking.resourceName} e registre, se quiser, como estava o recurso após a aula.',
          confirmLabel: 'Marcar como finalizado',
          cancelLabel: 'Voltar',
        );
      },
    );

    if (completionFeedback == null) return;

    final response = await ApiService.completeBookingResult(
      schoolId: user.schoolId,
      bookingId: booking.id,
      userId: user.id,
      completionFeedback: completionFeedback,
    );

    if (!mounted) return;

    if (response.success) {
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
        response.message ?? 'Não foi possível finalizar o agendamento.',
        icon: Icons.error_outline,
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user!;
    final colorScheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 380;
    final isMobile = screenWidth < 640;
    final showBlockingLoader = isLoading && filteredBookings.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isCompact
              ? 'Meus Agendamentos'
              : 'Meus Agendamentos - ${user.schoolName}',
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
                    Container(
                      padding: EdgeInsets.all(isCompact ? 18 : 24),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            colorScheme.primary,
                            const Color(0xFF184E44),
                          ],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Seus agendamentos',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: colorScheme.onPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 8),
                          if (!isCompact)
                            Text(
                              'Acompanhe reservas ativas, consulte histórico e cancele quando necessário.',
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    color: colorScheme.onPrimary.withValues(
                                      alpha: 0.84,
                                    ),
                                    height: 1.4,
                                  ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
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
                                    onPressed: clearFilters,
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
                                    'Recurso, turma, disciplina, finalidade ou data',
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
                                  child: AdminDropdownFilter(
                                    label: 'Ordenar por',
                                    value: selectedSort,
                                    items: const [
                                      'date_desc',
                                      'date_asc',
                                      'resource_asc',
                                      'status',
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
                                  child: AdminDropdownFilter(
                                    label: 'Status',
                                    value: selectedStatus,
                                    items: const [
                                      'scheduled',
                                      'completed',
                                      'cancelled',
                                    ],
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
                    const SizedBox(height: 16),
                    if (isMobile)
                      Column(
                        children: [
                          AdminStatCard(
                            label: 'Agendados',
                            value: scheduledCount.toString(),
                            icon: Icons.check_circle_outline,
                            accentColor: const Color(0xFF1D7A6D),
                          ),
                          const SizedBox(height: 12),
                          AdminStatCard(
                            label: 'Finalizados',
                            value: completedCount.toString(),
                            icon: Icons.task_alt_outlined,
                            accentColor: const Color(0xFF315FA8),
                          ),
                          const SizedBox(height: 12),
                          AdminStatCard(
                            label: 'Cancelados',
                            value: cancelledCount.toString(),
                            icon: Icons.cancel_outlined,
                            accentColor: const Color(0xFFB54747),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: AdminStatCard(
                              label: 'Agendados',
                              value: scheduledCount.toString(),
                              icon: Icons.check_circle_outline,
                              accentColor: const Color(0xFF1D7A6D),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AdminStatCard(
                              label: 'Finalizados',
                              value: completedCount.toString(),
                              icon: Icons.task_alt_outlined,
                              accentColor: const Color(0xFF315FA8),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AdminStatCard(
                              label: 'Cancelados',
                              value: cancelledCount.toString(),
                              icon: Icons.cancel_outlined,
                              accentColor: const Color(0xFFB54747),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 18),
                    if (totalBookingsCount == 0 && activeFilterCount == 0)
                      const AdminEmptyState(
                        icon: Icons.event_note_outlined,
                        title: 'Você não possui agendamentos.',
                        message:
                            'Quando novas reservas forem criadas, elas aparecerão aqui para acompanhamento rápido.',
                      )
                    else if (filteredBookings.isEmpty)
                      const AdminEmptyState(
                        icon: Icons.filter_alt_off_outlined,
                        title: 'Nenhum agendamento encontrado.',
                        message:
                            'Ajuste a busca ou limpe os filtros para visualizar outras reservas.',
                      )
                    else
                      AdminPaginatedList<MyBookingModel>(
                        items: filteredBookings,
                        resetKey:
                            '$currentPage|$selectedSort|${selectedStatus ?? ''}|${_searchController.text.trim().toLowerCase()}',
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
                              subtitle: formatDisplayDate(booking.bookingDate),
                              badge: AdminStatusBadge(
                                label: statusLabel(booking.status),
                                accentColor: accentColor,
                              ),
                              trailing: _buildRecentActionBadge(recentAction),
                              details: [
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
                                      ? 'Nao informada'
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
                                          label: Text(
                                            isMobile
                                                ? 'Finalizar'
                                                : 'Marcar como finalizado',
                                          ),
                                        ),
                                      OutlinedButton.icon(
                                        onPressed: () => cancelBooking(booking),
                                        icon: const Icon(Icons.cancel_outlined),
                                        label: Text(
                                          isMobile
                                              ? 'Cancelar reserva'
                                              : 'Cancelar',
                                        ),
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
