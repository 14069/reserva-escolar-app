import 'dart:async';

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';

import '../models/teacher_model.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/csv_export_service.dart';
import '../services/pdf_export_service.dart';
import '../widgets/admin_ui.dart';

class TeacherAdminScreen extends StatefulWidget {
  const TeacherAdminScreen({super.key});

  @override
  State<TeacherAdminScreen> createState() => _TeacherAdminScreenState();
}

class _TeacherAdminScreenState extends State<TeacherAdminScreen> {
  static const int _pageSize = 20;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool isLoading = true;
  bool isLoadingMore = false;
  bool hasMorePages = false;
  int currentPage = 1;
  int totalTeachersCount = 0;
  int totalActiveTeachers = 0;
  int totalInactiveTeachers = 0;
  List<TeacherModel> teachers = [];
  Logger logger = Logger();
  String? selectedStatus;
  String selectedSort = 'name_asc';
  Timer? _searchDebounce;

  List<TeacherModel> get filteredTeachers => teachers;

  int get activeTeachers => totalActiveTeachers;

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
            loadTeachers();
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
            loadTeachers();
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
    loadTeachers();
  }

  void _handleSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      loadTeachers();
    });
  }

  String statusLabel(String value) {
    return value == 'active' ? 'Ativo' : 'Inativo';
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
    loadTeachers();
  }

  List<List<Object?>> _teacherExportRows() {
    return filteredTeachers
        .map(
          (teacher) => [
            teacher.name,
            teacher.email,
            teacher.active == 1 ? 'Ativo' : 'Inativo',
            teacher.createdAt,
          ],
        )
        .toList();
  }

  Future<void> _exportTeachersCsv() async {
    final result = await CsvExportService.exportRows(
      filePrefix: 'professores',
      title: 'Professores',
      subject: 'Professores',
      shareText: 'Exportação CSV da lista de professores.',
      headers: const ['Nome', 'Email', 'Status', 'Criado em'],
      rows: _teacherExportRows(),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));
  }

  Future<void> _exportTeachersPdf() async {
    final result = await PdfExportService.exportTable(
      filePrefix: 'professores',
      title: 'Professores',
      subject: 'Professores',
      shareText: 'Exportação PDF da lista de professores.',
      headers: const ['Nome', 'Email', 'Status', 'Criado em'],
      rows: _teacherExportRows(),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));
  }

  Future<void> loadTeachers({bool loadMore = false}) async {
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
      final response = await ApiService.getTeachersPage(
        schoolId: user.schoolId,
        page: nextPage,
        pageSize: _pageSize,
        search: _searchController.text,
        status: selectedStatus,
        sort: selectedSort,
      );

      if (response.success) {
        final fetchedTeachers = response.items;
        final summary = response.summary;
        final meta = response.meta;
        teachers = loadMore
            ? [...teachers, ...fetchedTeachers]
            : fetchedTeachers;
        currentPage = nextPage;
        totalTeachersCount = meta.total == 0 ? teachers.length : meta.total;
        totalActiveTeachers =
            summary?.activeCount ??
            teachers.where((teacher) => teacher.active == 1).length;
        totalInactiveTeachers =
            summary?.inactiveCount ??
            (totalTeachersCount - totalActiveTeachers);
        hasMorePages = meta.hasNextPage;
      }
    } catch (e) {
      logger.i('ERRO AO CARREGAR PROFESSORES: $e');
    }

    if (!mounted) return;

    setState(() {
      isLoading = false;
      isLoadingMore = false;
    });
  }

  Future<void> showTeacherDialog({TeacherModel? teacher}) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final formKey = GlobalKey<FormState>();
    final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

    final nameController = TextEditingController(text: teacher?.name ?? '');
    final emailController = TextEditingController(text: teacher?.email ?? '');
    final passwordController = TextEditingController();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        bool saving = false;

        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return AdminFormDialog(
              title: teacher == null ? 'Novo professor' : 'Editar professor',
              subtitle: teacher == null
                  ? 'Cadastre o professor e defina uma senha inicial para liberar o acesso.'
                  : 'Atualize os dados do professor selecionado.',
              icon: Icons.people_outline,
              content: Form(
                key: formKey,
                child: SizedBox(
                  width: 420,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nome',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (value) {
                          if ((value?.trim() ?? '').isEmpty) {
                            return 'Informe o nome';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.alternate_email),
                        ),
                        validator: (value) {
                          final email = value?.trim() ?? '';
                          if (email.isEmpty) {
                            return 'Informe o email';
                          }
                          if (!emailPattern.hasMatch(email)) {
                            return 'Informe um email válido';
                          }
                          return null;
                        },
                      ),
                      if (teacher == null) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Senha inicial',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                          validator: (value) {
                            final password = value?.trim() ?? '';
                            if (password.isEmpty) {
                              return 'Informe a senha inicial';
                            }
                            if (password.length < 6) {
                              return 'Use ao menos 6 caracteres';
                            }
                            return null;
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dialogContext),
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
                          final email = emailController.text.trim();
                          final password = passwordController.text.trim();

                          setModalState(() {
                            saving = true;
                          });

                          final response = teacher == null
                              ? await ApiService.createTeacherResult(
                                  schoolId: user.schoolId,
                                  userId: user.id,
                                  name: name,
                                  email: email,
                                  password: password,
                                )
                              : await ApiService.updateTeacherResult(
                                  schoolId: user.schoolId,
                                  userId: user.id,
                                  teacherId: teacher.id,
                                  name: name,
                                  email: email,
                                );

                          if (!mounted || !modalContext.mounted) return;

                          Navigator.pop(modalContext);

                          scaffoldMessenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                response.message ?? 'Operação concluída.',
                              ),
                            ),
                          );

                          if (response.success) {
                            loadTeachers();
                          }
                        },
                  child: Text(teacher == null ? 'Criar' : 'Salvar'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
  }

  Future<void> toggleTeacher(TeacherModel teacher) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) return;

    final response = await ApiService.toggleTeacherStatusResult(
      schoolId: user.schoolId,
      userId: user.id,
      teacherId: teacher.id,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(response.message ?? 'Operação concluída.')),
    );

    if (response.success) {
      loadTeachers();
    }
  }

  Future<void> resetPassword(TeacherModel teacher) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final formKey = GlobalKey<FormState>();

    final passwordController = TextEditingController();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        bool saving = false;

        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return AdminFormDialog(
              title: 'Redefinir senha',
              subtitle:
                  'Defina uma nova senha para o professor selecionado com segurança.',
              icon: Icons.lock_reset,
              content: Form(
                key: formKey,
                child: TextFormField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Nova senha',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) {
                      return 'Informe a nova senha';
                    }
                    if (text.length < 6) {
                      return 'Use ao menos 6 caracteres';
                    }
                    return null;
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (!(formKey.currentState?.validate() ?? false)) {
                            return;
                          }
                          final newPassword = passwordController.text.trim();

                          setModalState(() {
                            saving = true;
                          });

                          final response =
                              await ApiService.resetTeacherPasswordResult(
                                schoolId: user.schoolId,
                                userId: user.id,
                                teacherId: teacher.id,
                                newPassword: newPassword,
                              );

                          if (!mounted || !modalContext.mounted) return;

                          Navigator.pop(modalContext);

                          scaffoldMessenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                response.message ?? 'Operação concluída.',
                              ),
                            ),
                          );
                        },
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );

    passwordController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user!;
    final isCompact = MediaQuery.of(context).size.width < 380;
    final showBlockingLoader = isLoading && filteredTeachers.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isCompact ? 'Professores' : 'Professores - ${user.schoolName}',
        ),
        actions: [
          AdminExportMenuButton(
            onExportCsv: _exportTeachersCsv,
            onExportPdf: _exportTeachersPdf,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showTeacherDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Novo professor'),
      ),
      body: showBlockingLoader
          ? const AdminPageSkeleton()
          : RefreshIndicator(
              onRefresh: loadTeachers,
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
                    title: 'Gerenciar professores',
                    subtitle:
                        'Mantenha docentes, acessos e redefinicoes de senha organizados em um só lugar.',
                    icon: Icons.people_outline,
                  ),
                  const SizedBox(height: 16),
                  AdminStatsPanel(
                    children: [
                      AdminStatCard(
                        label: activeFilterCount > 0 ? 'Exibidos' : 'Total',
                        value: totalTeachersCount.toString(),
                        icon: Icons.badge_outlined,
                        accentColor: const Color(0xFF315FA8),
                      ),
                      AdminStatCard(
                        label: 'Ativos',
                        value: activeTeachers.toString(),
                        icon: Icons.verified_user_outlined,
                        accentColor: const Color(0xFF1D7A6D),
                      ),
                      AdminStatCard(
                        label: 'Inativos',
                        value: totalInactiveTeachers.toString(),
                        icon: Icons.person_off_outlined,
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
                              labelText: 'Buscar professor',
                              hintText: 'Nome ou email',
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
                                    loadTeachers();
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
                                    loadTeachers();
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
                  if (totalTeachersCount == 0 && activeFilterCount == 0)
                    const AdminEmptyState(
                      icon: Icons.people_outline,
                      title: 'Nenhum professor cadastrado.',
                      message:
                          'Adicione professores para liberar o acesso e o uso das reservas no aplicativo.',
                    )
                  else if (filteredTeachers.isEmpty)
                    const AdminEmptyState(
                      icon: Icons.filter_alt_off_outlined,
                      title: 'Nenhum professor encontrado.',
                      message:
                          'Ajuste a busca ou limpe os filtros para visualizar outros professores.',
                    )
                  else
                    AdminPaginatedList<TeacherModel>(
                      items: filteredTeachers,
                      resetKey:
                          '$currentPage|$selectedSort|${selectedStatus ?? ''}|${_searchController.text.trim().toLowerCase()}',
                      summaryLabel: 'professores',
                      totalCount: totalTeachersCount,
                      hasMoreExternal: hasMorePages,
                      isLoadingMore: isLoadingMore,
                      onLoadMore: () => loadTeachers(loadMore: true),
                      itemBuilder: (context, teacher) {
                        final isActive = teacher.active == 1;

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
                                      isActive
                                          ? Icons.person
                                          : Icons.person_off,
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
                                          teacher.name,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          teacher.email,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: const Color(0xFF5A7069),
                                              ),
                                        ),
                                        const SizedBox(height: 10),
                                        AdminStatusBadge(
                                          label: isActive ? 'Ativo' : 'Inativo',
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
                                        showTeacherDialog(teacher: teacher);
                                      } else if (value == 'toggle') {
                                        toggleTeacher(teacher);
                                      } else if (value == 'password') {
                                        resetPassword(teacher);
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
                                      const PopupMenuItem(
                                        value: 'password',
                                        child: Text('Redefinir senha'),
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
