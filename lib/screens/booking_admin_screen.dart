import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';

import '../models/booking_admin_model.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/admin_ui.dart';

class BookingAdminScreen extends StatefulWidget {
  const BookingAdminScreen({super.key});

  @override
  State<BookingAdminScreen> createState() => _BookingAdminScreenState();
}

class _BookingAdminScreenState extends State<BookingAdminScreen> {
  bool isLoading = true;
  List<BookingAdminModel> bookings = [];
  DateTime? selectedDate;

  int get scheduledCount {
    return bookings.where((booking) => booking.status == 'scheduled').length;
  }

  int get cancelledCount {
    return bookings.where((booking) => booking.status != 'scheduled').length;
  }

  @override
  void initState() {
    super.initState();
    loadBookings();
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
                        label: 'Total',
                        value: bookings.length.toString(),
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
                  if (bookings.isEmpty)
                    const AdminEmptyState(
                      icon: Icons.assignment_outlined,
                      title: 'Nenhum agendamento encontrado.',
                      message:
                          'Quando houver reservas na escola, elas aparecerão aqui para acompanhamento e suporte.',
                    )
                  else
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
                    }),
                ],
              ),
            ),
    );
  }
}
