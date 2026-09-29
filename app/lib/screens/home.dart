import 'package:flutter/material.dart';
import '../api.dart';
import '../theme.dart';
import 'login.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override State<HomeShell> createState() => _H();
}
class _H extends State<HomeShell> {
  int i = 0;
  static const titles = ['Overview', 'District Forecast', 'Verification', 'Profile'];
  @override Widget build(BuildContext context) => Scaffold(
    body: Column(children: [
      ClipRRect(borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)), child: RainBackground(drops: 40, child: SafeArea(bottom: false,
        child: Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 20), child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Hello, ${(Api.user?['name'] ?? '').toString().split(' ').first} 👋', style: const TextStyle(color: C.sky, fontSize: 13)),
            const SizedBox(height: 2),
            Text(titles[i], style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
          ])),
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withOpacity(.12), shape: BoxShape.circle),
              child: const Icon(Icons.water_drop_rounded, color: C.cyan)),
        ]))))),
      Expanded(child: IndexedStack(index: i, children: const [DashboardTab(), DistrictsTab(), VerificationTab(), ProfileTab()])),
    ]),
    bottomNavigationBar: NavigationBar(selectedIndex: i, onDestinationSelected: (v) => setState(() => i = v), destinations: const [
      NavigationDestination(icon: Icon(Icons.grid_view_outlined), selectedIcon: Icon(Icons.grid_view_rounded, color: C.blue), label: 'Overview'),
      NavigationDestination(icon: Icon(Icons.location_on_outlined), selectedIcon: Icon(Icons.location_on, color: C.blue), label: 'Districts'),
      NavigationDestination(icon: Icon(Icons.verified_outlined), selectedIcon: Icon(Icons.verified, color: C.blue), label: 'Verify'),
      NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person, color: C.blue), label: 'Profile'),
    ]),
  );
}

class Loader extends StatefulWidget {
  final String path; final Widget Function(Map<String, dynamic>) builder;
  const Loader(this.path, this.builder, {super.key});
  @override State<Loader> createState() => _LoaderState();
}
class _LoaderState extends State<Loader> {
  late Future<Map<String, dynamic>> f = Api.get(widget.path);
  @override Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: () async { setState(() => f = Api.get(widget.path)); await f; },
    child: FutureBuilder<Map<String, dynamic>>(future: f, builder: (_, s) {
      if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
      if (s.hasError) return ListView(children: [Padding(padding: const EdgeInsets.all(40), child: Column(children: [
        const Icon(Icons.cloud_off_rounded, size: 56, color: C.sky), const SizedBox(height: 12),
        Text('${s.error}', textAlign: TextAlign.center), const Text('Pull down to retry', style: TextStyle(color: Colors.black45))]))]);
      return widget.builder(s.data!);
    }));
}

Widget _iconBox(IconData ic, Color c) => Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: c.withOpacity(.12), borderRadius: BorderRadius.circular(12)), child: Icon(ic, color: c, size: 22));

