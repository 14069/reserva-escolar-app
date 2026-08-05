import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/platform_metrics_model.dart';
import '../services/api_service.dart';

class AdminGeralMetricsScreen extends StatefulWidget {
  const AdminGeralMetricsScreen({super.key});

  @override
  State<AdminGeralMetricsScreen> createState() =>
      _AdminGeralMetricsScreenState();
}

class _AdminGeralMetricsScreenState extends State<AdminGeralMetricsScreen> {
  PlatformMetricsModel? _metrics;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadMetrics();
  }

  Future<void> _loadMetrics() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final metrics = await ApiService.getSystemAdminMetrics();
      if (mounted) setState(() => _metrics = metrics);
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'Não foi possível carregar as métricas.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Métricas da Plataforma'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar',
            onPressed: _loadMetrics,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildError()
              : _metrics == null
                  ? const SizedBox.shrink()
                  : RefreshIndicator(
                      onRefresh: _loadMetrics,
                      child: _buildContent(_metrics!),
                    ),
    );
  }

  Widget _buildError() {
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
            Text(_errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 20),
            FilledButton.tonal(
                onPressed: _loadMetrics, child: const Text('Tentar novamente')),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(PlatformMetricsModel m) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionLabel('Escolas'),
        const SizedBox(height: 10),
        _TwoColRow(children: [
          _BigStatCard(
            label: 'Total de escolas',
            value: '${m.schools.total}',
            icon: Icons.school_outlined,
            color: colorScheme.primary,
          ),
          _BigStatCard(
            label: 'Novas este mês',
            value: '${m.schools.newThisMonth}',
            icon: Icons.add_business_outlined,
            color: colorScheme.secondary,
          ),
        ]),
        const SizedBox(height: 10),
        _TwoColRow(children: [
          _BigStatCard(
            label: 'Ativas',
            value: '${m.schools.active}',
            icon: Icons.check_circle_outline,
            color: Colors.green,
          ),
          _BigStatCard(
            label: 'Suspensas',
            value: '${m.schools.suspended}',
            icon: Icons.block_outlined,
            color: colorScheme.error,
          ),
        ]),
        const SizedBox(height: 20),
        _SectionLabel('Usuários'),
        const SizedBox(height: 10),
        _TwoColRow(children: [
          _BigStatCard(
            label: 'Total de usuários',
            value: '${m.users.total}',
            icon: Icons.people_outline,
            color: colorScheme.primary,
          ),
          _BigStatCard(
            label: 'Professores',
            value: '${m.users.teachers}',
            icon: Icons.person_outline,
            color: colorScheme.secondary,
          ),
        ]),
        const SizedBox(height: 10),
        _TwoColRow(children: [
          _BigStatCard(
            label: 'Técnicos',
            value: '${m.users.technicians}',
            icon: Icons.manage_accounts_outlined,
            color: colorScheme.tertiary,
          ),
          const _EmptyCard(),
        ]),
        const SizedBox(height: 20),
        _SectionLabel('Agendamentos'),
        const SizedBox(height: 10),
        _TwoColRow(children: [
          _BigStatCard(
            label: 'Total geral',
            value: '${m.bookings.total}',
            icon: Icons.calendar_month_outlined,
            color: colorScheme.primary,
          ),
          _BigStatCard(
            label: 'Este mês',
            value: '${m.bookings.thisMonth}',
            icon: Icons.today_outlined,
            color: colorScheme.secondary,
          ),
        ]),
        const SizedBox(height: 10),
        _TwoColRow(children: [
          _BigStatCard(
            label: 'Concluídos',
            value: '${m.bookings.completed}',
            icon: Icons.check_circle_outline,
            color: Colors.green,
          ),
          _BigStatCard(
            label: 'Cancelados',
            value: '${m.bookings.cancelled}',
            icon: Icons.cancel_outlined,
            color: colorScheme.error,
          ),
        ]),
        if (m.recentSchools.isNotEmpty) ...[
          const SizedBox(height: 24),
          _SectionLabel('Escolas recentes'),
          const SizedBox(height: 10),
          ...m.recentSchools.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                child: ListTile(
                  leading: Icon(
                    Icons.school_outlined,
                    color: s.active ? colorScheme.primary : colorScheme.error,
                  ),
                  title: Text(s.schoolName,
                      style:
                          const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(s.schoolCode),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: s.active
                              ? Colors.green.withValues(alpha: 0.12)
                              : colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          s.active ? 'Ativa' : 'Suspensa',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: s.active
                                ? Colors.green
                                : colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(s.createdAt),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 11,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context)
          .textTheme
          .titleMedium
          ?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

class _TwoColRow extends StatelessWidget {
  final List<Widget> children;
  const _TwoColRow({required this.children});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: children
          .map((w) => Expanded(child: w))
          .toList()
          .expand((w) => [w, const SizedBox(width: 10)])
          .toList()
        ..removeLast(),
    );
  }
}

class _BigStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _BigStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
