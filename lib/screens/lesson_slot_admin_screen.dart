import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';

import '../models/lesson_slot_admin_model.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/admin_ui.dart';

class LessonSlotAdminScreen extends StatefulWidget {
  const LessonSlotAdminScreen({super.key});

  @override
  State<LessonSlotAdminScreen> createState() => _LessonSlotAdminScreenState();
}

class _LessonSlotAdminScreenState extends State<LessonSlotAdminScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool isLoading = true;
  List<LessonSlotAdminModel> lessonSlots = [];
  Logger logger = Logger();
  String? selectedStatus;

  List<LessonSlotAdminModel> get filteredLessonSlots {
    final query = _searchController.text.trim().toLowerCase();

    return lessonSlots.where((lesson) {
      final matchesStatus =
          selectedStatus == null ||
          (selectedStatus == 'active' && lesson.active == 1) ||
          (selectedStatus == 'inactive' && lesson.active != 1);
      final timeText = '${lesson.startTime ?? ""} ${lesson.endTime ?? ""}';
      final matchesQuery =
          query.isEmpty ||
          lesson.label.toLowerCase().contains(query) ||
          lesson.lessonNumber.toString().contains(query) ||
          timeText.toLowerCase().contains(query);

      return matchesStatus && matchesQuery;
    }).toList();
  }

  int get activeLessons {
    return filteredLessonSlots.where((lesson) => lesson.active == 1).length;
  }

  int get activeFilterCount {
    return [
      if (_searchController.text.trim().isNotEmpty) _searchController.text,
      selectedStatus,
    ].length;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
    loadLessonSlots();
  }

  void _handleSearchChanged() {
    if (!mounted) return;
    setState(() {});
  }

  String statusLabel(String value) {
    return value == 'active' ? 'Ativa' : 'Inativa';
  }

  void clearFilters() {
    setState(() {
      _searchController.clear();
      selectedStatus = null;
    });
  }

  Future<void> loadLessonSlots() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) return;

    setState(() {
      isLoading = true;
    });

    try {
      final response = await ApiService.getLessonSlotsAdmin(
        schoolId: user.schoolId,
      );

      if (response['success'] == true) {
        final List data = response['data'];
        lessonSlots = data
            .map((e) => LessonSlotAdminModel.fromJson(e))
            .toList();
      }
    } catch (e) {
      logger.i('ERRO AO CARREGAR AULAS: $e');
    }

    if (!mounted) return;

    setState(() {
      isLoading = false;
    });
  }

  Future<void> showLessonDialog({LessonSlotAdminModel? lesson}) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) return;
    final formKey = GlobalKey<FormState>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final timePattern = RegExp(r'^\d{2}:\d{2}:\d{2}$');

    final lessonNumberController = TextEditingController(
      text: lesson?.lessonNumber.toString() ?? '',
    );
    final labelController = TextEditingController(text: lesson?.label ?? '');
    final startTimeController = TextEditingController(
      text: lesson?.startTime ?? '',
    );
    final endTimeController = TextEditingController(
      text: lesson?.endTime ?? '',
    );

    await showDialog(
      context: context,
      builder: (modelContext) {
        bool saving = false;

        return StatefulBuilder(
          builder: (modelContext, setModalState) {
            return AdminFormDialog(
              title: lesson == null ? 'Nova aula' : 'Editar aula',
              subtitle: lesson == null
                  ? 'Configure um novo horário para uso nos agendamentos.'
                  : 'Atualize número, rótulo e horário da aula selecionada.',
              icon: Icons.schedule_outlined,
              content: Form(
                key: formKey,
                child: SizedBox(
                  width: 420,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: lessonNumberController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Número da aula',
                          prefixIcon: Icon(Icons.format_list_numbered),
                        ),
                        validator: (value) {
                          final lessonNumber = int.tryParse(
                            value?.trim() ?? '',
                          );
                          if (lessonNumber == null || lessonNumber <= 0) {
                            return 'Informe um número de aula válido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: labelController,
                        decoration: const InputDecoration(
                          labelText: 'Rótulo',
                          prefixIcon: Icon(Icons.label_outline),
                        ),
                        validator: (value) {
                          if ((value?.trim() ?? '').isEmpty) {
                            return 'Informe o rótulo da aula';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: startTimeController,
                        decoration: const InputDecoration(
                          labelText: 'Hora inicial (HH:MM:SS)',
                          prefixIcon: Icon(Icons.access_time),
                        ),
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.isNotEmpty && !timePattern.hasMatch(text)) {
                            return 'Use o formato HH:MM:SS';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: endTimeController,
                        decoration: const InputDecoration(
                          labelText: 'Hora final (HH:MM:SS)',
                          prefixIcon: Icon(Icons.access_time_filled_outlined),
                        ),
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.isNotEmpty && !timePattern.hasMatch(text)) {
                            return 'Use o formato HH:MM:SS';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (!(formKey.currentState?.validate() ?? false)) {
                            return;
                          }
                          final lessonNumber = int.parse(
                            lessonNumberController.text.trim(),
                          );
                          final label = labelController.text.trim();
                          final startTime = startTimeController.text.trim();
                          final endTime = endTimeController.text.trim();

                          setModalState(() {
                            saving = true;
                          });

                          Map<String, dynamic> response;

                          if (lesson == null) {
                            response = await ApiService.createLessonSlot(
                              schoolId: user.schoolId,
                              userId: user.id,
                              lessonNumber: lessonNumber,
                              label: label,
                              startTime: startTime.isEmpty ? null : startTime,
                              endTime: endTime.isEmpty ? null : endTime,
                            );
                          } else {
                            response = await ApiService.updateLessonSlot(
                              schoolId: user.schoolId,
                              userId: user.id,
                              lessonSlotId: lesson.id,
                              lessonNumber: lessonNumber,
                              label: label,
                              startTime: startTime.isEmpty ? null : startTime,
                              endTime: endTime.isEmpty ? null : endTime,
                            );
                          }

                          if (!mounted || !modelContext.mounted) return;

                          Navigator.pop(modelContext);

                          scaffoldMessenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                response['message'] ?? 'Operação concluída.',
                              ),
                            ),
                          );

                          if (response['success'] == true) {
                            loadLessonSlots();
                          }
                        },
                  child: Text(lesson == null ? 'Criar' : 'Salvar'),
                ),
              ],
            );
          },
        );
      },
    );

    lessonNumberController.dispose();
    labelController.dispose();
    startTimeController.dispose();
    endTimeController.dispose();
  }

  Future<void> toggleLesson(LessonSlotAdminModel lesson) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) return;

    final response = await ApiService.toggleLessonSlotStatus(
      schoolId: user.schoolId,
      userId: user.id,
      lessonSlotId: lesson.id,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(response['message'] ?? 'Operação concluída.')),
    );

    if (response['success'] == true) {
      loadLessonSlots();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user!;
    final isCompact = MediaQuery.of(context).size.width < 380;

    return Scaffold(
      appBar: AppBar(
        title: Text(isCompact ? 'Aulas' : 'Aulas - ${user.schoolName}'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showLessonDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Nova aula'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadLessonSlots,
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
                    title: 'Gerenciar aulas',
                    subtitle:
                        'Configure a sequência de horários para que as reservas usem os tempos corretos.',
                    icon: Icons.schedule_outlined,
                  ),
                  const SizedBox(height: 16),
                  AdminStatsPanel(
                    children: [
                      AdminStatCard(
                        label: activeFilterCount > 0 ? 'Exibidas' : 'Total',
                        value: filteredLessonSlots.length.toString(),
                        icon: Icons.format_list_numbered,
                        accentColor: const Color(0xFF0B7285),
                      ),
                      AdminStatCard(
                        label: 'Ativas',
                        value: activeLessons.toString(),
                        icon: Icons.check_circle_outline,
                        accentColor: const Color(0xFF1D7A6D),
                      ),
                      AdminStatCard(
                        label: 'Inativas',
                        value: (lessonSlots.length - activeLessons).toString(),
                        icon: Icons.block_outlined,
                        accentColor: const Color(0xFFB54747),
                      ),
                    ],
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
                              labelText: 'Buscar aula',
                              hintText: 'Numero, rotulo ou horario',
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
                          SizedBox(
                            width: 260,
                            child: AdminDropdownFilter(
                              label: 'Status',
                              value: selectedStatus,
                              items: const ['active', 'inactive'],
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
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (lessonSlots.isEmpty)
                    const AdminEmptyState(
                      icon: Icons.schedule_outlined,
                      title: 'Nenhuma aula cadastrada.',
                      message:
                          'Crie os horários da escola para que os agendamentos possam selecionar os tempos disponiveis.',
                    )
                  else if (filteredLessonSlots.isEmpty)
                    const AdminEmptyState(
                      icon: Icons.filter_alt_off_outlined,
                      title: 'Nenhuma aula encontrada.',
                      message:
                          'Ajuste a busca ou limpe os filtros para visualizar outros horários.',
                    )
                  else
                    ...filteredLessonSlots.map((lesson) {
                      final isActive = lesson.active == 1;
                      final timeText =
                          '${lesson.startTime ?? "--"} às ${lesson.endTime ?? "--"}';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color:
                                        (isActive
                                                ? const Color(0xFF1D7A6D)
                                                : const Color(0xFFB54747))
                                            .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(
                                    Icons.schedule,
                                    color: isActive
                                        ? const Color(0xFF1D7A6D)
                                        : const Color(0xFFB54747),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${lesson.lessonNumber} - ${lesson.label}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        timeText,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: const Color(0xFF5A7069),
                                            ),
                                      ),
                                      const SizedBox(height: 10),
                                      AdminStatusBadge(
                                        label: isActive ? 'Ativa' : 'Inativa',
                                        accentColor: isActive
                                            ? const Color(0xFF1D7A6D)
                                            : const Color(0xFFB54747),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      showLessonDialog(lesson: lesson);
                                    } else if (value == 'toggle') {
                                      toggleLesson(lesson);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Editar'),
                                    ),
                                    PopupMenuItem(
                                      value: 'toggle',
                                      child: Text(
                                        isActive ? 'Desativar' : 'Ativar',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
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
