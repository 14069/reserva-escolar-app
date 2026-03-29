import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/user_model.dart';

class AnalyticsService {
  AnalyticsService._();

  static final AnalyticsService instance = AnalyticsService._();

  bool get isEnabled =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  FirebaseAnalytics? get _analytics =>
      isEnabled ? FirebaseAnalytics.instance : null;

  Future<void> _runSafely(
    Future<void> Function(FirebaseAnalytics analytics) action,
  ) async {
    final analytics = _analytics;
    if (analytics == null) return;

    try {
      await action(analytics);
    } catch (error, stackTrace) {
      debugPrint('AnalyticsService error: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  List<NavigatorObserver> get navigatorObservers {
    final analytics = _analytics;
    if (analytics == null) return const [];

    return [FirebaseAnalyticsObserver(analytics: analytics)];
  }

  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    await _runSafely((analytics) async {
      await analytics.logScreenView(
        screenName: screenName,
        screenClass: screenClass ?? screenName,
      );
    });
  }

  Future<void> logLoginSuccess(UserModel user) async {
    await _runSafely((analytics) async {
      await analytics.setUserId(id: '${user.schoolId}:${user.id}');
      await analytics.setUserProperty(name: 'user_role', value: user.role);
      await analytics.logLogin(loginMethod: 'password');
      await analytics.logEvent(
        name: 'login_success',
        parameters: {
          'role': user.role,
          'school_id': user.schoolId,
        },
      );
    });
  }

  Future<void> logLoginFailure() async {
    await _runSafely((analytics) async {
      await analytics.logEvent(name: 'login_failed');
    });
  }

  Future<void> logLogout() async {
    await _runSafely((analytics) async {
      await analytics.logEvent(name: 'logout');
      await analytics.setUserId(id: null);
      await analytics.setUserProperty(name: 'user_role', value: null);
    });
  }

  Future<void> logOpenSchoolRegistration() async {
    await _runSafely((analytics) async {
      await analytics.logEvent(name: 'open_school_registration');
    });
  }

  Future<void> logSchoolRegistrationCompleted({
    required int classGroupsCount,
    required int subjectsCount,
    required int lessonCount,
  }) async {
    await _runSafely((analytics) async {
      await analytics.logEvent(
        name: 'school_registration_completed',
        parameters: {
          'class_groups_count': classGroupsCount,
          'subjects_count': subjectsCount,
          'lesson_count': lessonCount,
        },
      );
    });
  }

  Future<void> logBookingCreated({
    required int resourceId,
    required String resourceCategory,
    required int lessonCount,
  }) async {
    await _runSafely((analytics) async {
      await analytics.logEvent(
        name: 'booking_created',
        parameters: {
          'resource_id': resourceId,
          'resource_category': resourceCategory,
          'lesson_count': lessonCount,
        },
      );
    });
  }
}
