import 'package:flutter/material.dart';

const kBg = Color(0xFF050B1E);
const kCard = Color(0xFF0B1A3A);
const kBlue = Color(0xFF1E6BFF);
const kGreen = Color(0xFF22E06B);

void main() => runApp(const SignalsApp());

class SignalsApp extends StatelessWidget {
  const SignalsApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Farid Hamzaoui Signals Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: kBg),
      builder: (c, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
      home: const Shell(),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int tab = 0;
  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const HomePage(),
      const _Soon('السجل'),
      const _Soon('الإعدادات'),
      const _Soon('معلومات'),
    ];
    return Scaffold(
      body: SafeArea(child: pages[tab]),
      bottomNavigationBar: NavigationBar(
        backgroundColor: kCard,
        indicatorColor: kBlue.withOpacity(0.4),
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'السجل'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'الإعدادات'),
          NavigationDestination(icon: Icon(Icons.info_outline), label: 'معلومات'),
        ],
      ),
    );
  }
}

class _Soon extends StatelessWidget {
  final String name;
  const _Soon(this.name);
  @override
  Widget build(BuildContext context) =>
      Center(child: Text('صفحة $name تُضاف في خطوة قادمة'));
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const durations = [
    '30 ثانية', '1 دقيقة', '2 دقيقة', '3 دقائق', '4 دقائق', '5 دقائق',
    '6 دقائق', '7 دقائق', '8 دقائق', '9 دقائق', '10 دقائق', '11 دقيقة',
    '12 دقيقة', '13 دقيقة', '14 دقيقة', '15 دقيقة',
  ];
  String duration = '5 دقائق';
  String? pair;
  bool loading = false;
  String? result;

  Widget box(Widget child, {VoidCallback? onTap}) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kBlue.withOpacity(0.5)),
          ),
          child: child,
        ),
      );

  void pickPair() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kCard,
      builder: (_) => const Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'قائمة الأزواج تُجلب من مصدر البيانات، وهو غير متصل بعد. '
          'لن تظهر أزواج غير مدعومة.',
        ),
      ),
    );
  }

  void pickDuration() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kCard,
      builder: (_) => ListView(
        children: [
          for (final d in durations)
            ListTile(
              title: Text(d),
              trailing: d == duration
                  ? const Icon(Icons.check, color: kGreen)
                  : null,
              onTap: () {
                setState(() => duration = d);
                Navigator.pop(context);
              },
            ),
        ],
      ),
    );
  }

  Future<void> analyze() async {
    if (loading) return;
    if (pair == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('اختر زوج التداول أولاً')));
      return;
    }
    setState(() {
      loading = true;
      result = null;
    });
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      loading = false;
      result = 'DATA UNAVAILABLE';
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Farid Hamzaoui Signals Pro',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const Text('تحليل ذكي .. قرارات أدق .. فرص أفضل',
            style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 16),
        box(Row(children: const [
          Icon(Icons.link_off, color: Colors.orange),
          SizedBox(width: 8),
          Text('مصدر البيانات: غير متصل'),
        ])),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: box(
              Text(pair ?? 'اختر الزوج'),
              onTap: pickPair,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: box(Text(duration), onTap: pickDuration)),
        ]),
        const SizedBox(height: 16),
        InkWell(
          onTap: analyze,
          borderRadius: BorderRadius.circular(40),
          child: Container(
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(40),
              gradient: const LinearGradient(
                  colors: [Color(0xFF0A3CFF), Color(0xFF2E8BFF)]),
              boxShadow: [
                BoxShadow(color: kBlue.withOpacity(0.6), blurRadius: 18),
              ],
            ),
            child: loading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('تحليل الآن',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 16),
        if (result != null)
          box(Column(children: [
            Text(result!,
                style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange)),
            const Text('بيانات السوق غير متاحة، لا توجد إشارة'),
          ])),
      ],
    );
  }
}
