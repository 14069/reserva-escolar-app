import 'dart:collection';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

import '../models/api_result.dart';
import '../models/class_group_model.dart';
import '../models/lesson_slot_model.dart';
import '../models/resource_model.dart';
import '../models/subject_model.dart';
import '../services/api_service.dart';
import '../utils/app_formatters.dart';

sealed class NewBookingOutcome {}

class NewBookingSuccess extends NewBookingOutcome {
  final int resourceId;
  final String resourceCategory;
  final int lessonCount;
  NewBookingSuccess({
    required this.resourceId,
    required this.resourceCategory,
    required this.lessonCount,
  });
}

class NewBookingConflict extends NewBookingOutcome {
  final String message;
  NewBookingConflict(this.message);
}

class NewBookingFailure extends NewBookingOutcome {
  final String message;
  NewBookingFailure(this.message);
}

class NewBookingProvider extends ChangeNotifier {
  NewBookingProvider({required int schoolId, required int userId})
      : _schoolId = schoolId,
        _userId = userId;

  final int _schoolId;
  final int _userId;
  final _logger = Logger();

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

  final Set<int> _selectedLessonIds = {};
  Set<int> get selectedLessonIds => UnmodifiableSetView(_selectedLessonIds);

  CancelToken? _lessonsCancelToken;
  int _lessonsRequestId = 0;
  String? _pendingIdempotencyKey;

  String get selectedDateLabel {
    if (selectedDate == null) return 'Data não selecionada';
    final day = selectedDate!.day.toString().padLeft(2, '0');
    final month = selectedDate!.month.toString().padLeft(2, '0');
    final year = selectedDate!.year.toString();
    return '$day/$month/$year';
  }

  String _formatDate(DateTime date) => AppFormatters.formatApiDate(date);

  void invalidatePurpose() {
    _pendingIdempotencyKey = null;
  }

  Future<void> loadInitialData() async {
    isLoadingInitialData = true;
    notifyListeners();

    try {
      final resourcesFuture = ApiService.getResourcesList(schoolId: _schoolId);
      final classGroupsFuture = ApiService.getClassGroupsList(schoolId: _schoolId);
      final subjectsFuture = ApiService.getSubjectsList(schoolId: _schoolId);

      final resourcesResp = await resourcesFuture;
      final classGroupsResp = await classGroupsFuture;
      final subjectsResp = await subjectsFuture;

      resources = resourcesResp.success ? resourcesResp.items : const [];
      classGroups = classGroupsResp.success ? classGroupsResp.items : const [];
      subjects = subjectsResp.success ? subjectsResp.items : const [];

      if (resources.isNotEmpty) selectedResource = resources.first;
      if (classGroups.isNotEmpty) selectedClassGroup = classGroups.first;
      if (subjects.isNotEmpty) selectedSubject = subjects.first;
    } catch (e) {
      _logger.e('loadInitialData error: $e');
    }

    isLoadingInitialData = false;
    notifyListeners();
  }

  void selectDate(DateTime date) {
    selectedDate = date;
    _selectedLessonIds.clear();
    availableLessons = [];
    lessonsLoadError = null;
    _pendingIdempotencyKey = null;
    notifyListeners();
    loadAvailableLessons();
  }

  void selectResource(ResourceModel? resource) {
    selectedResource = resource;
    _selectedLessonIds.clear();
    availableLessons = [];
    lessonsLoadError = null;
    _pendingIdempotencyKey = null;
    notifyListeners();
    if (selectedDate != null) loadAvailableLessons();
  }

  void selectClassGroup(ClassGroupModel? group) {
    selectedClassGroup = group;
    _pendingIdempotencyKey = null;
    notifyListeners();
  }

  void selectSubject(SubjectModel? subject) {
    selectedSubject = subject;
    _pendingIdempotencyKey = null;
    notifyListeners();
  }

  void toggleLesson(int id, bool selected) {
    if (selected) {
      _selectedLessonIds.add(id);
    } else {
      _selectedLessonIds.remove(id);
    }
    _pendingIdempotencyKey = null;
    notifyListeners();
  }

