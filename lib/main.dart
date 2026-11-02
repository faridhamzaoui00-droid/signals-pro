import 'package:flutter/material.dart';
import 'settings_page.dart';

const kBg1 = Color(0xFF030A1F);
const kBg2 = Color(0xFF07163F);
const kCard = Color(0xFF0A1A3F);
const kLine = Color(0xFF1F4FB5);
const kBlue = Color(0xFF2E7BFF);
const kGreen = Color(0xFF2BE86F);
const kRed = Color(0xFFFF4B5C);
const kAmber = Color(0xFFFFB020);
const kCyan = Color(0xFF28D7E8);
const kGrey = Color(0xFF7C8BA8);

void main() => runApp(const SignalsApp());

Color tcolor(String t) {
  switch (t) {
    case 'UP':
      return kGreen;
    case 'DOWN':
      return kRed;
    case 'WAIT':
      return kAmber;
    default:
      return kGrey;
  }
}

Color dark(Color c, double k) => Color.lerp(Colors.black, c, k)!;

class Analysis {
  final String type;
  final int score;
  final double? winRate;
  final Map<String, String> tf;
  final double? adx, rsi;
  final String st, sr, reason;
  final bool sample;
  const Analysis({
    required this.type,
    this.score = 0,
    this.winRate,
    this.tf = const {},
    this.adx,
    this.rsi,
    this.st = '',
    this.sr = '—',
    this.reason = '—',
    this.sample = false,
  });
}

const kSample = Analysis(
  type: 'UP',
  score: 9,
  winRate: 87,
  tf: {'M15': 'UP', 'M5': 'UP', 'M1': 'UP'},
  adx: 32.5,
  rsi: 64.8,
  st: 'UP',
  sr: 'منطقة دعم قوية',
  reason: 'ارتداد من الدعم + توافق المؤشرات',
  sample: true,
);

