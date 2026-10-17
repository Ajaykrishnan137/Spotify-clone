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
        borderRadius: BorderRadius.circular(widget.size * 0.24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primarySkyBlue.withOpacity(0.4),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.size * 0.24),
        child: Image.asset(
          'assets/branding/icons/skytune_icon_512.png',
          width: widget.size,
          height: widget.size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            decoration: const BoxDecoration(
              gradient: AppColors.logoGradient,
            ),
            child: Center(
              child: CustomPaint(
                size: Size(widget.size * 0.72, widget.size * 0.72),
                painter: SkyTuneIconPainter(),
              ),
            ),
          ),
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

/// Custom painter for SkyTune's Geometric Soundwave 'S' pattern
class SkyTuneIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final s = w / 100.0;

    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final arcPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2 * s
      ..strokeCap = StrokeCap.round;

    // 5 Precision Vertical Equalizer Bars forming rhythm
    // Bar 1 (Left Upper)
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(24 * s, 30 * s, 6.2 * s, 26 * s), Radius.circular(3.1 * s)),
      whitePaint,
    );
    // Bar 2 (Peak Left)
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(35 * s, 21 * s, 6.2 * s, 44 * s), Radius.circular(3.1 * s)),
      whitePaint,
    );
    // Bar 3 (Center Pivot)
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(46 * s, 35 * s, 6.2 * s, 30 * s), Radius.circular(3.1 * s)),
      whitePaint,
    );
    // Bar 4 (Peak Right)
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(57 * s, 33 * s, 6.2 * s, 44 * s), Radius.circular(3.1 * s)),
      whitePaint,
    );
    // Bar 5 (Right Lower)
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(68 * s, 43 * s, 6.2 * s, 26 * s), Radius.circular(3.1 * s)),
      whitePaint,
    );

    // Connecting sound frequency arcs forming the flow of 'S'
    // Upper arc
    canvas.drawArc(
      Rect.fromLTWH(26 * s, 20 * s, 24 * s, 22 * s),
      3.14,
      3.14,
      false,
      arcPaint,
    );
    // Lower arc
    canvas.drawArc(
      Rect.fromLTWH(48 * s, 53 * s, 24 * s, 22 * s),
      0,
      3.14,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