class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});
  @override Widget build(BuildContext context) => Loader('/forecast/summary', (d) => ListView(padding: const EdgeInsets.all(16), children: [
    FadeIn(0, Container(padding: const EdgeInsets.all(20), margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(gradient: C.accent, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: C.blue.withOpacity(.35), blurRadius: 24, offset: const Offset(0, 10))]),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Pill('HEADLINE RISK', Colors.white, icon: Icons.warning_amber_rounded),
          const SizedBox(height: 12),
          Text(d['headline'], style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800, height: 1.25)),
          const SizedBox(height: 8),
          Text('Cycle ${d['cycle']}', style: TextStyle(color: Colors.white.withOpacity(.85), fontSize: 12)),
        ])),
        const Icon(Icons.thunderstorm_rounded, size: 64, color: Colors.white38),
      ]))),
    FadeIn(1, Row(children: [
      Expanded(child: _stat(Icons.cyclone, C.blue, 'Regime', d['regime'], '${(d['confidence'] * 100).round()}% confidence')),
      const SizedBox(width: 12),
      Expanded(child: _stat(Icons.crisis_alert, const Color(0xFFE5484D), 'High-risk', '${d['highRiskCount']} districts', '> ${d['threshold']} mm')),
    ])),
    FadeIn(2, SoftCard(child: Row(children: [_iconBox(Icons.memory, const Color(0xFF12A594)), const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Active model', style: TextStyle(color: Colors.black45, fontSize: 12)),
        Text(d['modelVersion'], style: const TextStyle(fontWeight: FontWeight.w800, color: C.ink, fontSize: 16)),
        const Text('Raw NWP kept as baseline', style: TextStyle(color: Colors.black38, fontSize: 11))]))]))),
    FadeIn(3, SoftCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Forecast pipeline', style: TextStyle(fontWeight: FontWeight.w800, color: C.ink, fontSize: 16)),
      const SizedBox(height: 12),
      ...['Raw NWP', 'Weather regime', 'Suitable correction', 'Heavy-rain probability', 'District / grid product', 'Verification'].asMap().entries.map((e) =>
        Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
          CircleAvatar(radius: 11, backgroundColor: C.blue, child: Text('${e.key + 1}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
          const SizedBox(width: 12), Text(e.value, style: const TextStyle(color: C.ink))]))),
    ]))),
  ]));
  Widget _stat(IconData ic, Color c, String t, String v, String sub) => SoftCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _iconBox(ic, c), const SizedBox(height: 12),
    Text(t, style: const TextStyle(color: Colors.black45, fontSize: 12)),
    Text(v, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: C.ink)),
    Text(sub, style: const TextStyle(fontSize: 11, color: Colors.black38))]));
}

class DistrictsTab extends StatefulWidget {
  const DistrictsTab({super.key});
  @override State<DistrictsTab> createState() => _DT();
}
class _DT extends State<DistrictsTab> {
  String q = ''; bool highOnly = false;
  @override Widget build(BuildContext context) => Loader('/forecast/districts', (d) {
    final list = (d['districts'] as List).where((x) => x['district'].toString().toLowerCase().contains(q.toLowerCase()) && (!highOnly || x['heavyProb'] >= .5)).toList();
    return ListView(padding: const EdgeInsets.all(16), children: [
      TextField(onChanged: (v) => setState(() => q = v), decoration: const InputDecoration(hintText: 'Search district', prefixIcon: Icon(Icons.search))),
      const SizedBox(height: 10),
      Row(children: [
        FilterChip(label: const Text('High risk only'), selected: highOnly, onSelected: (v) => setState(() => highOnly = v), selectedColor: C.blue.withOpacity(.18)),
        const Spacer(), Text('P(> ${d['threshold']} mm)', style: const TextStyle(color: Colors.black45, fontSize: 12))]),
      Text('${d['validPeriod']} • Tap a district for AI explanation • Source: ${d['source']}', style: const TextStyle(color: Colors.black38, fontSize: 11)),
      const SizedBox(height: 10),
      ...list.asMap().entries.map((e) {
        final x = e.value; final p = (x['heavyProb'] as num).toDouble(); final col = C.risk(p);
        final delta = (x['correctedMm'] as num) - (x['rawMm'] as num);
        return FadeIn(e.key, GestureDetector(onTap: () => showExplain(context, x['district']), child: SoftCard(child: Row(children: [
          Ring(p, col, '${(p * 100).round()}%'),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Expanded(child: Text(x['district'], style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: C.ink))), Pill(C.riskLabel(p), col)]),
            const SizedBox(height: 2),
            Text(x['regime'], style: const TextStyle(color: Colors.black45, fontSize: 12)),
            const SizedBox(height: 10),
            Row(children: [
              Text('${x['rawMm']}', style: const TextStyle(color: Colors.black38, decoration: TextDecoration.lineThrough, fontSize: 14)),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Icon(Icons.arrow_forward_rounded, size: 15, color: C.sky)),
              Text('${x['correctedMm']} mm', style: const TextStyle(color: C.blue, fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(width: 8), Pill('${delta >= 0 ? '+' : ''}$delta', delta >= 0 ? C.blue : Colors.grey),
            ]),
          ])),
        ]))));
      }),
      if (list.isEmpty) const Padding(padding: EdgeInsets.all(40), child: Center(child: Text('No districts match', style: TextStyle(color: Colors.black38)))),
    ]);
  });
}

