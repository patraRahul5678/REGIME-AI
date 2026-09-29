import 'dart:math';
import 'package:flutter/material.dart';

class C {
  static const navy = Color(0xFF071B34), deep = Color(0xFF0F3057), blue = Color(0xFF1E6FD9),
      sky = Color(0xFF9DB8D6), cyan = Color(0xFF2DD4E6), mist = Color(0xFFE8F0F9), bg = Color(0xFFF2F6FB), ink = Color(0xFF0B2545);
  static const grad = LinearGradient(colors: [navy, deep, Color(0xFF1B5FBF)], begin: Alignment.topLeft, end: Alignment.bottomRight);
  static const accent = LinearGradient(colors: [Color(0xFF1E6FD9), Color(0xFF2DD4E6)]);
  static Color risk(double p) => p >= .6 ? const Color(0xFFE5484D) : p >= .3 ? const Color(0xFFF5A524) : const Color(0xFF12A594);
  static String riskLabel(double p) => p >= .6 ? 'HIGH' : p >= .3 ? 'MODERATE' : 'LOW';
  static List<BoxShadow> shadow = [BoxShadow(color: const Color(0xFF0B2545).withOpacity(.08), blurRadius: 22, offset: const Offset(0, 8))];
}

ThemeData buildTheme() => ThemeData(
  useMaterial3: true, scaffoldBackgroundColor: C.bg,
  colorScheme: ColorScheme.fromSeed(seedColor: C.blue, primary: C.blue, secondary: C.cyan),
  inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: C.mist.withOpacity(.7),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: C.blue, width: 1.6))),
  navigationBarTheme: NavigationBarThemeData(backgroundColor: Colors.white, indicatorColor: C.blue.withOpacity(.14), height: 68,
      labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
  elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(
      backgroundColor: C.blue, foregroundColor: Colors.white, elevation: 0, minimumSize: const Size.fromHeight(54),
      textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))),
);

class RainBackground extends StatefulWidget {
  final Widget child; final int drops;
  const RainBackground({super.key, required this.child, this.drops = 70});
  @override State<RainBackground> createState() => _RainState();
}
class _RainState extends State<RainBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => Container(decoration: const BoxDecoration(gradient: C.grad),
    child: Stack(children: [
      Positioned.fill(child: RepaintBoundary(child: AnimatedBuilder(animation: _c, builder: (_, __) => CustomPaint(painter: _RainPainter(_c.value, widget.drops))))),
      widget.child]));
}
class _RainPainter extends CustomPainter {
  final double t; final int n; _RainPainter(this.t, this.n);
  @override void paint(Canvas c, Size s) {
    final r = Random(7); final p = Paint()..strokeWidth = 1.5..strokeCap = StrokeCap.round;
    for (var i = 0; i < n; i++) {
      final x = r.nextDouble() * s.width, sp = .6 + r.nextDouble() * .8, len = 10 + r.nextDouble() * 18;
      final y = ((t * sp + r.nextDouble()) % 1) * (s.height + 40) - 20;
      p.color = Colors.white.withOpacity(.08 + r.nextDouble() * .16);
      c.drawLine(Offset(x, y), Offset(x - 3, y + len), p);
    }
  }
  @override bool shouldRepaint(_RainPainter o) => true;
}

class FadeIn extends StatelessWidget {
  final int i; final Widget child;
  const FadeIn(this.i, this.child, {super.key});
  @override Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1), duration: Duration(milliseconds: 450 + i * 110), curve: Curves.easeOutCubic,
    builder: (_, v, c) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 26 * (1 - v)), child: c)), child: child);
}

class SoftCard extends StatelessWidget {
  final Widget child; final EdgeInsets pad;
  const SoftCard({super.key, required this.child, this.pad = const EdgeInsets.all(16)});
  @override Widget build(BuildContext context) => Container(padding: pad, margin: const EdgeInsets.only(bottom: 14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: C.shadow), child: child);
}

class Ring extends StatelessWidget {
  final double value, size; final Color color; final String label;
  const Ring(this.value, this.color, this.label, {super.key, this.size = 64});
  @override Widget build(BuildContext context) => SizedBox(width: size, height: size, child: Stack(alignment: Alignment.center, children: [
    TweenAnimationBuilder<double>(tween: Tween(begin: 0, end: value), duration: const Duration(milliseconds: 1000), curve: Curves.easeOutCubic,
      builder: (_, v, __) => CustomPaint(size: Size(size, size), painter: _RingP(v, color))),
    Text(label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: size * .25, color: C.ink))]));
}
class _RingP extends CustomPainter {
  final double v; final Color c; _RingP(this.v, this.c);
  @override void paint(Canvas cv, Size s) {
    final r = Rect.fromLTWH(5, 5, s.width - 10, s.height - 10);
    final base = Paint()..style = PaintingStyle.stroke..strokeWidth = 7..color = c.withOpacity(.15);
    final fg = Paint()..style = PaintingStyle.stroke..strokeWidth = 7..strokeCap = StrokeCap.round..color = c;
    cv.drawArc(r, 0, 2 * pi, false, base);
    cv.drawArc(r, -pi / 2, 2 * pi * v, false, fg);
  }
  @override bool shouldRepaint(_RingP o) => o.v != v || o.c != c;
}

class Pill extends StatelessWidget {
  final String text; final Color color; final IconData? icon;
  const Pill(this.text, this.color, {super.key, this.icon});
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: color.withOpacity(.13), borderRadius: BorderRadius.circular(20)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      if (icon != null) ...[Icon(icon, size: 13, color: color), const SizedBox(width: 4)],
      Text(text, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w700))]));
}
