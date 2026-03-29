import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';

import '../models/my_booking_model.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/admin_ui.dart';

class MyBookingsV2Screen extends StatefulWidget {
  const MyBookingsV2Screen({super.key});

  @override
  State<MyBookingsV2Screen> createState() => _MyBookingsV2ScreenState();
}

class _MyBookingsV2ScreenState extends State<MyBookingsV2Screen> {
  final TextEditingController _searchController = TextEditingController();
  bool isLoading = true;
  List<MyBookingModel> bookings = [];
  String? selectedStatus;
  String selectedSort = 'date_desc';

  List<MyBookingModel> get filteredBookings {
    final query = _searchController.text.trim().toLowerCase();

    final filtered = bookings.where((booking) {
      final matchesStatus =
          selectedStatus == null || booking.status == selectedStatus;
      final matchesQuery =
          query.isEmpty ||
          booking.resourceName.toLowerCase().contains(query) ||
          booking.classGroupName.toLowerCase().contains(query) ||
          booking.subjectName.toLowerCase().contains(query) ||
          booking.purpose.toLowerCase().contains(query) ||
          formatDisplayDate(booking.bookingDate).contains(query);

      return matchesStatus && matchesQuery;
    }).toList();

    filtered.sort((a, b) {
      switch (selectedSort) {
        case 'date_asc':
          return a.bookingDate.compareTo(b.bookingDate);
        case 'resource_asc':
          return a.resourceName.compareTo(b.resourceName);
        case 'status':
          final statusCompare = a.status.compareTo(b.status);
          if (statusCompare != 0) return statusCompare;
          return b.bookingDate.compareTo(a.bookingDate);
        case 'date_desc':
        default:
          return b.bookingDate.compareTo(a.bookingDate);
      }
    });

    return filtered;
  }

  int get activeFilterCount {
    return [
      if (_searchController.text.trim().isNotEmpty) _searchController.text,
      selectedStatus,
    ].length;
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
    loadBookings();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    if (!mounted) return;
    setState(() {});
  }

  String formatLessons(List<MyBookingLessonModel> lessons) {
    if (lessons.isEmpty) return 'Sem aulas';
    return lessons.map((lesson) => lesson.label).join(', ');
  }

  String formatDisplayDate(String value) {
    final parts = value.split('-');
    if (parts.length != 3) return value;
    return '${parts[2]}/${parts[1]}/${parts[0]}';
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
      final response = await ApiService.getMyBookings(
        schoolId: user.schoolId,
        userId: user.id,
      );

      if (response['success'] == true) {
        final List data = response['data'];
        bookings = data.map((e) => MyBookingModel.fromJson(e)).toList();
      }
    } catch (e) {
      logger.i('ERRO AO CARREGAR MEUS AGENDAMENTOS: $e');
    }

    if (!mounted) return;

    setState(() {
      isLoading = false;
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
    final colorScheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 380;
    final isMobile = screenWidth < 640;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isCompact
              ? 'Meus Agendamentos'
              : 'Meus Agendamentos - ${user.schoolName}',
        ),
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
                  Container(
                    padding: EdgeInsets.all(isCompact ? 18 : 24),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [colorScheme.primary, const Color(0xFF184E44)],
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
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                              if (activeFilterCount > 0)
                                TextButton.icon(
                                  onPressed: clearFilters,
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
                                  'Recurso, turma, disciplina, finalidade ou data',
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon:
                                  _searchController.text.trim().isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: 'Limpar busca',
                                      onPressed: () => _searchController.clear(),
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
                                  },
                                ),
                              ),
                              SizedBox(
                                width: 260,
                                child: AdminDropdownFilter(
                                  label: 'Status',
                                  value: selectedStatus,
                                  items: const ['scheduled', 'cancelled'],
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
                            label: 'Cancelados',
                            value: cancelledCount.toString(),
                            icon: Icons.cancel_outlined,
                            accentColor: const Color(0xFFB54747),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 18),
                  if (bookings.isEmpty)
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
                    ...filteredBookings.map((booking) {
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
                          subtitle: formatDisplayDate(booking.bookingDate),
                          badge: AdminStatusBadge(
                            label: isScheduled ? 'Agendado' : 'Cancelado',
                            accentColor: accentColor,
                          ),
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
                          ],
                          footerActions: isScheduled
                              ? [
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
                    }),
                ],
              ),
            ),
    );
  }
}
