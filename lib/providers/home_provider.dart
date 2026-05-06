import 'package:flutter/material.dart';

import '../services/api_service.dart';

class HomeProvider extends ChangeNotifier {
  HomeProvider({required int schoolId}) : _schoolId = schoolId;

  final int _schoolId;
  int unreadNotificationCount = 0;

  Future<void> loadUnreadNotificationCount() async {
    final response = await ApiService.getUnreadNotificationCountData(
      schoolId: _schoolId,
    );
    if (response.success) {
      unreadNotificationCount = response.data?.unreadCount ?? 0;
      notifyListeners();
    }
  }
}