  Future<void> loadAvailableLessons() async {
    if (selectedResource == null || selectedDate == null) return;

    final requestId = ++_lessonsRequestId;
    final resourceId = selectedResource!.id;
    final bookingDate = _formatDate(selectedDate!);

    _lessonsCancelToken?.cancel();
    final cancelToken = CancelToken();
    _lessonsCancelToken = cancelToken;

    isLoadingLessons = true;
    lessonsLoadError = null;
    notifyListeners();

    try {
      final response = await ApiService.getAvailableLessonsList(
        schoolId: _schoolId,
        resourceId: resourceId,
        bookingDate: bookingDate,
        cancelToken: cancelToken,
      );

      if (!_isLatestRequest(requestId: requestId, resourceId: resourceId, bookingDate: bookingDate) ||
          response.message == 'Requisição cancelada.') {
        return;
      }

      if (response.success) {
        availableLessons = response.items;
        final availableIds = response.items.map((l) => l.id).toSet();
        final prev = Set<int>.from(_selectedLessonIds);
        _selectedLessonIds.retainAll(availableIds);
        if (!_sameSet(prev, _selectedLessonIds)) _pendingIdempotencyKey = null;
        lessonsLoadError = null;
      } else {
        availableLessons = [];
        lessonsLoadError = response.message ?? 'Não foi possível carregar os horários.';
      }
    } catch (e) {
      if (!_isLatestRequest(requestId: requestId, resourceId: resourceId, bookingDate: bookingDate)) return;
      _logger.e('loadAvailableLessons error: $e');
      availableLessons = [];
      lessonsLoadError = 'Não foi possível carregar os horários.';
    }

    if (!_isLatestRequest(requestId: requestId, resourceId: resourceId, bookingDate: bookingDate)) return;

    isLoadingLessons = false;
    notifyListeners();
  }

  Future<NewBookingOutcome> submitBooking({required String purpose}) async {
    if (selectedResource == null ||
        selectedClassGroup == null ||
        selectedSubject == null ||
        selectedDate == null) {
      return NewBookingFailure('Preencha todos os campos obrigatórios.');
    }
    if (_selectedLessonIds.isEmpty) {
      return NewBookingFailure('Selecione ao menos uma aula.');
    }

    isLoading = true;
    notifyListeners();

    try {
      final idempotencyKey = _pendingIdempotencyKey ?? _generateIdempotencyKey();
      _pendingIdempotencyKey = idempotencyKey;

      final response = await ApiService.createBookingResult(
        schoolId: _schoolId,
        resourceId: selectedResource!.id,
        userId: _userId,
        classGroupId: selectedClassGroup!.id,
        subjectId: selectedSubject!.id,
        bookingDate: _formatDate(selectedDate!),
        purpose: purpose,
        lessonIds: _selectedLessonIds.toList()..sort(),
        idempotencyKey: idempotencyKey,
      );

      if (_isBookingConflict(response)) {
        await loadAvailableLessons();
        isLoading = false;
        notifyListeners();
        return NewBookingConflict(
          response.message ??
              'Esse horário acabou de ser reservado por outro professor. Atualizamos a disponibilidade para você.',
        );
      }

      isLoading = false;
      notifyListeners();

      if (response.success) {
        return NewBookingSuccess(
          resourceId: selectedResource!.id,
          resourceCategory: selectedResource!.categoryName,
          lessonCount: _selectedLessonIds.length,
        );
      }

      return NewBookingFailure(response.message ?? 'Operação concluída.');
    } catch (e) {
      _logger.e('submitBooking error: $e');
      isLoading = false;
      notifyListeners();
      return NewBookingFailure('Erro ao criar agendamento.');
    }
  }

  bool _isLatestRequest({
    required int requestId,
    required int resourceId,
    required String bookingDate,
  }) {
    return requestId == _lessonsRequestId &&
        selectedResource?.id == resourceId &&
        selectedDate != null &&
        _formatDate(selectedDate!) == bookingDate;
  }

  bool _isBookingConflict(ApiActionResult response) {
    if (response.statusCode == 409) return true;
    final msg = (response.message ?? '').toLowerCase();
    const hints = [
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
    return hints.any(msg.contains);
  }

  bool _sameSet(Set<int> a, Set<int> b) {
    if (a.length != b.length) return false;
    return a.every(b.contains);
  }

  String _generateIdempotencyKey() {
    final random = Random.secure();
    final now = DateTime.now().microsecondsSinceEpoch;
    final nonce = List.generate(
      4,
      (_) => random.nextInt(0x100000000).toRadixString(16).padLeft(8, '0'),
    ).join();
    return 'booking-$now-$nonce';
  }

  @override
  void dispose() {
    _lessonsCancelToken?.cancel();
    super.dispose();
  }
}
