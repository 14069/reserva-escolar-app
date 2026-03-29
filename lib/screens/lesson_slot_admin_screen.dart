import 'dart:async';

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';

import '../models/lesson_slot_admin_model.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/csv_export_service.dart';
import '../services/pdf_export_service.dart';
import '../widgets/admin_ui.dart';

class LessonSlotAdminScreen extends StatefulWidget {
  const LessonSlotAdminScreen({super.key});

  @override
  State<LessonSlotAdminScreen> createState() => _LessonSlotAdminScreenState();
}

class _LessonSlotAdminScreenState extends State<LessonSlotAdminScreen> {
  static const int _pageSize = 20;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool isLoading = true;
  bool isLoadingMore = false;
  bool hasMorePages = false;
  int currentPage = 1;
  int totalLessonSlotsCount = 0;
  int totalActiveLessons = 0;
  int totalInactiveLessons = 0;
  List<LessonSlotAdminModel> lessonSlots = [];
  Logger logger = Logger();
  String? selectedStatus;
  String selectedSort = 'lesson_number_asc';
  Timer? _searchDebounce;

  List<LessonSlotAdminModel> get filteredLessonSlots => lessonSlots;

  int get activeLessons => totalActiveLessons;

  int get activeFilterCount {
    return [
      if (_searchController.text.trim().isNotEmpty) _searchController.text,
      selectedStatus,
    ].length;
  }

  List<AdminActiveFilterItem> get activeFilterItems {
    final items = <AdminActiveFilterItem>[];

    if (_searchController.text.trim().isNotEmpty) {
      items.add(
        AdminActiveFilterItem(
          label: 'Busca: ${_searchController.text.trim()}',
          onRemove: () {
            setState(() {
              _searchController.clear();
            });
            loadLessonSlots();
          },
        ),
      );
    }

    if (selectedStatus != null) {
      items.add(
        AdminActiveFilterItem(
          label: 'Status: ${statusLabel(selectedStatus!)}',
          onRemove: () {
            setState(() {
              selectedStatus = null;
            });
            loadLessonSlots();
          },
        ),
      );
    }

    return items;
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
    loadLessonSlots();
  }

