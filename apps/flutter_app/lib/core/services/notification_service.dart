enum NotificationCategory {
  gameInvite,
  turnReminder,
  friendRequest,
  challengeReady,
  seasonReward,
  dailyBonus,
  chatMessage,
  tournamentStart,
  systemAlert,
}

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  Future<void> initialize() async {
    // Push notification wiring comes in a later session.
  }

  Future<void> show({
    required NotificationCategory category,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    // Stub — will integrate with FCM / local notifications.
  }

  Future<void> requestPermission() async {
    // Platform-specific permission request.
  }
}
