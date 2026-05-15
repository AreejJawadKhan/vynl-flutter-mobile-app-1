import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_text_styles.dart';

/// A consistent empty state display with an icon, title, optional subtitle,
/// and an optional action button.
///
/// Used on: Library (no songs), Rooms (no rooms), Voice (no history).
class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? buttonLabel;
  final VoidCallback? onButtonTap;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.buttonLabel,
    this.onButtonTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon in a soft circle.
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.blushDark.withOpacity(0.4),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 48,
                color: AppColors.stone,
              ),
            ),

            const SizedBox(height: AppConstants.spaceL),

            Text(
              title,
              style: AppTextStyles.headlineSmall,
              textAlign: TextAlign.center,
            ),

            if (subtitle != null) ...[
              const SizedBox(height: AppConstants.spaceS),
              Text(
                subtitle!,
                style: AppTextStyles.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],

            if (buttonLabel != null && onButtonTap != null) ...[
              const SizedBox(height: AppConstants.spaceXL),
              ElevatedButton.icon(
                onPressed: onButtonTap,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(buttonLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