  void _handleSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      loadLessonSlots();
    });
  }

  String statusLabel(String value) {
    return value == 'active' ? 'Ativa' : 'Inativa';
  }

  String sortLabel(String value) {
    switch (value) {
      case 'lesson_number_desc':
        return 'Numero (maior-menor)';
      case 'label_asc':
        return 'Rotulo (A-Z)';
      case 'status':
        return 'Status';
      case 'lesson_number_asc':
      default:
        return 'Numero (menor-maior)';
    }
  }

  void clearFilters() {
    setState(() {
      _searchController.clear();
      selectedStatus = null;
    });
    loadLessonSlots();
  }

  List<List<Object?>> _lessonSlotExportRows() {
    return filteredLessonSlots
        .map(
          (lesson) => [
            lesson.lessonNumber,
            lesson.label,
            lesson.startTime ?? '',
            lesson.endTime ?? '',
            lesson.active == 1 ? 'Ativa' : 'Inativa',
            lesson.createdAt,
          ],
        )
        .toList();
  }

  Future<void> _exportLessonSlotsCsv() async {
    final result = await CsvExportService.exportRows(
      filePrefix: 'aulas',
      title: 'Aulas',
      subject: 'Aulas',
      shareText: 'Exportação CSV da lista de aulas.',
      headers: const [
        'Numero da aula',
        'Rotulo',
        'Hora inicial',
        'Hora final',
        'Status',
        'Criado em',
      ],
      rows: _lessonSlotExportRows(),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));
  }

  Future<void> _exportLessonSlotsPdf() async {
    final result = await PdfExportService.exportTable(
      filePrefix: 'aulas',
      title: 'Aulas',
      subject: 'Aulas',
      shareText: 'Exportação PDF da lista de aulas.',
      headers: const [
        'Numero da aula',
        'Rotulo',
        'Hora inicial',
        'Hora final',
        'Status',
        'Criado em',
      ],
      rows: _lessonSlotExportRows(),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));
  }

  Future<void> loadLessonSlots({bool loadMore = false}) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) return;

    setState(() {
      if (loadMore) {
        isLoadingMore = true;
      } else {
        isLoading = true;
      }
    });

    try {
      final nextPage = loadMore ? currentPage + 1 : 1;
      final response = await ApiService.getLessonSlotsAdmin(
        schoolId: user.schoolId,
        page: nextPage,
        pageSize: _pageSize,
        search: _searchController.text,
        status: selectedStatus,
        sort: selectedSort,
      );

      if (response['success'] == true) {
        final List data = response['data'];
        final fetchedLessonSlots = data
            .map((e) => LessonSlotAdminModel.fromJson(e))
            .toList();
        final meta = response['meta'] as Map<String, dynamic>? ?? const {};
        final summary = meta['summary'] as Map<String, dynamic>? ?? const {};

        lessonSlots = loadMore
            ? [...lessonSlots, ...fetchedLessonSlots]
            : fetchedLessonSlots;
        currentPage = nextPage;
        totalLessonSlotsCount =
            (meta['total'] as num?)?.toInt() ?? lessonSlots.length;
        totalActiveLessons =
            (summary['active_count'] as num?)?.toInt() ??
            lessonSlots.where((lesson) => lesson.active == 1).length;
        totalInactiveLessons =
            (summary['inactive_count'] as num?)?.toInt() ??
            (totalLessonSlotsCount - totalActiveLessons);
        hasMorePages = meta['has_next_page'] == true;
      }
    } catch (e) {
      logger.i('ERRO AO CARREGAR AULAS: $e');
    }

    if (!mounted) return;

    setState(() {
      isLoading = false;
      isLoadingMore = false;
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
    final showBlockingLoader = isLoading && filteredLessonSlots.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(isCompact ? 'Aulas' : 'Aulas - ${user.schoolName}'),
        actions: [
          AdminExportMenuButton(
            onExportCsv: _exportLessonSlotsCsv,
            onExportPdf: _exportLessonSlotsPdf,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showLessonDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Nova aula'),
      ),
      body: showBlockingLoader
          ? const AdminPageSkeleton()
          : RefreshIndicator(
              onRefresh: loadLessonSlots,
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
                    if (isLoading) const AdminInlineLoadingIndicator(),
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
                        value: totalLessonSlotsCount.toString(),
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
                        value: totalInactiveLessons.toString(),
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
                              labelText: 'Buscar aula',
                              hintText: 'Numero, rotulo ou horario',
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
                                child: AdminDropdownFilter(
                                  label: 'Ordenar por',
                                  value: selectedSort,
                                  items: const [
                                    'lesson_number_asc',
                                    'lesson_number_desc',
                                    'label_asc',
                                    'status',
                                  ],
                                  itemLabelBuilder: sortLabel,
                                  onChanged: (value) {
                                    if (value == null) return;
                                    setState(() {
                                      selectedSort = value;
                                    });
                                    loadLessonSlots();
                                  },
                                ),
                              ),
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
                                    loadLessonSlots();
                                  },
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
                  if (totalLessonSlotsCount == 0 && activeFilterCount == 0)
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
                    AdminPaginatedList<LessonSlotAdminModel>(
                      items: filteredLessonSlots,
                      resetKey:
                          '$currentPage|$selectedSort|${selectedStatus ?? ''}|${_searchController.text.trim().toLowerCase()}',
                      summaryLabel: 'aulas',
                      totalCount: totalLessonSlotsCount,
                      hasMoreExternal: hasMorePages,
                      isLoadingMore: isLoadingMore,
                      onLoadMore: () => loadLessonSlots(loadMore: true),
                      itemBuilder: (context, lesson) {
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
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
