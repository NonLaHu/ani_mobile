import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A sleek, futuristic anime-styled rotating cycle loading animation.
///
/// Features:
/// - Dual rotating neon arcs (clockwise & counter-clockwise) with gradient shader.
/// - Pulsing glowing center core.
/// - Dynamic animated dot cycling message ('Loading stream.', '..', '...').
/// - Customizable size, stroke width, and color palettes.
class LoadingCycle extends StatefulWidget {
  final double size;
  final double strokeWidth;
  final String? message;
  final Color primaryColor;
  final Color secondaryColor;
  final bool showCore;

  const LoadingCycle({
    super.key,
    this.size = 48.0,
    this.strokeWidth = 3.5,
    this.message,
    this.primaryColor = AppTheme.accentCyan,
    this.secondaryColor = AppTheme.primaryPurple,
    this.showCore = true,
  });

  @override
  State<LoadingCycle> createState() => _LoadingCycleState();
}

class _LoadingCycleState extends State<LoadingCycle>
    with TickerProviderStateMixin {
  late final AnimationController _rotationController;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  late final AnimationController _dotController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );

    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    _dotController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer clockwise rotating gradient arc
              AnimatedBuilder(
                animation: _rotationController,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _rotationController.value * 2 * math.pi,
                    child: child,
                  );
                },
                child: CustomPaint(
                  size: Size(widget.size, widget.size),
                  painter: _CycleArcPainter(
                    startAngle: 0.0,
                    sweepAngle: 1.5 * math.pi,
                    strokeWidth: widget.strokeWidth,
                    colors: [
                      widget.secondaryColor.withOpacity(0.1),
                      widget.secondaryColor,
                      widget.primaryColor,
                    ],
                  ),
                ),
              ),

              // Inner counter-clockwise secondary cycle arc (seamless integer rotation)
              AnimatedBuilder(
                animation: _rotationController,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: -_rotationController.value * 2 * math.pi,
                    child: child,
                  );
                },
                child: CustomPaint(
                  size: Size(widget.size * 0.72, widget.size * 0.72),
                  painter: _CycleArcPainter(
                    startAngle: math.pi * 0.5,
                    sweepAngle: 1.1 * math.pi,
                    strokeWidth: widget.strokeWidth * 0.8,
                    colors: [
                      widget.primaryColor.withOpacity(0.2),
                      widget.primaryColor,
                    ],
                  ),
                ),
              ),

              // Pulsing core glowing center with smooth easeInOut curve
              if (widget.showCore)
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    final scale = 0.75 + (_pulseAnimation.value * 0.35);
                    final opacity = 0.5 + (_pulseAnimation.value * 0.5);
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: widget.size * 0.22,
                        height: widget.size * 0.22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.primaryColor.withOpacity(opacity),
                          boxShadow: [
                            BoxShadow(
                              color: widget.primaryColor.withOpacity(0.6),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),

        // Optional Message with cycling dots
        if (widget.message != null) ...[
          const SizedBox(height: 14),
          AnimatedBuilder(
            animation: _dotController,
            builder: (context, child) {
              final dotIndex = (_dotController.value * 3).floor() + 1;
              final dots = '.' * dotIndex;
              final padding = ' ' * (3 - dotIndex);

              return Text(
                '${widget.message}$dots$padding',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

/// Custom painter rendering a smooth tapered anti-aliased cycle arc with gradient
class _CycleArcPainter extends CustomPainter {
  final double startAngle;
  final double sweepAngle;
  final double strokeWidth;
  final List<Color> colors;

  const _CycleArcPainter({
    required this.startAngle,
    required this.sweepAngle,
    required this.strokeWidth,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final sweepGradient = SweepGradient(
      colors: colors,
      startAngle: startAngle,
      endAngle: startAngle + sweepAngle,
      transform: const GradientRotation(0),
    );

    final paint = Paint()
      ..shader = sweepGradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
  }

  @override
  bool shouldRepaint(covariant _CycleArcPainter oldDelegate) {
    return oldDelegate.startAngle != startAngle ||
        oldDelegate.sweepAngle != sweepAngle ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.colors != colors;
  }
}

/// Floating backdrop modal HUD overlay featuring the LoadingCycle animation
class LoadingCycleOverlay extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onCancel;

  const LoadingCycleOverlay({
    super.key,
    this.title = 'Loading Stream',
    this.subtitle = 'Resolving video streams & connecting to server...',
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      alignment: Alignment.center,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        decoration: BoxDecoration(
          color: AppTheme.darkSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.accentCyan.withOpacity(0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.6),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: AppTheme.accentCyan.withOpacity(0.12),
              blurRadius: 20,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LoadingCycle(
              size: 56,
              strokeWidth: 4,
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12.5,
                ),
              ),
            ],
            if (onCancel != null) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: onCancel,
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
