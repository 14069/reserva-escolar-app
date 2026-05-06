import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:provider/provider.dart';

import '../models/booking_admin_model.dart';
import '../providers/app_preferences_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/reports_admin_provider.dart';
import '../services/csv_export_service.dart';
import '../services/pdf_export_service.dart';
import '../utils/app_formatters.dart';
import '../widgets/admin_ui.dart';

class ReportsAdminScreen extends StatelessWidget {
  const ReportsAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthProvider>().user!;
    final preferences = context.read<AppPreferencesProvider>();
    return ChangeNotifierProvider(
      create: (_) => ReportsAdminProvider(
        schoolId: user.schoolId,
        preferences: preferences,
      )..initialize(),
      child: _ReportsAdminView(schoolName: user.schoolName),
    );
  }
}

class _ReportsAdminView extends StatefulWidget {
  final String schoolName;
  const _ReportsAdminView({required this.schoolName});

  @override
  State<_ReportsAdminView> createState() => _ReportsAdminViewState();
}

class _ReportsAdminViewState extends State<_ReportsAdminView> {
  final ScrollController _scrollController = ScrollController();

  static const List<double> _exportColumnFlexes = [
    1.0, 1.0, 1.4, 1.4, 1.3, 1.3, 2.0, 1.5, 0.8, 1.3, 1.3, 1.2,
  ];

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickCustomRange() async {
    final vm = context.read<ReportsAdminProvider>();
    final now = DateUtils.dateOnly(DateTime.now());
    final initialRange = vm.customRange ??
        DateTimeRange(
          start: now.subtract(const Duration(days: 29)),
          end: now,
        );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
      initialDateRange: initialRange,
    );