class VerificationTab extends StatelessWidget {
  const VerificationTab({super.key});
  @override Widget build(BuildContext context) => Loader('/verification', (d) {
    final ms = d['metrics'] as List;
    final gains = ms.map((m) { final r = (m['raw'] as num).toDouble(), c = (m['corrected'] as num).toDouble(); return (m['lowerBetter'] == true ? (r - c) : (c - r)) / (r == 0 ? 1 : r) * 100; }).toList();
    final avg = gains.reduce((a, b) => a + b) / gains.length;
    return ListView(padding: const EdgeInsets.all(16), children: [
      FadeIn(0, Container(padding: const EdgeInsets.all(20), margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(gradient: C.grad, borderRadius: BorderRadius.circular(24)),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Average skill improvement', style: TextStyle(color: C.sky, fontSize: 12)),
            Text('+${avg.toStringAsFixed(0)}%', style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800)),
            const Text('Corrected vs raw NWP', style: TextStyle(color: C.cyan, fontSize: 12))])),
          const Icon(Icons.trending_up_rounded, size: 60, color: C.cyan)]))),
      ...ms.asMap().entries.map((e) {
        final m = e.value; final raw = (m['raw'] as num).toDouble(), cor = (m['corrected'] as num).toDouble(), mx = raw > cor ? raw : cor, g = gains[e.key];
        return FadeIn(e.key + 1, SoftCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(m['name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: C.ink)),
            if (m['lowerBetter'] == true) const Text('  lower is better', style: TextStyle(fontSize: 11, color: Colors.black38)),
            const Spacer(), Pill('${g >= 0 ? '+' : ''}${g.toStringAsFixed(0)}%', g >= 0 ? const Color(0xFF12A594) : const Color(0xFFE5484D), icon: g >= 0 ? Icons.arrow_upward : Icons.arrow_downward)]),
          const SizedBox(height: 12), _bar('Raw NWP', raw, mx, Colors.blueGrey.shade200),
          const SizedBox(height: 8), _bar('Corrected', cor, mx, C.blue),
        ])));
      }),
      Text(d['note'], style: const TextStyle(color: Colors.black38, fontSize: 11)),
    ]);
  });
  Widget _bar(String l, double v, double mx, Color c) => Row(children: [
    SizedBox(width: 74, child: Text(l, style: const TextStyle(fontSize: 12, color: Colors.black54))),
    Expanded(child: TweenAnimationBuilder<double>(tween: Tween(begin: 0, end: (mx == 0 ? 0.0 : v / mx)), duration: const Duration(milliseconds: 900), curve: Curves.easeOutCubic,
      builder: (_, t, __) => ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: t, color: c, backgroundColor: C.mist, minHeight: 10)))),
    SizedBox(width: 48, child: Text('$v', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700, color: C.ink)))]);
}

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});
  @override State<ProfileTab> createState() => _P();
}
class _P extends State<ProfileTab> {
  final name = TextEditingController(text: Api.user?['name']), org = TextEditingController(text: Api.user?['organization']),
      role = TextEditingController(text: Api.user?['role']);
  bool busy = false;
  void snack(String m) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating)); }
  Future<void> save() async {
    setState(() => busy = true);
    try { await Api.updateProfile({'name': name.text, 'organization': org.text, 'role': role.text}); snack('Profile updated'); } catch (e) { snack('$e'); }
    if (mounted) setState(() => busy = false);
  }
  Future<void> logout() async {
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Log out?'), content: const Text('You will need to sign in again.'),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE5484D)), onPressed: () => Navigator.pop(c, true), child: const Text('Log out'))]));
    if (ok != true) return;
    await Api.logout();
    if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }
  @override Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
    FadeIn(0, SoftCard(pad: const EdgeInsets.all(20), child: Row(children: [
      Container(width: 68, height: 68, alignment: Alignment.center, decoration: const BoxDecoration(gradient: C.accent, shape: BoxShape.circle),
        child: Text((Api.user?['name'] ?? '?').toString().substring(0, 1).toUpperCase(), style: const TextStyle(fontSize: 30, color: Colors.white, fontWeight: FontWeight.w800))),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(Api.user?['name'] ?? '', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: C.ink)),
        Text(Api.user?['email'] ?? '', style: const TextStyle(color: Colors.black45, fontSize: 13)),
        const SizedBox(height: 6), Pill(Api.user?['role'] ?? '', C.blue, icon: Icons.badge_outlined)]))]))),
    FadeIn(1, SoftCard(pad: const EdgeInsets.all(20), child: Column(children: [
      TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline))), const SizedBox(height: 14),
      TextField(controller: role, decoration: const InputDecoration(labelText: 'Role', prefixIcon: Icon(Icons.badge_outlined))), const SizedBox(height: 14),
      TextField(controller: org, decoration: const InputDecoration(labelText: 'Organization', prefixIcon: Icon(Icons.apartment_outlined))), const SizedBox(height: 20),
      ElevatedButton(onPressed: busy ? null : save, child: const Text('Save changes'))]))),
    FadeIn(2, OutlinedButton.icon(onPressed: logout, icon: const Icon(Icons.logout_rounded), label: const Text('Log out'),
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(54), foregroundColor: const Color(0xFFE5484D), side: const BorderSide(color: Color(0xFFE5484D)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))))),
  ]);
}