class SignalsApp extends StatelessWidget {
  const SignalsApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Farid Hamzaoui Signals Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: kBg1),
      builder: (c, child) => MediaQuery(
        data: MediaQuery.of(c).copyWith(textScaler: TextScaler.noScaling),
        child: Directionality(textDirection: TextDirection.rtl, child: child!),
      ),
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
  void go(int i) => setState(() => tab = i);

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomePage(onSettings: () => go(2)),
      const _Soon('السجل'),
      const SettingsPage(),
      const _Soon('معلومات'),
    ];
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [kBg1, kBg2, kBg1],
          ),
        ),
        child: SafeArea(bottom: false, child: pages[tab]),
      ),
      bottomNavigationBar: _navBar(),
    );
  }

  Widget _navItem(int i, IconData icon, String label) {
    final sel = tab == i;
    final double pad = sel ? 8 : 4;
    return Expanded(
      child: InkWell(
        onTap: () => go(i),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: sel
              ? BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [kBlue.withOpacity(0.55), Colors.transparent],
                  ),
                )
              : null,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: EdgeInsets.all(pad),
              decoration: sel
                  ? BoxDecoration(
                      shape: BoxShape.circle,
                      color: kBlue.withOpacity(0.35),
                      boxShadow: [
                        BoxShadow(color: kBlue.withOpacity(0.7), blurRadius: 16)
                      ],
                    )
                  : null,
              child: Icon(icon,
                  size: 28, color: sel ? Colors.white : const Color(0xFF8FB0E8)),
            ),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                    color: sel ? kCyan : const Color(0xFF8FB0E8))),
          ]),
        ),
      ),
    );
  }

  Widget _navBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF071230),
        border: Border(top: BorderSide(color: kLine.withOpacity(0.6))),
      ),
      child: SafeArea(
        top: false,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Row(children: [
            _navItem(1, Icons.bar_chart, 'السجل'),
            _navItem(2, Icons.settings, 'الإعدادات'),
            _navItem(0, Icons.home, 'الرئيسية'),
            _navItem(3, Icons.info_outline, 'معلومات'),
          ]),
        ),
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
  final VoidCallback onSettings;
  const HomePage({super.key, required this.onSettings});
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
  bool preview = false;
  bool connected = false;
  String updated = '--:--:--';
  Analysis? current;

  String get market =>
      pair == null ? '—' : (pair!.contains('OTC') ? 'OTC' : 'السوق العادي');

  String _now() {
    final n = DateTime.now();
    String t(int v) => v.toString().padLeft(2, '0');
    return '${t(n.hour)}:${t(n.minute)}:${t(n.second)}';
  }

  void togglePreview() {
    setState(() {
      preview = !preview;
      if (preview) {
        pair = 'EUR/USD OTC';
        current = kSample;
        updated = _now();
      } else {
        pair = null;
        current = null;
        updated = '--:--:--';
      }
    });
  }

  void pickPair() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kCard,
      builder: (_) => const Padding(
        padding: EdgeInsets.all(24),
        child: Text('قائمة الأزواج تُجلب من مصدر البيانات، وهو غير متصل بعد. '
            'لن تظهر أزواج غير مدعومة.'),
      ),
    );
  }

  void pickDuration() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kCard,
      builder: (_) => ListView(children: [
        for (final d in durations)
          ListTile(
            title: Text(d),
            trailing:
                d == duration ? const Icon(Icons.check, color: kGreen) : null,
            onTap: () {
              setState(() => duration = d);
              Navigator.pop(context);
            },
          ),
      ]),
    );
  }

  Future<void> analyze() async {
    if (loading) return;
    if (pair == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('اختر زوج التداول أولاً')));
      return;
    }
    setState(() => loading = true);
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      loading = false;
      updated = _now();
      current = preview
          ? kSample
          : const Analysis(
              type: 'NA', reason: 'مصدر البيانات غير متصل، لا توجد إشارة');
    });
  }

  BoxDecoration _glass(Color border, {double r = 18}) => BoxDecoration(
        borderRadius: BorderRadius.circular(r),
        border: Border.all(color: border.withOpacity(0.7), width: 1.2),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [kCard.withOpacity(0.95), const Color(0xFF071533)],
        ),
        boxShadow: [BoxShadow(color: border.withOpacity(0.25), blurRadius: 10)],
      );

  Widget _header() {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(children: [
        GestureDetector(
          onLongPress: togglePreview,
          child: Image.asset('assets/logo.png', width: 58),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: RichText(
                text: const TextSpan(
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  children: [
                    TextSpan(text: 'Farid Hamzaoui Signals '),
                    TextSpan(text: 'Pro', style: TextStyle(color: kBlue)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 2),
            const FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text('تحليل ذكي .. قرارات أدق .. فرص أفضل',
                  style: TextStyle(fontSize: 13, color: Colors.white70)),
            ),
          ]),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: widget.onSettings,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: _glass(kLine, r: 14),
            child: const Icon(Icons.settings, color: kBlue, size: 26),
          ),
        ),
      ]),
    );
  }

  Widget _statusRow() {
    final c = connected ? kGreen : kAmber;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(children: [
        Expanded(
          child: Container(
            height: 74,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: _glass(c),
            child: Row(children: [
              Icon(connected ? Icons.verified_user : Icons.gpp_maybe,
                  color: c, size: 28),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(connected ? 'متصل' : 'غير متصل',
                            style: TextStyle(
                                color: c,
                                fontSize: 17,
                                fontWeight: FontWeight.bold)),
                      ),
                      const FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text('مصدر البيانات',
                            style: TextStyle(
                                fontSize: 12, color: Colors.white70)),
                      ),
                    ]),
              ),
            ]),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 74,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: _glass(kLine),
            child: Row(children: [
              const Icon(Icons.access_time, color: kBlue, size: 28),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text('آخر تحديث', style: TextStyle(fontSize: 13)),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(updated,
                            style: const TextStyle(
                                color: kCyan,
                                fontSize: 17,
                                fontWeight: FontWeight.bold)),
                      ),
                    ]),
              ),
            ]),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 74,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: _glass(kLine),
            child: Row(children: [
              Image.asset('assets/po.png', width: 28),
              const SizedBox(width: 6),
              const Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text('Pocket Option',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _selector(IconData icon, String label, String value, VoidCallback f) {
    return Expanded(
      child: InkWell(
        onTap: f,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 78,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: _glass(kLine),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Row(children: [
              Icon(icon, size: 34, color: kGreen),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: const TextStyle(
                              fontSize: 13, color: Colors.white70)),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(value,
                            style: const TextStyle(
                                fontSize: 19, fontWeight: FontWeight.bold)),
                      ),
                    ]),
              ),
              const Icon(Icons.keyboard_arrow_down, color: Colors.white70),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _analyzeButton() {
    return InkWell(
      onTap: analyze,
      borderRadius: BorderRadius.circular(40),
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: const Color(0xFF6FB1FF), width: 1.5),
          gradient: const LinearGradient(
              colors: [Color(0xFF0A3CFF), Color(0xFF2E8BFF), Color(0xFF0A3CFF)]),
          boxShadow: [BoxShadow(color: kBlue.withOpacity(0.7), blurRadius: 22)],
        ),
        child: loading
            ? const Center(
                child: SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 3)))
            : Directionality(
                textDirection: TextDirection.ltr,
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.query_stats, size: 36, color: Colors.white),
                  const SizedBox(width: 14),
                  const Text('تحليل الآن',
                      style:
                          TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 14),
                  Icon(Icons.keyboard_double_arrow_left,
                      size: 36, color: Colors.white.withOpacity(0.9)),
                ]),
              ),
      ),
    );
  }

  Widget _signalCard(Analysis? a) {
    final t = a?.type ?? 'NONE';
    final c = tcolor(t);
    final arrow = t == 'UP' || t == 'DOWN';
    String badge;
    String main;
    String big;
    String chip;
    if (arrow) {
      final sc = a!.score;
      badge = sc >= 10
          ? 'توافق ممتاز'
          : (sc == 9 ? 'إشارة قوية جداً' : 'إشارة قوية');
      main = t == 'UP' ? 'UP – صاعد' : 'DOWN – هابط';
      big = a.winRate != null ? '${a.winRate!.round()}%' : '—';
      chip = a.winRate != null
          ? 'نسبة النجاح التاريخية'
          : 'بيانات غير كافية لنسبة النجاح';
    } else if (t == 'WAIT') {
      badge = 'لا توجد فرصة';
      main = 'WAIT – انتظر';
      big = '—';
      chip = a!.reason;
    } else if (t == 'NA') {
      badge = 'بيانات غير متاحة';
      main = 'DATA UNAVAILABLE';
      big = '—';
      chip = a!.reason;
    } else {
      badge = 'جاهز';
      main = 'بانتظار التحليل';
      big = '—';
      chip = 'اختر الزوج ثم اضغط تحليل';
    }
    return LayoutBuilder(builder: (ctx, cons) {
      final s = cons.maxWidth / 960;
      Widget img = Image.asset('assets/arrow.png');
      if (t == 'DOWN') {
        img = Transform(
          alignment: Alignment.center,
          transform: Matrix4.diagonal3Values(1, -1, 1),
          child: ColorFiltered(
            colorFilter: const ColorFilter.matrix(<double>[
              0, 1, 0, 0, 0,
              1, 0, 0, 0, 0,
              0, 0, 1, 0, 0,
              0, 0, 0, 1, 0,
            ]),
            child: img,
          ),
        );
      }
      return Container(
        height: 345 * s,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30 * s),
          border: Border.all(color: c, width: 2),
          boxShadow: [BoxShadow(color: c.withOpacity(0.45), blurRadius: 18)],
          gradient: LinearGradient(colors: [dark(c, 0.14), dark(c, 0.32)]),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28 * s),
          child: Stack(children: [
            Positioned(
              left: 4 * s,
              top: 5 * s,
              width: 396 * s,
              height: 328 * s,
              child: Image.asset('assets/bull.png', fit: BoxFit.fill),
            ),
            if (arrow)
              Positioned(
                right: 6 * s,
                bottom: 3 * s,
                width: 240 * s,
                height: 265 * s,
                child: img,
              ),
            Positioned(
              left: 400 * s,
              right: (arrow ? 215 : 20) * s,
              top: 10 * s,
              bottom: 10 * s,
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 22 * s, vertical: 8 * s),
                        decoration: BoxDecoration(
                          color: c.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(40),
                          border: Border.all(color: c),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(badge,
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 36 * s)),
                            SizedBox(width: 8 * s),
                            Icon(Icons.check_circle, color: c, size: 44 * s),
                          ]),
                        ),
                      ),
                      SizedBox(height: 8 * s),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(main,
                              style: TextStyle(
                                  color: Color.lerp(c, Colors.white, 0.1),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 66 * s)),
                        ),
                      ),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(big,
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 120 * s)),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 20 * s, vertical: 6 * s),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(40),
                          border: Border.all(color: c),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(chip,
                              style: TextStyle(
                                  color: Colors.white, fontSize: 34 * s)),
                        ),
                      ),
                    ]),
              ),
            ),
          ]),
        ),
      );
    });
  }

  Widget _tfCell(String name, String v) {
    final up = v == 'UP', down = v == 'DOWN';
    final c = up ? kGreen : (down ? kRed : kGrey);
    String txt = up ? 'صاعد' : (down ? 'هابط' : '—');
    if (name == 'M1' && up) txt = 'تأكيد شراء';
    if (name == 'M1' && down) txt = 'تأكيد بيع';
    return Expanded(
      child: Column(children: [
        Text(name,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(up ? Icons.north_east : (down ? Icons.south_east : Icons.remove),
                color: c, size: 22),
            const SizedBox(width: 4),
            Text(txt,
                style: TextStyle(
                    color: c, fontSize: 16, fontWeight: FontWeight.bold)),
          ]),
        ),
      ]),
    );
  }

  Widget _metric(IconData icon, Color ic, String label, String value, Color vc) {
    return Expanded(
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: ic, size: 22),
        const SizedBox(width: 3),
        Flexible(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label, style: const TextStyle(fontSize: 13)),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                  style: TextStyle(
                      color: vc, fontSize: 20, fontWeight: FontWeight.bold)),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _box(Widget child) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kLine.withOpacity(0.5)),
          color: Colors.black12,
        ),
        child: child,
      );

  Widget _details(Analysis? a) {
    final real =
        a != null && (a.type == 'UP' || a.type == 'DOWN' || a.type == 'WAIT');
    final stUp = a?.st == 'UP';
    final stDown = a?.st == 'DOWN';
    final adxTxt = a?.adx != null ? a!.adx!.toStringAsFixed(1) : '—';
    final rsiTxt = a?.rsi != null ? a!.rsi!.toStringAsFixed(1) : '—';
    final scoreTxt = real ? '${a.score}/10' : '—';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _glass(kLine, r: 22),
      child: Column(children: [
        Align(
          alignment: Alignment.centerRight,
          child: Row(mainAxisSize: MainAxisSize.min, children: const [
            Icon(Icons.bar_chart, color: kBlue, size: 28),
            SizedBox(width: 8),
            Text('تفاصيل التحليل',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ]),
        ),
        const SizedBox(height: 10),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Column(children: [
            _box(Row(children: [
              _tfCell('M15', a?.tf['M15'] ?? ''),
              _tfCell('M5', a?.tf['M5'] ?? ''),
              _tfCell('M1', a?.tf['M1'] ?? ''),
            ])),
            const SizedBox(height: 8),
            _box(Row(children: [
              _metric(Icons.star, kAmber, 'التقييم', scoreTxt, kAmber),
              _metric(Icons.verified_user_outlined, kGreen, 'ADX', adxTxt,
                  Colors.white),
              _metric(Icons.show_chart, kCyan, 'RSI', rsiTxt, Colors.white),
              _metric(
                  Icons.multiline_chart,
                  kBlue,
                  'SuperTrend',
                  stUp ? 'صاعد' : (stDown ? 'هابط' : '—'),
                  stUp ? kGreen : (stDown ? kRed : Colors.white)),
            ])),
            const SizedBox(height: 8),
            _box(Row(children: [
              Expanded(
                child: Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
                    Icon(Icons.grid_view, color: kCyan, size: 20),
                    SizedBox(width: 6),
                    Text('الدعم والمقاومة', style: TextStyle(fontSize: 14)),
                  ]),
                  const SizedBox(height: 4),
                  Text(a?.sr ?? '—',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: kCyan,
                          fontSize: 17,
                          fontWeight: FontWeight.bold)),
                ]),
              ),
              Container(width: 1, height: 50, color: kLine.withOpacity(0.5)),
              Expanded(
                child: Column(children: [
                  const Text('السبب الرئيسي', style: TextStyle(fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(a?.reason ?? '—',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14)),
                ]),
              ),
            ])),
          ]),
        ),
      ]),
    );
  }

  Widget _footer() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: _glass(kLine, r: 20),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            const Icon(Icons.access_time, size: 26),
            const SizedBox(width: 8),
            Text('مدة الصفقة: $duration', style: const TextStyle(fontSize: 16)),
          ]),
          Row(children: [
            Text('نوع السوق: $market', style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            const Icon(Icons.stacked_bar_chart, color: kGreen, size: 26),
          ]),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
      children: [
        _header(),
        const SizedBox(height: 12),
        _statusRow(),
        const SizedBox(height: 12),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Row(children: [
            _selector(Icons.candlestick_chart, 'زوج التداول',
                pair ?? 'اختر الزوج', pickPair),
            const SizedBox(width: 10),
            _selector(Icons.access_time, 'مدة الصفقة', duration, pickDuration),
          ]),
        ),
        const SizedBox(height: 14),
        _analyzeButton(),
        const SizedBox(height: 14),
        if (preview)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('معاينة تصميم: بيانات تجريبية وليست إشارة حقيقية',
                textAlign: TextAlign.center,
                style: TextStyle(color: kAmber, fontSize: 13)),
          ),
        _signalCard(current),
        const SizedBox(height: 12),
        _details(current),
        const SizedBox(height: 12),
        _footer(),
      ],
    );
  }
}
