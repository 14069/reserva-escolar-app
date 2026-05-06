import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/class_group_model.dart';
import '../models/resource_model.dart';
import '../models/subject_model.dart';
import '../providers/auth_provider.dart';
import '../providers/new_booking_provider.dart';
import '../services/analytics_service.dart';

class NewBookingScreen extends StatelessWidget {
  const NewBookingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthProvider>().user!;
    return ChangeNotifierProvider(
      create: (_) => NewBookingProvider(schoolId: user.schoolId, userId: user.id)
        ..loadInitialData(),
      child: const _NewBookingView(),
    );
  }
}

class _NewBookingView extends StatefulWidget {
  const _NewBookingView();

  @override
  State<_NewBookingView> createState() => _NewBookingViewState();
}

class _NewBookingViewState extends State<_NewBookingView> {
  final _formKey = GlobalKey<FormState>();
  final _purposeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _purposeController.addListener(_onPurposeChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AnalyticsService.instance.logScreenView(screenName: 'new_booking');
    });
  }

  void _onPurposeChanged() {
    context.read<NewBookingProvider>().invalidatePurpose();
  }

  @override
  void dispose() {
    _purposeController.removeListener(_onPurposeChanged);
    _purposeController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final vm = context.read<NewBookingProvider>();
    final picked = await showDatePicker(
      context: context,
      initialDate: vm.selectedDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null && mounted) {
      vm.selectDate(picked);
    }
  }

  Future<void> _submitBooking() async {
    if (!_formKey.currentState!.validate()) return;

    final vm = context.read<NewBookingProvider>();
    final outcome = await vm.submitBooking(
      purpose: _purposeController.text.trim(),
    );

    if (!mounted) return;

    switch (outcome) {
      case NewBookingSuccess(:final resourceId, :final resourceCategory, :final lessonCount):
        await AnalyticsService.instance.logBookingCreated(
          resourceId: resourceId,
          resourceCategory: resourceCategory,
          lessonCount: lessonCount,
        );
        if (!mounted) return;
        Navigator.pop(context, true);

      case NewBookingConflict(:final message):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );

      case NewBookingFailure(:final message):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NewBookingProvider>();
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 380;
    final horizontalPadding = isCompact ? 14.0 : 16.0;
    final heroPadding = isCompact ? 18.0 : 24.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(isCompact ? 'Novo Agendamento' : 'Novo Agendamento V2'),
      ),
      body: vm.isLoadingInitialData
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                8,
                horizontalPadding,
                24,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HeroCard(
                      vm: vm,
                      heroPadding: heroPadding,
                      isCompact: isCompact,
                    ),
                    const SizedBox(height: 16),
                    _buildSectionCard(
                      context: context,
                      step: 'Etapa 1',
                      title: 'Defina recurso e data',
                      subtitle:
                          'Esses dados determinam quais aulas podem ser reservadas.',
                      child: Column(
                        children: [
                          DropdownButtonFormField<ResourceModel>(
                            initialValue: vm.selectedResource,
                            isExpanded: true,
                            menuMaxHeight: 320,
                            decoration: const InputDecoration(
                              labelText: 'Recurso',
                              prefixIcon: Icon(Icons.widgets_outlined),
                            ),
                            items: vm.resources.map((resource) {
                              return DropdownMenuItem(
                                value: resource,
                                child: _dropdownText(
                                  _resourceLabel(resource, compact: isCompact),
                                  maxLines: 2,
                                ),
                              );
                            }).toList(),
                            selectedItemBuilder: (context) {
                              return vm.resources.map((resource) {
                                return Align(
                                  alignment: Alignment.centerLeft,
                                  child: _dropdownText(
                                    _resourceLabel(resource, compact: true),
                                  ),
                                );
                              }).toList();
                            },
                            onChanged: (value) {
                              context.read<NewBookingProvider>().selectResource(value);
                            },
                          ),
                          const SizedBox(height: 16),
                          _DatePickerTile(
                            label: vm.selectedDateLabel,
                            hasDate: vm.selectedDate != null,
                            onTap: _pickDate,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSectionCard(
                      context: context,
                      step: 'Etapa 2',
                      title: 'Informe o contexto da aula',
                      subtitle:
                          'Essas informações ajudam a equipe a entender o uso da reserva.',
                      child: Column(
                        children: [
                          DropdownButtonFormField<ClassGroupModel>(
                            initialValue: vm.selectedClassGroup,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Turma',
                              prefixIcon: Icon(Icons.groups_outlined),
                            ),
                            items: vm.classGroups.map((group) {
                              return DropdownMenuItem(
                                value: group,
                                child: _dropdownText(group.name, maxLines: 2),
                              );
                            }).toList(),
                            selectedItemBuilder: (context) {
                              return vm.classGroups.map((group) {
                                return Align(
                                  alignment: Alignment.centerLeft,
                                  child: _dropdownText(group.name),
                                );
                              }).toList();
                            },
                            onChanged: (value) {
                              context.read<NewBookingProvider>().selectClassGroup(value);
                            },
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<SubjectModel>(
                            initialValue: vm.selectedSubject,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Disciplina',
                              prefixIcon: Icon(Icons.menu_book_outlined),
                            ),
                            items: vm.subjects.map((subject) {
                              return DropdownMenuItem(
                                value: subject,
                                child: _dropdownText(subject.name, maxLines: 2),
                              );
                            }).toList(),
                            selectedItemBuilder: (context) {
                              return vm.subjects.map((subject) {
                                return Align(
                                  alignment: Alignment.centerLeft,
                                  child: _dropdownText(subject.name),
                                );
                              }).toList();
                            },
                            onChanged: (value) {
                              context.read<NewBookingProvider>().selectSubject(value);
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _purposeController,
                            decoration: const InputDecoration(
                              labelText: 'Finalidade',
                              hintText:
                                  'Descreva rapidamente a atividade planejada',
                              prefixIcon: Icon(Icons.edit_note),
                              alignLabelWithHint: true,
                            ),
                            maxLines: 4,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Informe a finalidade';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSectionCard(
                      context: context,
                      step: 'Etapa 3',
                      title: 'Selecione as aulas disponíveis',
                      subtitle:
                          'Escolha um ou mais horários livres para concluir o pedido.',
                      child: _LessonsContent(vm: vm),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Resumo da reserva',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 12),
                            _BookingSummaryRow(
                              icon: Icons.widgets_outlined,
                              label: 'Recurso',
                              value: vm.selectedResource?.name ?? 'Não selecionado',
                            ),
                            const SizedBox(height: 10),
                            _BookingSummaryRow(
                              icon: Icons.calendar_today_outlined,
                              label: 'Data',
                              value: vm.selectedDateLabel,
                            ),
                            const SizedBox(height: 10),
                            _BookingSummaryRow(
                              icon: Icons.groups_outlined,
                              label: 'Turma',
                              value: vm.selectedClassGroup?.name ?? 'Não selecionada',
                            ),
                            const SizedBox(height: 10),
                            _BookingSummaryRow(
                              icon: Icons.schedule,
                              label: 'Aulas',
                              value: vm.selectedLessonIds.isEmpty
                                  ? 'Nenhuma selecionada'
                                  : '${vm.selectedLessonIds.length} aula(s)',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton.icon(
                      onPressed: vm.isLoading ? null : _submitBooking,
                      icon: vm.isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.4),
                            )
                          : const Icon(Icons.check_circle_outline),
                      label: Text(
                        vm.isLoading
                            ? 'Salvando agendamento...'
                            : 'Salvar agendamento',
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionCard({
    required BuildContext context,
    required String step,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                step,
                style: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }

  static Widget _dropdownText(String text, {int maxLines = 1}) {
    return Text(text, maxLines: maxLines, overflow: TextOverflow.ellipsis);
  }

  static String _resourceLabel(ResourceModel resource, {bool compact = false}) {
    if (compact) return resource.name;
    return '${resource.name} (${resource.categoryName})';
  }
}

class _HeroCard extends StatelessWidget {
  final NewBookingProvider vm;
  final double heroPadding;
  final bool isCompact;

  const _HeroCard({
    required this.vm,
    required this.heroPadding,
    required this.isCompact,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.all(heroPadding),
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
            'Monte sua reserva',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: colorScheme.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          if (!isCompact)
            Text(
              'Escolha o recurso, defina a data e selecione os horários disponíveis em poucos passos.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onPrimary.withValues(alpha: 0.84),
                    height: 1.4,
                  ),
            ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (vm.selectedResource != null)
                _SummaryChip(
                  icon: Icons.widgets_outlined,
                  label: vm.selectedResource!.name,
                ),
              _SummaryChip(
                icon: Icons.calendar_today_outlined,
                label: vm.selectedDateLabel,
              ),
              _SummaryChip(
                icon: Icons.schedule,
                label: '${vm.selectedLessonIds.length} aula(s)',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SummaryChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: colorScheme.onPrimary),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colorScheme.onPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DatePickerTile extends StatelessWidget {
  final String label;
  final bool hasDate;
  final VoidCallback onTap;

  const _DatePickerTile({
    required this.label,
    required this.hasDate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: colorScheme.surfaceContainerLow,
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.calendar_month, color: colorScheme.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Data da reserva',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasDate ? label : 'Toque para escolher a data',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _LessonsContent extends StatelessWidget {
  final NewBookingProvider vm;

  const _LessonsContent({required this.vm});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (vm.selectedDate == null) {
      return const _InfoStateCard(
        icon: Icons.calendar_month_outlined,
        title: 'Escolha uma data primeiro',
        message:
            'As aulas disponíveis aparecem assim que a data da reserva for definida.',
      );
    }

    if (vm.isLoadingLessons) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (vm.lessonsLoadError != null) {
      return _InfoStateCard(
        icon: Icons.wifi_off_outlined,
        title: 'Falha ao carregar horários',
        message: vm.lessonsLoadError!,
      );
    }

    if (vm.availableLessons.isEmpty) {
      return const _InfoStateCard(
        icon: Icons.event_busy_outlined,
        title: 'Nenhuma aula disponivel',
        message:
            'Tente outra data ou outro recurso para encontrar horários livres.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: vm.availableLessons.map((lesson) {
            final isSelected = vm.selectedLessonIds.contains(lesson.id);
            return FilterChip(
              label: Text(lesson.label),
              selected: isSelected,
              onSelected: (selected) {
                context.read<NewBookingProvider>().toggleLesson(lesson.id, selected);
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
        Text(
          vm.selectedLessonIds.isEmpty
              ? 'Selecione pelo menos uma aula para concluir o agendamento.'
              : '${vm.selectedLessonIds.length} aula(s) selecionada(s).',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _InfoStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _InfoStateCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(icon, size: 30, color: colorScheme.primary),
          const SizedBox(height: 10),
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _BookingSummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _BookingSummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: colorScheme.primary),
        const SizedBox(width: 10),
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
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
