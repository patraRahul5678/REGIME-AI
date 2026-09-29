import 'package:flutter/material.dart';
import '../api.dart';
import '../theme.dart';
import 'home.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _L();
}

class _L extends State<LoginScreen> {
  final email = TextEditingController(text: 'forecaster@rain.ai');
  final pass = TextEditingController(text: 'rain1234');
  final name = TextEditingController();
  final org = TextEditingController();
  bool register = false, busy = false, hide = true;
  String? err;

  Future<void> submit() async {
    setState(() { busy = true; err = null; });
    try {
      if (register) {
        await Api.register({'name': name.text.trim(), 'email': email.text.trim(), 'password': pass.text, 'organization': org.text.trim()});
      } else {
        await Api.login(email.text.trim(), pass.text);
      }
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeShell()));
    } catch (e) {
      setState(() => err = e.toString());
    }
    if (mounted) setState(() => busy = false);
  }

  Widget field(TextEditingController c, String l, IconData i, {bool pw = false, TextInputType? k}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: c,
        obscureText: pw && hide,
        keyboardType: k,
        decoration: InputDecoration(
          labelText: l,
          prefixIcon: Icon(i, color: C.blue),
          suffixIcon: pw
              ? IconButton(
                  icon: Icon(hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => hide = !hide))
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RainBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: FadeIn(
                0,
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: C.accent,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: C.cyan.withOpacity(.4), blurRadius: 30)],
                      ),
                      child: const Icon(Icons.water_drop_rounded, size: 40, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    const Text('RainRegime AI', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    const Text('Regime-aware rainfall intelligence', style: TextStyle(color: C.sky)),
                    const SizedBox(height: 28),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.25), blurRadius: 40, offset: const Offset(0, 16))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(register ? 'Create account' : 'Welcome back',
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: C.ink)),
                          Text(register ? 'Join the forecast workspace' : 'Sign in to continue',
                              style: const TextStyle(color: Colors.black45)),
                          const SizedBox(height: 20),
                          if (register) ...[
                            field(name, 'Full name', Icons.person_outline),
                            field(org, 'Organization', Icons.apartment_outlined),
                          ],
                          field(email, 'Email', Icons.mail_outline, k: TextInputType.emailAddress),
                          field(pass, 'Password', Icons.lock_outline, pw: true),
                          if (err != null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: const Color(0xFFFFEBEB), borderRadius: BorderRadius.circular(12)),
                              child: Row(children: [
                                const Icon(Icons.error_outline, color: Color(0xFFE5484D), size: 18),
                                const SizedBox(width: 8),
                                Expanded(child: Text(err!, style: const TextStyle(color: Color(0xFFB42318), fontSize: 13))),
                              ]),
                            ),
                          ElevatedButton(
                            onPressed: busy ? null : submit,
                            child: busy
                                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                                : Text(register ? 'Create account' : 'Sign in'),
                          ),
                          Center(
                            child: TextButton(
                              onPressed: () => setState(() { register = !register; err = null; }),
                              child: Text(register ? 'Have an account? Sign in' : 'New here? Create account'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text('Decision support only • Human review required', style: TextStyle(color: C.sky, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
