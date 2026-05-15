import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_text_styles.dart';
import '../models/song_model.dart';
import '../providers/library_provider.dart';

/// Modal bottom sheet for choosing sort mode.
///
/// Call [SortBottomSheet.show] to present it.
class SortBottomSheet extends StatelessWidget {
  const SortBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    // Capture the LibraryProvider from the calling context BEFORE the modal
    // opens, then inject it via ChangeNotifierProvider.value so the builder's
    // fresh route context can still find it.
    final library = context.read<LibraryProvider>();

    return showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConstants.radiusXL),
        ),
      ),
      builder: (_) => ChangeNotifierProvider<LibraryProvider>.value(
        value: library,
        child: const SortBottomSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppConstants.spaceM,
          AppConstants.spaceM,
          AppConstants.spaceM,
          AppConstants.spaceL,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Handle ───────────────────────────────────────────────────
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.stone.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            const SizedBox(height: AppConstants.spaceL),

            Text('Sort by', style: AppTextStyles.headlineSmall),

            const SizedBox(height: AppConstants.spaceM),

            // ── Options ──────────────────────────────────────────────────
            ...SortMode.values.map((mode) {
              final isSelected = library.sortMode == mode;
              return _SortOption(
                mode: mode,
                isSelected: isSelected,
                onTap: () {
                  HapticFeedback.selectionClick();
                  context.read<LibraryProvider>().setSortMode(mode);
                  Navigator.pop(context);
                },
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _SortOption extends StatelessWidget {
  final SortMode mode;
  final bool isSelected;
  final VoidCallback onTap;

  const _SortOption({
    required this.mode,
    required this.isSelected,
    required this.onTap,
  });

  IconData get _icon {
    switch (mode) {
      case SortMode.titleAZ:       return Icons.sort_by_alpha_rounded;
      case SortMode.artistAZ:      return Icons.person_outline_rounded;
      case SortMode.recentlyAdded: return Icons.access_time_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppConstants.radiusM),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spaceM,
          vertical: AppConstants.spaceM,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.darkBerry.withOpacity(0.09)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppConstants.radiusM),
          border: isSelected
              ? Border.all(
                  color: AppColors.darkBerry.withOpacity(0.25),
                  width: 1,
                )
              : null,
        ),
        child: Row(
          children: [
            Icon(
              _icon,
              size: AppConstants.iconM,
              color: isSelected ? AppColors.darkBerry : AppColors.stone,
            ),
            const SizedBox(width: AppConstants.spaceM),
            Expanded(
              child: Text(
                mode.label,
                style: isSelected
                    ? AppTextStyles.bodyLarge.copyWith(
                        color: AppColors.darkBerry,
                        fontWeight: FontWeight.w600,
                      )
                    : AppTextStyles.bodyLarge,
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_rounded,
                color: AppColors.darkBerry,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
