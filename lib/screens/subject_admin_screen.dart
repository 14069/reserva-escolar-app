import 'dart:async';

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';

import '../models/subject_admin_model.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/csv_export_service.dart';
import '../services/pdf_export_service.dart';
import '../widgets/admin_ui.dart';

class SubjectAdminScreen extends StatefulWidget {
  const SubjectAdminScreen({super.key});

  @override
  State<SubjectAdminScreen> createState() => _SubjectAdminScreenState();
}

class _SubjectAdminScreenState extends State<SubjectAdminScreen> {
  static const int _pageSize = 20;
  final TextEditingController _searchController = TextEditingController();
  bool isLoading = true;
  bool isLoadingMore = false;
  bool hasMorePages = false;
  int currentPage = 1;
  int totalSubjectsCount = 0;
  int totalActiveSubjects = 0;
  int totalInactiveSubjects = 0;
  List<SubjectAdminModel> subjects = [];
  Logger logger = Logger();
  String? selectedStatus;
  String selectedSort = 'name_asc';
  Timer? _searchDebounce;

  List<SubjectAdminModel> get filteredSubjects => subjects;

  int get activeSubjects => totalActiveSubjects;

  int get activeFilterCount {
    return [
      if (_searchController.text.trim().isNotEmpty) _searchController.text,
      selectedStatus,
    ].length;
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
    loadSubjects();
  }

  void _handleSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      loadSubjects();
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
    loadSubjects();
  }

  List<List<Object?>> _subjectExportRows() {
    return filteredSubjects
        .map(
          (subject) => [
            subject.name,
            subject.active == 1 ? 'Ativa' : 'Inativa',
            subject.createdAt,
          ],
        )
        .toList();
  }

  Future<void> _exportSubjectsCsv() async {
    final result = await CsvExportService.exportRows(
      filePrefix: 'disciplinas',
      title: 'Disciplinas',
      subject: 'Disciplinas',
      shareText: 'Exportação CSV da lista de disciplinas.',
      headers: const ['Nome', 'Status', 'Criado em'],
      rows: _subjectExportRows(),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));
  }

  Future<void> _exportSubjectsPdf() async {
    final result = await PdfExportService.exportTable(
      filePrefix: 'disciplinas',
      title: 'Disciplinas',
      subject: 'Disciplinas',
      shareText: 'Exportação PDF da lista de disciplinas.',
      headers: const ['Nome', 'Status', 'Criado em'],
      rows: _subjectExportRows(),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));
  }

  Future<void> loadSubjects({bool loadMore = false}) async {
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
      final response = await ApiService.getSubjectsAdmin(
        schoolId: user.schoolId,
        page: nextPage,
        pageSize: _pageSize,
        search: _searchController.text,
        status: selectedStatus,
        sort: selectedSort,
      );

      if (response['success'] == true) {
        final List data = response['data'];
        final fetchedSubjects = data
            .map((e) => SubjectAdminModel.fromJson(e))
            .toList();
        final meta = response['meta'] as Map<String, dynamic>? ?? const {};
        final summary = meta['summary'] as Map<String, dynamic>? ?? const {};

        subjects = loadMore
            ? [...subjects, ...fetchedSubjects]
            : fetchedSubjects;
        currentPage = nextPage;
        totalSubjectsCount =
            (meta['total'] as num?)?.toInt() ?? subjects.length;
        totalActiveSubjects =
            (summary['active_count'] as num?)?.toInt() ??
            subjects.where((subject) => subject.active == 1).length;
        totalInactiveSubjects =
            (summary['inactive_count'] as num?)?.toInt() ??
            (totalSubjectsCount - totalActiveSubjects);
        hasMorePages = meta['has_next_page'] == true;
      }
    } catch (e) {
      logger.i('ERRO AO CARREGAR DISCIPLINAS V2: $e');
    }

    if (!mounted) return;

    setState(() {
      isLoading = false;
      isLoadingMore = false;
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
        actions: [
          AdminExportMenuButton(
            onExportCsv: _exportSubjectsCsv,
            onExportPdf: _exportSubjectsPdf,
          ),
        ],
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
                        value: totalSubjectsCount.toString(),
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
                        value: totalInactiveSubjects.toString(),
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
                              labelText: 'Buscar disciplina',
                              hintText: 'Nome da disciplina',
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
                                    loadSubjects();
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
                                    loadSubjects();
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
                  if (totalSubjectsCount == 0 && activeFilterCount == 0)
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
                    AdminPaginatedList<SubjectAdminModel>(
                      items: filteredSubjects,
                      resetKey:
                          '$currentPage|$selectedSort|${selectedStatus ?? ''}|${_searchController.text.trim().toLowerCase()}',
                      summaryLabel: 'disciplinas',
                      totalCount: totalSubjectsCount,
                      hasMoreExternal: hasMorePages,
                      isLoadingMore: isLoadingMore,
                      onLoadMore: () => loadSubjects(loadMore: true),
                      itemBuilder: (context, subject) {
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
                      },
                    ),
                ],
              ),
            ),
    );
  }
}
