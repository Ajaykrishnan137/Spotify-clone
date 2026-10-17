import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../controllers/audio_player_controller.dart';
import '../../core/constants/app_colors.dart';

/// Provider for dynamic color theme extracted or tuned for SkyTune
final nowPlayingThemeColorProvider = Provider<Color>((ref) {
  final playerState = ref.watch(audioPlayerControllerProvider);
  final song = playerState.currentSong;
  if (song == null) {
    return AppColors.cyanAccent;
  }

  final genre = song.genre.toLowerCase();
  if (genre.contains('tamil')) {
    return const Color(0xFFFF7043); // Coral Sunset
  } else if (genre.contains('malayalam')) {
    return AppColors.cyanAccent;    // Sky Cyan
  } else if (genre.contains('sai')) {
    return const Color(0xFFFF5252); // Warm Rose
  } else if (genre.contains('pradeep')) {
    return AppColors.softGold;      // Soft Gold
  } else if (genre.contains('lana')) {
    return const Color(0xFF7C4DFF); // Deep Indigo
  } else if (genre.contains('love')) {
    return AppColors.sunsetCoral;   // Sunset Coral
  }

  // Harmonic SkyTune palette
  final hues = [
    AppColors.cyanAccent,
    AppColors.primarySkyBlue,
    const Color(0xFF5B4BFF),
    AppColors.sunsetCoral,
    AppColors.softGold,
    const Color(0xFF00E676),
  ];
  final hash = song.title.hashCode.abs();
  return hues[hash % hues.length];
});

/// SkyTune Animated Brand Logo (Cloud + Soundwave bars + Crescent accent)
class SkyTuneDynamicLogo extends ConsumerStatefulWidget {
  final double size;
  final bool animated;

  const SkyTuneDynamicLogo({
    super.key,
    this.size = 32.0,
    this.animated = true,
  });

  @override
  ConsumerState<SkyTuneDynamicLogo> createState() => _SkyTuneDynamicLogoState();
}

class _SkyTuneDynamicLogoState extends ConsumerState<SkyTuneDynamicLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _scaleAnimation = Tween<double>(begin: 0.94, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(audioPlayerControllerProvider);

    if (widget.animated && playerState.isPlaying) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      if (_pulseController.isAnimating) {
        _pulseController.stop();
      }
    }

    Widget content = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.size * 0.225),
        gradient: AppColors.logoGradient,
        boxShadow: [
          BoxShadow(
            color: AppColors.primarySkyBlue.withOpacity(0.4),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: CustomPaint(
          size: Size(widget.size * 0.76, widget.size * 0.76),
          painter: SkyTuneIconPainter(),
        ),
      ),
    );

    if (widget.animated && playerState.isPlaying) {
      return ScaleTransition(
        scale: _scaleAnimation,
        child: content,
      );
    }

    return content;
  }
}

/// Wordmark widget "Sky" (white) + "Tune" (sky cyan)
class SkyTuneWordmark extends StatelessWidget {
  final double fontSize;

  const SkyTuneWordmark({super.key, this.fontSize = 22.0});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        children: const [
          TextSpan(text: 'Sky', style: TextStyle(color: Colors.white)),
          TextSpan(text: 'Tune', style: TextStyle(color: AppColors.cyanAccent)),
        ],
      ),
    );
  }
}

/// Custom painter for SkyTune's Geometric Soundwave 'S' pattern (matches skytune_icon.svg 1:1)
class SkyTuneIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 512x512 reference coordinates scaled to canvas size
    final s = size.width / 512.0;

    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final arcPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16.0 * s
      ..strokeCap = StrokeCap.round;

    // 5 Precision Vertical Equalizer Bars matching skytune_icon.svg
    // Bar 1 (Left Upper): x=130, y=160, w=32, h=130, rx=16
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(130 * s, 160 * s, 32 * s, 130 * s), Radius.circular(16 * s)),
      whitePaint,
    );
    // Bar 2 (Peak Left): x=185, y=115, w=32, h=220, rx=16
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(185 * s, 115 * s, 32 * s, 220 * s), Radius.circular(16 * s)),
      whitePaint,
    );
    // Bar 3 (Center Pivot): x=240, y=180, w=32, h=152, rx=16
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(240 * s, 180 * s, 32 * s, 152 * s), Radius.circular(16 * s)),
      whitePaint,
    );
    // Bar 4 (Peak Right): x=295, y=175, w=32, h=220, rx=16
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(295 * s, 175 * s, 32 * s, 220 * s), Radius.circular(16 * s)),
      whitePaint,
    );
    // Bar 5 (Right Lower): x=350, y=220, w=32, h=130, rx=16
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(350 * s, 220 * s, 32 * s, 130 * s), Radius.circular(16 * s)),
      whitePaint,
    );

    // Connecting sound frequency arcs matching skytune_icon.svg
    // Upper arc: M 146 160 A 55 55 0 0 1 256 180
    final upperArc = Path()
      ..moveTo(146 * s, 160 * s)
      ..arcToPoint(Offset(256 * s, 180 * s), radius: Radius.circular(55 * s), clockwise: true);
    canvas.drawPath(upperArc, arcPaint);

    // Lower arc: M 256 332 A 55 55 0 0 1 366 350
    final lowerArc = Path()
      ..moveTo(256 * s, 332 * s)
      ..arcToPoint(Offset(366 * s, 350 * s), radius: Radius.circular(55 * s), clockwise: true);
    canvas.drawPath(lowerArc, arcPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
