import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'package:dio/dio.dart';

import '../models/class_group_model.dart';
import '../models/lesson_slot_model.dart';
import '../models/api_result.dart';
import '../models/resource_model.dart';
import '../models/subject_model.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/analytics_service.dart';
import '../utils/app_formatters.dart';

class NewBookingScreen extends StatefulWidget {
  const NewBookingScreen({super.key});

  @override
  State<NewBookingScreen> createState() => _NewBookingScreenState();
}

class _NewBookingScreenState extends State<NewBookingScreen> {
  Logger logger = Logger();

  final _formKey = GlobalKey<FormState>();
  final _purposeController = TextEditingController();

  bool isLoading = false;
  bool isLoadingInitialData = true;
  bool isLoadingLessons = false;
  String? lessonsLoadError;

  List<ResourceModel> resources = [];
  List<ClassGroupModel> classGroups = [];
  List<SubjectModel> subjects = [];
  List<LessonSlotModel> availableLessons = [];

  ResourceModel? selectedResource;
  ClassGroupModel? selectedClassGroup;
  SubjectModel? selectedSubject;
  DateTime? selectedDate;
  final Set<int> selectedLessonIds = {};
  CancelToken? _lessonsCancelToken;
  int _lessonsRequestId = 0;
  String? _pendingBookingIdempotencyKey;

