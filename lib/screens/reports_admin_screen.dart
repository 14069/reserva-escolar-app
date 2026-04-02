import 'dart:async';

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';

import '../models/api_summary_models.dart';
import '../models/booking_admin_model.dart';
import '../models/filter_preferences_model.dart';
import '../providers/app_preferences_provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/csv_export_service.dart';
import '../services/pdf_export_service.dart';
import '../utils/app_formatters.dart';
import '../widgets/admin_ui.dart';

class ReportsAdminScreen extends StatefulWidget {
  const ReportsAdminScreen({super.key});

  @override
  State<ReportsAdminScreen> createState() => _ReportsAdminScreenState();
}

class _ReportsAdminScreenState extends State<ReportsAdminScreen> {
  static const String _filtersPreferenceKey = 'reports_admin_filters_v1';
  final Logger _logger = Logger();
  static const int _pageSize = 15;
  final ScrollController _scrollController = ScrollController();

  bool isLoading = true;
  bool isLoadingMore = false;
  String? loadError;
  List<BookingAdminModel> detailedBookings = [];
  _ReportPeriod selectedPeriod = _ReportPeriod.all;
  DateTimeRange? customRange;
  String? selectedTeacher;
  String? selectedResource;
  String? selectedClassGroup;
  String? selectedStatus;
  int currentPage = 1;
  bool hasMorePages = false;
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
  List<String> teacherOptions = [];
  List<String> resourceOptions = [];
  List<String> classGroupOptions = [];
  List<String> statusOptions = [];
  List<_RankingEntry> teacherRanking = const [];
  List<_RankingEntry> resourceRanking = const [];
  List<_RankingEntry> subjectRanking = const [];
  List<_RankingEntry> classGroupRanking = const [];

  @override
  void initState() {
    super.initState();
    _restoreFiltersAndLoad();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  int get activeFilterCount {
    final filters = [
      selectedTeacher,
      selectedResource,
      selectedClassGroup,
      selectedStatus,
    ];
    return filters.where((value) => value != null).length;
  }

  List<AdminActiveFilterItem> get activeFilterItems {
    final items = <AdminActiveFilterItem>[];

    if (selectedPeriod != _ReportPeriod.all) {
      items.add(
        AdminActiveFilterItem(
          label: 'Período: ${_formatRangeLabel()}',
          onRemove: () {
            setState(() {
              selectedPeriod = _ReportPeriod.all;
              customRange = null;
            });
            _loadReport();
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
            _loadReport();
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
            _loadReport();
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
            _loadReport();
          },
        ),
      );
    }

    if (selectedStatus != null) {
      items.add(
        AdminActiveFilterItem(
          label: 'Status: ${_statusLabel(selectedStatus!)}',
          onRemove: () {
            setState(() {
              selectedStatus = null;
            });
            _loadReport();
          },
        ),
      );
    }

    return items;
  }

  double get cancellationRate {
    if (totalBookingsCount == 0) return 0;
    return (cancelledCount / totalBookingsCount) * 100;
  }

  DateTimeRange? _resolveRange() {
    final now = DateUtils.dateOnly(DateTime.now());

    switch (selectedPeriod) {
      case _ReportPeriod.last7Days:
        return DateTimeRange(
          start: now.subtract(const Duration(days: 6)),
          end: now,
        );
      case _ReportPeriod.last30Days:
        return DateTimeRange(
          start: now.subtract(const Duration(days: 29)),
          end: now,
        );
      case _ReportPeriod.thisMonth:
        return DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);
      case _ReportPeriod.custom:
        return customRange;
      case _ReportPeriod.all:
        return null;
    }
  }

  String? get _dateFromValue {
    final range = _resolveRange();
    if (range == null) return null;
    return _toApiDate(DateUtils.dateOnly(range.start));
  }

  String? get _dateToValue {
    final range = _resolveRange();
    if (range == null) return null;
    return _toApiDate(DateUtils.dateOnly(range.end));
  }

