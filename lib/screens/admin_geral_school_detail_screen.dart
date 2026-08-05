import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/school_detail_model.dart';
import '../models/school_summary_model.dart';
import '../services/api_service.dart';

class AdminGeralSchoolDetailScreen extends StatefulWidget {
  final SchoolSummaryModel school;

  const AdminGeralSchoolDetailScreen({super.key, required this.school});

  @override
  State<AdminGeralSchoolDetailScreen> createState() =>
      _AdminGeralSchoolDetailScreenState();
}

class _AdminGeralSchoolDetailScreenState
    extends State<AdminGeralSchoolDetailScreen> {
  SchoolDetailModel? _detail;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isToggling = false;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final detail =
          await ApiService.getSystemAdminSchoolDetail(widget.school.id);
      if (mounted) setState(() => _detail = detail);
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'Não foi possível carregar os dados.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmToggleStatus() async {
    if (_detail == null) return;
    final isActive = _detail!.active;
    final actionLabel = isActive ? 'Suspender' : 'Ativar';
    final color = isActive ? Colors.red : Colors.green;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$actionLabel escola?'),
        content: Text(
          isActive
              ? 'Ao suspender, todos os usuários desta escola serão desconectados e não poderão fazer login até que a escola seja reativada.'
              : 'A escola voltará a operar normalmente e seus usuários poderão fazer login.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: color),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(actionLabel),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isToggling = true);
    try {
      final newActive =
          await ApiService.toggleSystemAdminSchoolStatus(widget.school.id);
      if (mounted) {
        setState(() => _detail = _detail!.copyWith(active: newActive));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newActive ? 'Escola ativada com sucesso.' : 'Escola suspensa com sucesso.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao alterar status da escola.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isToggling = false);
    }
  }

  String _formatDate(String? raw) {
    if (raw == null) return '—';
    try {
      return DateFormat('dd/MM/yyyy').format(DateTime.parse(raw));
    } catch (_) {
      return '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final detail = _detail;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.school.schoolName),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _ErrorView(message: _errorMessage!, onRetry: _loadDetail)
              : detail == null
                  ? const SizedBox.shrink()
                  : RefreshIndicator(
                      onRefresh: _loadDetail,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _StatusHeader(
                            detail: detail,
                            isToggling: _isToggling,
                            onToggle: _confirmToggleStatus,
                            formatDate: _formatDate,
                          ),
                          const SizedBox(height: 16),
                          _SectionTitle('Agendamentos'),
                          const SizedBox(height: 10),
                          _MetricsGrid(children: [
                            _MetricCard(
                              icon: Icons.calendar_month_outlined,
                              label: 'Total',
                              value: '${detail.metrics.totalBookings}',
                              color: colorScheme.primary,
                            ),
                            _MetricCard(
                              icon: Icons.today_outlined,
                              label: 'Este mês',
                              value: '${detail.metrics.bookingsThisMonth}',
                              color: colorScheme.secondary,
                            ),
                            _MetricCard(
                              icon: Icons.check_circle_outline,
                              label: 'Concluídos',
                              value: '${detail.metrics.bookingsCompleted}',
                              color: Colors.green,
                            ),
                            _MetricCard(
                              icon: Icons.cancel_outlined,
                              label: 'Cancelados',
                              value: '${detail.metrics.bookingsCancelled}',
                              color: colorScheme.error,
                            ),
                          ]),
                          const SizedBox(height: 20),
                          _SectionTitle('Estrutura'),
                          const SizedBox(height: 10),
                          _MetricsGrid(children: [
                            _MetricCard(
                              icon: Icons.devices_outlined,
                              label: 'Recursos',
                              value:
                                  '${detail.metrics.activeResources}/${detail.metrics.totalResources}',
                              color: colorScheme.tertiary,
                              subtitle: 'ativos/total',
                            ),
                            _MetricCard(
                              icon: Icons.person_outline,
                              label: 'Professores',
                              value: '${detail.metrics.totalTeachers}',
                              color: colorScheme.primary,
                            ),
                            _MetricCard(
                              icon: Icons.groups_outlined,
                              label: 'Turmas',
                              value: '${detail.metrics.activeClassGroups}',
                              color: colorScheme.secondary,
                            ),
                            _MetricCard(
                              icon: Icons.menu_book_outlined,
                              label: 'Disciplinas',
                              value: '${detail.metrics.activeSubjects}',
                              color: colorScheme.tertiary,
                            ),
                            _MetricCard(
                              icon: Icons.schedule_outlined,
                              label: 'Horários',
                              value: '${detail.metrics.activeLessonSlots}',
                              color: colorScheme.primary,
                            ),
                            _MetricCard(
                              icon: Icons.manage_accounts_outlined,
                              label: 'Técnicos',
                              value: '${detail.metrics.totalTechnicians}',
                              color: colorScheme.secondary,
                            ),
                          ]),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
    );
  }
}

class _StatusHeader extends StatelessWidget {
  final SchoolDetailModel detail;
  final bool isToggling;
  final VoidCallback onToggle;
  final String Function(String?) formatDate;

  const _StatusHeader({
    required this.detail,
    required this.isToggling,
    required this.onToggle,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isActive = detail.active;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        detail.schoolName,
                        style:
                            Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        detail.schoolCode,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontFamily: 'monospace',
                              fontSize: 13,
                            ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.green.withValues(alpha: 0.12)
                        : colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isActive ? Icons.check_circle : Icons.block,
                        size: 14,
                        color: isActive ? Colors.green : colorScheme.error,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isActive ? 'Ativa' : 'Suspensa',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color:
                              isActive ? Colors.green : colorScheme.onErrorContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Cadastrada em ${formatDate(detail.createdAt)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isToggling ? null : onToggle,
                icon: isToggling
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(isActive ? Icons.block : Icons.check_circle_outline),
                label: Text(isActive ? 'Suspender escola' : 'Ativar escola'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isActive ? colorScheme.error : Colors.green,
                  side: BorderSide(
                    color: isActive ? colorScheme.error : Colors.green,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  final List<Widget> children;
  const _MetricsGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.8,
      children: children,
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String? subtitle;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 10,
                        ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined,
                size: 48, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 20),
            FilledButton.tonal(
                onPressed: onRetry, child: const Text('Tentar novamente')),
          ],
        ),
      ),
    );
  }
}
