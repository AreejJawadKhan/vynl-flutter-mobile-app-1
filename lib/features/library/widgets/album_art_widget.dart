import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';

class AlbumArtWidget extends StatelessWidget {
  final int? albumId;
  final String? albumArtUrl; // direct URL — no async fetch needed
  final double size;
  final double borderRadius;

  const AlbumArtWidget({
    super.key,
    this.albumId,
    this.albumArtUrl,
    this.size = AppConstants.albumArtListSize,
    this.borderRadius = AppConstants.radiusS,
  });

  @override
  Widget build(BuildContext context) {
    if (albumArtUrl != null && albumArtUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: CachedNetworkImage(
          imageUrl: albumArtUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (_, __) => _placeholder(),
          errorWidget: (_, __, ___) => _placeholder(),
        ),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
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

/// Circular variant
class AlbumArtCircle extends StatelessWidget {
  final int? albumId;
  final String? albumArtUrl;
  final double size;

  const AlbumArtCircle({
    super.key,
    this.albumId,
    this.albumArtUrl,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return AlbumArtWidget(
      albumId:     albumId,
      albumArtUrl: albumArtUrl,
      size:        size,
      borderRadius: size / 2,
    );
  }
}