import 'dart:async';

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';

import '../models/class_group_admin_model.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/csv_export_service.dart';
import '../services/pdf_export_service.dart';
import '../widgets/admin_ui.dart';

class ClassGroupAdminScreen extends StatefulWidget {
  const ClassGroupAdminScreen({super.key});

  @override
  State<ClassGroupAdminScreen> createState() => _ClassGroupAdminScreenState();
}

class _ClassGroupAdminScreenState extends State<ClassGroupAdminScreen> {
  static const int _pageSize = 20;
  final TextEditingController _searchController = TextEditingController();
  bool isLoading = true;
  bool isLoadingMore = false;
  bool hasMorePages = false;
  int currentPage = 1;
  int totalClassGroupsCount = 0;
  int totalActiveClassGroups = 0;
  int totalInactiveClassGroups = 0;
  List<ClassGroupAdminModel> classGroups = [];
  Logger logger = Logger();
  String? selectedStatus;
  String selectedSort = 'name_asc';
  Timer? _searchDebounce;

  List<ClassGroupAdminModel> get filteredClassGroups => classGroups;

  int get activeClassGroups => totalActiveClassGroups;

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
            loadClassGroups();
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
            loadClassGroups();
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
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
    loadClassGroups();
  }

  void _handleSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      loadClassGroups();
    });
  }

  String statusLabel(String value) {
    return value == 'active' ? 'Ativa' : 'Inativa';
  }

  String sortLabel(String value) {
    switch (value) {
      case 'name_desc':
        return 'Nome (Z-A)';
      case 'status':
        return 'Status';
      case 'name_asc':
      default:
        return 'Nome (A-Z)';
    }
  }

  void clearFilters() {
    setState(() {
      _searchController.clear();
      selectedStatus = null;
    });
    loadClassGroups();
  }

  List<List<Object?>> _classGroupExportRows() {
    return filteredClassGroups
        .map(
          (classGroup) => [
            classGroup.name,
            classGroup.active == 1 ? 'Ativa' : 'Inativa',
            classGroup.createdAt,
          ],
        )
        .toList();
  }

  Future<void> _exportClassGroupsCsv() async {
    final result = await CsvExportService.exportRows(
      filePrefix: 'turmas',
      title: 'Turmas',
      subject: 'Turmas',
      shareText: 'Exportação CSV da lista de turmas.',
      headers: const ['Nome', 'Status', 'Criado em'],
      rows: _classGroupExportRows(),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));
  }

  Future<void> _exportClassGroupsPdf() async {
    final result = await PdfExportService.exportTable(
      filePrefix: 'turmas',
      title: 'Turmas',
      subject: 'Turmas',
      shareText: 'Exportação PDF da lista de turmas.',
      headers: const ['Nome', 'Status', 'Criado em'],
      rows: _classGroupExportRows(),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));
  }

  Future<void> loadClassGroups({bool loadMore = false}) async {
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
      final response = await ApiService.getClassGroupsAdmin(
        schoolId: user.schoolId,
        page: nextPage,
        pageSize: _pageSize,
        search: _searchController.text,
        status: selectedStatus,
        sort: selectedSort,
      );

      if (response['success'] == true) {
        final List data = response['data'];
        final fetchedClassGroups = data
            .map((e) => ClassGroupAdminModel.fromJson(e))
            .toList();
        final meta = response['meta'] as Map<String, dynamic>? ?? const {};
        final summary = meta['summary'] as Map<String, dynamic>? ?? const {};

        classGroups = loadMore
            ? [...classGroups, ...fetchedClassGroups]
            : fetchedClassGroups;
        currentPage = nextPage;
        totalClassGroupsCount =
            (meta['total'] as num?)?.toInt() ?? classGroups.length;
        totalActiveClassGroups =
            (summary['active_count'] as num?)?.toInt() ??
            classGroups.where((classGroup) => classGroup.active == 1).length;
        totalInactiveClassGroups =
            (summary['inactive_count'] as num?)?.toInt() ??
            (totalClassGroupsCount - totalActiveClassGroups);
        hasMorePages = meta['has_next_page'] == true;
      }
    } catch (e) {
      logger.i('ERRO AO CARREGAR TURMAS: $e');
    }

    if (!mounted) return;

    setState(() {
      isLoading = false;
      isLoadingMore = false;
    });
  }

  Future<void> showClassGroupDialog({ClassGroupAdminModel? classGroup}) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) return;
    final formKey = GlobalKey<FormState>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final nameController = TextEditingController(text: classGroup?.name ?? '');

    await showDialog(
      context: context,
      builder: (dialogContext) {
        bool saving = false;

        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return AdminFormDialog(
              title: classGroup == null ? 'Nova turma' : 'Editar turma',
              subtitle: classGroup == null
                  ? 'Crie uma turma para vincular reservas ao contexto correto das aulas.'
                  : 'Atualize o nome da turma selecionada.',
              icon: Icons.groups_outlined,
              content: Form(
                key: formKey,
                child: TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome da turma',
                    prefixIcon: Icon(Icons.class_outlined),
                  ),
                  validator: (value) {
                    if ((value?.trim() ?? '').isEmpty) {
                      return 'Informe o nome da turma';
                    }
                    return null;
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(modalContext),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (!(formKey.currentState?.validate() ?? false)) {
                            return;
                          }
                          final name = nameController.text.trim();

                          setModalState(() {
                            saving = true;
                          });

                          Map<String, dynamic> response;

                          if (classGroup == null) {
                            response = await ApiService.createClassGroup(
                              schoolId: user.schoolId,
                              userId: user.id,
                              name: name,
                            );
                          } else {
                            response = await ApiService.updateClassGroup(
                              schoolId: user.schoolId,
                              userId: user.id,
                              classGroupId: classGroup.id,
                              name: name,
                            );
                          }

                          if (!mounted || !modalContext.mounted) return;

                          Navigator.pop(modalContext);

                          scaffoldMessenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                response['message'] ?? 'Operação concluída.',
                              ),
                            ),
                          );

                          if (response['success'] == true) {
                            loadClassGroups();
                          }
                        },
                  child: Text(classGroup == null ? 'Criar' : 'Salvar'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
  }

  Future<void> toggleClassGroup(ClassGroupAdminModel classGroup) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) return;

    final response = await ApiService.toggleClassGroupStatus(
      schoolId: user.schoolId,
      userId: user.id,
      classGroupId: classGroup.id,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(response['message'] ?? 'Operação concluída.')),
    );

    if (response['success'] == true) {
      loadClassGroups();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user!;
    final isCompact = MediaQuery.of(context).size.width < 380;
    final showBlockingLoader = isLoading && filteredClassGroups.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(isCompact ? 'Turmas' : 'Turmas - ${user.schoolName}'),
        actions: [
          AdminExportMenuButton(
            onExportCsv: _exportClassGroupsCsv,
            onExportPdf: _exportClassGroupsPdf,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showClassGroupDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Nova turma'),
      ),
      body: showBlockingLoader
          ? const AdminPageSkeleton()
          : RefreshIndicator(
              onRefresh: loadClassGroups,
              child: Scrollbar(
                child: ListView(
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
                    title: 'Gerenciar turmas',
                    subtitle:
                        'Organize as turmas disponiveis para uso nas reservas e no planejamento escolar.',
                    icon: Icons.groups_outlined,
                  ),
                  const SizedBox(height: 16),
                  AdminStatsPanel(
                    children: [
                      AdminStatCard(
                        label: activeFilterCount > 0 ? 'Exibidas' : 'Total',
                        value: totalClassGroupsCount.toString(),
                        icon: Icons.group_work_outlined,
                        accentColor: const Color(0xFF7A4A9E),
                      ),
                      AdminStatCard(
                        label: 'Ativas',
                        value: activeClassGroups.toString(),
                        icon: Icons.check_circle_outline,
                        accentColor: const Color(0xFF1D7A6D),
                      ),
                      AdminStatCard(
                        label: 'Inativas',
                        value: totalInactiveClassGroups.toString(),
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
                              labelText: 'Buscar turma',
                              hintText: 'Nome da turma',
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
                                    'name_asc',
                                    'name_desc',
                                    'status',
                                  ],
                                  itemLabelBuilder: sortLabel,
                                  onChanged: (value) {
                                    if (value == null) return;
                                    setState(() {
                                      selectedSort = value;
                                    });
                                    loadClassGroups();
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
                                    loadClassGroups();
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
                  if (totalClassGroupsCount == 0 && activeFilterCount == 0)
                    const AdminEmptyState(
                      icon: Icons.groups_outlined,
                      title: 'Nenhuma turma cadastrada.',
                      message:
                          'Crie turmas para relacionar os agendamentos ao contexto correto de aula.',
                    )
                  else if (filteredClassGroups.isEmpty)
                    const AdminEmptyState(
                      icon: Icons.filter_alt_off_outlined,
                      title: 'Nenhuma turma encontrada.',
                      message:
                          'Ajuste a busca ou limpe os filtros para visualizar outras turmas.',
                    )
                  else
                    AdminPaginatedList<ClassGroupAdminModel>(
                      items: filteredClassGroups,
                      resetKey:
                          '$currentPage|$selectedSort|${selectedStatus ?? ''}|${_searchController.text.trim().toLowerCase()}',
                      summaryLabel: 'turmas',
                      totalCount: totalClassGroupsCount,
                      hasMoreExternal: hasMorePages,
                      isLoadingMore: isLoadingMore,
                      onLoadMore: () => loadClassGroups(loadMore: true),
                      itemBuilder: (context, classGroup) {
                        final isActive = classGroup.active == 1;

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
                                      isActive ? Icons.class_ : Icons.block,
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
                                          classGroup.name,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
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
                                        showClassGroupDialog(
                                          classGroup: classGroup,
                                        );
                                      } else if (value == 'toggle') {
                                        toggleClassGroup(classGroup);
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
