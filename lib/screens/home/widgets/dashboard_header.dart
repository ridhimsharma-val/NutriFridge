import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../saved_recipes/saved_recipes_screen.dart';

class DashboardHeader extends StatelessWidget {
  final VoidCallback? onNotificationTap;
  final bool hasUnread;

  const DashboardHeader({
    super.key,
    this.onNotificationTap,
    this.hasUnread = true,
    String? greeting,
    String? subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Top Left Logo Icon + Brand Title
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.tealPrimary.withValues(alpha: 0.16),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: Image.asset(
                    'assets/images/magic_fridge/nutrifridge_app_icon.png',
                    width: 38,
                    height: 38,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.kitchen_rounded, color: AppColors.tealPrimary),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              RichText(
                text: const TextSpan(
                  children: [
                    TextSpan(
                      text: 'Nutri',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.darkText,
                        letterSpacing: -0.4,
                      ),
                    ),
                    TextSpan(
                      text: 'Fridge',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryForest,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Top Right: Saved Recipes Bookmark & Notification Bell
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Saved Recipes Bookmark Button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  key: const ValueKey('saved_recipes_header_btn'),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SavedRecipesScreen()),
                    );
                  },
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.cardWhite,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.cardBorder,
                        width: 1,
                      ),
                      boxShadow: const [AppColors.cardShadow],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.bookmark_outline_rounded,
                        size: 21,
                        color: AppColors.primaryForest,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Notification Bell in a soft rounded circular container
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onNotificationTap,
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.cardWhite,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.cardBorder,
                        width: 1,
                      ),
                      boxShadow: const [AppColors.cardShadow],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Icon(
                          Icons.notifications_outlined,
                          size: 22,
                          color: AppColors.primaryForest,
                        ),
                        // Small subtle notification badge dot (visible when unread notifications exist)
                        if (hasUnread)
                          Positioned(
                            top: 9,
                            right: 10,
                            child: Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(
                                color: AppColors.peachPrimary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.cardWhite,
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.peachPrimary.withValues(alpha: 0.35),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
