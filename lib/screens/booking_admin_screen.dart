import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';

import '../models/booking_admin_model.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/csv_export_service.dart';
import '../widgets/admin_ui.dart';

class BookingAdminScreen extends StatefulWidget {
  const BookingAdminScreen({super.key});

  @override
  State<BookingAdminScreen> createState() => _BookingAdminScreenState();
}

class _BookingAdminScreenState extends State<BookingAdminScreen> {
  final TextEditingController _searchController = TextEditingController();

  bool isLoading = true;
  List<BookingAdminModel> bookings = [];
  DateTime? selectedDate;
  String? selectedTeacher;
  String? selectedResource;
  String? selectedClassGroup;
  String? selectedStatus;
  String selectedSort = 'date_desc';

  List<BookingAdminModel> get filteredBookings {
    final query = _searchController.text.trim().toLowerCase();

    final filtered = bookings.where((booking) {
      final matchesTeacher =
          selectedTeacher == null || booking.userName == selectedTeacher;
      final matchesResource =
          selectedResource == null || booking.resourceName == selectedResource;
      final matchesClassGroup =
          selectedClassGroup == null ||
          booking.classGroupName == selectedClassGroup;
      final matchesStatus =
          selectedStatus == null || booking.status == selectedStatus;

      final matchesQuery =
          query.isEmpty ||
          booking.resourceName.toLowerCase().contains(query) ||
          booking.userName.toLowerCase().contains(query) ||
          booking.classGroupName.toLowerCase().contains(query) ||
          booking.subjectName.toLowerCase().contains(query) ||
          booking.purpose.toLowerCase().contains(query) ||
          formatDisplayDate(booking.bookingDate).contains(query);

      return matchesTeacher &&
          matchesResource &&
          matchesClassGroup &&
          matchesStatus &&
          matchesQuery;
    }).toList();

    filtered.sort((a, b) {
      switch (selectedSort) {
        case 'date_asc':
          return a.bookingDate.compareTo(b.bookingDate);
        case 'teacher_asc':
          return a.userName.compareTo(b.userName);
        case 'resource_asc':
          return a.resourceName.compareTo(b.resourceName);
        case 'date_desc':
        default:
          return b.bookingDate.compareTo(a.bookingDate);
      }
    });

    return filtered;
  }

  int get scheduledCount {
    return filteredBookings
        .where((booking) => booking.status == 'scheduled')
        .length;
  }

  int get cancelledCount {
    return filteredBookings
        .where((booking) => booking.status != 'scheduled')
        .length;
  }

  int get activeFilterCount {
    final filters = [
      if (_searchController.text.trim().isNotEmpty) _searchController.text,
      selectedTeacher,
      selectedResource,
      selectedClassGroup,
      selectedStatus,
    ];
    return filters.length;
  }

  List<String> get teacherOptions =>
      _sortedOptions(bookings.map((booking) => booking.userName));

  List<String> get resourceOptions =>
      _sortedOptions(bookings.map((booking) => booking.resourceName));

  List<String> get classGroupOptions =>
      _sortedOptions(bookings.map((booking) => booking.classGroupName));

  List<String> get statusOptions =>
      _sortedOptions(bookings.map((booking) => booking.status));

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
    loadBookings();
  }

  void _handleSearchChanged() {
    if (!mounted) return;
    setState(() {});
  }

  String formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String formatLessons(List<BookingLessonModel> lessons) {
    if (lessons.isEmpty) return 'Sem aulas';
    return lessons.map((lesson) => lesson.label).join(', ');
  }

  String formatDisplayDate(String value) {
    final parts = value.split('-');
    if (parts.length != 3) return value;
    return '${parts[2]}/${parts[1]}/${parts[0]}';
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

  String statusLabel(String value) {
    switch (value) {
      case 'scheduled':
        return 'Agendado';
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
      _searchController.clear();
      selectedTeacher = null;
      selectedResource = null;
      selectedClassGroup = null;
      selectedStatus = null;
    });
  }

  Future<void> _exportBookings() async {
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
        'Cancelado em',
      ],
      rows: filteredBookings
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
              booking.cancelledAt ?? '',
            ],
          )
          .toList(),
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

  Future<void> loadBookings() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    final logger = Logger();
    if (user == null) return;

    setState(() {
      isLoading = true;
    });

    try {
      final response = await ApiService.getAllBookings(
        schoolId: user.schoolId,
        bookingDate: selectedDate != null ? formatDate(selectedDate!) : null,
      );

      if (response['success'] == true) {
        final List data = response['data'];
        bookings = data.map((e) => BookingAdminModel.fromJson(e)).toList();
      }
    } catch (e) {
      logger.i('ERRO AO CARREGAR AGENDAMENTOS ADMIN: $e');
    }

    if (!mounted) return;

    setState(() {
      isLoading = false;
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(response['message'] ?? 'Operação concluída.')),
    );

    if (response['success'] == true) {
      loadBookings();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user!;
    final isCompact = MediaQuery.of(context).size.width < 380;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isCompact ? 'Agendamentos' : 'Agendamentos - ${user.schoolName}',
        ),
        actions: [
          IconButton(
            tooltip: 'Exportar CSV',
            onPressed: _exportBookings,
            icon: const Icon(Icons.download_rounded),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadBookings,
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
                        value: filteredBookings.length.toString(),
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
                                  style: Theme.of(context).textTheme.titleMedium
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
                              suffixIcon: _searchController.text.trim().isEmpty
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
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (bookings.isEmpty)
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
                          '${filteredBookings.length}|$selectedSort|${selectedDate?.toIso8601String() ?? ''}|${selectedTeacher ?? ''}|${selectedResource ?? ''}|${selectedClassGroup ?? ''}|${selectedStatus ?? ''}|${_searchController.text.trim().toLowerCase()}',
                      summaryLabel: 'agendamentos',
                      itemBuilder: (context, booking) {
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
                              label: isScheduled ? 'Agendado' : 'Cancelado',
                              accentColor: accentColor,
                            ),
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
                            ],
                            footerActions: isScheduled
                                ? [
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
