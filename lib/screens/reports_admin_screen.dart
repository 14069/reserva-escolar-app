import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';

import '../models/booking_admin_model.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/admin_ui.dart';

class ReportsAdminScreen extends StatefulWidget {
  const ReportsAdminScreen({super.key});

  @override
  State<ReportsAdminScreen> createState() => _ReportsAdminScreenState();
}

class _ReportsAdminScreenState extends State<ReportsAdminScreen> {
  final Logger _logger = Logger();

  bool isLoading = true;
  String? loadError;
  List<BookingAdminModel> allBookings = [];
  _ReportPeriod selectedPeriod = _ReportPeriod.all;
  DateTimeRange? customRange;
  String? selectedTeacher;
  String? selectedResource;
  String? selectedClassGroup;
  String? selectedStatus;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  List<BookingAdminModel> get periodFilteredBookings {
    if (selectedPeriod == _ReportPeriod.all) return allBookings;

    final range = _resolveRange();
    if (range == null) return allBookings;

    final start = DateUtils.dateOnly(range.start);
    final end = DateUtils.dateOnly(range.end);

    return allBookings.where((booking) {
      final bookingDate = DateTime.tryParse(booking.bookingDate);
      if (bookingDate == null) return false;

      final normalized = DateUtils.dateOnly(bookingDate);
      final isAfterStart =
          normalized.isAtSameMomentAs(start) || normalized.isAfter(start);
      final isBeforeEnd =
          normalized.isAtSameMomentAs(end) || normalized.isBefore(end);
      return isAfterStart && isBeforeEnd;
    }).toList();
  }

  List<BookingAdminModel> get filteredBookings {
    return periodFilteredBookings.where((booking) {
      final matchesTeacher =
          selectedTeacher == null || booking.userName == selectedTeacher;
      final matchesResource =
          selectedResource == null || booking.resourceName == selectedResource;
      final matchesClassGroup =
          selectedClassGroup == null ||
          booking.classGroupName == selectedClassGroup;
      final matchesStatus =
          selectedStatus == null || booking.status == selectedStatus;

      return matchesTeacher &&
          matchesResource &&
          matchesClassGroup &&
          matchesStatus;
    }).toList();
  }

  List<String> get teacherOptions {
    return _sortedOptions(
      periodFilteredBookings.map((booking) => booking.userName),
    );
  }

  List<String> get resourceOptions {
    return _sortedOptions(
      periodFilteredBookings.map((booking) => booking.resourceName),
    );
  }

  List<String> get classGroupOptions {
    return _sortedOptions(
      periodFilteredBookings.map((booking) => booking.classGroupName),
    );
  }

