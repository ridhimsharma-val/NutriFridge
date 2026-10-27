import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/notification_data.dart';

/// Elegant compact Notification Popover Card.
/// Anchored near the top-right notification bell with a dimmed background overlay.
class NotificationPopover extends StatelessWidget {
  const NotificationPopover({super.key});

  /// Displays the notification popover modal using a dimmed general dialog
  static Future<void> show(BuildContext context) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Notifications Overlay',
      barrierColor: Colors.black.withValues(alpha: 0.32),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (context, anim1, anim2) {
        return const SafeArea(
          child: NotificationPopover(),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        final curve = CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curve,
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: NotificationRepository.notifier,
      builder: (context, _) {
        final notifications = NotificationRepository.notifications;
        final unreadCount = NotificationRepository.unreadCount;
        final screenWidth = MediaQuery.of(context).size.width;
        final popoverWidth = (screenWidth - 32).clamp(280.0, 360.0);

        return Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 54, 16, 0),
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: popoverWidth,
                constraints: const BoxConstraints(maxHeight: 460),
                decoration: BoxDecoration(
                  color: AppColors.cardWhite,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: AppColors.cardBorder,
                    width: 1.2,
                  ),
                  boxShadow: [
                    AppColors.softShadow,
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header Bar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 14, 14, 10),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Notifications',
                                style: AppTypography.greeting.copyWith(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (unreadCount > 0) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.peachLight,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '$unreadCount new',
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.peachPrimary,
                                    ),
                                  ),
                                ),
                              ],
                              const Spacer(),
                              GestureDetector(
                                onTap: () => Navigator.of(context).pop(),
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: const BoxDecoration(
                                    color: AppColors.background,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    size: 17,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (unreadCount > 0) ...[
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Recent updates',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => NotificationRepository.markAllAsRead(),
                                  child: const Text(
                                    'Mark all read',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.tealPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    const Divider(color: Color(0xFFF0F4F2), height: 1),

                    // Notification Items or Empty State
                    Flexible(
                      child: notifications.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                              child: Center(
                                child: Text(
                                  "You're all caught up.",
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              itemCount: notifications.length,
                              separatorBuilder: (context, index) => const Divider(
                                color: Color(0xFFF7FAF8),
                                height: 1,
                                indent: 18,
                                endIndent: 18,
                              ),
                              itemBuilder: (context, index) {
                                final notif = notifications[index];
                                return _buildNotificationTile(notif);
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotificationTile(AppNotification notif) {
    return InkWell(
      onTap: () => NotificationRepository.markAsRead(notif.id),
      child: Container(
        color: notif.isRead ? Colors.transparent : const Color(0xFFF8FCFA),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Unread Dot Indicator
            Container(
              margin: const EdgeInsets.only(top: 5, right: 10),
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: notif.isRead ? Colors.transparent : AppColors.peachPrimary,
                shape: BoxShape.circle,
              ),
            ),

            // Content Column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          notif.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: notif.isRead ? FontWeight.w600 : FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        notif.timeAgo,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    notif.description,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w400,
                      color: notif.isRead
                          ? AppColors.textSecondary
                          : AppColors.textPrimary.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
