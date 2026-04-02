import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/notification_model.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../utils/app_formatters.dart';
import '../widgets/admin_ui.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isLoading = true;
  bool _isMarkingAll = false;
  int _unreadCount = 0;
  List<NotificationModel> _notifications = [];

  @override
  void initState() {
    super.initState();
    loadNotifications();
  }

  Future<void> loadNotifications() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    setState(() {
      _isLoading = true;
    });

    final response = await ApiService.getNotificationsFeed(
      schoolId: user.schoolId,
      page: 1,
      pageSize: 50,
    );

    if (!mounted) return;

    if (response.success) {
      setState(() {
        _notifications = response.items;
        _unreadCount =
            response.summary?.unreadCount ??
            response.items.where((notification) => !notification.isRead).length;
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _markAsRead(NotificationModel notification) async {
    if (notification.isRead) return;

    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    final response = await ApiService.markNotificationReadResult(
      schoolId: user.schoolId,
      notificationId: notification.id,
    );

    if (!mounted || !response.success) return;

    setState(() {
      _notifications = _notifications
          .map(
            (item) => item.id == notification.id
                ? item.copyWith(readAt: DateTime.now().toIso8601String())
                : item,
          )
          .toList();
      _unreadCount = (_unreadCount - 1).clamp(0, _unreadCount);
    });
  }

  Future<void> _markAllAsRead() async {
    final user = context.read<AuthProvider>().user;
    if (user == null || _unreadCount == 0 || _isMarkingAll) return;

    setState(() {
      _isMarkingAll = true;
    });

    final response = await ApiService.markAllNotificationsReadResult(
      schoolId: user.schoolId,
    );

    if (!mounted) return;

    if (response.success) {
      setState(() {
        _notifications = _notifications
            .map(
              (notification) => notification.copyWith(
                readAt: DateTime.now().toIso8601String(),
              ),
            )
            .toList();
        _unreadCount = 0;
      });
    }

    setState(() {
      _isMarkingAll = false;
    });
  }

  String _formatDateTime(String value) {
    return AppFormatters.formatDateTimeString(value);
  }

  (IconData, Color) _visualForType(String type) {
    switch (type) {
      case 'booking_created':
        return (Icons.add_task_outlined, const Color(0xFF0F766E));
      case 'booking_cancelled':
        return (Icons.cancel_outlined, const Color(0xFFB54747));
      case 'booking_completed':
        return (Icons.task_alt_outlined, const Color(0xFF315FA8));
      case 'booking_reminder_complete':
        return (Icons.notifications_active_outlined, const Color(0xFF8A6A10));
      default:
        return (Icons.notifications_none_outlined, const Color(0xFF5A7069));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificações'),
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _isMarkingAll ? null : _markAllAsRead,
              child: Text(_isMarkingAll ? 'Marcando...' : 'Marcar todas'),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: loadNotifications,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            const AdminHeaderCard(
              title: 'Central de notificações',
              subtitle:
                  'Acompanhe atualizações de agendamentos e lembretes para finalizar reservas.',
              icon: Icons.notifications_none_outlined,
            ),
            const SizedBox(height: 16),
            AdminStatsPanel(
              children: [
                AdminStatCard(
                  label: 'Não lidas',
                  value: _unreadCount.toString(),
                  icon: Icons.markunread_outlined,
                  accentColor: const Color(0xFFB54747),
                ),
                AdminStatCard(
                  label: 'Total',
                  value: _notifications.length.toString(),
                  icon: Icons.notifications_none_outlined,
                  accentColor: const Color(0xFF315FA8),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_notifications.isEmpty)
              const AdminEmptyState(
                icon: Icons.notifications_off_outlined,
                title: 'Nenhuma notificação por aqui.',
                message:
                    'Quando houver movimentações de agendamento, elas aparecerão nesta central.',
              )
            else
              ..._notifications.map((notification) {
                final (icon, accentColor) = _visualForType(notification.type);
                final metadata = notification.metadata;
                final details = <AdminDetailRow>[
                  AdminDetailRow(
                    icon: Icons.message_outlined,
                    label: 'Mensagem',
                    value: notification.message,
                  ),
                  if (notification.bookingId != null)
                    AdminDetailRow(
                      icon: Icons.assignment_outlined,
                      label: 'Agendamento',
                      value: '#${notification.bookingId}',
                    ),
                  if ((metadata?.resourceName ?? '').isNotEmpty)
                    AdminDetailRow(
                      icon: Icons.devices_outlined,
                      label: 'Recurso',
                      value: metadata!.resourceName!,
                    ),
                  if ((metadata?.classGroupName ?? '').isNotEmpty)
                    AdminDetailRow(
                      icon: Icons.groups_outlined,
                      label: 'Turma',
                      value: metadata!.classGroupName!,
                    ),
                  if ((metadata?.subjectName ?? '').isNotEmpty)
                    AdminDetailRow(
                      icon: Icons.menu_book_outlined,
                      label: 'Disciplina',
                      value: metadata!.subjectName!,
                    ),
                  if ((metadata?.bookingDate ?? '').isNotEmpty)
                    AdminDetailRow(
                      icon: Icons.event_outlined,
                      label: 'Data',
                      value: AppFormatters.formatDateString(
                        metadata!.bookingDate!,
                      ),
                    ),
                ];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => _markAsRead(notification),
                    child: AdminEntityCard(
                      icon: icon,
                      accentColor: accentColor,
                      title: notification.title,
                      subtitle: _formatDateTime(notification.createdAt),
                      badge: notification.isRead
                          ? null
                          : AdminStatusBadge(
                              label: 'Nova',
                              accentColor: accentColor,
                            ),
                      details: details,
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
