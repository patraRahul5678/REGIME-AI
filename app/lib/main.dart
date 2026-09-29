import 'package:flutter/material.dart';
import 'api.dart';
import 'theme.dart';
import 'screens/splash.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Api.load();
  runApp(const RainRegimeApp());
}

class RainRegimeApp extends StatelessWidget {
  const RainRegimeApp({super.key});
  @override Widget build(BuildContext context) => MaterialApp(
      title: 'RainRegime AI', debugShowCheckedModeBanner: false, theme: buildTheme(), home: const SplashScreen());
}
