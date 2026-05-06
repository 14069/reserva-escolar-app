import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/my_booking_model.dart';
import '../providers/app_preferences_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/my_bookings_provider.dart';
import '../services/csv_export_service.dart';
import '../services/pdf_export_service.dart';
import '../utils/app_formatters.dart';
import '../widgets/admin_ui.dart';

class MyBookingsV2Screen extends StatelessWidget {
  const MyBookingsV2Screen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthProvider>().user!;
    final preferences = context.read<AppPreferencesProvider>();
    return ChangeNotifierProvider(
      create: (_) => MyBookingsProvider(
        schoolId: user.schoolId,
        userId: user.id,
        userName: user.name,
        preferences: preferences,
      ),
      child: _MyBookingsView(schoolName: user.schoolName),
    );
  }
}

class _MyBookingsView extends StatefulWidget {
  final String schoolName;
  const _MyBookingsView({required this.schoolName});

  @override
  State<_MyBookingsView> createState() => _MyBookingsViewState();
}

class _MyBookingsViewState extends State<_MyBookingsView> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;
  bool _isSyncingSearch = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final vm = context.read<MyBookingsProvider>();
      await vm.initialize();
      if (!mounted) return;
      _isSyncingSearch = true;
      _searchController.text = vm.search;
      _isSyncingSearch = false;
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    if (_isSyncingSearch) return;
    final vm = context.read<MyBookingsProvider>();
    vm.updateSearch(_searchController.text);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      vm.loadBookings();
    });
  }

  void _clearFilters() {
    _isSyncingSearch = true;
    _searchController.clear();
    _isSyncingSearch = false;
    context.read<MyBookingsProvider>().clearFilters();
  }

  Future<void> _showCancelDialog(MyBookingModel booking) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AdminConfirmDialog(
        title: 'Cancelar agendamento',
        message:
            'Deseja cancelar o agendamento de ${booking.resourceName}? Essa ação libera o horário para novas reservas.',
        icon: Icons.cancel_outlined,
        confirmLabel: 'Cancelar reserva',
        cancelLabel: 'Voltar',
      ),
    );
    if (confirm != true || !mounted) return;

    final outcome =
        await context.read<MyBookingsProvider>().performCancel(booking);
    if (!mounted) return;
    _showActionSnackBar(
      outcome is MyBookingActionSuccess
          ? outcome.message
          : (outcome as MyBookingActionFailure).message,
      icon: outcome is MyBookingActionSuccess
          ? Icons.cancel_outlined
          : Icons.error_outline,
      isError: outcome is MyBookingActionFailure,
    );
  }

  Future<void> _showCompleteDialog(MyBookingModel booking) async {
    final feedback = await showDialog<String>(
      context: context,
      builder: (context) => BookingCompletionDialog(
        title: 'Finalizar agendamento',
        subtitle:
            'Confirme o uso de ${booking.resourceName} e registre, se quiser, como estava o recurso após a aula.',
        confirmLabel: 'Marcar como finalizado',
        cancelLabel: 'Voltar',
      ),
    );
    if (feedback == null || !mounted) return;

    final outcome = await context
        .read<MyBookingsProvider>()
        .performComplete(booking, feedback: feedback);
    if (!mounted) return;
    _showActionSnackBar(
      outcome is MyBookingActionSuccess
          ? outcome.message
          : (outcome as MyBookingActionFailure).message,
      icon: outcome is MyBookingActionSuccess
          ? Icons.task_alt_outlined
          : Icons.error_outline,
      isError: outcome is MyBookingActionFailure,
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

  List<List<Object?>> _buildExportRows(
    List<MyBookingModel> bookings,
  ) {
    return bookings
        .map(
          (booking) => [
            AppFormatters.formatDateString(booking.bookingDate),
            _statusLabel(booking.status),
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

  Future<void> _exportCsv() async {
    final rows =
        _buildExportRows(context.read<MyBookingsProvider>().bookings);
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
      rows: rows,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(result.message)));
  }

  Future<void> _exportPdf() async {
    final rows =
        _buildExportRows(context.read<MyBookingsProvider>().bookings);
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
      rows: rows,
      landscape: true,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(result.message)));
  }

  Widget? _buildRecentActionBadge(String? recentAction) {
    if (recentAction == null) return null;
    final isCompleted = recentAction == 'completed';
    final backgroundColor =
        isCompleted ? const Color(0xFFE3F6EE) : const Color(0xFFFDE8E8);
    final foregroundColor =
        isCompleted ? const Color(0xFF166A5C) : const Color(0xFF9F2F2F);

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

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MyBookingsProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 380;
    final isMobile = screenWidth < 640;
    final showBlockingLoader = vm.isLoading && vm.bookings.isEmpty;

    final activeFilterItems = <AdminActiveFilterItem>[
      if (_searchController.text.trim().isNotEmpty)
        AdminActiveFilterItem(
          label: 'Busca: ${_searchController.text.trim()}',
          onRemove: () {
            _isSyncingSearch = true;
            _searchController.clear();
            _isSyncingSearch = false;
            vm.updateSearch('');
            vm.loadBookings();
          },
        ),
      if (vm.selectedStatus != null)
        AdminActiveFilterItem(
          label: 'Status: ${_statusLabel(vm.selectedStatus!)}',
          onRemove: () => vm.setStatus(null),
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isCompact
              ? 'Meus Agendamentos'
              : 'Meus Agendamentos - ${widget.schoolName}',
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
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
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
                                    color: colorScheme.onPrimary
                                        .withValues(alpha: 0.84),
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
                                if (vm.activeFilterCount > 0 ||
                                    _searchController.text.trim().isNotEmpty)
                                  TextButton.icon(
                                    onPressed: _clearFilters,
                                    icon: const Icon(
                                        Icons.filter_alt_off_outlined),
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
                                            icon: const Icon(
                                                Icons.close_rounded),
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
                                    value: vm.selectedSort,
                                    items: MyBookingsProvider.sortValues,
                                    itemLabelBuilder: _sortLabel,
                                    onChanged: (value) {
                                      if (value == null) return;
                                      vm.setSort(value);
                                    },
                                  ),
                                ),
                                SizedBox(
                                  width: 260,
                                  child: AdminDropdownFilter(
                                    label: 'Status',
                                    value: vm.selectedStatus,
                                    items: const [
                                      'scheduled',
                                      'completed',
                                      'cancelled',
                                    ],
                                    itemLabelBuilder: _statusLabel,
                                    onChanged: vm.setStatus,
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
                            value: vm.totalScheduledCount.toString(),
                            icon: Icons.check_circle_outline,
                            accentColor: const Color(0xFF1D7A6D),
                          ),
                          const SizedBox(height: 12),
                          AdminStatCard(
                            label: 'Finalizados',
                            value: vm.totalCompletedCount.toString(),
                            icon: Icons.task_alt_outlined,
                            accentColor: const Color(0xFF315FA8),
                          ),
                          const SizedBox(height: 12),
                          AdminStatCard(
                            label: 'Cancelados',
                            value: vm.totalCancelledCount.toString(),
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
                              value: vm.totalScheduledCount.toString(),
                              icon: Icons.check_circle_outline,
                              accentColor: const Color(0xFF1D7A6D),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AdminStatCard(
                              label: 'Finalizados',
                              value: vm.totalCompletedCount.toString(),
                              icon: Icons.task_alt_outlined,
                              accentColor: const Color(0xFF315FA8),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AdminStatCard(
                              label: 'Cancelados',
                              value: vm.totalCancelledCount.toString(),
                              icon: Icons.cancel_outlined,
                              accentColor: const Color(0xFFB54747),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 18),
                    if (vm.totalBookingsCount == 0 &&
                        vm.activeFilterCount == 0 &&
                        _searchController.text.trim().isEmpty)
                      const AdminEmptyState(
                        icon: Icons.event_note_outlined,
                        title: 'Você não possui agendamentos.',
                        message:
                            'Quando novas reservas forem criadas, elas aparecerão aqui para acompanhamento rápido.',
                      )
                    else if (vm.bookings.isEmpty)
                      const AdminEmptyState(
                        icon: Icons.filter_alt_off_outlined,
                        title: 'Nenhum agendamento encontrado.',
                        message:
                            'Ajuste a busca ou limpe os filtros para visualizar outras reservas.',
                      )
                    else
                      AdminPaginatedList<MyBookingModel>(
                        items: vm.bookings,
                        resetKey:
                            '${vm.currentPage}|${vm.selectedSort}|${vm.selectedStatus ?? ''}|${_searchController.text.trim().toLowerCase()}',
                        summaryLabel: 'agendamentos',
                        totalCount: vm.totalBookingsCount,
                        hasMoreExternal: vm.hasMorePages,
                        isLoadingMore: vm.isLoadingMore,
                        onLoadMore: () => vm.loadBookings(loadMore: true),
                        itemBuilder: (context, booking) {
                          final isScheduled = booking.status == 'scheduled';
                          final isCompleted = booking.status == 'completed';
                          final recentAction =
                              vm.recentActionByBookingId[booking.id];
                          final accentColor = isScheduled
                              ? const Color(0xFF1D7A6D)
                              : isCompleted
                                  ? const Color(0xFF315FA8)
                                  : const Color(0xFFB54747);
                          final highlightColor =
                              recentAction == 'completed'
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
                                            alpha: 0.18),
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
                              subtitle: AppFormatters.formatDateString(
                                  booking.bookingDate),
                              badge: AdminStatusBadge(
                                label: _statusLabel(booking.status),
                                accentColor: accentColor,
                              ),
                              trailing:
                                  _buildRecentActionBadge(recentAction),
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
                                  value: _formatLessons(booking.lessons),
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
                                      if (vm.canCompleteBooking(booking))
                                        FilledButton.icon(
                                          onPressed: () =>
                                              _showCompleteDialog(booking),
                                          icon: const Icon(
                                              Icons.task_alt_outlined),
                                          label: Text(
                                            isMobile
                                                ? 'Finalizar'
                                                : 'Marcar como finalizado',
                                          ),
                                        ),
                                      OutlinedButton.icon(
                                        onPressed: () =>
                                            _showCancelDialog(booking),
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

String _sortLabel(String value) {
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

String _formatLessons(List<MyBookingLessonModel> lessons) {
  if (lessons.isEmpty) return 'Sem aulas';
  return lessons.map((lesson) => lesson.label).join(', ');
}
