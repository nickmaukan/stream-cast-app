/// Stub notification service - notifications can be added later
class NotificationService {
  Future<void> initialize() async {}
  Future<void> showCastingNotification({
    required String title,
    required String deviceName,
    String? thumbnailUrl,
  }) async {}
  Future<void> updateCastingNotification({
    required dynamic state,
    required String deviceName,
  }) async {}
  Future<void> hideCastingNotification() async {}
  Future<bool> requestPermissions() async => true;
}
