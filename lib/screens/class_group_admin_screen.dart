import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';

import '../models/class_group_admin_model.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/csv_export_service.dart';
import '../widgets/admin_ui.dart';

class ClassGroupAdminScreen extends StatefulWidget {
  const ClassGroupAdminScreen({super.key});

  @override
  State<ClassGroupAdminScreen> createState() => _ClassGroupAdminScreenState();
}

class _ClassGroupAdminScreenState extends State<ClassGroupAdminScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool isLoading = true;
  List<ClassGroupAdminModel> classGroups = [];
  Logger logger = Logger();
  String? selectedStatus;
  String selectedSort = 'name_asc';

  List<ClassGroupAdminModel> get filteredClassGroups {
    final query = _searchController.text.trim().toLowerCase();

    final filtered = classGroups.where((classGroup) {
      final matchesStatus =
          selectedStatus == null ||
          (selectedStatus == 'active' && classGroup.active == 1) ||
          (selectedStatus == 'inactive' && classGroup.active != 1);
      final matchesQuery =
          query.isEmpty || classGroup.name.toLowerCase().contains(query);

      return matchesStatus && matchesQuery;
    }).toList();

    filtered.sort((a, b) {
      switch (selectedSort) {
        case 'name_desc':
          return b.name.compareTo(a.name);
        case 'status':
          final statusCompare = b.active.compareTo(a.active);
          if (statusCompare != 0) return statusCompare;
          return a.name.compareTo(b.name);
        case 'name_asc':
        default:
          return a.name.compareTo(b.name);
      }
    });

    return filtered;
  }

  int get activeClassGroups {
    return filteredClassGroups
        .where((classGroup) => classGroup.active == 1)
        .length;
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
    loadClassGroups();
  }

  void _handleSearchChanged() {
    if (!mounted) return;
    setState(() {});
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
  }

  Future<void> _exportClassGroups() async {
    final result = await CsvExportService.exportRows(
      filePrefix: 'turmas',
      title: 'Turmas',
      subject: 'Turmas',
      shareText: 'Exportação CSV da lista de turmas.',
      headers: const ['Nome', 'Status', 'Criado em'],
      rows: filteredClassGroups
          .map(
            (classGroup) => [
              classGroup.name,
              classGroup.active == 1 ? 'Ativa' : 'Inativa',
              classGroup.createdAt,
            ],
          )
          .toList(),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));
  }

  Future<void> loadClassGroups() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) return;

    setState(() {
      isLoading = true;
    });

    try {
      final response = await ApiService.getClassGroupsAdmin(
        schoolId: user.schoolId,
      );

      if (response['success'] == true) {
        final List data = response['data'];
        classGroups = data
            .map((e) => ClassGroupAdminModel.fromJson(e))
            .toList();
      }
    } catch (e) {
      logger.i('ERRO AO CARREGAR TURMAS: $e');
    }

    if (!mounted) return;

    setState(() {
      isLoading = false;
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

    return Scaffold(
      appBar: AppBar(
        title: Text(isCompact ? 'Turmas' : 'Turmas - ${user.schoolName}'),
        actions: [
          IconButton(
            tooltip: 'Exportar CSV',
            onPressed: _exportClassGroups,
            icon: const Icon(Icons.download_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showClassGroupDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Nova turma'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadClassGroups,
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
                        value: filteredClassGroups.length.toString(),
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
                        value: (filteredClassGroups.length - activeClassGroups)
                            .toString(),
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
                  if (classGroups.isEmpty)
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
                    ...filteredClassGroups.map((classGroup) {
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
                    }),
                ],
              ),
            ),
    );
  }
}