  List<String> get statusOptions {
    return _sortedOptions(
      periodFilteredBookings.map((booking) => booking.status),
    );
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

  int get scheduledCount {
    return filteredBookings
        .where((booking) => booking.status == 'scheduled')
        .length;
  }

  int get cancelledCount {
    return filteredBookings.length - scheduledCount;
  }

  int get uniqueTeachersCount {
    return filteredBookings.map((booking) => booking.userName).toSet().length;
  }

  int get uniqueResourcesCount {
    return filteredBookings
        .map((booking) => booking.resourceName)
        .toSet()
        .length;
  }

  int get uniqueClassGroupsCount {
    return filteredBookings
        .map((booking) => booking.classGroupName)
        .toSet()
        .length;
  }

  int get uniqueSubjectsCount {
    return filteredBookings
        .map((booking) => booking.subjectName)
        .toSet()
        .length;
  }

  int get totalReservedLessons {
    return filteredBookings.fold<int>(
      0,
      (sum, booking) => sum + booking.lessons.length,
    );
  }

  double get cancellationRate {
    if (filteredBookings.isEmpty) return 0;
    return (cancelledCount / filteredBookings.length) * 100;
  }

  double get averageLessonsPerBooking {
    if (filteredBookings.isEmpty) return 0;

    final totalLessons = filteredBookings.fold<int>(
      0,
      (sum, booking) => sum + booking.lessons.length,
    );
    return totalLessons / filteredBookings.length;
  }

  String get busiestWeekdayLabel {
    if (filteredBookings.isEmpty) return 'Sem dados';

    final weekdayCounter = <int, int>{};
    for (final booking in filteredBookings) {
      final date = DateTime.tryParse(booking.bookingDate);
      if (date == null) continue;
      weekdayCounter.update(
        date.weekday,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }

    if (weekdayCounter.isEmpty) return 'Sem dados';

    final busiest = weekdayCounter.entries.reduce(
      (current, next) => next.value > current.value ? next : current,
    );
    return _weekdayLabel(busiest.key);
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

  Future<void> _loadBookings() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.user;
    if (user == null) return;

    setState(() {
      isLoading = true;
      loadError = null;
    });

    try {
      final response = await ApiService.getAllBookings(schoolId: user.schoolId);

      if (response['success'] == true) {
        final data = response['data'] as List<dynamic>? ?? const [];
        allBookings = data
            .map((item) => BookingAdminModel.fromJson(item))
            .toList();
        _normalizeAdvancedFilters();
      } else {
        loadError =
            response['message']?.toString() ??
            'Não foi possível carregar os relatórios.';
      }
    } catch (error) {
      _logger.e('ERRO AO CARREGAR RELATORIOS ADMIN V2: $error');
      loadError = 'Não foi possível carregar os relatórios.';
    }

    if (!mounted) return;

    setState(() {
      isLoading = false;
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
      _normalizeAdvancedFilters();
    });
  }

  void _clearAdvancedFilters() {
    setState(() {
      selectedTeacher = null;
      selectedResource = null;
      selectedClassGroup = null;
      selectedStatus = null;
    });
  }

  void _normalizeAdvancedFilters() {
    if (selectedTeacher != null && !teacherOptions.contains(selectedTeacher)) {
      selectedTeacher = null;
    }
    if (selectedResource != null &&
        !resourceOptions.contains(selectedResource)) {
      selectedResource = null;
    }
    if (selectedClassGroup != null &&
        !classGroupOptions.contains(selectedClassGroup)) {
      selectedClassGroup = null;
    }
    if (selectedStatus != null && !statusOptions.contains(selectedStatus)) {
      selectedStatus = null;
    }
  }

  List<_RankingEntry> _buildRanking(
    String Function(BookingAdminModel booking) labelSelector,
  ) {
    final counter = <String, int>{};

    for (final booking in filteredBookings) {
      final key = labelSelector(booking).trim();
      if (key.isEmpty) continue;
      counter.update(key, (count) => count + 1, ifAbsent: () => 1);
    }

    final ranking =
        counter.entries
            .map((entry) => _RankingEntry(label: entry.key, value: entry.value))
            .toList()
          ..sort((a, b) {
            final valueComparison = b.value.compareTo(a.value);
            if (valueComparison != 0) return valueComparison;
            return a.label.compareTo(b.label);
          });

    return ranking.take(5).toList();
  }

  String _formatRangeLabel() {
    final range = _resolveRange();
    if (range == null) return 'Todo o histórico';
    return '${_formatDate(range.start)} a ${_formatDate(range.end)}';
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString().padLeft(4, '0');
    return '$day/$month/$year';
  }

  List<String> _sortedOptions(Iterable<String> values) {
    final options =
        values
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return options;
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user!;
    final isCompact = MediaQuery.of(context).size.width < 380;
    final teacherRanking = _buildRanking((booking) => booking.userName);
    final resourceRanking = _buildRanking((booking) => booking.resourceName);
    final subjectRanking = _buildRanking((booking) => booking.subjectName);
    final classGroupRanking = _buildRanking(
      (booking) => booking.classGroupName,
    );
    final recentBookings = [...filteredBookings]
      ..sort((a, b) => b.bookingDate.compareTo(a.bookingDate));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isCompact ? 'Relatórios' : 'Relatórios - ${user.schoolName}',
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadBookings,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  isCompact ? 14 : 16,
                  8,
                  isCompact ? 14 : 16,
                  24,
                ),
                children: [
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
                        _normalizeAdvancedFilters();
                      });
                    },
                    onPickCustomRange: _pickCustomRange,
                    onSelectTeacher: (value) {
                      setState(() {
                        selectedTeacher = value;
                      });
                    },
                    onSelectResource: (value) {
                      setState(() {
                        selectedResource = value;
                      });
                    },
                    onSelectClassGroup: (value) {
                      setState(() {
                        selectedClassGroup = value;
                      });
                    },
                    onSelectStatus: (value) {
                      setState(() {
                        selectedStatus = value;
                      });
                    },
                    onClearAdvancedFilters: _clearAdvancedFilters,
                  ),
                  const SizedBox(height: 16),
                  if (loadError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: AdminEmptyState(
                        icon: Icons.error_outline,
                        title: 'Não foi possível gerar os relatórios.',
                        message: loadError!,
                      ),
                    ),
                  if (filteredBookings.isEmpty)
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
                          value: filteredBookings.length.toString(),
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
                      filteredCount: filteredBookings.length,
                      totalCount: allBookings.length,
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
                    _ReportsDetailedListCard(bookings: recentBookings),
                  ],
                ],
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
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month';
  }

  String _statusLabel(String value) {
    switch (value) {
      case 'scheduled':
        return 'Agendado';
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

  const _ReportsDetailedListCard({required this.bookings});

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
        ...bookings.map((booking) {
          final isScheduled = booking.status == 'scheduled';
          final accentColor = isScheduled
              ? const Color(0xFF1D7A6D)
              : const Color(0xFFB54747);

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AdminEntityCard(
              icon: isScheduled
                  ? Icons.event_available_outlined
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
                if ((booking.cancelledAt ?? '').isNotEmpty)
                  _ReportDetailLine(
                    label: 'Cancelado em',
                    value: booking.cancelledAt!,
                  ),
              ],
            ),
          );
        }),
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

String _weekdayLabel(int weekday) {
  switch (weekday) {
    case DateTime.monday:
      return 'Segunda-feira';
    case DateTime.tuesday:
      return 'Terça-feira';
    case DateTime.wednesday:
      return 'Quarta-feira';
    case DateTime.thursday:
      return 'Quinta-feira';
    case DateTime.friday:
      return 'Sexta-feira';
    case DateTime.saturday:
      return 'Sábado';
    case DateTime.sunday:
      return 'Domingo';
    default:
      return 'Não informado';
  }
}

String _statusLabel(String value) {
  switch (value) {
    case 'scheduled':
      return 'Agendado';
    case 'cancelled':
      return 'Cancelado';
    default:
      return value.isEmpty ? 'Nao informado' : value;
  }
}

String _formatDisplayDate(String value) {
  final parts = value.split('-');
  if (parts.length != 3) return value;
  return '${parts[2]}/${parts[1]}/${parts[0]}';
}

String _formatLessons(List<BookingLessonModel> lessons) {
  if (lessons.isEmpty) return 'Sem aulas';
  return lessons.map((lesson) => lesson.label).join(', ');
}
