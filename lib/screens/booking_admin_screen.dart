import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/booking_admin_model.dart';
import '../providers/app_preferences_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/booking_admin_provider.dart';
import '../services/csv_export_service.dart';
import '../services/pdf_export_service.dart';
import '../utils/app_formatters.dart';
import '../widgets/admin_ui.dart';

class BookingAdminScreen extends StatelessWidget {
  const BookingAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthProvider>().user!;
    final preferences = context.read<AppPreferencesProvider>();
    return ChangeNotifierProvider(
      create: (_) => BookingAdminProvider(
        schoolId: user.schoolId,
        userId: user.id,
        userName: user.name,
        preferences: preferences,
      )..initialize(),
      child: const _BookingAdminView(),
    );
  }
}

class _BookingAdminView extends StatefulWidget {
  const _BookingAdminView();

  @override
  State<_BookingAdminView> createState() => _BookingAdminViewState();
}

class _BookingAdminViewState extends State<_BookingAdminView> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;
  bool _isSyncingSearch = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
  }

  void _handleSearchChanged() {
    if (_isSyncingSearch) return;
    final vm = context.read<BookingAdminProvider>();
    vm.updateSearch(_searchController.text);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      vm.loadBookings();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final vm = context.read<BookingAdminProvider>();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: vm.selectedDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null && mounted) {
      vm.setDate(picked);
    }
  }

  void _clearAllFilters() {
    _isSyncingSearch = true;
    _searchController.clear();
    _isSyncingSearch = false;
    context.read<BookingAdminProvider>().clearAllFilters();
  }

  Future<void> _showCancelDialog(BookingAdminModel booking) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AdminConfirmDialog(
        title: 'Cancelar agendamento',
        message:
            'Deseja cancelar o agendamento de ${booking.resourceName} para ${booking.userName}? Essa ação libera o horário para novas reservas.',
        icon: Icons.cancel_outlined,
        confirmLabel: 'Cancelar reserva',
        cancelLabel: 'Voltar',
      ),
    );

    if (confirm != true || !mounted) return;

    final vm = context.read<BookingAdminProvider>();
    final outcome = await vm.performCancel(booking);

    if (!mounted) return;
    _showActionSnackBar(
      outcome is BookingActionSuccess ? outcome.message : (outcome as BookingActionFailure).message,
      icon: outcome is BookingActionSuccess ? Icons.cancel_outlined : Icons.error_outline,
      isError: outcome is BookingActionFailure,
    );
  }

  Future<void> _showCompleteDialog(BookingAdminModel booking) async {
    final feedback = await showDialog<String>(
      context: context,
      builder: (context) => BookingCompletionDialog(
        title: 'Finalizar agendamento',
        subtitle:
            'Confirme o uso de ${booking.resourceName} por ${booking.userName} e registre, se necessário, o estado do recurso.',
        confirmLabel: 'Marcar como finalizado',
        cancelLabel: 'Voltar',
      ),
    );

    if (feedback == null || !mounted) return;

    final vm = context.read<BookingAdminProvider>();
    final outcome = await vm.performComplete(booking, feedback: feedback);

    if (!mounted) return;
    _showActionSnackBar(
      outcome is BookingActionSuccess ? outcome.message : (outcome as BookingActionFailure).message,
      icon: outcome is BookingActionSuccess ? Icons.task_alt_outlined : Icons.error_outline,
      isError: outcome is BookingActionFailure,
    );
  }

  void _showActionSnackBar(
    String message, {
    required IconData icon,
    bool isError = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? colorScheme.error : const Color(0xFF1D7A6D),
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

  List<List<Object?>> _bookingExportRows(List<BookingAdminModel> bookings) {
    return bookings
        .map((b) => [
              AppFormatters.formatDateString(b.bookingDate),
              _statusLabel(b.status),
              b.userName,
              b.resourceName,
              b.classGroupName,
              b.subjectName,
              b.purpose,
              b.lessons.map((l) => l.label).join(', '),
              b.lessons.length,
              b.completedAt ?? '',
              b.completedByName ?? '',
              b.cancelledAt ?? '',
            ])
        .toList();
  }

  Future<void> _exportCsv(List<BookingAdminModel> bookings) async {
    final result = await CsvExportService.exportRows(
      filePrefix: 'agendamentos_admin',
      title: 'Agendamentos administrativos',
      subject: 'Agendamentos administrativos',
      shareText: 'Exportação CSV dos agendamentos administrativos.',
      headers: _exportHeaders,
      rows: _bookingExportRows(bookings),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );
  }

  Future<void> _exportPdf(List<BookingAdminModel> bookings) async {
    final result = await PdfExportService.exportTable(
      filePrefix: 'agendamentos_admin',
      title: 'Agendamentos administrativos',
      subject: 'Agendamentos administrativos',
      shareText: 'Exportação PDF dos agendamentos administrativos.',
      headers: _exportHeaders,
      rows: _bookingExportRows(bookings),
      landscape: true,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );
  }

  static const List<String> _exportHeaders = [
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
  ];

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

  static String _sortLabel(String value) {
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

  Widget? _buildRecentActionBadge(String? recentAction) {
    if (recentAction == null) return null;
    final isCompleted = recentAction == 'completed';
    final bg = isCompleted ? const Color(0xFFE3F6EE) : const Color(0xFFFDE8E8);
    final fg = isCompleted ? const Color(0xFF166A5C) : const Color(0xFF9F2F2F);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      opacity: 1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: fg.withValues(alpha: 0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isCompleted ? Icons.task_alt_outlined : Icons.cancel_outlined,
              size: 14,
              color: fg,
            ),
            const SizedBox(width: 6),
            Text(
              isCompleted ? 'Finalizado agora' : 'Cancelado agora',
              style: TextStyle(
                color: fg,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<AdminActiveFilterItem> _buildActiveFilterItems(
    BuildContext context,
    BookingAdminProvider vm,
  ) {
    final items = <AdminActiveFilterItem>[];

    if (vm.selectedDate != null) {
      items.add(AdminActiveFilterItem(
        label:
            'Data: ${AppFormatters.formatDateString(AppFormatters.formatApiDate(vm.selectedDate!))}',
        onRemove: () => context.read<BookingAdminProvider>().clearDate(),
      ));
    }

    if (vm.search.trim().isNotEmpty) {
      items.add(AdminActiveFilterItem(
        label: 'Busca: ${vm.search.trim()}',
        onRemove: () {
          _isSyncingSearch = true;
          _searchController.clear();
          _isSyncingSearch = false;
          final v = context.read<BookingAdminProvider>();
          v.updateSearch('');
          v.loadBookings();
        },
      ));
    }

    if (vm.selectedTeacher != null) {
      items.add(AdminActiveFilterItem(
        label: 'Professor: ${vm.selectedTeacher}',
        onRemove: () => context.read<BookingAdminProvider>().setTeacher(null),
      ));
    }

    if (vm.selectedResource != null) {
      items.add(AdminActiveFilterItem(
        label: 'Recurso: ${vm.selectedResource}',
        onRemove: () => context.read<BookingAdminProvider>().setResource(null),
      ));
    }

    if (vm.selectedClassGroup != null) {
      items.add(AdminActiveFilterItem(
        label: 'Turma: ${vm.selectedClassGroup}',
        onRemove: () => context.read<BookingAdminProvider>().setClassGroup(null),
      ));
    }

    if (vm.selectedStatus != null) {
      items.add(AdminActiveFilterItem(
        label: 'Status: ${_statusLabel(vm.selectedStatus!)}',
        onRemove: () => context.read<BookingAdminProvider>().setStatus(null),
      ));
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<BookingAdminProvider>();
    final isCompact = MediaQuery.of(context).size.width < 380;
    final showBlockingLoader = vm.isLoading && vm.bookings.isEmpty;
    final activeFilterItems = _buildActiveFilterItems(context, vm);

    return Scaffold(
      appBar: AppBar(
        title: Text(isCompact ? 'Agendamentos' : 'Agendamentos'),
        actions: [
          AdminExportMenuButton(
            onExportCsv: () => _exportCsv(vm.bookings),
            onExportPdf: () => _exportPdf(vm.bookings),
          ),
        ],
      ),
      body: showBlockingLoader
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: vm.loadBookings,
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
                      title: 'Painel de agendamentos',
                      subtitle:
                          'Acompanhe reservas da escola, filtre por data e cancele agendamentos quando necessário.',
                      icon: Icons.assignment_outlined,
                    ),
                    const SizedBox(height: 16),
                    AdminStatsPanel(
                      children: [
                        AdminStatCard(
                          label: vm.activeFilterCount > 0 ? 'Exibidos' : 'Total',
                          value: vm.totalBookingsCount.toString(),
                          icon: Icons.assignment_outlined,
                          accentColor: const Color(0xFFB54747),
                        ),
                        AdminStatCard(
                          label: 'Agendados',
                          value: vm.totalScheduledCount.toString(),
                          icon: Icons.check_circle_outline,
                          accentColor: const Color(0xFF1D7A6D),
                        ),
                        AdminStatCard(
                          label: 'Finalizados',
                          value: vm.totalCompletedCount.toString(),
                          icon: Icons.task_alt_outlined,
                          accentColor: const Color(0xFF315FA8),
                        ),
                        AdminStatCard(
                          label: 'Finalizadas hoje',
                          value: vm.totalCompletedTodayCount.toString(),
                          icon: Icons.today_outlined,
                          accentColor: const Color(0xFF8A6A10),
                        ),
                        AdminStatCard(
                          label: 'Cancelados',
                          value: vm.totalCancelledCount.toString(),
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
                                onPressed: _pickDate,
                                icon: const Icon(Icons.calendar_month),
                                label: Text(
                                  vm.selectedDate == null
                                      ? 'Filtrar por data'
                                      : AppFormatters.formatDateString(
                                          AppFormatters.formatApiDate(
                                            vm.selectedDate!,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (vm.selectedDate != null)
                              IconButton(
                                onPressed: vm.clearDate,
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
                                if (vm.activeFilterCount > 0)
                                  TextButton.icon(
                                    onPressed: _clearAllFilters,
                                    icon: const Icon(Icons.filter_alt_off_outlined),
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
                                suffixIcon: vm.search.trim().isEmpty
                                    ? null
                                    : IconButton(
                                        tooltip: 'Limpar busca',
                                        onPressed: () {
                                          _isSyncingSearch = true;
                                          _searchController.clear();
                                          _isSyncingSearch = false;
                                          final v = context.read<BookingAdminProvider>();
                                          v.updateSearch('');
                                          v.loadBookings();
                                        },
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
                                    value: vm.selectedSort,
                                    items: BookingAdminProvider.sortValues,
                                    itemLabelBuilder: _sortLabel,
                                    onChanged: (v) {
                                      if (v != null) {
                                        context.read<BookingAdminProvider>().setSort(v);
                                      }
                                    },
                                  ),
                                ),
                                SizedBox(
                                  width: 260,
                                  child: _BookingDropdownFilter(
                                    label: 'Professor',
                                    value: vm.selectedTeacher,
                                    items: vm.availableTeacherOptions,
                                    onChanged: (v) =>
                                        context.read<BookingAdminProvider>().setTeacher(v),
                                  ),
                                ),
                                SizedBox(
                                  width: 260,
                                  child: _BookingDropdownFilter(
                                    label: 'Recurso',
                                    value: vm.selectedResource,
                                    items: vm.availableResourceOptions,
                                    onChanged: (v) =>
                                        context.read<BookingAdminProvider>().setResource(v),
                                  ),
                                ),
                                SizedBox(
                                  width: 260,
                                  child: _BookingDropdownFilter(
                                    label: 'Turma',
                                    value: vm.selectedClassGroup,
                                    items: vm.availableClassGroupOptions,
                                    onChanged: (v) =>
                                        context.read<BookingAdminProvider>().setClassGroup(v),
                                  ),
                                ),
                                SizedBox(
                                  width: 260,
                                  child: _BookingDropdownFilter(
                                    label: 'Status',
                                    value: vm.selectedStatus,
                                    items: vm.availableStatusOptions,
                                    itemLabelBuilder: _statusLabel,
                                    onChanged: (v) =>
                                        context.read<BookingAdminProvider>().setStatus(v),
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
                    if (vm.totalBookingsCount == 0 && vm.activeFilterCount == 0)
                      if (vm.loadError != null)
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
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 8),
                                Text(vm.loadError!),
                                const SizedBox(height: 14),
                                FilledButton.icon(
                                  onPressed: vm.loadBookings,
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
                    else if (vm.bookings.isEmpty)
                      const AdminEmptyState(
                        icon: Icons.filter_alt_off_outlined,
                        title: 'Nenhum resultado para os filtros aplicados.',
                        message:
                            'Tente limpar alguns filtros ou ajustar a busca para encontrar outros agendamentos.',
                      )
                    else
                      AdminPaginatedList<BookingAdminModel>(
                        items: vm.bookings,
                        resetKey:
                            '${vm.currentPage}|${vm.selectedSort}|${vm.selectedDate?.toIso8601String() ?? ''}|${vm.selectedTeacher ?? ''}|${vm.selectedResource ?? ''}|${vm.selectedClassGroup ?? ''}|${vm.selectedStatus ?? ''}|${vm.search.trim().toLowerCase()}',
                        summaryLabel: 'agendamentos',
                        totalCount: vm.totalBookingsCount,
                        hasMoreExternal: vm.hasMorePages,
                        isLoadingMore: vm.isLoadingMore,
                        onLoadMore: () => vm.loadBookings(loadMore: true),
                        itemBuilder: (context, booking) {
                          final isScheduled = booking.status == 'scheduled';
                          final isCompleted = booking.status == 'completed';
                          final recentAction = vm.recentActionByBookingId[booking.id];
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
                                        color: highlightColor.withValues(alpha: 0.18),
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
                                label: _statusLabel(booking.status),
                                accentColor: accentColor,
                              ),
                              trailing: _buildRecentActionBadge(recentAction),
                              details: [
                                AdminDetailRow(
                                  icon: Icons.calendar_today_outlined,
                                  label: 'Data',
                                  value: AppFormatters.formatDateString(booking.bookingDate),
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
                                  value: booking.lessons.isEmpty
                                      ? 'Sem aulas'
                                      : booking.lessons.map((l) => l.label).join(', '),
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
                                if ((booking.completionFeedback ?? '').isNotEmpty)
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
                                      if (vm.canCompleteBooking(booking))
                                        FilledButton.icon(
                                          onPressed: () => _showCompleteDialog(booking),
                                          icon: const Icon(Icons.task_alt_outlined),
                                          label: const Text('Finalizar'),
                                        ),
                                      OutlinedButton.icon(
                                        onPressed: () => _showCancelDialog(booking),
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
