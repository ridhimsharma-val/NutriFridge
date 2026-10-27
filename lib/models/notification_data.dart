import 'package:flutter/foundation.dart';
import '../screens/fridge/models/category_item.dart';

/// Notification category types
enum NotificationType {
  foodExpiring,
  mealLogged,
  inventoryUpdate,
  nutritionSummary,
}

/// Represents an in-app notification item.
class AppNotification {
  final String id;
  final String title;
  final String description;
  final String timeAgo;
  final DateTime timestamp;
  final NotificationType type;
  bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.description,
    required this.timeAgo,
    required this.timestamp,
    required this.type,
    this.isRead = false,
  });

  AppNotification copyWith({
    String? id,
    String? title,
    String? description,
    String? timeAgo,
    DateTime? timestamp,
    NotificationType? type,
    bool? isRead,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      timeAgo: timeAgo ?? this.timeAgo,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
    );
  }
}

/// Centralized repository managing shared notification state across the application.
class NotificationRepository {
  static final ValueNotifier<int> notifier = ValueNotifier<int>(0);

  static void _notify() {
    notifier.value++;
  }

  static List<AppNotification> _notifications = _buildInitialNotifications();

  /// Total count of unread notifications
  static int get unreadCount => _notifications.where((n) => !n.isRead).length;

  /// Whether there are any unread notifications
  static bool get hasUnread => unreadCount > 0;

  /// All notifications in chronological order (most recent first)
  static List<AppNotification> get notifications =>
      List.unmodifiable(_notifications);

  /// Builds clean initial session notifications deriving from inventory & meals
  static List<AppNotification> _buildInitialNotifications() {
    final now = DateTime.now();

    // Check if an expiring food item exists in fridge inventory
    String expiringFoodDesc = 'Your Fresh Milk expires in 2 days.';
    final expiringFood = _findFirstExpiringFood();
    if (expiringFood != null) {
      final days = expiringFood.expiryDays;
      expiringFoodDesc = days == 0
          ? 'Your ${expiringFood.name} expires today.'
          : days == 1
              ? 'Your ${expiringFood.name} expires in 1 day.'
              : 'Your ${expiringFood.name} expires in $days days.';
    }

    return [
      AppNotification(
        id: 'notif_expiry_1',
        title: 'Food expiring soon',
        description: expiringFoodDesc,
        timeAgo: '15m ago',
        timestamp: now.subtract(const Duration(minutes: 15)),
        type: NotificationType.foodExpiring,
        isRead: false,
      ),
      AppNotification(
        id: 'notif_meal_1',
        title: 'Meal logged',
        description: 'Your Lunch (Paneer Rice Bowl) has been added to today\'s nutrition.',
        timeAgo: '1h ago',
        timestamp: now.subtract(const Duration(hours: 1)),
        type: NotificationType.mealLogged,
        isRead: false,
      ),
      AppNotification(
        id: 'notif_inventory_1',
        title: 'Inventory update',
        description: 'Paneer was added to your fridge.',
        timeAgo: '3h ago',
        timestamp: now.subtract(const Duration(hours: 3)),
        type: NotificationType.inventoryUpdate,
        isRead: true,
      ),
      AppNotification(
        id: 'notif_summary_1',
        title: 'Nutrition summary',
        description: 'Your daily nutrition summary is ready.',
        timeAgo: '5h ago',
        timestamp: now.subtract(const Duration(hours: 5)),
        type: NotificationType.nutritionSummary,
        isRead: true,
      ),
    ];
  }

  static CategoryFoodItem? _findFirstExpiringFood() {
    try {
      final dairy = FridgeCategoryRepository.dairyProducts;
      for (final item in dairy.items) {
        if (item.expiryDays <= 3) return item;
      }
    } catch (_) {}
    return null;
  }

  /// Mark an individual notification as read
  static void markAsRead(String id) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1 && !_notifications[index].isRead) {
      _notifications[index].isRead = true;
      _notify();
    }
  }

  /// Mark all notifications as read
  static void markAllAsRead() {
    bool changed = false;
    for (final n in _notifications) {
      if (!n.isRead) {
        n.isRead = true;
        changed = true;
      }
    }
    if (changed) {
      _notify();
    }
  }

  /// Adds a new notification to the shared state (prepended as most recent)
  static void addNotification({
    required String title,
    required String description,
    required NotificationType type,
  }) {
    // Avoid exact duplicate descriptions within recent notifications
    if (_notifications.any((n) => n.description == description)) {
      return;
    }

    final newNotif = AppNotification(
      id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      description: description,
      timeAgo: 'Just now',
      timestamp: DateTime.now(),
      type: type,
      isRead: false,
    );

    _notifications.insert(0, newNotif);
    _notify();
  }

  /// Resets notifications repository (for tests)
  static void reset() {
    _notifications = _buildInitialNotifications();
    _notify();
  }
}
