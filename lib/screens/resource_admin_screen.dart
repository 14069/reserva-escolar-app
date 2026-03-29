import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import '../models/resource_category_model.dart';
import '../models/resource_model.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/admin_ui.dart';

class ResourceAdminScreen extends StatefulWidget {
  const ResourceAdminScreen({super.key});

  @override
  State<ResourceAdminScreen> createState() => _ResourceAdminScreenState();
}

class _ResourceAdminScreenState extends State<ResourceAdminScreen> {
  final TextEditingController _searchController = TextEditingController();
  Logger logger = Logger();
  bool isLoading = true;
  List<ResourceModel> resources = [];
  List<ResourceCategoryModel> categories = [];
  String? selectedCategory;
  String? selectedStatus;

  List<ResourceModel> get filteredResources {
    final query = _searchController.text.trim().toLowerCase();

    return resources.where((resource) {
      final matchesCategory =
          selectedCategory == null || resource.categoryName == selectedCategory;
      final matchesStatus =
          selectedStatus == null ||
          (selectedStatus == 'active' && resource.active == 1) ||
          (selectedStatus == 'inactive' && resource.active != 1);
      final matchesQuery =
          query.isEmpty ||
          resource.name.toLowerCase().contains(query) ||
          formatCategory(resource.categoryName).toLowerCase().contains(query);

      return matchesCategory && matchesStatus && matchesQuery;
    }).toList();
  }

  int get activeResources {
    return filteredResources.where((resource) => resource.active == 1).length;
  }

  int get activeFilterCount {
    return [
      if (_searchController.text.trim().isNotEmpty) _searchController.text,
      selectedCategory,
      selectedStatus,
    ].length;
  }

  List<String> get categoryOptions =>
      categories.map((category) => category.name).toList()
        ..sort((a, b) => formatCategory(a).compareTo(formatCategory(b)));

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
    loadData();
  }

  void _handleSearchChanged() {
    if (!mounted) return;
    setState(() {});
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

  void clearFilters() {
    setState(() {
      _searchController.clear();
      selectedCategory = null;
      selectedStatus = null;
    });
  }

  Future<void> loadData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) return;

    setState(() {
      isLoading = true;
    });

    try {
      final resourcesResponse = await ApiService.getResourcesAdmin(
        schoolId: user.schoolId,
      );
      final categoriesResponse = await ApiService.getResourceCategories();

      if (resourcesResponse['success'] == true) {
        final List data = resourcesResponse['data'];
        resources = data.map((e) => ResourceModel.fromJson(e)).toList();
      }

      if (categoriesResponse['success'] == true) {
        final List data = categoriesResponse['data'];
        categories = data
            .map((e) => ResourceCategoryModel.fromJson(e))
            .toList();
      }
    } catch (e) {
      logger.i('ERRO AO CARREGAR RECURSOS ADMIN: $e');
    }

    if (!mounted) return;

    setState(() {
      isLoading = false;
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

                          Map<String, dynamic> response;

                          if (resource == null) {
                            response = await ApiService.createResource(
                              schoolId: user.schoolId,
                              userId: user.id,
                              name: name,
                              categoryId: selectedCategory!.id,
                            );
                          } else {
                            response = await ApiService.updateResource(
                              schoolId: user.schoolId,
                              userId: user.id,
                              resourceId: resource.id,
                              name: name,
                              categoryId: selectedCategory!.id,
                            );
                          }

                          if (!mounted) return;

                          navigator.pop();

                          scaffoldMessenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                response['message'] ?? 'Operação concluída.',
                              ),
                            ),
                          );

                          if (response['success'] == true) {
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

    final response = await ApiService.toggleResourceStatus(
      schoolId: user.schoolId,
      userId: user.id,
      resourceId: resource.id,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(response['message'] ?? 'Operação concluída.')),
    );

    if (response['success'] == true) {
      loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user!;
    final isCompact = MediaQuery.of(context).size.width < 380;

    return Scaffold(
      appBar: AppBar(
        title: Text(isCompact ? 'Recursos' : 'Recursos - ${user.schoolName}'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: categories.isEmpty ? null : () => showResourceDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Novo recurso'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadData,
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
                        value: filteredResources.length.toString(),
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
                                  icon: const Icon(Icons.filter_alt_off_outlined),
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
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
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
                  if (resources.isEmpty)
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
                    ...filteredResources.map((resource) {
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
                    }),
                ],
              ),
            ),
    );
  }
}
