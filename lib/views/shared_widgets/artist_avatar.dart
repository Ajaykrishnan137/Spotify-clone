import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/artist_avatar_service.dart';

class ArtistAvatar extends StatefulWidget {
  final String artistName;
  final String? avatarUrl;
  final double size;
  final double borderWidth;
  final Color? borderColor;
  final VoidCallback? onTap;

  const ArtistAvatar({
    super.key,
    required this.artistName,
    this.avatarUrl,
    this.size = 76.0,
    this.borderWidth = 1.5,
    this.borderColor,
    this.onTap,
  });

  @override
  State<ArtistAvatar> createState() => _ArtistAvatarState();
}

class _ArtistAvatarState extends State<ArtistAvatar> {
  String? _resolvedUrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _resolvedUrl = widget.avatarUrl;
    if (_resolvedUrl == null || _resolvedUrl!.isEmpty) {
      _resolveAvatar();
    }
  }

  @override
  void didUpdateWidget(covariant ArtistAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.artistName != widget.artistName || oldWidget.avatarUrl != widget.avatarUrl) {
      _resolvedUrl = widget.avatarUrl;
      if (_resolvedUrl == null || _resolvedUrl!.isEmpty) {
        _resolveAvatar();
      }
    }
  }

  Future<void> _resolveAvatar() async {
    setState(() => _isLoading = true);
    final url = await ArtistAvatarService.getArtistAvatarUrl(widget.artistName);
    if (mounted) {
      setState(() {
        _resolvedUrl = url;
        _isLoading = false;
      });
    }
  }

  Widget _buildFallbackInitials() {
    final initials = ArtistAvatarService.getInitials(widget.artistName);
    final gradient = ArtistAvatarService.getGradientForArtist(widget.artistName);
    final fontSize = (widget.size * 0.38).clamp(12.0, 36.0);

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: gradient,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surface,
      ),
      child: const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.cyanAccent),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBorderColor = widget.borderColor ?? AppColors.cyanAccent.withOpacity(0.4);

    Widget innerContent;
    if (_isLoading && (_resolvedUrl == null || _resolvedUrl!.isEmpty)) {
      innerContent = _buildSkeletonLoader();
    } else if (_resolvedUrl != null && _resolvedUrl!.isNotEmpty) {
      innerContent = CachedNetworkImage(
        imageUrl: _resolvedUrl!,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        maxWidthDiskCache: 256,
        maxHeightDiskCache: 256,
        memCacheWidth: 256,
        memCacheHeight: 256,
        placeholder: (_, __) => _buildSkeletonLoader(),
        errorWidget: (_, __, ___) => _buildFallbackInitials(),
      );
    } else {
      innerContent = _buildFallbackInitials();
    }

    final avatarCircle = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: widget.borderWidth > 0
            ? Border.all(color: effectiveBorderColor, width: widget.borderWidth)
            : null,
        boxShadow: [
          BoxShadow(
            color: AppColors.cyanAccent.withOpacity(0.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipOval(child: innerContent),
    );

    if (widget.onTap != null) {
      return InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(widget.size / 2),
        child: avatarCircle,
      );
    }

    return avatarCircle;
  }
}