  Future<void> _restoreFiltersAndLoad() async {
    final preferences = context.read<AppPreferencesProvider>();
    final savedFilters = await preferences.getObjectPreference(
      _filtersPreferenceKey,
      ReportsFiltersPreference.fromJson,
    );

    if (!mounted) return;

    if (savedFilters != null) {
      final restoredPeriod = _reportPeriodFromName(savedFilters.selectedPeriod);
      final restoredStart = DateTime.tryParse(
        savedFilters.customRangeStart ?? '',
      );
      final restoredEnd = DateTime.tryParse(savedFilters.customRangeEnd ?? '');

      setState(() {
        selectedPeriod = restoredPeriod;
        customRange =
            restoredPeriod == _ReportPeriod.custom &&
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
      });
    }

    _loadReport();
  }

  _ReportPeriod _reportPeriodFromName(String? value) {
    return _ReportPeriod.values.firstWhere(
      (period) => period.name == value,
      orElse: () => _ReportPeriod.all,
    );
  }

  bool get _hasCustomPreferences {
    return selectedPeriod != _ReportPeriod.all ||
        customRange != null ||
        selectedTeacher != null ||
        selectedResource != null ||
        selectedClassGroup != null ||
        selectedStatus != null;
  }

  Future<void> _persistFilters() async {
    final preferences = context.read<AppPreferencesProvider>();
    if (!_hasCustomPreferences) {
      await preferences.removePreference(_filtersPreferenceKey);
      return;
    }

    await preferences.setObjectPreference(
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

  Future<void> _loadReport({bool loadMore = false}) async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.user;
    if (user == null) return;

    if (!loadMore) {
      unawaited(_persistFilters());
    }

    final nextPage = loadMore ? currentPage + 1 : 1;

    setState(() {
      if (loadMore) {
        isLoadingMore = true;
      } else {
        isLoading = true;
        loadError = null;
      }
    });

    try {
      final response = await ApiService.getAllBookingsPage(
        schoolId: user.schoolId,
        dateFrom: _dateFromValue,
        dateTo: _dateToValue,
        page: nextPage,
        pageSize: _pageSize,
        teacher: selectedTeacher,
        resource: selectedResource,
        classGroup: selectedClassGroup,
        status: selectedStatus,
        sort: 'date_desc',
      );

      if (response.success) {
        final fetchedBookings = response.items;
        final summary = response.summary;
        if (!mounted) return;

        setState(() {
          detailedBookings = loadMore
              ? [...detailedBookings, ...fetchedBookings]
              : fetchedBookings;
          currentPage = nextPage;
          hasMorePages = response.hasNextPage;
          totalBookingsCount = response.total == 0
              ? fetchedBookings.length
              : response.total;
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
          busiestWeekdayLabel = _resolvedBusiestWeekdayLabel(summary);
          teacherOptions = _mergeSelectedOption(
            summary?.teacherOptions ?? const [],
            selectedTeacher,
          );
          resourceOptions = _mergeSelectedOption(
            summary?.resourceOptions ?? const [],
            selectedResource,
          );
          classGroupOptions = _mergeSelectedOption(
            summary?.classGroupOptions ?? const [],
            selectedClassGroup,
          );
          statusOptions = _mergeSelectedOption(
            summary?.statusOptions ?? const [],
            selectedStatus,
          );
          teacherRanking = _toRankingEntries(summary?.teacherRanking);
          resourceRanking = _toRankingEntries(summary?.resourceRanking);
          classGroupRanking = _toRankingEntries(summary?.classGroupRanking);
          subjectRanking = _toRankingEntries(summary?.subjectRanking);
          loadError = null;
        });
      } else {
        if (!mounted) return;
        setState(() {
          loadError =
              response.message ?? 'Não foi possível carregar os relatórios.';
        });
      }
    } catch (error) {
      _logger.e('ERRO AO CARREGAR RELATORIOS ADMIN V2: $error');
      if (!mounted) return;
      setState(() {
        loadError = 'Não foi possível carregar os relatórios.';
      });
    }

    if (!mounted) return;

    setState(() {
      isLoading = false;
      isLoadingMore = false;
    });
  }

  Future<void> _pickCustomRange() async {
    final now = DateUtils.dateOnly(DateTime.now());
    final initialRange =
        customRange ??
        DateTimeRange(start: now.subtract(const Duration(days: 29)), end: now);

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
      initialDateRange: initialRange,
    );

    if (picked == null) return;

    setState(() {
      customRange = picked;
      selectedPeriod = _ReportPeriod.custom;
    });
    _loadReport();
  }

