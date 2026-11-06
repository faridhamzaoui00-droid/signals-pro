import 'package:flutter/material.dart';
import 'engine/cfg.dart';
import 'engine/datasource.dart';
import 'engine/indicators.dart';
import 'engine/monitor.dart';
import 'engine/strategy.dart';
import 'history_page.dart';
import 'info_page.dart';
import 'l10n.dart';
import 'l10n2.dart';
import 'notify_page.dart';
import 'pair_sheet.dart';
import 'settings_page.dart';
import 'signals_page.dart';
import 'strategy_page.dart';

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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadLang();
  runApp(const SignalsApp());
}

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

String rtext(String enc) {
  return enc
      .split(';')
      .where((e) => e.isNotEmpty)
      .map((e) {
        final p = e.split('|');
        return t2(p[0], p.length > 1 ? p[1] : null);
      })
      .join(' • ');
}

String encR(List<Reason> rs) =>
    rs.map((r) => r.v == null ? r.key : '${r.key}|${r.v}').join(';');

String arrow(int? v) => v == 1 ? '↑' : (v == -1 ? '↓' : '–');

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
    this.sr = 'sr_none',
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
  sr: 'sample_sr',
  reason: 'sample_reason',
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
        child: ValueListenableBuilder<String>(
          valueListenable: langNotifier,
          builder: (_, l, __) =>
              Directionality(textDirection: dirFor(l), child: child!),
        ),
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

  void _onLang() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    langNotifier.addListener(_onLang);
    Monitor.I.load();
  }

  @override
  void dispose() {
    langNotifier.removeListener(_onLang);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomePage(onSettings: () => go(2)),
      const HistoryPage(),
      const SettingsPage(),
      const InfoPage(),
      const SignalsPage(),
      const NotifyPage(),
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
    final double pad = sel ? 6 : 3;
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
                        BoxShadow(color: kBlue.withOpacity(0.7), blurRadius: 14)
                      ],
                    )
                  : null,
              child: Icon(icon,
                  size: 24, color: sel ? Colors.white : const Color(0xFF8FB0E8)),
            ),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(label,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                        color: sel ? kCyan : const Color(0xFF8FB0E8))),
              ),
            ),
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
            _navItem(1, Icons.bar_chart, tr('nav_history')),
            _navItem(2, Icons.settings, tr('nav_settings')),
            _navItem(0, Icons.home, tr('nav_home')),
            _navItem(4, Icons.bolt, t2('nav_signals')),
            _navItem(5, Icons.notifications_active, t2('nav_notify')),
            _navItem(3, Icons.info_outline, tr('nav_info')),
          ]),
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final VoidCallback onSettings;
  const HomePage({super.key, required this.onSettings});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const durations = [
    30, 60, 120, 180, 240, 300, 360, 420, 480, 540, 600, 660, 720, 780, 840, 900,
  ];
  int duration = 300;
  String? pair;
  bool loading = false;
  bool preview = false;
  bool connected = false;
  String updated = '--:--:--';
  Analysis? current;

  void _onLang() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    langNotifier.addListener(_onLang);
    Cfg.load().then((_) {
      if (mounted) setState(() {});
    });
    DataSource.resolvePending();
  }

  @override
  void dispose() {
    langNotifier.removeListener(_onLang);
    super.dispose();
  }

  String get market => pair == null
      ? '—'
      : (pair!.contains('OTC') ? 'OTC' : tr('market_regular'));

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

  Future<void> pickPair() async {
    final r = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: kCard,
      builder: (_) => const PairSheet(),
    );
    if (!mounted || r == null) return;
    setState(() {
      pair = r;
      preview = false;
      current = null;
    });
  }

  void pickDuration() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kCard,
      builder: (_) => ListView(children: [
        for (final d in durations)
          ListTile(
            title: Text(durText(d)),
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

  double? _winRate(List<SignalRecord> all, String p, int dur) {
    final d = all
        .where((r) =>
            r.pair == p &&
            r.duration == '$dur' &&
            (r.result == 'WIN' || r.result == 'LOSS'))
        .toList();
    if (d.length < 30) return null;
    return d.where((r) => r.result == 'WIN').length * 100 / d.length;
  }

  Analysis _toAnalysis(EngineResult r, double? wr) {
    String dn(int? v) => v == 1 ? 'UP' : (v == -1 ? 'DOWN' : '');
    return Analysis(
      type: r.type,
      score: r.score,
      winRate: wr,
      tf: {for (final e in r.tf.entries) e.key: dn(e.value)},
      adx: r.adx,
      rsi: r.rsi,
      st: dn(r.st),
      sr: r.sr,
      reason: encR(r.reasons),
    );
  }

  Future<Analysis> _realAnalysis() async {
    final p = pair!;
    Analysis na(String key) => Analysis(type: 'NA', reason: key);
    final tfs = Strategy.tfsFor(duration);
    if (tfs.isEmpty) return na('na_duration');
    final data = <String, List<Candle>>{};
    for (final n in tfs) {
      final f = await DataSource.candles(
          p, n, DateTime.now().millisecondsSinceEpoch);
      if (f.data == null) {
        connected = false;
        return na(f.error ?? 'na_source_error');
      }
      data[n] = f.data!;
    }
    connected = true;
    var hist = <SignalRecord>[];
    try {
      hist = await HistoryDb.all();
    } catch (_) {}
    LastSignal? last;
    for (final h in hist) {
      if (h.pair == p) {
        last = LastSignal(h.direction, h.issuedAt, h.price ?? 0);
        break;
      }
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final r = Strategy.run(
      data: data,
      durationSec: duration,
      nowMs: now,
      connectionOk: true,
      last: last,
    );
    if (r.type == 'UP' || r.type == 'DOWN') {
      final ind = 'RSI ${r.rsi?.toStringAsFixed(1)} | ADX '
          '${r.adx?.toStringAsFixed(1)} | ST ${arrow(r.st)} | ATR '
          '${r.atr?.toStringAsFixed(5)} | '
          '${r.tf.entries.map((e) => '${e.key}${arrow(e.value)}').join(' ')}';
      try {
        await HistoryDb.insert(SignalRecord(
          pair: p,
          market: p.contains('OTC') ? 'OTC' : 'REG',
          direction: r.type,
          duration: '$duration',
          indicators: ind,
          reasons: r.reasons.map((x) => t2(x.key, x.v)).join(' • '),
          issuedAt: now,
          price: r.price,
          score: r.score,
        ));
      } catch (_) {}
    }
    DataSource.resolvePending();
    return _toAnalysis(r, r.type == 'NA' ? null : _winRate(hist, p, duration));
  }

  Future<void> analyze() async {
    if (loading) return;
    if (pair == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr('pick_pair_first'))));
      return;
    }
    setState(() => loading = true);
    Analysis res;
    if (preview) {
      await Future.delayed(const Duration(seconds: 1));
      res = kSample;
    } else {
      try {
        res = await _realAnalysis();
      } catch (_) {
        res = const Analysis(type: 'NA', reason: 'na_source_error');
      }
    }
    if (!mounted) return;
    setState(() {
      loading = false;
      updated = _now();
      current = res;
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
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(tr('tagline'),
                  style: const TextStyle(fontSize: 13, color: Colors.white70)),
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
                        child: Text(
                            connected ? tr('connected') : tr('disconnected'),
                            style: TextStyle(
                                color: c,
                                fontSize: 17,
                                fontWeight: FontWeight.bold)),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(tr('data_source'),
                            style: const TextStyle(
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
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(tr('last_update'),
                            style: const TextStyle(fontSize: 13)),
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
            textDirection: dirFor(langNotifier.value),
            child: Row(children: [
              Icon(icon, size: 34, color: kGreen),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(label,
                            style: const TextStyle(
                                fontSize: 13, color: Colors.white70)),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
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
                  const SizedBox(width: 12),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(tr('analyze_now'),
                          style: const TextStyle(
                              fontSize: 28, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.keyboard_double_arrow_left,
                      size: 36, color: Colors.white.withOpacity(0.9)),
                ]),
              ),
      ),
    );
  }

  Widget _stratLine() {
    final l = langNotifier.value;
    final label = l == 'ar' ? 'الاستراتيجية' : (l == 'fr' ? 'Stratégie' : 'Strategy');
    return InkWell(
      onTap: () async {
        await Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const StrategyPage()));
        if (mounted) setState(() {});
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: _glass(kLine, r: 14),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Row(children: [
            const Icon(Icons.tune, color: kCyan, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text('$label: ${Cfg.activeLine()}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13)),
            ),
            const Icon(Icons.chevron_right, color: Colors.white54),
          ]),
        ),
      ),
    );
  }

  Widget _signalCard(Analysis? a) {
    final t = a?.type ?? 'NONE';
    final c = tcolor(t);
    final hasArrow = t == 'UP' || t == 'DOWN';
    String badge;
    String main;
    String big;
    String chip;
    if (hasArrow) {
      final sc = a!.score;
      badge = sc >= 10
          ? tr('badge_excellent')
          : (sc == 9 ? tr('badge_vstrong') : tr('badge_strong'));
      main = t == 'UP' ? tr('main_up') : tr('main_down');
      big = a.winRate != null ? '${a.winRate!.round()}%' : '—';
      chip = a.winRate != null ? tr('chip_rate') : tr('chip_nodata');
    } else if (t == 'WAIT') {
      badge = tr('badge_wait');
      main = tr('main_wait');
      big = '—';
      chip = rtext(a!.reason);
    } else if (t == 'NA') {
      badge = tr('badge_na');
      main = 'DATA UNAVAILABLE';
      big = '—';
      chip = rtext(a!.reason);
    } else {
      badge = tr('badge_ready');
      main = tr('main_none');
      big = '—';
      chip = tr('chip_pick');
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
            if (hasArrow)
              Positioned(
                right: 6 * s,
                bottom: 3 * s,
                width: 240 * s,
                height: 265 * s,
                child: img,
              ),
            Positioned(
              left: 400 * s,
              right: (hasArrow ? 215 : 20) * s,
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

  Widget _tfCell(String name, String v, bool entry) {
    final up = v == 'UP', down = v == 'DOWN';
    final c = up ? kGreen : (down ? kRed : kGrey);
    String txt = up ? tr('tf_up') : (down ? tr('tf_down') : '—');
    if (entry && up) txt = tr('tf_buy');
    if (entry && down) txt = tr('tf_sell');
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

  Widget _tfRows(Analysis? a) {
    final names = (a != null && a.tf.isNotEmpty)
        ? a.tf.keys.toList()
        : Strategy.tfsFor(duration);
    if (names.isEmpty) return const SizedBox.shrink();
    int mn(String t) => Strategy.tfMs[t] ?? 0;
    final entry = names.reduce((x, y) => mn(x) <= mn(y) ? x : y);
    final ordered = List<String>.from(names)
      ..sort((x, y) => mn(y).compareTo(mn(x)));
    final rows = <Widget>[];
    for (var i = 0; i < ordered.length; i += 4) {
      final end = i + 4 > ordered.length ? ordered.length : i + 4;
      final chunk = ordered.sublist(i, end);
      if (rows.isNotEmpty) rows.add(const SizedBox(height: 6));
      rows.add(_box(Row(children: [
        for (final n in chunk) _tfCell(n, a?.tf[n] ?? '', n == entry),
      ])));
    }
    return Column(children: rows);
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
    final adxTxt = !Cfg.useAdx
        ? 'OFF'
        : (a?.adx != null ? a!.adx!.toStringAsFixed(1) : '—');
    final rsiTxt = !Cfg.useRsi
        ? 'OFF'
        : (a?.rsi != null ? a!.rsi!.toStringAsFixed(1) : '—');
    final stTxt = !Cfg.useSt
        ? 'OFF'
        : (stUp ? tr('tf_up') : (stDown ? tr('tf_down') : '—'));
    final scoreTxt = real ? '${a.score}/10' : '—';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _glass(kLine, r: 22),
      child: Column(children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.bar_chart, color: kBlue, size: 28),
            const SizedBox(width: 8),
            Text(tr('details_title'),
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ]),
        ),
        const SizedBox(height: 10),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Column(children: [
            _tfRows(a),
            const SizedBox(height: 8),
            _box(Row(children: [
              _metric(Icons.star, kAmber, tr('m_score'), scoreTxt, kAmber),
              _metric(Icons.verified_user_outlined, kGreen, 'ADX', adxTxt,
                  Cfg.useAdx ? Colors.white : kGrey),
              _metric(Icons.show_chart, kCyan, 'RSI', rsiTxt,
                  Cfg.useRsi ? Colors.white : kGrey),
              _metric(
                  Icons.multiline_chart,
                  kBlue,
                  'SuperTrend',
                  stTxt,
                  !Cfg.useSt
                      ? kGrey
                      : (stUp ? kGreen : (stDown ? kRed : Colors.white))),
            ])),
            const SizedBox(height: 8),
            _box(Row(children: [
              Expanded(
                child: Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.grid_view, color: kCyan, size: 20),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(tr('sr_label'),
                          style: const TextStyle(fontSize: 14)),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Text(a == null ? '—' : (Cfg.useSr ? t2(a.sr) : 'OFF'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Cfg.useSr ? kCyan : kGrey,
                          fontSize: 17,
                          fontWeight: FontWeight.bold)),
                ]),
              ),
              Container(width: 1, height: 50, color: kLine.withOpacity(0.5)),
              Expanded(
                child: Column(children: [
                  Text(tr('main_reason'),
                      style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(rtext(a?.reason ?? '—'),
                      textAlign: TextAlign.center,
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13)),
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
          Flexible(
            child: Row(children: [
              const Icon(Icons.access_time, size: 24),
              const SizedBox(width: 6),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                      '${tr('footer_duration')}: ${durText(duration)}',
                      style: const TextStyle(fontSize: 15)),
                ),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('${tr('footer_market')}: $market',
                      style: const TextStyle(fontSize: 15)),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.stacked_bar_chart, color: kGreen, size: 24),
            ]),
          ),
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
            _selector(Icons.candlestick_chart, tr('pair_label'),
                pair ?? tr('pair_hint'), pickPair),
            const SizedBox(width: 10),
            _selector(Icons.access_time, tr('duration_label'),
                durText(duration), pickDuration),
          ]),
        ),
        const SizedBox(height: 14),
        _analyzeButton(),
        const SizedBox(height: 10),
        _stratLine(),
        const SizedBox(height: 14),
        if (preview)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(tr('preview_banner'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: kAmber, fontSize: 13)),
          ),
        _signalCard(current),
        const SizedBox(height: 12),
        _details(current),
        const SizedBox(height: 12),
        _footer(),
        const SizedBox(height: 10),
        Text(t2('ext_note'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: Colors.white38)),
      ],
    );
  }
}