    if (picked != null && mounted) {
      vm.setCustomRange(picked);
    }
  }

  Future<void> _exportCsv() async {
    final vm = context.read<ReportsAdminProvider>();
    try {
      final allRows = await vm.loadAllForExport();
      final result = await CsvExportService.exportRows(
        filePrefix: 'relatorios_agendamentos',
        title: 'Relatório de agendamentos',
        subject: 'Relatório de agendamentos',
        shareText: 'Exportação CSV do relatório filtrado de agendamentos.',
        subtitle: 'Período: ${vm.rangeLabel}',
        contextLines: _buildContextLines(vm, allRows),
        summaryRows: _buildSummaryStats(vm, allRows)
            .map((s) => [s.label, s.value])
            .toList(growable: false),
        headers: _exportHeaders,
        rows: _exportRows(allRows),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível exportar o relatório agora.'),
        ),
      );
    }
  }

  Future<void> _exportPdf() async {
    final vm = context.read<ReportsAdminProvider>();
    try {
      final allRows = await vm.loadAllForExport();
      final result = await PdfExportService.exportTable(
        filePrefix: 'relatorios_agendamentos',
        title: 'Relatório de agendamentos',
        subject: 'Relatório de agendamentos',
        shareText: 'Exportação PDF do relatório filtrado de agendamentos.',
        subtitle: 'Período: ${vm.rangeLabel}',
        contextLines: _buildContextLines(vm, allRows),
        summaryStats: _buildSummaryStats(vm, allRows),
        columnFlexes: _exportColumnFlexes,
        footerNote:
            'Relatório administrativo da escola com filtros aplicados no momento da exportação.',
        headers: _exportHeaders,
        rows: _exportRows(allRows),
        landscape: true,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível exportar o relatório agora.'),
        ),
      );
    }
  }

  static const List<String> _exportHeaders = [
    'Data', 'Status', 'Professor', 'Recurso', 'Turma', 'Disciplina',
    'Finalidade', 'Aulas', 'Quantidade de aulas', 'Finalizado em',
    'Finalizado por', 'Cancelado em',
  ];

  List<List<Object?>> _exportRows(List<BookingAdminModel> bookings) {
    return bookings.map((b) => [
      AppFormatters.formatDateString(b.bookingDate),
      _statusLabel(b.status),
      _val(b.userName),
      _val(b.resourceName),
      _val(b.classGroupName),
      _val(b.subjectName),
      _val(b.purpose, emptyFallback: 'Nao informada'),
      b.lessons.map((l) => l.label).join(', '),
      b.lessons.length,
      AppFormatters.formatDateTimeString(b.completedAt ?? '', emptyFallback: '—'),
      _val(b.completedByName),
      AppFormatters.formatDateTimeString(b.cancelledAt ?? '', emptyFallback: '—'),
    ]).toList();
  }

  List<String> _buildContextLines(
    ReportsAdminProvider vm,
    List<BookingAdminModel> bookings,
  ) {
    final lines = <String>[
      'Período: ${vm.rangeLabel}',
      'Reservas exportadas: ${bookings.length}',
    ];
    if (vm.selectedTeacher != null) lines.add('Professor: ${vm.selectedTeacher}');
    if (vm.selectedResource != null) lines.add('Recurso: ${vm.selectedResource}');
    if (vm.selectedClassGroup != null) lines.add('Turma: ${vm.selectedClassGroup}');
    if (vm.selectedStatus != null) lines.add('Status: ${_statusLabel(vm.selectedStatus!)}');
    if (lines.length == 2) lines.add('Escopo: histórico completo da escola');
    return lines;
  }

  List<PdfExportSummaryStat> _buildSummaryStats(
    ReportsAdminProvider vm,
    List<BookingAdminModel> bookings,
  ) {
    return [
      PdfExportSummaryStat(label: 'Reservas no arquivo', value: bookings.length.toString()),
      PdfExportSummaryStat(
        label: 'Agendadas',
        value: vm.scheduledCount.toString(),
        accentColor: const PdfColor.fromInt(0xFF1D7A6D),
      ),
      PdfExportSummaryStat(
        label: 'Finalizadas',
        value: vm.completedCount.toString(),
        accentColor: const PdfColor.fromInt(0xFF315FA8),
      ),
      PdfExportSummaryStat(
        label: 'Canceladas',
        value: vm.cancelledCount.toString(),
        accentColor: const PdfColor.fromInt(0xFFB54747),
      ),
      PdfExportSummaryStat(
        label: 'Aulas reservadas',
        value: vm.totalReservedLessons.toString(),
        accentColor: const PdfColor.fromInt(0xFF0B7285),
      ),
      PdfExportSummaryStat(
        label: 'Taxa de cancelamento',
        value: '${vm.cancellationRate.toStringAsFixed(1)}%',
        accentColor: const PdfColor.fromInt(0xFF8A6A10),
      ),
    ];
  }

  List<AdminActiveFilterItem> _buildActiveFilterItems(ReportsAdminProvider vm) {
    final items = <AdminActiveFilterItem>[];

    if (vm.selectedPeriod != ReportPeriod.all) {
      items.add(AdminActiveFilterItem(
        label: 'Período: ${vm.rangeLabel}',
        onRemove: () {
          final v = context.read<ReportsAdminProvider>();
          v.selectPeriod(ReportPeriod.all);
        },
      ));
    }

    if (vm.selectedTeacher != null) {
      items.add(AdminActiveFilterItem(
        label: 'Professor: ${vm.selectedTeacher}',
        onRemove: () => context.read<ReportsAdminProvider>().setTeacher(null),
      ));
    }

    if (vm.selectedResource != null) {
      items.add(AdminActiveFilterItem(
        label: 'Recurso: ${vm.selectedResource}',
        onRemove: () => context.read<ReportsAdminProvider>().setResource(null),
      ));
    }

    if (vm.selectedClassGroup != null) {
      items.add(AdminActiveFilterItem(
        label: 'Turma: ${vm.selectedClassGroup}',
        onRemove: () => context.read<ReportsAdminProvider>().setClassGroup(null),
      ));
    }

    if (vm.selectedStatus != null) {
      items.add(AdminActiveFilterItem(
        label: 'Status: ${_statusLabel(vm.selectedStatus!)}',
        onRemove: () => context.read<ReportsAdminProvider>().setStatus(null),
      ));
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ReportsAdminProvider>();
    final isCompact = MediaQuery.of(context).size.width < 380;
    final showBlockingLoader = vm.isLoading && vm.detailedBookings.isEmpty;
    final activeFilterItems = _buildActiveFilterItems(vm);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isCompact ? 'Relatórios' : 'Relatórios - ${widget.schoolName}',
        ),
        actions: [
          AdminExportMenuButton(
            onExportCsv: _exportCsv,
            onExportPdf: _exportPdf,
          ),
        ],
      ),
      body: showBlockingLoader
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: vm.loadReport,
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
                    if (vm.isLoading) const AdminInlineLoadingIndicator(),
                    const AdminHeaderCard(
                      title: 'Relatórios administrativos',
                      subtitle:
                          'Analise reservas, identifique picos de uso e acompanhe o comportamento da escola por período.',
                      icon: Icons.bar_chart_rounded,
                    ),
                    const SizedBox(height: 16),
                    _ReportsFilterCard(
                      selectedPeriod: vm.selectedPeriod,
                      customRange: vm.customRange,
                      selectedTeacher: vm.selectedTeacher,
                      selectedResource: vm.selectedResource,
                      selectedClassGroup: vm.selectedClassGroup,
                      selectedStatus: vm.selectedStatus,
                      teacherOptions: vm.teacherOptions,
                      resourceOptions: vm.resourceOptions,
                      classGroupOptions: vm.classGroupOptions,
                      statusOptions: vm.statusOptions,
                      activeFilterCount: vm.activeFilterCount,
                      onSelectPeriod: (period) {
                        if (period == ReportPeriod.custom) {
                          _pickCustomRange();
                          return;
                        }
                        context.read<ReportsAdminProvider>().selectPeriod(period);
                      },
                      onPickCustomRange: _pickCustomRange,
                      onSelectTeacher: (v) =>
                          context.read<ReportsAdminProvider>().setTeacher(v),
                      onSelectResource: (v) =>
                          context.read<ReportsAdminProvider>().setResource(v),
                      onSelectClassGroup: (v) =>
                          context.read<ReportsAdminProvider>().setClassGroup(v),
                      onSelectStatus: (v) =>
                          context.read<ReportsAdminProvider>().setStatus(v),
                      onClearAdvancedFilters: () =>
                          context.read<ReportsAdminProvider>().clearAdvancedFilters(),
                    ),
                    const SizedBox(height: 16),
                    if (activeFilterItems.isNotEmpty) ...[
                      AdminActiveFiltersWrap(items: activeFilterItems),
                      const SizedBox(height: 16),
                    ],
                    if (vm.loadError != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: AdminEmptyState(
                          icon: Icons.error_outline,
                          title: 'Não foi possível gerar os relatórios.',
                          message: vm.loadError!,
                        ),
                      ),
                    if (vm.totalBookingsCount == 0)
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
                            value: vm.totalBookingsCount.toString(),
                            icon: Icons.assignment_outlined,
                            accentColor: const Color(0xFF0F766E),
                          ),
                          AdminStatCard(
                            label: 'Agendadas',
                            value: vm.scheduledCount.toString(),
                            icon: Icons.check_circle_outline,
                            accentColor: const Color(0xFF1D7A6D),
                          ),
                          AdminStatCard(
                            label: 'Finalizadas',
                            value: vm.completedCount.toString(),
                            icon: Icons.task_alt_outlined,
                            accentColor: const Color(0xFF315FA8),
                          ),
                          AdminStatCard(
                            label: 'Canceladas',
                            value: vm.cancelledCount.toString(),
                            icon: Icons.cancel_outlined,
                            accentColor: const Color(0xFFB54747),
                          ),
                          AdminStatCard(
                            label: 'Recursos usados',
                            value: vm.uniqueResourcesCount.toString(),
                            icon: Icons.meeting_room_outlined,
                            accentColor: const Color(0xFF315FA8),
                          ),
                          AdminStatCard(
                            label: 'Professores ativos',
                            value: vm.uniqueTeachersCount.toString(),
                            icon: Icons.people_alt_outlined,
                            accentColor: const Color(0xFF8A6A10),
                          ),
                          AdminStatCard(
                            label: 'Turmas atendidas',
                            value: vm.uniqueClassGroupsCount.toString(),
                            icon: Icons.groups_2_outlined,
                            accentColor: const Color(0xFF7A4A9E),
                          ),
                          AdminStatCard(
                            label: 'Disciplinas',
                            value: vm.uniqueSubjectsCount.toString(),
                            icon: Icons.menu_book_outlined,
                            accentColor: const Color(0xFFAA5F2C),
                          ),
                          AdminStatCard(
                            label: 'Aulas reservadas',
                            value: vm.totalReservedLessons.toString(),
                            icon: Icons.schedule_outlined,
                            accentColor: const Color(0xFF0B7285),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _ReportsCoverageCard(
                        filteredCount: vm.totalBookingsCount,
                        totalCount: vm.overallBookingsCount,
                        periodLabel: vm.rangeLabel,
                        activeFilterCount: vm.activeFilterCount,
                      ),
                      const SizedBox(height: 16),
                      _ReportsInsightsCard(
                        periodLabel: vm.rangeLabel,
                        cancellationRate: vm.cancellationRate,
                        averageLessonsPerBooking: vm.averageLessonsPerBooking,
                        busiestWeekdayLabel: vm.busiestWeekdayLabel,
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
                                  entries: vm.resourceRanking,
                                  emptyLabel: 'Sem recursos para listar.',
                                ),
                              ),
                              SizedBox(
                                width: cardWidth,
                                child: _ReportsRankingCard(
                                  title: 'Professores com mais reservas',
                                  icon: Icons.person_outline_rounded,
                                  entries: vm.teacherRanking,
                                  emptyLabel: 'Sem professores para listar.',
                                ),
                              ),
                              SizedBox(
                                width: cardWidth,
                                child: _ReportsRankingCard(
                                  title: 'Turmas com mais reservas',
                                  icon: Icons.groups_outlined,
                                  entries: vm.classGroupRanking,
                                  emptyLabel: 'Sem turmas para listar.',
                                ),
                              ),
                              SizedBox(
                                width: cardWidth,
                                child: _ReportsRankingCard(
                                  title: 'Disciplinas mais agendadas',
                                  icon: Icons.menu_book_outlined,
                                  entries: vm.subjectRanking,
                                  emptyLabel: 'Sem disciplinas para listar.',
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      _ReportsDetailedListCard(
                        bookings: vm.detailedBookings,
                        totalCount: vm.totalBookingsCount,
                        hasMorePages: vm.hasMorePages,
                        isLoadingMore: vm.isLoadingMore,
                        resetKey: Object.hash(
                          vm.selectedPeriod,
                          vm.customRange?.start.millisecondsSinceEpoch,
                          vm.customRange?.end.millisecondsSinceEpoch,
                          vm.selectedTeacher,
                          vm.selectedResource,
                          vm.selectedClassGroup,
                          vm.selectedStatus,
                        ),
                        onLoadMore: () => vm.loadReport(loadMore: true),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  static String _statusLabel(String value) {
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

  static String _val(String? raw, {String emptyFallback = '—'}) {
    final trimmed = raw?.trim() ?? '';
    return trimmed.isEmpty ? emptyFallback : trimmed;
  }
}

// ── sub-widgets ──────────────────────────────────────────────────────────────

class _ReportsFilterCard extends StatelessWidget {
  final ReportPeriod selectedPeriod;
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
  final ValueChanged<ReportPeriod> onSelectPeriod;
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
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
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
                  selected: selectedPeriod == ReportPeriod.last7Days,
                  onTap: () => onSelectPeriod(ReportPeriod.last7Days),
                ),
                _PeriodChip(
                  label: '30 dias',
                  selected: selectedPeriod == ReportPeriod.last30Days,
                  onTap: () => onSelectPeriod(ReportPeriod.last30Days),
                ),
                _PeriodChip(
                  label: 'Este mês',
                  selected: selectedPeriod == ReportPeriod.thisMonth,
                  onTap: () => onSelectPeriod(ReportPeriod.thisMonth),
                ),
                _PeriodChip(
                  label: customRange == null
                      ? 'Personalizado'
                      : 'Personalizado: ${AppFormatters.formatShortDate(customRange!.start)} - ${AppFormatters.formatShortDate(customRange!.end)}',
                  selected: selectedPeriod == ReportPeriod.custom,
                  onTap: onPickCustomRange,
                ),
                _PeriodChip(
                  label: 'Histórico',
                  selected: selectedPeriod == ReportPeriod.all,
                  onTap: () => onSelectPeriod(ReportPeriod.all),
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

  static String _statusLabel(String value) {
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
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
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
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
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
  final List<RankingEntry> entries;
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
            ...entries.asMap().entries.map((e) {
              return _RankingRow(
                position: e.key + 1,
                label: e.value.label,
                value: e.value.value,
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
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
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
                    value: AppFormatters.formatDateString(booking.bookingDate),
                  ),
                  _ReportDetailLine(label: 'Turma', value: booking.classGroupName),
                  _ReportDetailLine(label: 'Disciplina', value: booking.subjectName),
                  _ReportDetailLine(
                    label: 'Aulas',
                    value: booking.lessons.isEmpty
                        ? 'Sem aulas'
                        : booking.lessons.map((l) => l.label).join(', '),
                  ),
                  _ReportDetailLine(
                    label: 'Finalidade',
                    value: booking.purpose.isEmpty ? 'Nao informada' : booking.purpose,
                  ),
                  if ((booking.completedAt ?? '').isNotEmpty)
                    _ReportDetailLine(
                      label: 'Finalizado em',
                      value: AppFormatters.formatDateTimeString(
                        booking.completedAt!,
                        emptyFallback: booking.completedAt!,
                      ),
                    ),
                  if ((booking.completedByName ?? '').isNotEmpty)
                    _ReportDetailLine(
                      label: 'Finalizado por',
                      value: booking.completedByName!,
                    ),
                  if ((booking.cancelledAt ?? '').isNotEmpty)
                    _ReportDetailLine(
                      label: 'Cancelado em',
                      value: AppFormatters.formatDateTimeString(
                        booking.cancelledAt!,
                        emptyFallback: booking.cancelledAt!,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  static String _statusLabel(String value) {
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
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
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
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$value',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
