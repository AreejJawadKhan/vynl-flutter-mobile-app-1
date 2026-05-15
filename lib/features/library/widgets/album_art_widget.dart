import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';

/// displays a consistent music note icon.
class AlbumArtWidget extends StatelessWidget {
  final int? albumId;
  final double size;
  final double borderRadius;
  const AlbumArtWidget({
    super.key,
    this.albumId,
    this.size = AppConstants.albumArtListSize,
    this.borderRadius = AppConstants.radiusS,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        width: size,
        height: size,
        color: AppColors.blushDark,
        child: Icon(
          Icons.music_note_rounded,
          color: AppColors.stone,
          size: size * 0.45,
        ),
      ),
    );
  }
}

/// Circular variant.
class AlbumArtCircle extends StatelessWidget {
  final int? albumId;
  final double size;
  const AlbumArtCircle({
    super.key,
    this.albumId,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return AlbumArtWidget(
      albumId: albumId,
      size: size,
      borderRadius: size / 2,
    );
  }
}
