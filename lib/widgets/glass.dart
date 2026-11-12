// glass.dart
// Liquid-glass UI kit: Glass container, floating-bubble background, bottom nav,
// settings row, sub-page scaffold and small text helpers.

import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';

TextStyle ts(Palette p, {double size = 16, FontWeight w = FontWeight.w500, bool sub = false, Color? color, double? spacing}) =>
    TextStyle(fontSize: size, fontWeight: w, color: color ?? (sub ? p.sub : p.text), letterSpacing: spacing, height: 1.25);

/// Frosted liquid-glass surface (blur 20, white 30-50% border, cyan glow).
class Glass extends StatelessWidget {
  final Widget? child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double? width, height;
  final bool active;
  final bool circle;
  final Color? tint;

  const Glass({
    super.key,
    this.child,
    this.radius = 28,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.width,
    this.height,
    this.active = false,
    this.circle = false,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppState>().palette;
    final r = BorderRadius.circular(circle ? 999 : radius);
    final base = tint ?? Colors.white;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: r,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00E5FF).withOpacity(active ? 0.30 : 0.15),
              blurRadius: active ? 28 : 20,
              spreadRadius: -2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: r,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                borderRadius: r,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    base.withOpacity(p.dark ? 0.16 : 0.55),
                    base.withOpacity(p.dark ? 0.05 : 0.18),
                  ],
                ),
                border: Border.all(color: Colors.white.withOpacity(0.45), width: 1),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class GlassCircle extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final Color? iconColor;
  const GlassCircle({super.key, required this.icon, this.onTap, this.size = 52, this.iconColor});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppState>().palette;
    return Glass(
      circle: true,
      width: size,
      height: size,
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Center(child: Icon(icon, size: size * 0.46, color: iconColor ?? p.text)),
    );
  }
}

/// Gradient + rising bubbles + golden sparkles.
class BubbleBackground extends StatefulWidget {
  final Widget child;
  const BubbleBackground({super.key, required this.child});
  @override
  State<BubbleBackground> createState() => _BubbleBackgroundState();
}

class _BubbleBackgroundState extends State<BubbleBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 40))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppState>().palette;
    return Stack(children: [
      Positioned.fill(
        child: RepaintBoundary(
          child: CustomPaint(painter: _BubblePainter(_c, p)),
        ),
      ),
      Positioned.fill(child: widget.child),
    ]);
  }
}

class _BubblePainter extends CustomPainter {
  final Animation<double> t;
  final Palette p;
  _BubblePainter(this.t, this.p) : super(repaint: t);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p.bgTop, p.bgBottom],
        ).createShader(Offset.zero & size),
    );
    final rnd = Random(7);
    // bubbles
    for (var i = 0; i < 14; i++) {
      final x = rnd.nextDouble() * size.width;
      final r = 8 + rnd.nextDouble() * 34;
      final speed = 1 + rnd.nextInt(3);
      final phase = rnd.nextDouble();
      final prog = (t.value * speed + phase) % 1.0;
      final y = size.height + r - prog * (size.height + 2 * r);
      final dx = sin((t.value * 2 * pi * speed) + i) * 10;
      final c = Offset(x + dx, y);
      canvas.drawCircle(c, r, Paint()..color = Colors.white.withOpacity(p.dark ? 0.04 : 0.12));
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = Colors.white.withOpacity(p.dark ? 0.25 : 0.65),
      );
      canvas.drawCircle(c.translate(-r * 0.35, -r * 0.35), r * 0.16, Paint()..color = Colors.white.withOpacity(0.8));
    }
    // golden bokeh sparkles
    final sr = Random(21);
    for (var i = 0; i < 36; i++) {
      final pos = Offset(sr.nextDouble() * size.width, sr.nextDouble() * size.height);
      final a = 0.2 + 0.6 * ((sin(t.value * 2 * pi * 4 + i * 1.7) + 1) / 2);
      canvas.drawCircle(pos, 1 + sr.nextDouble() * 2.2, Paint()..color = const Color(0xFFFFD54F).withOpacity(a * 0.7));
    }
  }

  @override
  bool shouldRepaint(covariant _BubblePainter old) => old.p != p;
}

