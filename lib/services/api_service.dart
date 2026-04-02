import 'package:logger/logger.dart';

import 'api_client.dart';

class ApiService {
  static const String _defaultBaseUrl = 'https://api.reservaescolar.app.br';
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: _defaultBaseUrl,
  );
  static const Duration _timeout = Duration(seconds: 10);
  static const Duration _longTimeout = Duration(seconds: 30);
  static final Logger logger = Logger();
  static final ApiClient _client = ApiClient(baseUrl: baseUrl, logger: logger);

  static void setAuthToken(String? authToken) {
    _client.setAuthToken(authToken);
  }

  static void clearAuthToken() {
    _client.clearAuthToken();
  }

  static Future<Map<String, dynamic>> _getJson(
    String path, {
    required String requestName,
    Map<String, dynamic>? queryParameters,
    Duration timeout = _timeout,
  }) async {
    return _client.getJson(
      path,
      requestName: requestName,
      queryParameters: queryParameters,
      timeout: timeout,
    );
  }

  static Future<Map<String, dynamic>> _postJson(
    String path, {
    required String requestName,
    required Map<String, dynamic> body,
    bool includeJsonContentType = true,
    Duration timeout = _timeout,
  }) async {
    return _client.postJson(
      path,
      requestName: requestName,
      body: body,
      includeJsonContentType: includeJsonContentType,
      timeout: timeout,
    );
  }

  static Future<Map<String, dynamic>> login({
    required String schoolCode,
    required String email,
    required String password,
  }) async {
    return _postJson(
      'login.php',
      requestName: 'LOGIN V2',
      body: {'school_code': schoolCode, 'email': email, 'password': password},
    );
  }

  static Future<Map<String, dynamic>> logout() async {
    return _postJson('logout.php', requestName: 'LOGOUT V2', body: const {});
  }

  static Future<Map<String, dynamic>> getNotifications({
    required int schoolId,
    int? page,
    int? pageSize,
    bool unreadOnly = false,
  }) async {
    final queryParameters = <String, dynamic>{'school_id': schoolId};
    if (page != null) queryParameters['page'] = page;
    if (pageSize != null) queryParameters['page_size'] = pageSize;
    if (unreadOnly) queryParameters['unread_only'] = 1;

    return _getJson(
      'get_notifications.php',
      requestName: 'GET NOTIFICATIONS V2',
      queryParameters: queryParameters,
    );
  }

  static Future<Map<String, dynamic>> getUnreadNotificationCount({
    required int schoolId,
  }) async {
    return _getJson(
      'get_notifications_unread_count.php',
      requestName: 'GET NOTIFICATIONS UNREAD COUNT V2',
      queryParameters: {'school_id': schoolId},
    );
  }

  static Future<Map<String, dynamic>> markNotificationRead({
    required int schoolId,
    required int notificationId,
  }) async {
    return _postJson(
      'mark_notification_read.php',
      requestName: 'MARK NOTIFICATION READ V2',
      body: {'school_id': schoolId, 'notification_id': notificationId},
    );
  }

  static Future<Map<String, dynamic>> markAllNotificationsRead({
    required int schoolId,
  }) async {
    return _postJson(
      'mark_all_notifications_read.php',
      requestName: 'MARK ALL NOTIFICATIONS READ V2',
      body: {'school_id': schoolId},
    );
  }

  static Future<Map<String, dynamic>> changeMyPassword({
    required int schoolId,
    required int userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    return _postJson(
      'change_my_password.php',
      requestName: 'CHANGE MY PASSWORD V2',
      body: {
        'school_id': schoolId,
        'user_id': userId,
        'current_password': currentPassword,
        'new_password': newPassword,
      },
    );
  }

  static Future<Map<String, dynamic>> registerSchool({
    required String schoolName,
    required String schoolCode,
    required String schoolPassword,
    required String technicianName,
    required String technicianEmail,
    required String technicianPassword,
    required int chromebooksCount,
    required int audiovisualCount,
    required int spacesCount,
    required List<String> classGroups,
    required List<String> subjects,
    required int lessonCount,
  }) async {
    return _postJson(
      'register_school.php',
      requestName: 'REGISTER SCHOOL V2',
      body: {
        'school_name': schoolName,
        'school_code': schoolCode,
        'school_password': schoolPassword,
        'technician_name': technicianName,
        'technician_email': technicianEmail,
        'technician_password': technicianPassword,
        'chromebooks_count': chromebooksCount,
        'audiovisual_count': audiovisualCount,
        'spaces_count': spacesCount,
        'class_groups': classGroups,
        'subjects': subjects,
        'lesson_count': lessonCount,
      },
    );
  }

  static Future<Map<String, dynamic>> getResources({
    required int schoolId,
  }) async {
    return _getJson(
      'get_resources.php',
      requestName: 'RESOURCES V2',
      queryParameters: {'school_id': schoolId},
    );
  }

  static Future<Map<String, dynamic>> getClassGroups({
    required int schoolId,
  }) async {
    return _getJson(
      'get_class_groups.php',
      requestName: 'CLASS GROUPS V2',
      queryParameters: {'school_id': schoolId},
    );
  }

  static Future<Map<String, dynamic>> getSubjects({
    required int schoolId,
  }) async {
    return _getJson(
      'get_subjects.php',
      requestName: 'SUBJECTS V2',
      queryParameters: {'school_id': schoolId},
    );
  }

  static Future<Map<String, dynamic>> getAvailableLessons({
    required int schoolId,
    required int resourceId,
    required String bookingDate,
  }) async {
    return _getJson(
      'get_available_lessons.php',
      requestName: 'AVAILABLE LESSONS V2',
      queryParameters: {
        'school_id': schoolId,
        'resource_id': resourceId,
        'booking_date': bookingDate,
      },
    );
  }

  static Future<Map<String, dynamic>> createBooking({
    required int schoolId,
    required int resourceId,
    required int userId,
    required int classGroupId,
    required int subjectId,
    required String bookingDate,
    required String purpose,
    required List<int> lessonIds,
  }) async {
    return _postJson(
      'create_booking.php',
      requestName: 'CREATE BOOKING V2',
      body: {
        'school_id': schoolId,
        'resource_id': resourceId,
        'user_id': userId,
        'class_group_id': classGroupId,
        'subject_id': subjectId,
        'booking_date': bookingDate,
        'purpose': purpose,
        'lesson_ids': lessonIds,
      },
      timeout: _longTimeout,
    );
  }

  static Future<Map<String, dynamic>> getResourceCategories() async {
    return _getJson(
      'get_resource_categories.php',
      requestName: 'RESOURCE CATEGORIES V2',
    );
  }

  static Future<Map<String, dynamic>> getResourcesAdmin({
    required int schoolId,
    int? page,
    int? pageSize,
    String? search,
    String? status,
    String? category,
    String? sort,
  }) async {
    final queryParameters = <String, dynamic>{
      'school_id': schoolId,
      'only_active': 0,
    };
    if (page != null) queryParameters['page'] = page;
    if (pageSize != null) queryParameters['page_size'] = pageSize;
    if (search != null && search.trim().isNotEmpty) {
      queryParameters['search'] = search.trim();
    }
    if (status != null && status.isNotEmpty) queryParameters['status'] = status;
    if (category != null && category.isNotEmpty) {
      queryParameters['category'] = category;
    }
    if (sort != null && sort.isNotEmpty) queryParameters['sort'] = sort;

    return _getJson(
      'get_resources.php',
      requestName: 'RESOURCES ADMIN V2',
      queryParameters: queryParameters,
    );
  }

  static Future<Map<String, dynamic>> createResource({
    required int schoolId,
    required int userId,
    required String name,
    required int categoryId,
  }) async {
    return _postJson(
      'create_resource.php',
      requestName: 'CREATE RESOURCE V2',
      body: {
        'school_id': schoolId,
        'user_id': userId,
        'name': name,
        'category_id': categoryId,
      },
    );
  }

  static Future<Map<String, dynamic>> updateResource({
    required int schoolId,
    required int userId,
    required int resourceId,
    required String name,
    required int categoryId,
  }) async {
    return _postJson(
      'update_resource.php',
      requestName: 'UPDATE RESOURCE V2',
      body: {
        'school_id': schoolId,
        'user_id': userId,
        'resource_id': resourceId,
        'name': name,
        'category_id': categoryId,
      },
    );
  }

  static Future<Map<String, dynamic>> toggleResourceStatus({
    required int schoolId,
    required int userId,
    required int resourceId,
  }) async {
    return _postJson(
      'toggle_resource_status.php',
      requestName: 'TOGGLE RESOURCE V2',
      body: {
        'school_id': schoolId,
        'user_id': userId,
        'resource_id': resourceId,
      },
    );
  }

  static Future<Map<String, dynamic>> getTeachers({
    required int schoolId,
    int? page,
    int? pageSize,
    String? search,
    String? status,
    String? sort,
  }) async {
    final queryParameters = <String, dynamic>{'school_id': schoolId};
    if (page != null) queryParameters['page'] = page;
    if (pageSize != null) queryParameters['page_size'] = pageSize;
    if (search != null && search.trim().isNotEmpty) {
      queryParameters['search'] = search.trim();
    }
    if (status != null && status.isNotEmpty) queryParameters['status'] = status;
    if (sort != null && sort.isNotEmpty) queryParameters['sort'] = sort;

    return _getJson(
      'get_teachers.php',
      requestName: 'TEACHERS V2',
      queryParameters: queryParameters,
    );
  }

  static Future<Map<String, dynamic>> createTeacher({
    required int schoolId,
    required int userId,
    required String name,
    required String email,
    required String password,
  }) async {
    return _postJson(
      'create_teacher.php',
      requestName: 'CREATE TEACHER V2',
      body: {
        'school_id': schoolId,
        'user_id': userId,
        'name': name,
        'email': email,
        'password': password,
      },
    );
  }

  static Future<Map<String, dynamic>> updateTeacher({
    required int schoolId,
    required int userId,
    required int teacherId,
    required String name,
    required String email,
  }) async {
    return _postJson(
      'update_teacher.php',
      requestName: 'UPDATE TEACHER V2',
      body: {
        'school_id': schoolId,
        'user_id': userId,
        'teacher_id': teacherId,
        'name': name,
        'email': email,
      },
    );
  }

  static Future<Map<String, dynamic>> toggleTeacherStatus({
    required int schoolId,
    required int userId,
    required int teacherId,
  }) async {
    return _postJson(
      'toggle_teacher_status.php',
      requestName: 'TOGGLE TEACHER V2',
      body: {'school_id': schoolId, 'user_id': userId, 'teacher_id': teacherId},
    );
  }

  static Future<Map<String, dynamic>> resetTeacherPassword({
    required int schoolId,
    required int userId,
    required int teacherId,
    required String newPassword,
  }) async {
    return _postJson(
      'reset_teacher_password.php',
      requestName: 'RESET TEACHER PASSWORD V2',
      body: {
        'school_id': schoolId,
        'user_id': userId,
        'teacher_id': teacherId,
        'new_password': newPassword,
      },
    );
  }

  static Future<Map<String, dynamic>> getClassGroupsAdmin({
    required int schoolId,
    int? page,
    int? pageSize,
    String? search,
    String? status,
    String? sort,
  }) async {
    final queryParameters = <String, dynamic>{'school_id': schoolId};
    if (page != null) queryParameters['page'] = page;
    if (pageSize != null) queryParameters['page_size'] = pageSize;
    if (search != null && search.trim().isNotEmpty) {
      queryParameters['search'] = search.trim();
    }
    if (status != null && status.isNotEmpty) queryParameters['status'] = status;
    if (sort != null && sort.isNotEmpty) queryParameters['sort'] = sort;

    return _getJson(
      'get_class_groups_admin.php',
      requestName: 'CLASS GROUPS ADMIN V2',
      queryParameters: queryParameters,
    );
  }

  static Future<Map<String, dynamic>> createClassGroup({
    required int schoolId,
    required int userId,
    required String name,
  }) async {
    return _postJson(
      'create_class_group.php',
      requestName: 'CREATE CLASS GROUP V2',
      body: {'school_id': schoolId, 'user_id': userId, 'name': name},
    );
  }

  static Future<Map<String, dynamic>> updateClassGroup({
    required int schoolId,
    required int userId,
    required int classGroupId,
    required String name,
  }) async {
    return _postJson(
      'update_class_group.php',
      requestName: 'UPDATE CLASS GROUP V2',
      body: {
        'school_id': schoolId,
        'user_id': userId,
        'class_group_id': classGroupId,
        'name': name,
      },
    );
  }

  static Future<Map<String, dynamic>> toggleClassGroupStatus({
    required int schoolId,
    required int userId,
    required int classGroupId,
  }) async {
    return _postJson(
      'toggle_class_group_status.php',
      requestName: 'TOGGLE CLASS GROUP V2',
      body: {
        'school_id': schoolId,
        'user_id': userId,
        'class_group_id': classGroupId,
      },
    );
  }

  static Future<Map<String, dynamic>> getSubjectsAdmin({
    required int schoolId,
    int? page,
    int? pageSize,
    String? search,
    String? status,
    String? sort,
  }) async {
    final queryParameters = <String, dynamic>{'school_id': schoolId};
    if (page != null) queryParameters['page'] = page;
    if (pageSize != null) queryParameters['page_size'] = pageSize;
    if (search != null && search.trim().isNotEmpty) {
      queryParameters['search'] = search.trim();
    }
    if (status != null && status.isNotEmpty) queryParameters['status'] = status;
    if (sort != null && sort.isNotEmpty) queryParameters['sort'] = sort;

    return _getJson(
      'get_subjects_admin.php',
      requestName: 'SUBJECTS ADMIN V2',
      queryParameters: queryParameters,
    );
  }

  static Future<Map<String, dynamic>> createSubject({
    required int schoolId,
    required int userId,
    required String name,
  }) async {
    return _postJson(
      'create_subject.php',
      requestName: 'CREATE SUBJECT V2',
      body: {'school_id': schoolId, 'user_id': userId, 'name': name},
    );
  }

  static Future<Map<String, dynamic>> updateSubject({
    required int schoolId,
    required int userId,
    required int subjectId,
    required String name,
  }) async {
    return _postJson(
      'update_subject.php',
      requestName: 'UPDATE SUBJECT V2',
      body: {
        'school_id': schoolId,
        'user_id': userId,
        'subject_id': subjectId,
        'name': name,
      },
    );
  }

  static Future<Map<String, dynamic>> toggleSubjectStatus({
    required int schoolId,
    required int userId,
    required int subjectId,
  }) async {
    return _postJson(
      'toggle_subject_status.php',
      requestName: 'TOGGLE SUBJECT V2',
      body: {'school_id': schoolId, 'user_id': userId, 'subject_id': subjectId},
    );
  }

  static Future<Map<String, dynamic>> getLessonSlotsAdmin({
    required int schoolId,
    int? page,
    int? pageSize,
    String? search,
    String? status,
    String? sort,
  }) async {
    final queryParameters = <String, dynamic>{'school_id': schoolId};
    if (page != null) queryParameters['page'] = page;
    if (pageSize != null) queryParameters['page_size'] = pageSize;
    if (search != null && search.trim().isNotEmpty) {
      queryParameters['search'] = search.trim();
    }
    if (status != null && status.isNotEmpty) queryParameters['status'] = status;
    if (sort != null && sort.isNotEmpty) queryParameters['sort'] = sort;

    return _getJson(
      'get_lesson_slots_admin.php',
      requestName: 'LESSON SLOTS ADMIN V2',
      queryParameters: queryParameters,
    );
  }

  static Future<Map<String, dynamic>> createLessonSlot({
    required int schoolId,
    required int userId,
    required int lessonNumber,
    required String label,
    String? startTime,
    String? endTime,
  }) async {
    return _postJson(
      'create_lesson_slot.php',
      requestName: 'CREATE LESSON SLOT V2',
      body: {
        'school_id': schoolId,
        'user_id': userId,
        'lesson_number': lessonNumber,
        'label': label,
        'start_time': startTime ?? '',
        'end_time': endTime ?? '',
      },
    );
  }

  static Future<Map<String, dynamic>> updateLessonSlot({
    required int schoolId,
    required int userId,
    required int lessonSlotId,
    required int lessonNumber,
    required String label,
    String? startTime,
    String? endTime,
  }) async {
    return _postJson(
      'update_lesson_slot.php',
      requestName: 'UPDATE LESSON SLOT V2',
      body: {
        'school_id': schoolId,
        'user_id': userId,
        'lesson_slot_id': lessonSlotId,
        'lesson_number': lessonNumber,
        'label': label,
        'start_time': startTime ?? '',
        'end_time': endTime ?? '',
      },
    );
  }

  static Future<Map<String, dynamic>> toggleLessonSlotStatus({
    required int schoolId,
    required int userId,
    required int lessonSlotId,
  }) async {
    return _postJson(
      'toggle_lesson_slot_status.php',
      requestName: 'TOGGLE LESSON SLOT V2',
      body: {
        'school_id': schoolId,
        'user_id': userId,
        'lesson_slot_id': lessonSlotId,
      },
    );
  }

  static Future<Map<String, dynamic>> getAllBookings({
    required int schoolId,
    String? bookingDate,
    String? dateFrom,
    String? dateTo,
    int? page,
    int? pageSize,
    String? search,
    String? status,
    String? teacher,
    String? resource,
    String? classGroup,
    String? sort,
    bool includeFullSummary = true,
  }) async {
    final queryParameters = <String, dynamic>{'school_id': schoolId};
    if (bookingDate != null && bookingDate.isNotEmpty) {
      queryParameters['booking_date'] = bookingDate;
    }
    if (dateFrom != null && dateFrom.isNotEmpty) {
      queryParameters['date_from'] = dateFrom;
    }
    if (dateTo != null && dateTo.isNotEmpty) {
      queryParameters['date_to'] = dateTo;
    }
    if (page != null) queryParameters['page'] = page;
    if (pageSize != null) queryParameters['page_size'] = pageSize;
    if (search != null && search.trim().isNotEmpty) {
      queryParameters['search'] = search.trim();
    }
    if (status != null && status.isNotEmpty) queryParameters['status'] = status;
    if (teacher != null && teacher.isNotEmpty) {
      queryParameters['teacher'] = teacher;
    }
    if (resource != null && resource.isNotEmpty) {
      queryParameters['resource'] = resource;
    }
    if (classGroup != null && classGroup.isNotEmpty) {
      queryParameters['class_group'] = classGroup;
    }
    if (sort != null && sort.isNotEmpty) queryParameters['sort'] = sort;
    queryParameters['summary_mode'] = includeFullSummary ? 'full' : 'simple';

    return _getJson(
      'get_all_bookings.php',
      requestName: 'ALL BOOKINGS V2',
      queryParameters: queryParameters,
      timeout: _longTimeout,
    );
  }

  static Future<Map<String, dynamic>> cancelBooking({
    required int schoolId,
    required int bookingId,
    required int userId,
  }) async {
    return _postJson(
      'cancel_booking.php',
      requestName: 'CANCEL BOOKING V2',
      body: {'school_id': schoolId, 'booking_id': bookingId, 'user_id': userId},
    );
  }

  static Future<Map<String, dynamic>> completeBooking({
    required int schoolId,
    required int bookingId,
    required int userId,
    String? completionFeedback,
  }) async {
    return _postJson(
      'complete_booking.php',
      requestName: 'COMPLETE BOOKING V2',
      body: {
        'school_id': schoolId,
        'booking_id': bookingId,
        'user_id': userId,
        'completion_feedback': completionFeedback?.trim(),
      },
    );
  }

  static Future<Map<String, dynamic>> getMyBookings({
    required int schoolId,
    required int userId,
    int? page,
    int? pageSize,
    String? search,
    String? status,
    String? sort,
  }) async {
    final queryParameters = <String, dynamic>{
      'school_id': schoolId,
      'user_id': userId,
    };
    if (page != null) queryParameters['page'] = page;
    if (pageSize != null) queryParameters['page_size'] = pageSize;
    if (search != null && search.trim().isNotEmpty) {
      queryParameters['search'] = search.trim();
    }
    if (status != null && status.isNotEmpty) queryParameters['status'] = status;
    if (sort != null && sort.isNotEmpty) queryParameters['sort'] = sort;

    return _getJson(
      'get_my_bookings.php',
      requestName: 'MY BOOKINGS V2',
      queryParameters: queryParameters,
      timeout: _longTimeout,
    );
  }
}
