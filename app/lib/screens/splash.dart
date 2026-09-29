import 'package:flutter/material.dart';
import '../api.dart';
import '../theme.dart';
import 'login.dart';
import 'home.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override State<SplashScreen> createState() => _S();
}
class _S extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..forward();
  @override void initState() {
    super.initState();
    Future.wait([Api.restore(), Future.delayed(const Duration(milliseconds: 2600))]).then((r) {
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => r[0] == true ? const HomeShell() : const LoginScreen()));
    });
  }
  @override void dispose() { _a.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => Scaffold(
    body: RainBackground(child: Center(child: FadeTransition(opacity: _a, child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(.12),
          border: Border.all(color: C.cyan, width: 2)), child: const Icon(Icons.thunderstorm_rounded, size: 64, color: Colors.white)),
      const SizedBox(height: 24),
      const Text('RainRegime AI', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: .5)),
      const SizedBox(height: 8),
      const Text('Regime-Aware Rainfall Intelligence', style: TextStyle(color: C.sky, fontSize: 14)),
      const SizedBox(height: 36),
      const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3, color: C.cyan)),
    ])))),
  );
}
