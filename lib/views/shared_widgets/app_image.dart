import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/constants/app_colors.dart';

class AppImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double borderRadius;
  final Widget? fallback;

  const AppImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = 8.0,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final placeholder = fallback ??
        Container(
          width: width,
          height: height,
          color: AppColors.card,
          child: const Icon(Icons.music_note, color: AppColors.textSecondary, size: 24),
        );

    Widget imageWidget;
    if (url.startsWith('assets/')) {
      imageWidget = Image.asset(
        url,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => placeholder,
      );
    } else if (url.startsWith('http://') || url.startsWith('https://')) {
      imageWidget = CachedNetworkImage(
        imageUrl: url,
        width: width,
        height: height,
        fit: fit,
        placeholder: (_, __) => Container(width: width, height: height, color: AppColors.card),
        errorWidget: (_, __, ___) => placeholder,
      );
    } else {
      imageWidget = placeholder;
    }

    if (borderRadius > 0) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: imageWidget,
      );
    }
    return imageWidget;
  }
}