void showExplain(BuildContext context, String district) {
  showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => Padding(padding: const EdgeInsets.all(24), child: FutureBuilder<Map<String, dynamic>>(
      future: Api.get('/forecast/explain/${Uri.encodeComponent(district)}'),
      builder: (_, s) {
        if (s.connectionState != ConnectionState.done) return const SizedBox(height: 180, child: Center(child: CircularProgressIndicator()));
        if (s.hasError) return SizedBox(height: 160, child: Center(child: Text('${s.error}')));
        final d = s.data!;
        Widget list(String t, List l, IconData ic, Color c) => Padding(padding: const EdgeInsets.only(top: 14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t, style: const TextStyle(fontWeight: FontWeight.w800, color: C.ink)),
          ...l.map((x) => Padding(padding: const EdgeInsets.only(top: 6), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(ic, size: 16, color: c), const SizedBox(width: 8), Expanded(child: Text('$x', style: const TextStyle(fontSize: 13)))])))]));
        return SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Text(d['district'], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: C.ink))),
            Pill(d['source'] == 'gemini' ? 'Gemini AI' : 'Rule-based', d['source'] == 'gemini' ? C.blue : Colors.grey, icon: Icons.auto_awesome)]),
          const SizedBox(height: 10), Text(d['summary'], style: const TextStyle(height: 1.4)),
          list('Key drivers', d['drivers'] as List, Icons.bolt, C.blue),
          list('Caveats', d['caveats'] as List, Icons.info_outline, const Color(0xFFF5A524)),
          list('Suggested action', [d['action']], Icons.check_circle_outline, const Color(0xFF12A594)),
          const SizedBox(height: 12), const Text('Decision support only. Follow official IMD warnings.', style: TextStyle(fontSize: 11, color: Colors.black38)),
        ]));
      })));
}
