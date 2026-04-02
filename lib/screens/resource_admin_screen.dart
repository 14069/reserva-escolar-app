import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import '../models/resource_category_model.dart';
import '../models/resource_model.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/csv_export_service.dart';
import '../services/pdf_export_service.dart';
import '../widgets/admin_ui.dart';

class ResourceAdminScreen extends StatefulWidget {
  const ResourceAdminScreen({super.key});

  @override
  State<ResourceAdminScreen> createState() => _ResourceAdminScreenState();
}

class _ResourceAdminScreenState extends State<ResourceAdminScreen> {
  static const int _pageSize = 20;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Logger logger = Logger();
  bool isLoading = true;
  bool isLoadingMore = false;
  bool hasMorePages = false;
  int currentPage = 1;
  int totalResourcesCount = 0;
  int totalActiveResources = 0;
  List<ResourceModel> resources = [];
  List<ResourceCategoryModel> categories = [];
  String? selectedCategory;
  String? selectedStatus;
  String selectedSort = 'name_asc';
  Timer? _searchDebounce;

  List<ResourceModel> get filteredResources => resources;

  int get activeResources => totalActiveResources;

  int get activeFilterCount {
    return [
      if (_searchController.text.trim().isNotEmpty) _searchController.text,
      selectedCategory,
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
            loadData();
          },
        ),
      );
    }

    if (selectedCategory != null) {
      items.add(
        AdminActiveFilterItem(
          label: 'Categoria: ${formatCategory(selectedCategory!)}',
          onRemove: () {
            setState(() {
              selectedCategory = null;
            });
            loadData();
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
            loadData();
          },
        ),
      );
    }

    return items;
  }

  List<String> get categoryOptions =>
      categories.map((category) => category.name).toList()
        ..sort((a, b) => formatCategory(a).compareTo(formatCategory(b)));

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
    loadData();
  }

  void _handleSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      loadData();
    });
  }

  String formatCategory(String category) {
    switch (category) {
      case 'chromebooks':
        return 'Chromebooks';
      case 'audiovisual':
        return 'Audiovisual';
      case 'espacos':
        return 'Espaços';
      default:
        return category;
    }
  }

  String statusLabel(String value) {
    return value == 'active' ? 'Ativo' : 'Inativo';
  }

  String sortLabel(String value) {
    switch (value) {
      case 'name_desc':
        return 'Nome (Z-A)';
      case 'category_asc':
        return 'Categoria';
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
      selectedCategory = null;
      selectedStatus = null;
    });
    loadData();
  }

  List<List<Object?>> _resourceExportRows() {
    return filteredResources
        .map(
          (resource) => [
            resource.name,
            formatCategory(resource.categoryName),
            resource.active == 1 ? 'Ativo' : 'Inativo',
          ],
        )
        .toList();
  }

  Future<void> _exportResourcesCsv() async {
    final result = await CsvExportService.exportRows(
      filePrefix: 'recursos',
      title: 'Recursos',
      subject: 'Recursos',
      shareText: 'Exportação CSV da lista de recursos.',
      headers: const ['Nome', 'Categoria', 'Status'],
      rows: _resourceExportRows(),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));
  }

  Future<void> _exportResourcesPdf() async {
    final result = await PdfExportService.exportTable(
      filePrefix: 'recursos',
      title: 'Recursos',
      subject: 'Recursos',
      shareText: 'Exportação PDF da lista de recursos.',
      headers: const ['Nome', 'Categoria', 'Status'],
      rows: _resourceExportRows(),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));
  }

  Future<void> loadData({bool loadMore = false}) async {
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
      final resourcesResponse = await ApiService.getResourcesAdminPage(
        schoolId: user.schoolId,
        page: nextPage,
        pageSize: _pageSize,
        search: _searchController.text,
        status: selectedStatus,
        category: selectedCategory,
        sort: selectedSort,
      );
      final categoriesResponse = categories.isNotEmpty && loadMore
          ? null
          : await ApiService.getResourceCategoriesList();

      if (resourcesResponse.success) {
        final fetchedResources = resourcesResponse.items;
        final summary = resourcesResponse.summary;
        resources = loadMore
            ? [...resources, ...fetchedResources]
            : fetchedResources;
        currentPage = nextPage;
        totalResourcesCount = resourcesResponse.total == 0
            ? resources.length
            : resourcesResponse.total;
        totalActiveResources =
            summary?.activeCount ??
            resources.where((resource) => resource.active == 1).length;
        hasMorePages = resourcesResponse.hasNextPage;
      }

      if (categoriesResponse != null && categoriesResponse.success) {
        categories = categoriesResponse.items;
      }
    } catch (e) {
      logger.i('ERRO AO CARREGAR RECURSOS ADMIN: $e');
    }

    if (!mounted) return;

    setState(() {
      isLoading = false;
      isLoadingMore = false;
    });
  }

  Future<void> showResourceDialog({ResourceModel? resource}) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) return;
    final formKey = GlobalKey<FormState>();

    final nameController = TextEditingController(text: resource?.name ?? '');
    ResourceCategoryModel? selectedCategory = resource == null
        ? (categories.isNotEmpty ? categories.first : null)
        : categories.firstWhere(
            (c) => c.id == resource.categoryId,
            orElse: () => categories.first,
          );

    final scaffoldMessenger = ScaffoldMessenger.of(context);

    await showDialog(
      context: context,
      builder: (dialogContext) {
        bool saving = false;

        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return AdminFormDialog(
              title: resource == null ? 'Novo recurso' : 'Editar recurso',
              subtitle: resource == null
                  ? 'Cadastre um recurso para disponibilizá-lo nas reservas da escola.'
                  : 'Atualize o nome e a categoria do recurso selecionado.',
              icon: Icons.widgets_outlined,
              content: Form(
                key: formKey,
                child: SizedBox(
                  width: 400,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nome do recurso',
                          prefixIcon: Icon(Icons.drive_file_rename_outline),
                        ),
                        validator: (value) {
                          if ((value?.trim() ?? '').isEmpty) {
                            return 'Informe o nome do recurso';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<ResourceCategoryModel>(
                        initialValue: selectedCategory,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Categoria',
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        items: categories.map((category) {
                          return DropdownMenuItem(
                            value: category,
                            child: Text(formatCategory(category.name)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setModalState(() {
                            selectedCategory = value;
                          });
                        },
                        validator: (value) {
                          if (value == null) {
                            return 'Selecione uma categoria';
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
                  onPressed: saving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final navigator = Navigator.of(dialogContext);
                          if (!(formKey.currentState?.validate() ?? false)) {
                            return;
                          }
                          final name = nameController.text.trim();

                          setModalState(() {
                            saving = true;
                          });

                          final response = resource == null
                              ? await ApiService.createResourceResult(
                                  schoolId: user.schoolId,
                                  userId: user.id,
                                  name: name,
                                  categoryId: selectedCategory!.id,
                                )
                              : await ApiService.updateResourceResult(
                                  schoolId: user.schoolId,
                                  userId: user.id,
                                  resourceId: resource.id,
                                  name: name,
                                  categoryId: selectedCategory!.id,
                                );

                          if (!mounted) return;

                          navigator.pop();

                          scaffoldMessenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                response.message ?? 'Operação concluída.',
                              ),
                            ),
                          );

                          if (response.success) {
                            loadData();
                          }
                        },
                  child: Text(resource == null ? 'Criar' : 'Salvar'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
  }

  Future<void> toggleStatus(ResourceModel resource) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) return;

    final response = await ApiService.toggleResourceStatusResult(
      schoolId: user.schoolId,
      userId: user.id,
      resourceId: resource.id,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(response.message ?? 'Operação concluída.')),
    );

    if (response.success) {
      loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user!;
    final isCompact = MediaQuery.of(context).size.width < 380;
    final showBlockingLoader = isLoading && filteredResources.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(isCompact ? 'Recursos' : 'Recursos - ${user.schoolName}'),
        actions: [
          AdminExportMenuButton(
            onExportCsv: _exportResourcesCsv,
            onExportPdf: _exportResourcesPdf,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: categories.isEmpty ? null : () => showResourceDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Novo recurso'),
      ),
      body: showBlockingLoader
          ? const AdminPageSkeleton()
          : RefreshIndicator(
              onRefresh: loadData,
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
                    title: 'Gerenciar recursos',
                    subtitle:
                        'Cadastre ambientes e equipamentos da escola para facilitar as reservas.',
                    icon: Icons.widgets_outlined,
                  ),
                  const SizedBox(height: 16),
                  AdminStatsPanel(
                    children: [
                      AdminStatCard(
                        label: activeFilterCount > 0 ? 'Exibidos' : 'Total',
                        value: totalResourcesCount.toString(),
                        icon: Icons.inventory_2_outlined,
                        accentColor: const Color(0xFF0F766E),
                      ),
                      AdminStatCard(
                        label: 'Ativos',
                        value: activeResources.toString(),
                        icon: Icons.check_circle_outline,
                        accentColor: const Color(0xFF1D7A6D),
                      ),
                      AdminStatCard(
                        label: 'Categorias',
                        value: categories.length.toString(),
                        icon: Icons.category_outlined,
                        accentColor: const Color(0xFF8A6A10),
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
                              labelText: 'Buscar recurso',
                              hintText: 'Nome ou categoria',
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
                                    'category_asc',
                                    'status',
                                  ],
                                  itemLabelBuilder: sortLabel,
                                  onChanged: (value) {
                                    if (value == null) return;
                                    setState(() {
                                      selectedSort = value;
                                    });
                                    loadData();
                                  },
                                ),
                              ),
                              SizedBox(
                                width: 260,
                                child: AdminDropdownFilter(
                                  label: 'Categoria',
                                  value: selectedCategory,
                                  items: categoryOptions,
                                  itemLabelBuilder: formatCategory,
                                  onChanged: (value) {
                                    setState(() {
                                      selectedCategory = value;
                                    });
                                    loadData();
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
                                    loadData();
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
                  if (totalResourcesCount == 0 && activeFilterCount == 0)
                    const AdminEmptyState(
                      icon: Icons.widgets_outlined,
                      title: 'Nenhum recurso cadastrado.',
                      message:
                          'Crie o primeiro recurso para disponibilizar laboratórios, salas ou equipamentos para reserva.',
                    )
                  else if (filteredResources.isEmpty)
                    const AdminEmptyState(
                      icon: Icons.filter_alt_off_outlined,
                      title: 'Nenhum recurso encontrado.',
                      message:
                          'Ajuste a busca ou limpe os filtros para visualizar outros recursos.',
                    )
                  else
                    AdminPaginatedList<ResourceModel>(
                      items: filteredResources,
                      resetKey:
                          '$currentPage|$selectedSort|${selectedCategory ?? ''}|${selectedStatus ?? ''}|${_searchController.text.trim().toLowerCase()}',
                      summaryLabel: 'recursos',
                      totalCount: totalResourcesCount,
                      hasMoreExternal: hasMorePages,
                      isLoadingMore: isLoadingMore,
                      onLoadMore: () => loadData(loadMore: true),
                      itemBuilder: (context, resource) {
                        final isActive = resource.active == 1;

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
                                          ? Icons.check_circle_outline
                                          : Icons.cancel_outlined,
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
                                          resource.name,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          formatCategory(resource.categoryName),
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
                                        showResourceDialog(resource: resource);
                                      } else if (value == 'toggle') {
                                        toggleStatus(resource);
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
