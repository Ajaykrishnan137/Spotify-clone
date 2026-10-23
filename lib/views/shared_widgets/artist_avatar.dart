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
    this.borderWidth = 1.0,
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
    _resolveAvatar();
  }

  @override
  void didUpdateWidget(covariant ArtistAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.artistName != widget.artistName || oldWidget.avatarUrl != widget.avatarUrl) {
      _resolvedUrl = widget.avatarUrl;
      _resolveAvatar();
    }
  }

  Future<void> _resolveAvatar() async {
    setState(() => _isLoading = true);
    final url = await ArtistAvatarService.getArtistAvatarUrl(
      widget.artistName,
      sourceProvidedUrl: widget.avatarUrl,
    );
    if (mounted) {
      setState(() {
        _resolvedUrl = url;
        _isLoading = false;
      });
    }
  }

  Widget _buildFallbackInitials() {
    final initials = ArtistAvatarService.getInitials(widget.artistName);
    final solidColor = ArtistAvatarService.getColorForArtist(widget.artistName);
    final fontSize = (widget.size * 0.38).clamp(12.0, 36.0);

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: solidColor,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: AppColors.textPrimary,
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
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primarySkyBlue),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBorderColor = widget.borderColor ?? AppColors.dividers;

    Widget innerContent;
    if (_isLoading && (_resolvedUrl == null || _resolvedUrl!.isEmpty)) {
      innerContent = _buildSkeletonLoader();
    } else if (_resolvedUrl != null && _resolvedUrl!.isNotEmpty) {
      innerContent = CachedNetworkImage(
        imageUrl: _resolvedUrl!,
        httpHeaders: const {
          'User-Agent': 'SkyTuneMusicPlayer/1.0 (contact@skytune.app; legal music streaming)',
        },
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