/// Bottom pill nav: Home, Chat, Voice, Settings, Code.
class GlassNavBar extends StatelessWidget {
  const GlassNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final p = app.palette;
    const items = [
      [Icons.home_rounded, 'Home'],
      [Icons.chat_bubble_rounded, 'Chat'],
      [Icons.mic_rounded, 'Voice'],
      [Icons.settings_rounded, 'Settings'],
      [Icons.code_rounded, 'Code'],
    ];
    Color activeColor(int i) {
      switch (i) {
        case 0:
          return const Color(0xFF2563EB);
        case 2:
          return const Color(0xFFE53935);
        default:
          return Colors.black;
      }
    }

    return Glass(
      radius: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (i) {
          // Voice is an action, highlighted while mic is live.
          final active = i == 2 ? app.micOn : app.tab == i;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (i == 2) {
                  app.requestMic();
                } else {
                  app.setTab(i);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  gradient: active
                      ? const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.white, Color(0xFFE8F1FB)])
                      : null,
                  boxShadow: active
                      ? [
                          BoxShadow(
                              color: (i == 2 ? Colors.red : Colors.black).withOpacity(0.18),
                              blurRadius: 14,
                              offset: const Offset(0, 4)),
                        ]
                      : null,
                  border: active ? Border.all(color: Colors.white, width: 1.5) : null,
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(items[i][0] as IconData, size: 26, color: active ? activeColor(i) : p.sub),
                  const SizedBox(height: 2),
                  Text(items[i][1] as String,
                      style: ts(p, size: 11, w: FontWeight.w700, color: active ? activeColor(i) : p.sub)),
                ]),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// A row inside a settings Glass card.
class SettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  const SettingsRow({super.key, required this.icon, required this.title, this.subtitle, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppState>().palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          Glass(
            circle: true,
            width: 50,
            height: 50,
            padding: EdgeInsets.zero,
            child: Icon(icon, color: p.accent, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: ts(p, size: 17, w: FontWeight.w800)),
              if (subtitle != null) Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(subtitle!, style: ts(p, size: 13.5, sub: true)),
              ),
            ]),
          ),
          if (trailing != null) trailing! else Icon(Icons.chevron_right_rounded, color: p.sub),
        ]),
      ),
    );
  }
}

/// Full-screen page with glass back button, title and scrolling children.
class SubPage extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;
  const SubPage({super.key, required this.title, this.subtitle, required this.children});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppState>().palette;
    return Scaffold(
      backgroundColor: p.bgTop,
      body: BubbleBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: GlassCircle(icon: Icons.arrow_back_ios_new_rounded, size: 46, onTap: () => Navigator.of(context).pop()),
              ),
              const SizedBox(height: 14),
              Text(title, style: ts(p, size: 28, w: FontWeight.w900)),
              if (subtitle != null)
                Padding(padding: const EdgeInsets.only(top: 4, bottom: 8), child: Text(subtitle!, style: ts(p, size: 15, sub: true))),
              const SizedBox(height: 10),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

Widget sectionLabel(Palette p, String s) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 0, 8),
      child: Text(s.toUpperCase(), style: ts(p, size: 13, w: FontWeight.w800, sub: true, spacing: 1.6)),
    );

Widget pill(Palette p, String text, Color color, {IconData? icon}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 16, color: color), const SizedBox(width: 6)],
        Text(text, style: ts(p, size: 12.5, w: FontWeight.w800, color: color, spacing: 0.6)),
      ]),
    );

/// Solid purple action button used for primary actions.
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Color color;
  final IconData? icon;
  const PrimaryButton({super.key, required this.label, this.onTap, this.color = const Color(0xFF6D4AFF), this.icon});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(colors: [color, Color.lerp(color, Colors.white, 0.25)!]),
          boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 18, offset: const Offset(0, 6))],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, color: Colors.white), const SizedBox(width: 8)],
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }
}

void snack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
}
