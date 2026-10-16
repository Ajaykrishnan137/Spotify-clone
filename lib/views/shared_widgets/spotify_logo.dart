import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../controllers/audio_player_controller.dart';
import '../../core/constants/app_colors.dart';

/// Provider for dynamic color extracted from the currently playing song
final nowPlayingThemeColorProvider = Provider<Color>((ref) {
  final playerState = ref.watch(audioPlayerControllerProvider);
  final song = playerState.currentSong;
  if (song == null) {
    return AppColors.accent;
  }

  // Generate a distinct, vibrant, song-themed accent color based on song metadata/genre
  final genre = song.genre.toLowerCase();
  if (genre.contains('tamil')) {
    return const Color(0xFFFF5722); // Vibrant Sunset Orange
  } else if (genre.contains('malayalam')) {
    return const Color(0xFF00B0FF); // Deep Ocean Cyan
  } else if (genre.contains('sai')) {
    return const Color(0xFFFF4081); // Radiant Electric Pink
  } else if (genre.contains('pradeep')) {
    return const Color(0xFFFFB300); // Warm Golden Amber
  } else if (genre.contains('lana')) {
    return const Color(0xFFAB47BC); // Atmospheric Velvet Purple
  } else if (genre.contains('love')) {
    return const Color(0xFFE91E63); // Crimson Rose
  }

  // Derive stable harmonious color from song title hash
  final hash = song.title.hashCode.abs();
  final hues = [
    const Color(0xFF1ED760), // Vibrant Spotify Green
    const Color(0xFF00E5FF), // Neon Cyan
    const Color(0xFFFF1744), // Vibrant Coral
    const Color(0xFF7C4DFF), // Deep Violet
    const Color(0xFFFF9100), // Electric Orange
    const Color(0xFF00E676), // Spring Green
    const Color(0xFFF50057), // Hot Rose
  ];
  return hues[hash % hues.length];
});

/// Spotify Waves Logo with dynamic song-themed tint and subtle breathing animation
class SpotifyDynamicLogo extends ConsumerStatefulWidget {
  final double size;
  final bool animated;

  const SpotifyDynamicLogo({
    super.key,
    this.size = 28.0,
    this.animated = true,
  });

  @override
  ConsumerState<SpotifyDynamicLogo> createState() => _SpotifyDynamicLogoState();
}

class _SpotifyDynamicLogoState extends ConsumerState<SpotifyDynamicLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(audioPlayerControllerProvider);
    final themeColor = ref.watch(nowPlayingThemeColorProvider);

    if (widget.animated && playerState.isPlaying) {
      if (!_animController.isAnimating) {
        _animController.repeat(reverse: true);
      }
    } else {
      if (_animController.isAnimating) {
        _animController.stop();
      }
    }

    Widget logoContent = AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: themeColor,
        boxShadow: [
          BoxShadow(
            color: themeColor.withOpacity(0.4),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Center(
        child: CustomPaint(
          size: Size(widget.size * 0.65, widget.size * 0.65),
          painter: SpotifyWavesPainter(color: Colors.black),
        ),
      ),
    );

    if (widget.animated && playerState.isPlaying) {
      return ScaleTransition(
        scale: _pulseAnimation,
        child: logoContent,
      );
    }

    return logoContent;
  }
}

/// Custom painter for the iconic 3 curved Spotify sound waves
class SpotifyWavesPainter extends CustomPainter {
  final Color color;

  SpotifyWavesPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;

    // Top wave
    paint.strokeWidth = w * 0.14;
    final topPath = Path()
      ..moveTo(w * 0.15, h * 0.30)
      ..quadraticBezierTo(w * 0.55, h * 0.14, w * 0.85, h * 0.38);
    canvas.drawPath(topPath, paint);

    // Middle wave
    paint.strokeWidth = w * 0.13;
    final midPath = Path()
      ..moveTo(w * 0.22, h * 0.52)
      ..quadraticBezierTo(w * 0.55, h * 0.40, w * 0.80, h * 0.60);
    canvas.drawPath(midPath, paint);

    // Bottom wave
    paint.strokeWidth = w * 0.11;
    final botPath = Path()
      ..moveTo(w * 0.30, h * 0.74)
      ..quadraticBezierTo(w * 0.55, h * 0.66, w * 0.74, h * 0.80);
    canvas.drawPath(botPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