  void _clearAdvancedFilters() {
    setState(() {
      selectedTeacher = null;
      selectedResource = null;
      selectedClassGroup = null;
      selectedStatus = null;
    });
    _loadReport();
  }

  List<List<Object?>> _reportExportRows(List<BookingAdminModel> bookings) {
    return bookings
        .map(
          (booking) => [
            _formatDate(DateTime.parse(booking.bookingDate)),
            _statusLabel(booking.status),
            booking.userName,
            booking.resourceName,
            booking.classGroupName,
            booking.subjectName,
            booking.purpose,
            _formatLessons(booking.lessons),
            booking.lessons.length,
            booking.completedAt ?? '',
            booking.completedByName ?? '',
            booking.cancelledAt ?? '',
          ],
        )
        .toList();
  }

  Future<void> _exportReportCsv() async {
    try {
      final allRows = await _loadAllRowsForExport();

      final result = await CsvExportService.exportRows(
        filePrefix: 'relatorios_agendamentos',
        title: 'Relatório de agendamentos',
        subject: 'Relatório de agendamentos',
        shareText: 'Exportação CSV do relatório filtrado de agendamentos.',
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
        rows: _reportExportRows(allRows),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível exportar o relatório agora.'),
        ),
      );
    }
  }

  Future<void> _exportReportPdf() async {
    try {
      final allRows = await _loadAllRowsForExport();

      final result = await PdfExportService.exportTable(
        filePrefix: 'relatorios_agendamentos',
        title: 'Relatório de agendamentos',
        subject: 'Relatório de agendamentos',
        shareText: 'Exportação PDF do relatório filtrado de agendamentos.',
        subtitle: 'Período: ${_formatRangeLabel()}',
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
        rows: _reportExportRows(allRows),
        landscape: true,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível exportar o relatório agora.'),
        ),
      );
    }
  }

  Future<List<BookingAdminModel>> _loadAllRowsForExport() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.user;
    if (user == null) return const [];

    final exported = <BookingAdminModel>[];
    var page = 1;
    var hasNextPage = true;

    while (hasNextPage) {
      final response = await ApiService.getAllBookingsPage(
        schoolId: user.schoolId,
        dateFrom: _dateFromValue,
        dateTo: _dateToValue,
        page: page,
        pageSize: 200,
        teacher: selectedTeacher,
        resource: selectedResource,
        classGroup: selectedClassGroup,
        status: selectedStatus,
        sort: 'date_desc',
      );

      if (!response.success) {
        throw Exception(
          response.message ?? 'Não foi possível exportar os relatórios.',
        );
      }

      exported.addAll(response.items);
      hasNextPage = response.hasNextPage;
      page += 1;

      if (response.items.isEmpty) {
        hasNextPage = false;
      }
    }

    return exported;
  }

  List<String> _mergeSelectedOption(List<String> values, String? selected) {
    final merged = [...values];
    if (selected != null && selected.isNotEmpty && !merged.contains(selected)) {
      merged.add(selected);
      merged.sort();
    }
    return merged;
  }

  String _resolvedBusiestWeekdayLabel(BookingSummaryModel? summary) {
    final value = summary?.busiestWeekdayLabel.trim() ?? '';
    return value.isEmpty ? 'Sem dados' : value;
  }

  List<_RankingEntry> _toRankingEntries(List<RankingEntryModel>? entries) {
    if (entries == null || entries.isEmpty) return const [];
    return entries
        .where((entry) => entry.label.trim().isNotEmpty)
        .map((entry) => _RankingEntry(label: entry.label, value: entry.value))
        .toList(growable: false);
  }

  String _toApiDate(DateTime date) {
    return AppFormatters.formatApiDate(date);
  }

  String _formatRangeLabel() {
    final range = _resolveRange();
    if (range == null) return 'Todo o histórico';
    return '${_formatDate(range.start)} a ${_formatDate(range.end)}';
  }

  String _formatDate(DateTime date) {
    return AppFormatters.formatDate(date);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user!;
    final isCompact = MediaQuery.of(context).size.width < 380;
    final recentBookings = detailedBookings;
    final showBlockingLoader = isLoading && recentBookings.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isCompact ? 'Relatórios' : 'Relatórios - ${user.schoolName}',
        ),
        actions: [
          AdminExportMenuButton(
            onExportCsv: _exportReportCsv,
            onExportPdf: _exportReportPdf,
          ),
        ],
      ),
      body: showBlockingLoader
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadReport,
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
                      title: 'Relatórios administrativos',
                      subtitle:
                          'Analise reservas, identifique picos de uso e acompanhe o comportamento da escola por período.',
                      icon: Icons.bar_chart_rounded,
                    ),
                    const SizedBox(height: 16),
                    _ReportsFilterCard(
                      selectedPeriod: selectedPeriod,
                      customRange: customRange,
                      selectedTeacher: selectedTeacher,
                      selectedResource: selectedResource,
                      selectedClassGroup: selectedClassGroup,
                      selectedStatus: selectedStatus,
                      teacherOptions: teacherOptions,
                      resourceOptions: resourceOptions,
                      classGroupOptions: classGroupOptions,
                      statusOptions: statusOptions,
                      activeFilterCount: activeFilterCount,
                      onSelectPeriod: (period) {
                        if (period == _ReportPeriod.custom) {
                          _pickCustomRange();
                          return;
                        }

                        setState(() {
                          selectedPeriod = period;
                        });
                        _loadReport();
                      },
                      onPickCustomRange: _pickCustomRange,
                      onSelectTeacher: (value) {
                        setState(() {
                          selectedTeacher = value;
                        });
                        _loadReport();
                      },
                      onSelectResource: (value) {
                        setState(() {
                          selectedResource = value;
                        });
                        _loadReport();
                      },
                      onSelectClassGroup: (value) {
                        setState(() {
                          selectedClassGroup = value;
                        });
                        _loadReport();
                      },
                      onSelectStatus: (value) {
                        setState(() {
                          selectedStatus = value;
                        });
                        _loadReport();
                      },
                      onClearAdvancedFilters: _clearAdvancedFilters,
                    ),
                    const SizedBox(height: 16),
                    if (activeFilterItems.isNotEmpty) ...[
                      AdminActiveFiltersWrap(items: activeFilterItems),
                      const SizedBox(height: 16),
                    ],
                    if (loadError != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: AdminEmptyState(
                          icon: Icons.error_outline,
                          title: 'Não foi possível gerar os relatórios.',
                          message: loadError!,
                        ),
                      ),
                    if (totalBookingsCount == 0)
                      const AdminEmptyState(
                        icon: Icons.insights_outlined,
                        title: 'Sem dados para esse período.',
                        message:
                            'Ajuste o filtro para visualizar indicadores e rankings dos agendamentos da escola.',
                      )
                    else ...[
                      AdminStatsPanel(
                        children: [
                          AdminStatCard(
                            label: 'Reservas',
                            value: totalBookingsCount.toString(),
                            icon: Icons.assignment_outlined,
                            accentColor: const Color(0xFF0F766E),
                          ),
                          AdminStatCard(
                            label: 'Agendadas',
                            value: scheduledCount.toString(),
                            icon: Icons.check_circle_outline,
                            accentColor: const Color(0xFF1D7A6D),
                          ),
                          AdminStatCard(
                            label: 'Finalizadas',
                            value: completedCount.toString(),
                            icon: Icons.task_alt_outlined,
                            accentColor: const Color(0xFF315FA8),
                          ),
                          AdminStatCard(
                            label: 'Canceladas',
                            value: cancelledCount.toString(),
                            icon: Icons.cancel_outlined,
                            accentColor: const Color(0xFFB54747),
                          ),
                          AdminStatCard(
                            label: 'Recursos usados',
                            value: uniqueResourcesCount.toString(),
                            icon: Icons.meeting_room_outlined,
                            accentColor: const Color(0xFF315FA8),
                          ),
                          AdminStatCard(
                            label: 'Professores ativos',
                            value: uniqueTeachersCount.toString(),
                            icon: Icons.people_alt_outlined,
                            accentColor: const Color(0xFF8A6A10),
                          ),
                          AdminStatCard(
                            label: 'Turmas atendidas',
                            value: uniqueClassGroupsCount.toString(),
                            icon: Icons.groups_2_outlined,
                            accentColor: const Color(0xFF7A4A9E),
                          ),
                          AdminStatCard(
                            label: 'Disciplinas',
                            value: uniqueSubjectsCount.toString(),
                            icon: Icons.menu_book_outlined,
                            accentColor: const Color(0xFFAA5F2C),
                          ),
                          AdminStatCard(
                            label: 'Aulas reservadas',
                            value: totalReservedLessons.toString(),
                            icon: Icons.schedule_outlined,
                            accentColor: const Color(0xFF0B7285),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _ReportsCoverageCard(
                        filteredCount: totalBookingsCount,
                        totalCount: overallBookingsCount,
                        periodLabel: _formatRangeLabel(),
                        activeFilterCount: activeFilterCount,
                      ),
                      const SizedBox(height: 16),
                      _ReportsInsightsCard(
                        periodLabel: _formatRangeLabel(),
                        cancellationRate: cancellationRate,
                        averageLessonsPerBooking: averageLessonsPerBooking,
                        busiestWeekdayLabel: busiestWeekdayLabel,
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 860;
                          final cardWidth = isWide
                              ? (constraints.maxWidth - 12) / 2
                              : constraints.maxWidth;

                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              SizedBox(
                                width: cardWidth,
                                child: _ReportsRankingCard(
                                  title: 'Recursos mais reservados',
                                  icon: Icons.devices_outlined,
                                  entries: resourceRanking,
                                  emptyLabel: 'Sem recursos para listar.',
                                ),
                              ),
                              SizedBox(
                                width: cardWidth,
                                child: _ReportsRankingCard(
                                  title: 'Professores com mais reservas',
                                  icon: Icons.person_outline_rounded,
                                  entries: teacherRanking,
                                  emptyLabel: 'Sem professores para listar.',
                                ),
                              ),
                              SizedBox(
                                width: cardWidth,
                                child: _ReportsRankingCard(
                                  title: 'Turmas com mais reservas',
                                  icon: Icons.groups_outlined,
                                  entries: classGroupRanking,
                                  emptyLabel: 'Sem turmas para listar.',
                                ),
                              ),
                              SizedBox(
                                width: cardWidth,
                                child: _ReportsRankingCard(
                                  title: 'Disciplinas mais agendadas',
                                  icon: Icons.menu_book_outlined,
                                  entries: subjectRanking,
                                  emptyLabel: 'Sem disciplinas para listar.',
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      _ReportsDetailedListCard(
                        bookings: recentBookings,
                        totalCount: totalBookingsCount,
                        hasMorePages: hasMorePages,
                        isLoadingMore: isLoadingMore,
                        resetKey: Object.hash(
                          selectedPeriod,
                          customRange?.start.millisecondsSinceEpoch,
                          customRange?.end.millisecondsSinceEpoch,
                          selectedTeacher,
                          selectedResource,
                          selectedClassGroup,
                          selectedStatus,
                        ),
                        onLoadMore: () => _loadReport(loadMore: true),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}

enum _ReportPeriod { last7Days, last30Days, thisMonth, custom, all }

class _ReportsFilterCard extends StatelessWidget {
  final _ReportPeriod selectedPeriod;
  final DateTimeRange? customRange;
  final String? selectedTeacher;
  final String? selectedResource;
  final String? selectedClassGroup;
  final String? selectedStatus;
  final List<String> teacherOptions;
  final List<String> resourceOptions;
  final List<String> classGroupOptions;
  final List<String> statusOptions;
  final int activeFilterCount;
  final ValueChanged<_ReportPeriod> onSelectPeriod;
  final ValueChanged<String?> onSelectTeacher;
  final ValueChanged<String?> onSelectResource;
  final ValueChanged<String?> onSelectClassGroup;
  final ValueChanged<String?> onSelectStatus;
  final VoidCallback onPickCustomRange;
  final VoidCallback onClearAdvancedFilters;

  const _ReportsFilterCard({
    required this.selectedPeriod,
    required this.customRange,
    required this.selectedTeacher,
    required this.selectedResource,
    required this.selectedClassGroup,
    required this.selectedStatus,
    required this.teacherOptions,
    required this.resourceOptions,
    required this.classGroupOptions,
    required this.statusOptions,
    required this.activeFilterCount,
    required this.onSelectPeriod,
    required this.onSelectTeacher,
    required this.onSelectResource,
    required this.onSelectClassGroup,
    required this.onSelectStatus,
    required this.onPickCustomRange,
    required this.onClearAdvancedFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Período do relatório',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Troque o recorte para comparar comportamento recente, mensal ou o histórico completo.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _PeriodChip(
                  label: '7 dias',
                  selected: selectedPeriod == _ReportPeriod.last7Days,
                  onTap: () => onSelectPeriod(_ReportPeriod.last7Days),
                ),
                _PeriodChip(
                  label: '30 dias',
                  selected: selectedPeriod == _ReportPeriod.last30Days,
                  onTap: () => onSelectPeriod(_ReportPeriod.last30Days),
                ),
                _PeriodChip(
                  label: 'Este mês',
                  selected: selectedPeriod == _ReportPeriod.thisMonth,
                  onTap: () => onSelectPeriod(_ReportPeriod.thisMonth),
                ),
                _PeriodChip(
                  label: customRange == null
                      ? 'Personalizado'
                      : 'Personalizado: ${_shortDate(customRange!.start)} - ${_shortDate(customRange!.end)}',
                  selected: selectedPeriod == _ReportPeriod.custom,
                  onTap: onPickCustomRange,
                ),
                _PeriodChip(
                  label: 'Histórico',
                  selected: selectedPeriod == _ReportPeriod.all,
                  onTap: () => onSelectPeriod(_ReportPeriod.all),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Filtros detalhados',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (activeFilterCount > 0)
                  TextButton.icon(
                    onPressed: onClearAdvancedFilters,
                    icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                    label: Text('Limpar ($activeFilterCount)'),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Refine o relatório por professor, recurso, turma ou status.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 760;
                final fieldWidth = isWide
                    ? (constraints.maxWidth - 12) / 2
                    : constraints.maxWidth;

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: fieldWidth,
                      child: _ReportDropdownFilter(
                        label: 'Professor',
                        value: selectedTeacher,
                        items: teacherOptions,
                        onChanged: onSelectTeacher,
                      ),
                    ),
                    SizedBox(
                      width: fieldWidth,
                      child: _ReportDropdownFilter(
                        label: 'Recurso',
                        value: selectedResource,
                        items: resourceOptions,
                        onChanged: onSelectResource,
                      ),
                    ),
                    SizedBox(
                      width: fieldWidth,
                      child: _ReportDropdownFilter(
                        label: 'Turma',
                        value: selectedClassGroup,
                        items: classGroupOptions,
                        onChanged: onSelectClassGroup,
                      ),
                    ),
                    SizedBox(
                      width: fieldWidth,
                      child: _ReportDropdownFilter(
                        label: 'Status',
                        value: selectedStatus,
                        items: statusOptions,
                        itemLabelBuilder: _statusLabel,
                        onChanged: onSelectStatus,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _shortDate(DateTime date) {
    return AppFormatters.formatShortDate(date);
  }

  String _statusLabel(String value) {
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
}

class _PeriodChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class _ReportDropdownFilter extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final String Function(String value)? itemLabelBuilder;

  const _ReportDropdownFilter({
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
        DropdownMenuItem<String>(value: null, child: Text('Todos')),
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

class _ReportsInsightsCard extends StatelessWidget {
  final String periodLabel;
  final double cancellationRate;
  final double averageLessonsPerBooking;
  final String busiestWeekdayLabel;

  const _ReportsInsightsCard({
    required this.periodLabel,
    required this.cancellationRate,
    required this.averageLessonsPerBooking,
    required this.busiestWeekdayLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Leituras rápidas',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Resumo do período $periodLabel.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _InsightPill(
                icon: Icons.event_repeat_outlined,
                label: 'Média de aulas por reserva',
                value: averageLessonsPerBooking.toStringAsFixed(1),
              ),
              _InsightPill(
                icon: Icons.trending_down_outlined,
                label: 'Taxa de cancelamento',
                value: '${cancellationRate.toStringAsFixed(1)}%',
              ),
              _InsightPill(
                icon: Icons.calendar_view_week_outlined,
                label: 'Dia mais movimentado',
                value: busiestWeekdayLabel,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReportsCoverageCard extends StatelessWidget {
  final int filteredCount;
  final int totalCount;
  final String periodLabel;
  final int activeFilterCount;

  const _ReportsCoverageCard({
    required this.filteredCount,
    required this.totalCount,
    required this.periodLabel,
    required this.activeFilterCount,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasFilter = filteredCount != totalCount || activeFilterCount > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.filter_alt_outlined, color: colorScheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasFilter
                      ? 'Exibindo $filteredCount de $totalCount reservas'
                      : 'Exibindo todas as $totalCount reservas',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  activeFilterCount > 0
                      ? 'Período: $periodLabel. Filtros detalhados ativos: $activeFilterCount.'
                      : 'Período analisado: $periodLabel.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InsightPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      constraints: const BoxConstraints(minWidth: 220),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportsRankingCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<_RankingEntry> entries;
  final String emptyLabel;

  const _ReportsRankingCard({
    required this.title,
    required this.icon,
    required this.entries,
    required this.emptyLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (entries.isEmpty)
            Text(
              emptyLabel,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            )
          else
            ...entries.asMap().entries.map((entry) {
              return _RankingRow(
                position: entry.key + 1,
                label: entry.value.label,
                value: entry.value.value,
              );
            }),
        ],
      ),
    );
  }
}

class _ReportsDetailedListCard extends StatelessWidget {
  final List<BookingAdminModel> bookings;
  final int totalCount;
  final bool hasMorePages;
  final bool isLoadingMore;
  final Object resetKey;
  final Future<void> Function() onLoadMore;

  const _ReportsDetailedListCard({
    required this.bookings,
    required this.totalCount,
    required this.hasMorePages,
    required this.isLoadingMore,
    required this.resetKey,
    required this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reservas detalhadas',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          'Lista completa do recorte atual para conferência e auditoria.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 14),
        AdminPaginatedList<BookingAdminModel>(
          items: bookings,
          resetKey: resetKey,
          summaryLabel: 'reservas',
          pageSize: 15,
          totalCount: totalCount,
          hasMoreExternal: hasMorePages,
          isLoadingMore: isLoadingMore,
          onLoadMore: onLoadMore,
          itemBuilder: (context, booking) {
            final isScheduled = booking.status == 'scheduled';
            final isCompleted = booking.status == 'completed';
            final accentColor = isScheduled
                ? const Color(0xFF1D7A6D)
                : isCompleted
                ? const Color(0xFF315FA8)
                : const Color(0xFFB54747);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
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
                  label: _statusLabel(booking.status),
                  accentColor: accentColor,
                ),
                details: [
                  _ReportDetailLine(
                    label: 'Data',
                    value: _formatDisplayDate(booking.bookingDate),
                  ),
                  _ReportDetailLine(
                    label: 'Turma',
                    value: booking.classGroupName,
                  ),
                  _ReportDetailLine(
                    label: 'Disciplina',
                    value: booking.subjectName,
                  ),
                  _ReportDetailLine(
                    label: 'Aulas',
                    value: _formatLessons(booking.lessons),
                  ),
                  _ReportDetailLine(
                    label: 'Finalidade',
                    value: booking.purpose.isEmpty
                        ? 'Nao informada'
                        : booking.purpose,
                  ),
                  if ((booking.completedAt ?? '').isNotEmpty)
                    _ReportDetailLine(
                      label: 'Finalizado em',
                      value: booking.completedAt!,
                    ),
                  if ((booking.completedByName ?? '').isNotEmpty)
                    _ReportDetailLine(
                      label: 'Finalizado por',
                      value: booking.completedByName!,
                    ),
                  if ((booking.cancelledAt ?? '').isNotEmpty)
                    _ReportDetailLine(
                      label: 'Cancelado em',
                      value: booking.cancelledAt!,
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ReportDetailLine extends StatelessWidget {
  final String label;
  final String value;

  const _ReportDetailLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _RankingRow extends StatelessWidget {
  final int position;
  final String label;
  final int value;

  const _RankingRow({
    required this.position,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$position',
              style: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$value',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _RankingEntry {
  final String label;
  final int value;

  const _RankingEntry({required this.label, required this.value});
}

String _statusLabel(String value) {
  switch (value) {
    case 'scheduled':
      return 'Agendado';
    case 'completed':
      return 'Finalizado';
    case 'cancelled':
      return 'Cancelado';
    default:
      return value.isEmpty ? 'Nao informado' : value;
  }
}

String _formatDisplayDate(String value) {
  return AppFormatters.formatDateString(value);
}

String _formatLessons(List<BookingLessonModel> lessons) {
  if (lessons.isEmpty) return 'Sem aulas';
  return lessons.map((lesson) => lesson.label).join(', ');
}