  @override
  void initState() {
    super.initState();
    _purposeController.addListener(_invalidatePendingBookingKey);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AnalyticsService.instance.logScreenView(screenName: 'new_booking');
    });
    loadInitialData();
  }

  String formatDate(DateTime date) {
    return AppFormatters.formatApiDate(date);
  }

  Future<void> loadInitialData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) return;

    setState(() {
      isLoadingInitialData = true;
    });

    try {
      final responses = await Future.wait([
        ApiService.getResourcesList(schoolId: user.schoolId),
        ApiService.getClassGroupsList(schoolId: user.schoolId),
        ApiService.getSubjectsList(schoolId: user.schoolId),
      ]);

      final resourcesResponse = responses[0] as ApiItemsResponse<ResourceModel>;
      final classGroupsResponse =
          responses[1] as ApiItemsResponse<ClassGroupModel>;
      final subjectsResponse = responses[2] as ApiItemsResponse<SubjectModel>;

      if (resourcesResponse.success) {
        resources = resourcesResponse.items;
      }

      if (classGroupsResponse.success) {
        classGroups = classGroupsResponse.items;
      }

      if (subjectsResponse.success) {
        subjects = subjectsResponse.items;
      }

      if (resources.isNotEmpty) selectedResource = resources.first;
      if (classGroups.isNotEmpty) selectedClassGroup = classGroups.first;
      if (subjects.isNotEmpty) selectedSubject = subjects.first;
    } catch (e) {
      logger.i('ERRO AO CARREGAR DADOS INICIAIS: $e');
    }

    if (!mounted) return;

    setState(() {
      isLoadingInitialData = false;
    });
  }

  Future<void> pickDate() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
    );

    if (picked != null) {
      setState(() {
        selectedDate = picked;
        selectedLessonIds.clear();
        availableLessons = [];
        lessonsLoadError = null;
      });
      _invalidatePendingBookingKey();

      await loadAvailableLessons();
    }
  }

  Future<void> loadAvailableLessons() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null || selectedResource == null || selectedDate == null) {
      return;
    }

    final requestId = ++_lessonsRequestId;
    final resourceId = selectedResource!.id;
    final bookingDate = formatDate(selectedDate!);

    _lessonsCancelToken?.cancel();
    final cancelToken = CancelToken();
    _lessonsCancelToken = cancelToken;

    setState(() {
      isLoadingLessons = true;
      lessonsLoadError = null;
    });

    try {
      final response = await ApiService.getAvailableLessonsList(
        schoolId: user.schoolId,
        resourceId: resourceId,
        bookingDate: bookingDate,
        cancelToken: cancelToken,
      );

      if (!_isLatestLessonsRequest(
            requestId: requestId,
            resourceId: resourceId,
            bookingDate: bookingDate,
          ) ||
          response.message == 'Requisição cancelada.') {
        return;
      }

      if (response.success) {
        availableLessons = response.items;
        final previousSelectedLessonIds = Set<int>.from(selectedLessonIds);
        final availableLessonIds = response.items.map((lesson) => lesson.id).toSet();
        selectedLessonIds.retainAll(availableLessonIds);
        if (!_sameLessonSelection(previousSelectedLessonIds, selectedLessonIds)) {
          _invalidatePendingBookingKey();
        }
        lessonsLoadError = null;
      } else {
        availableLessons = [];
        lessonsLoadError =
            response.message ?? 'Não foi possível carregar os horários.';
      }
    } catch (e) {
      if (!_isLatestLessonsRequest(
        requestId: requestId,
        resourceId: resourceId,
        bookingDate: bookingDate,
      )) {
        return;
      }

      availableLessons = [];
      lessonsLoadError = 'Não foi possível carregar os horários.';
      logger.i('ERRO AO CARREGAR AULAS DISPONÍVEIS: $e');
    }

    if (!_isLatestLessonsRequest(
      requestId: requestId,
      resourceId: resourceId,
      bookingDate: bookingDate,
    )) {
      return;
    }

    setState(() {
      isLoadingLessons = false;
    });
  }

  Future<void> saveBooking() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) return;

    if (selectedResource == null ||
        selectedClassGroup == null ||
        selectedSubject == null ||
        selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha todos os campos obrigatórios.')),
      );
      return;
    }

    if (selectedLessonIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione ao menos uma aula.')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final idempotencyKey =
          _pendingBookingIdempotencyKey ?? _generateBookingIdempotencyKey();
      _pendingBookingIdempotencyKey = idempotencyKey;

      final response = await ApiService.createBookingResult(
        schoolId: user.schoolId,
        resourceId: selectedResource!.id,
        userId: user.id,
        classGroupId: selectedClassGroup!.id,
        subjectId: selectedSubject!.id,
        bookingDate: formatDate(selectedDate!),
        purpose: _purposeController.text.trim(),
        lessonIds: selectedLessonIds.toList()..sort(),
        idempotencyKey: idempotencyKey,
      );

      if (!mounted) return;

      if (_isBookingConflict(response)) {
        await loadAvailableLessons();
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response.message ??
                  'Esse horário acabou de ser reservado por outro professor. Atualizamos a disponibilidade para você.',
            ),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response.message ?? 'Operação concluída.')),
      );

      if (response.success) {
        await AnalyticsService.instance.logBookingCreated(
          resourceId: selectedResource!.id,
          resourceCategory: selectedResource!.categoryName,
          lessonCount: selectedLessonIds.length,
        );
        if (!mounted) return;
        Navigator.pop(context, true);
        return;
      }
    } catch (e) {
      logger.i('ERRO AO CRIAR AGENDAMENTO: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao criar agendamento.')),
      );
    }

    if (!mounted) return;

    setState(() {
      isLoading = false;
    });
  }

  @override
  void dispose() {
    _purposeController.removeListener(_invalidatePendingBookingKey);
    _lessonsCancelToken?.cancel();
    _purposeController.dispose();
    super.dispose();
  }

  bool _isLatestLessonsRequest({
    required int requestId,
    required int resourceId,
    required String bookingDate,
  }) {
    if (!mounted) return false;
    return requestId == _lessonsRequestId &&
        selectedResource?.id == resourceId &&
        selectedDate != null &&
        formatDate(selectedDate!) == bookingDate;
  }

  bool _isBookingConflict(ApiActionResult response) {
    if (response.statusCode == 409) return true;

    final normalizedMessage = (response.message ?? '').toLowerCase();
    const conflictHints = [
      'conflito',
      'conflit',
      'ocupado',
      'ocupada',
      'indisponivel',
      'indisponível',
      'reservado',
      'reservada',
      'ja foi reservado',
      'já foi reservado',
      'horario indisponivel',
      'horário indisponível',
    ];

    return conflictHints.any(normalizedMessage.contains);
  }

  bool _sameLessonSelection(Set<int> previous, Set<int> current) {
    if (previous.length != current.length) return false;
    for (final lessonId in previous) {
      if (!current.contains(lessonId)) return false;
    }
    return true;
  }

  void _invalidatePendingBookingKey() {
    _pendingBookingIdempotencyKey = null;
  }

  String _generateBookingIdempotencyKey() {
    final random = Random.secure();
    final now = DateTime.now().microsecondsSinceEpoch;
    final nonce = List.generate(
      4,
      (_) => random.nextInt(0x100000000).toRadixString(16).padLeft(8, '0'),
    ).join();
    return 'booking-$now-$nonce';
  }

  String get selectedDateLabel {
    if (selectedDate == null) return 'Data não selecionada';

    final day = selectedDate!.day.toString().padLeft(2, '0');
    final month = selectedDate!.month.toString().padLeft(2, '0');
    final year = selectedDate!.year.toString();
    return '$day/$month/$year';
  }

  String buildResourceLabel(ResourceModel resource, {bool compact = false}) {
    if (compact) return resource.name;
    return '${resource.name} (${resource.categoryName})';
  }

  Widget _buildDropdownText(String text, {int maxLines = 1}) {
    return Text(text, maxLines: maxLines, overflow: TextOverflow.ellipsis);
  }

  Widget _buildSectionCard({
    required BuildContext context,
    required String step,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
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
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                step,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF5A7069),
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

  Widget _buildSummaryChip({
    required BuildContext context,
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.onPrimary),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLessonsContent(BuildContext context) {
    if (selectedDate == null) {
      return _InfoStateCard(
        icon: Icons.calendar_month_outlined,
        title: 'Escolha uma data primeiro',
        message:
            'As aulas disponíveis aparecem assim que a data da reserva for definida.',
      );
    }

    if (isLoadingLessons) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (lessonsLoadError != null) {
      return _InfoStateCard(
        icon: Icons.wifi_off_outlined,
        title: 'Falha ao carregar horários',
        message: lessonsLoadError!,
      );
    }

    if (availableLessons.isEmpty) {
      return _InfoStateCard(
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
          children: availableLessons.map((lesson) {
            final isSelected = selectedLessonIds.contains(lesson.id);

            return FilterChip(
              label: Text(lesson.label),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    selectedLessonIds.add(lesson.id);
                  } else {
                    selectedLessonIds.remove(lesson.id);
                  }
                  _invalidatePendingBookingKey();
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
        Text(
          selectedLessonIds.isEmpty
              ? 'Selecione pelo menos uma aula para concluir o agendamento.'
              : '${selectedLessonIds.length} aula(s) selecionada(s).',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF5A7069)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 380;
    final horizontalPadding = isCompact ? 14.0 : 16.0;
    final heroPadding = isCompact ? 18.0 : 24.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(isCompact ? 'Novo Agendamento' : 'Novo Agendamento V2'),
      ),
      body: isLoadingInitialData
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
                    Container(
                      padding: EdgeInsets.all(heroPadding),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            colorScheme.primary,
                            const Color(0xFF184E44),
                          ],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Monte sua reserva',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: colorScheme.onPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 8),
                          if (!isCompact)
                            Text(
                              'Escolha o recurso, defina a data e selecione os horários disponíveis em poucos passos.',
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    color: colorScheme.onPrimary.withValues(
                                      alpha: 0.84,
                                    ),
                                    height: 1.4,
                                  ),
                            ),
                          const SizedBox(height: 18),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              if (selectedResource != null)
                                _buildSummaryChip(
                                  context: context,
                                  icon: Icons.widgets_outlined,
                                  label: selectedResource!.name,
                                ),
                              _buildSummaryChip(
                                context: context,
                                icon: Icons.calendar_today_outlined,
                                label: selectedDateLabel,
                              ),
                              _buildSummaryChip(
                                context: context,
                                icon: Icons.schedule,
                                label: '${selectedLessonIds.length} aula(s)',
                              ),
                            ],
                          ),
                        ],
                      ),
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
                            initialValue: selectedResource,
                            isExpanded: true,
                            menuMaxHeight: 320,
                            decoration: const InputDecoration(
                              labelText: 'Recurso',
                              prefixIcon: Icon(Icons.widgets_outlined),
                            ),
                            items: resources.map((resource) {
                              return DropdownMenuItem(
                                value: resource,
                                child: _buildDropdownText(
                                  buildResourceLabel(
                                    resource,
                                    compact: isCompact,
                                  ),
                                  maxLines: 2,
                                ),
                              );
                            }).toList(),
                            selectedItemBuilder: (context) {
                              return resources.map((resource) {
                                return Align(
                                  alignment: Alignment.centerLeft,
                                  child: _buildDropdownText(
                                    buildResourceLabel(resource, compact: true),
                                  ),
                                );
                              }).toList();
                            },
                            onChanged: (value) async {
                              setState(() {
                                selectedResource = value;
                                selectedLessonIds.clear();
                                availableLessons = [];
                                lessonsLoadError = null;
                              });
                              _invalidatePendingBookingKey();

                              if (selectedDate != null) {
                                await loadAvailableLessons();
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: pickDate,
                            child: Ink(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: Colors.white,
                                border: Border.all(
                                  color: const Color(0xFFD6E1DA),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: colorScheme.primary.withValues(
                                        alpha: 0.10,
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(
                                      Icons.calendar_month,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Data da reserva',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          selectedDate == null
                                              ? 'Toque para escolher a data'
                                              : selectedDateLabel,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: const Color(0xFF5A7069),
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                            ),
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
                            initialValue: selectedClassGroup,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Turma',
                              prefixIcon: Icon(Icons.groups_outlined),
                            ),
                            items: classGroups.map((group) {
                              return DropdownMenuItem(
                                value: group,
                                child: _buildDropdownText(
                                  group.name,
                                  maxLines: 2,
                                ),
                              );
                            }).toList(),
                            selectedItemBuilder: (context) {
                              return classGroups.map((group) {
                                return Align(
                                  alignment: Alignment.centerLeft,
                                  child: _buildDropdownText(group.name),
                                );
                              }).toList();
                            },
                            onChanged: (value) {
                              setState(() {
                                selectedClassGroup = value;
                              });
                              _invalidatePendingBookingKey();
                            },
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<SubjectModel>(
                            initialValue: selectedSubject,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Disciplina',
                              prefixIcon: Icon(Icons.menu_book_outlined),
                            ),
                            items: subjects.map((subject) {
                              return DropdownMenuItem(
                                value: subject,
                                child: _buildDropdownText(
                                  subject.name,
                                  maxLines: 2,
                                ),
                              );
                            }).toList(),
                            selectedItemBuilder: (context) {
                              return subjects.map((subject) {
                                return Align(
                                  alignment: Alignment.centerLeft,
                                  child: _buildDropdownText(subject.name),
                                );
                              }).toList();
                            },
                            onChanged: (value) {
                              setState(() {
                                selectedSubject = value;
                              });
                              _invalidatePendingBookingKey();
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
                      child: _buildLessonsContent(context),
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
                              value:
                                  selectedResource?.name ?? 'Não selecionado',
                            ),
                            const SizedBox(height: 10),
                            _BookingSummaryRow(
                              icon: Icons.calendar_today_outlined,
                              label: 'Data',
                              value: selectedDateLabel,
                            ),
                            const SizedBox(height: 10),
                            _BookingSummaryRow(
                              icon: Icons.groups_outlined,
                              label: 'Turma',
                              value:
                                  selectedClassGroup?.name ?? 'Não selecionada',
                            ),
                            const SizedBox(height: 10),
                            _BookingSummaryRow(
                              icon: Icons.schedule,
                              label: 'Aulas',
                              value: selectedLessonIds.isEmpty
                                  ? 'Nenhuma selecionada'
                                  : '${selectedLessonIds.length} aula(s)',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton.icon(
                      onPressed: isLoading ? null : saveBooking,
                      icon: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                              ),
                            )
                          : const Icon(Icons.check_circle_outline),
                      label: Text(
                        isLoading
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAF8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD6E1DA)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 30, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 10),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF5A7069),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: const Color(0xFF5A7069),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
