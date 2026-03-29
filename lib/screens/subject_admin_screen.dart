import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';

import '../models/subject_admin_model.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/admin_ui.dart';

class SubjectAdminScreen extends StatefulWidget {
  const SubjectAdminScreen({super.key});

  @override
  State<SubjectAdminScreen> createState() => _SubjectAdminScreenState();
}

class _SubjectAdminScreenState extends State<SubjectAdminScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool isLoading = true;
  List<SubjectAdminModel> subjects = [];
  Logger logger = Logger();
  String? selectedStatus;

  List<SubjectAdminModel> get filteredSubjects {
    final query = _searchController.text.trim().toLowerCase();

    return subjects.where((subject) {
      final matchesStatus =
          selectedStatus == null ||
          (selectedStatus == 'active' && subject.active == 1) ||
          (selectedStatus == 'inactive' && subject.active != 1);
      final matchesQuery =
          query.isEmpty || subject.name.toLowerCase().contains(query);

      return matchesStatus && matchesQuery;
    }).toList();
  }

  int get activeSubjects {
    return filteredSubjects.where((subject) => subject.active == 1).length;
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
    loadSubjects();
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

  Future<void> loadSubjects() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) return;

    setState(() {
      isLoading = true;
    });

    try {
      final response = await ApiService.getSubjectsAdmin(
        schoolId: user.schoolId,
      );

      if (response['success'] == true) {
        final List data = response['data'];
        subjects = data.map((e) => SubjectAdminModel.fromJson(e)).toList();
      }
    } catch (e) {
      logger.i('ERRO AO CARREGAR DISCIPLINAS V2: $e');
    }

    if (!mounted) return;

    setState(() {
      isLoading = false;
    });
  }

  Future<void> showSubjectDialog({SubjectAdminModel? subject}) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) return;
    final formKey = GlobalKey<FormState>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final nameController = TextEditingController(text: subject?.name ?? '');

    await showDialog(
      context: context,
      builder: (modelContext) {
        bool saving = false;

        return StatefulBuilder(
          builder: (modelContext, setModalState) {
            return AdminFormDialog(
              title: subject == null ? 'Nova disciplina' : 'Editar disciplina',
              subtitle: subject == null
                  ? 'Cadastre a disciplina para relacionar os agendamentos ao componente curricular.'
                  : 'Atualize o nome da disciplina selecionada.',
              icon: Icons.menu_book_outlined,
              content: Form(
                key: formKey,
                child: TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome da disciplina',
                    prefixIcon: Icon(Icons.book_outlined),
                  ),
                  validator: (value) {
                    if ((value?.trim() ?? '').isEmpty) {
                      return 'Informe o nome da disciplina';
                    }
                    return null;
                  },
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
                          final name = nameController.text.trim();

                          setModalState(() {
                            saving = true;
                          });

                          Map<String, dynamic> response;

                          if (subject == null) {
                            response = await ApiService.createSubject(
                              schoolId: user.schoolId,
                              userId: user.id,
                              name: name,
                            );
                          } else {
                            response = await ApiService.updateSubject(
                              schoolId: user.schoolId,
                              userId: user.id,
                              subjectId: subject.id,
                              name: name,
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
                            loadSubjects();
                          }
                        },
                  child: Text(subject == null ? 'Criar' : 'Salvar'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
  }

  Future<void> toggleSubject(SubjectAdminModel subject) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) return;

    final response = await ApiService.toggleSubjectStatus(
      schoolId: user.schoolId,
      userId: user.id,
      subjectId: subject.id,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(response['message'] ?? 'Operação concluída.')),
    );

    if (response['success'] == true) {
      loadSubjects();
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
          isCompact ? 'Disciplinas' : 'Disciplinas - ${user.schoolName}',
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showSubjectDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Nova disciplina'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadSubjects,
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
                    title: 'Gerenciar disciplinas',
                    subtitle:
                        'Mantenha os componentes curriculares atualizados para uso nos agendamentos.',
                    icon: Icons.menu_book_outlined,
                  ),
                  const SizedBox(height: 16),
                  AdminStatsPanel(
                    children: [
                      AdminStatCard(
                        label: activeFilterCount > 0 ? 'Exibidas' : 'Total',
                        value: filteredSubjects.length.toString(),
                        icon: Icons.library_books_outlined,
                        accentColor: const Color(0xFFAA5F2C),
                      ),
                      AdminStatCard(
                        label: 'Ativas',
                        value: activeSubjects.toString(),
                        icon: Icons.check_circle_outline,
                        accentColor: const Color(0xFF1D7A6D),
                      ),
                      AdminStatCard(
                        label: 'Inativas',
                        value: (subjects.length - activeSubjects).toString(),
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
                              labelText: 'Buscar disciplina',
                              hintText: 'Nome da disciplina',
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
                  if (subjects.isEmpty)
                    const AdminEmptyState(
                      icon: Icons.menu_book_outlined,
                      title: 'Nenhuma disciplina cadastrada.',
                      message:
                          'Cadastre disciplinas para vincular corretamente as reservas as aulas planejadas.',
                    )
                  else if (filteredSubjects.isEmpty)
                    const AdminEmptyState(
                      icon: Icons.filter_alt_off_outlined,
                      title: 'Nenhuma disciplina encontrada.',
                      message:
                          'Ajuste a busca ou limpe os filtros para visualizar outras disciplinas.',
                    )
                  else
                    ...filteredSubjects.map((subject) {
                      final isActive = subject.active == 1;

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
                                    isActive ? Icons.menu_book : Icons.block,
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
                                        subject.name,
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
                                      showSubjectDialog(subject: subject);
                                    } else if (value == 'toggle') {
                                      toggleSubject(subject);
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
