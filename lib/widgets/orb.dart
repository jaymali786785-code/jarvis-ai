// orb.dart
// Procedurally painted golden "Iron Man" hologram orb (no PNG needed) that
// reacts to AppState.orb / AppState.level, plus the small cyan WaveBall.

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';

class JarvisOrb extends StatefulWidget {
  final double size;
  const JarvisOrb({super.key, this.size = 320});
  @override
  State<JarvisOrb> createState() => _JarvisOrbState();
}

class _JarvisOrbState extends State<JarvisOrb> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final mode = app.orb;
    final level = app.level;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = _c.value;
        double scale;
        double energy;
        switch (mode) {
          case OrbMode.listening:
            // small / medium / large pulses driven by mic level
            scale = 0.8 + 0.4 * level + 0.03 * sin(t * 2 * pi * 20);
            energy = 0.6 + level * 0.4;
            break;
          case OrbMode.speaking:
            scale = 1.0 + 0.2 * (0.5 + 0.5 * sin(t * 2 * pi * 6)) + 0.08 * sin(t * 2 * pi * 17);
            energy = 1.0;
            break;
          case OrbMode.thinking:
            scale = 0.95 + 0.04 * sin(t * 2 * pi * 4);
            energy = 0.7;
            break;
          case OrbMode.idle:
            scale = 1.0 + 0.05 * sin(t * 2 * pi); // slow breathing, 3s cycle
            energy = 0.35;
            break;
        }
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Transform.scale(
            scale: scale,
            child: CustomPaint(
              painter: _OrbPainter(t, energy, mode == OrbMode.listening, level, app.orbColor),
            ),
          ),
        );
      },
    );
  }
}

class _OrbPainter extends CustomPainter {
  final double t, energy, level;
  final bool listening;
  final Color gold;
  _OrbPainter(this.t, this.energy, this.listening, this.level, this.gold);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final R = size.width * 0.36;
    const cyan = Color(0xFF00E5FF);

    // outer golden glow + inner cyan glow
    canvas.drawCircle(c, R * 1.15, Paint()
      ..color = gold.withOpacity(0.18 + 0.22 * energy)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30));
    canvas.drawCircle(c, R * 0.55, Paint()
      ..color = cyan.withOpacity(0.10 + 0.12 * energy)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22));

    // rotating energy rings
    for (var i = 0; i < 6; i++) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(t * 2 * pi * (i.isEven ? 0.5 : -0.35) * (1 + energy) + i * 0.9);
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: R * 2 * (0.72 + 0.055 * i),
        height: R * 2 * (1.0 - 0.07 * i),
      );
      canvas.drawOval(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1 + energy
          ..color = gold.withOpacity(0.5 + 0.3 * energy),
      );
      canvas.restore();
    }
    // outer shell
    canvas.drawCircle(c, R, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = gold.withOpacity(0.7));

    // lightning branches (re-seeded 8x per cycle so they flicker)
    final flick = (t * 8).floor();
    final base = Random(11);
    for (var i = 0; i < 14; i++) {
      final ang = base.nextDouble() * 2 * pi + t * 2 * pi * 0.2;
      final rnd = Random(i * 31 + flick);
      final path = Path()..moveTo(c.dx, c.dy);
      var r = 0.0;
      var a = ang;
      final len = R * (0.75 + 0.35 * base.nextDouble() * (0.6 + energy));
      while (r < len) {
        r += len / 7;
        a += (rnd.nextDouble() - 0.5) * 0.35;
        path.lineTo(c.dx + cos(a) * r, c.dy + sin(a) * r);
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9
          ..strokeJoin = StrokeJoin.round
          ..color = Color.lerp(gold, Colors.white, 0.35)!.withOpacity(0.55 + 0.3 * energy),
      );
    }

    // sparkles
    final sr = Random(5);
    for (var i = 0; i < 70; i++) {
      final a = sr.nextDouble() * 2 * pi + t * 2 * pi * 0.15;
      final rr = sqrt(sr.nextDouble()) * R * 1.12;
      final alpha = 0.3 + 0.7 * (sin(t * 2 * pi * 3 + i).abs());
      canvas.drawCircle(
        c + Offset(cos(a) * rr, sin(a) * rr),
        0.8 + sr.nextDouble() * 1.8,
        Paint()..color = const Color(0xFFFFE082).withOpacity(alpha * 0.9),
      );
    }

    // cyan waveform bars while listening
    if (listening) {
      for (var i = -10; i <= 10; i++) {
        final h = (6 + (R * 0.5) * level * (0.4 + 0.6 * sin(t * 2 * pi * 12 + i).abs())) * (1 - i.abs() / 12);
        final x = c.dx + i * (R * 0.08);
        canvas.drawLine(
          Offset(x, c.dy - h),
          Offset(x, c.dy + h),
          Paint()
            ..color = cyan.withOpacity(0.85)
            ..strokeWidth = 2.4
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    // glowing core
    final coreR = R * 0.2 * (1 + 0.5 * energy);
    canvas.drawCircle(
      c,
      coreR * 2.2,
      Paint()
        ..shader = RadialGradient(colors: [
          Colors.white.withOpacity(0.95),
          gold.withOpacity(0.8),
          gold.withOpacity(0.0),
        ], stops: const [0.0, 0.35, 1.0])
            .createShader(Rect.fromCircle(center: c, radius: coreR * 2.2)),
    );
  }

  @override
  bool shouldRepaint(covariant _OrbPainter old) => true;
}

/// Small cyan glowing ball with waveform (Code screen voice input).
class WaveBall extends StatefulWidget {
  final double size;
  final VoidCallback? onTap;
  const WaveBall({super.key, this.size = 64, this.onTap});
  @override
  State<WaveBall> createState() => _WaveBallState();
}

class _WaveBallState extends State<WaveBall> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final live = app.micOn;
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final t = _c.value;
          final lvl = live ? app.level : 0.15;
          final scale = live ? 0.9 + 0.5 * lvl : 1.0 + 0.04 * sin(t * 2 * pi);
          return Transform.scale(
            scale: scale,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(colors: [Color(0xFF7DF9FF), Color(0xFF00B8D4)]),
                boxShadow: [BoxShadow(color: const Color(0xFF00E5FF).withOpacity(0.55), blurRadius: 24, spreadRadius: 2)],
              ),
              child: CustomPaint(painter: _BarsPainter(t, lvl)),
            ),
          );
        },
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  final double t, level;
  _BarsPainter(this.t, this.level);
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    for (var i = -7; i <= 7; i++) {
      final h = (3 + size.height * 0.28 * level * (0.4 + 0.6 * sin(t * 2 * pi * 4 + i * 0.9).abs())) * (1 - i.abs() / 9);
      final x = c.dx + i * (size.width * 0.055);
      canvas.drawLine(Offset(x, c.dy - h), Offset(x, c.dy + h),
          Paint()..color = Colors.white.withOpacity(0.9)..strokeWidth = 2..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(covariant _BarsPainter old) => true;
}
