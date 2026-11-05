import 'package:flutter/material.dart';
import 'engine/backtest.dart';
import 'engine/cfg.dart';
import 'l10n.dart';
import 'pair_sheet.dart';

String _t(String ar, String fr, String en) {
  final l = langNotifier.value;
  return l == 'ar' ? ar : (l == 'fr' ? fr : en);
}

const _card = Color(0xFF0A1A3F);
const _line = Color(0xFF1F4FB5);
const _blue = Color(0xFF2E7BFF);
const _green = Color(0xFF2BE86F);
const _red = Color(0xFFFF4B5C);
const _amber = Color(0xFFFFB020);

String _dt(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  String t(int v) => v.toString().padLeft(2, '0');
  return '${t(d.month)}/${t(d.day)} ${t(d.hour)}:${t(d.minute)}';
}

String _errText(String k) {
  final key = k.split(':').first;
  switch (key) {
    case 'na_no_key':
      return _t('احفظ الـ SSID في الإعدادات أولاً', "Enregistrez d'abord le SSID dans les Paramètres",
          'Save the SSID in Settings first');
    case 'na_net':
      return _t('لا يوجد اتصال بالإنترنت أو الخادم', 'Pas de connexion Internet ou au serveur',
          'No internet or server connection');
    case 'na_duration':
      return _t('هذه المدة غير مدعومة', 'Durée non prise en charge', 'Unsupported duration');
    case 'bt_cancel':
      return _t('أُلغي الاختبار', 'Test annulé', 'Test cancelled');
    case 'bt_short':
      final n = k.contains(':') ? k.split(':')[1] : '';
      return _t('تاريخ المنصة المتاح أقصر من اللازم للاختبار ($n شمعة فقط)',
          "L'historique disponible est trop court pour le test ($n bougies seulement)",
          'The available history is too short for the test (only $n candles)');
  }
  return _t('تعذر جلب البيانات من Pocket Option (قد يكون المفتاح منتهياً)',
      'Impossible de récupérer les données (clé peut-être expirée)',
      'Could not fetch data (the key may have expired)');
}

class BacktestPage extends StatefulWidget {
  const BacktestPage({super.key});
  @override
  State<BacktestPage> createState() => _BacktestPageState();
}

class _BacktestPageState extends State<BacktestPage> {
  static const durs = [
    60, 120, 180, 240, 300, 360, 420, 480, 540, 600, 660, 720, 780, 840, 900,
  ];
  String? pair;
  int duration = 300;
  int lead = 60;
  bool running = false;
  bool cancel = false;
  String status = '';
  String? err;
  BtResult? result;
  List<BtResult> saved = [];

  void _r() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    langNotifier.addListener(_r);
    Cfg.load();
    _loadSaved();
  }

  @override
  void dispose() {
    langNotifier.removeListener(_r);
    super.dispose();
  }

  Future<void> _loadSaved() async {
    final s = await BtStore.all();
    if (!mounted) return;
    setState(() => saved = s);
  }

  Future<void> _pick() async {
    final p = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _card,
      builder: (_) => const PairSheet(),
    );
    if (p != null && mounted) setState(() => pair = p);
  }

  Future<void> _run() async {
    if (pair == null || running) return;
    setState(() {
      running = true;
      cancel = false;
      result = null;
      err = null;
      status = '…';
    });
    final r = await Backtest.run(
      label: pair!,
      duration: duration,
      lead: lead,
      status: (s) {
        if (mounted) setState(() => status = s);
      },
      cancelled: () => cancel,
    );
    if (r.data != null) await BtStore.add(r.data!);
    final s = await BtStore.all();
    if (!mounted) return;
    setState(() {
      running = false;
      result = r.data;
      err = r.error;
      saved = s;
    });
  }

  Widget _box(List<Widget> children) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _line.withOpacity(0.7)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );

  Widget _line2(String k, String v, {Color? c}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Expanded(
              child: Text(k, style: const TextStyle(color: Colors.white70, fontSize: 13))),
          Text(v,
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14, color: c ?? Colors.white)),
        ]),
      );

  Widget _resultCard(BtResult r) {
    final rate = r.rate;
    final be = r.breakeven;
    final mg = r.margin;
    String verdict;
    Color vc;
    if (rate == null || r.decided < 30) {
      verdict = _t('بيانات غير كافية لحساب نسبة نجاح موثوقة',
          'Données insuffisantes pour un taux de réussite fiable',
          'Not enough data for a reliable win rate');
      vc = _amber;
    } else if (be != null && rate - (mg ?? 0) > be) {
      verdict = _t('أعلى من نسبة التعادل حتى بعد هامش الخطأ، لكنها فترة واحدة وليست ضماناً',
          "Au-dessus du seuil de rentabilité même avec la marge d'erreur, mais sur une seule période, sans garantie",
          'Above breakeven even after the margin of error, but one period only, not a guarantee');
      vc = _green;
    } else if (be != null && rate > be) {
      verdict = _t('فوق نسبة التعادل لكن ضمن هامش الخطأ، فلم يثبت بعد',
          "Au-dessus du seuil mais dans la marge d'erreur : non prouvé",
          'Above breakeven but within the margin of error: not proven');
      vc = _amber;
    } else if (be != null) {
      verdict = _t('أقل من نسبة التعادل، فالاستراتيجية بهذه الإعدادات خاسرة في هذه الفترة',
          'Sous le seuil de rentabilité : perdante sur cette période avec ces réglages',
          'Below breakeven: losing in this period with these settings');
      vc = _red;
    } else {
      verdict = '';
      vc = Colors.white;
    }
    return _box([
      Text('${r.pair} • ${durText(r.duration)} • OTC',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      _line2(_t('الفترة المختبرة', 'Période testée', 'Tested period'),
          '${_dt(r.fromMs)} → ${_dt(r.toMs)}'),
      _line2(_t('شموع مستعملة', 'Bougies utilisées', 'Candles used'), '${r.candles}'),
      _line2(_t('لحظات تحليل', "Moments d'analyse", 'Analysis moments'),
          '${r.steps} (${_t('بيانات ناقصة', 'données incomplètes', 'bad data')}: ${r.skipped})'),
      _line2(_t('إشارات', 'Signaux', 'Signals'), '${r.signals}'),
      _line2(_t('رابحة', 'Gagnants', 'Wins'), '${r.wins}', c: _green),
      _line2(_t('خاسرة', 'Perdants', 'Losses'), '${r.losses}', c: _red),
      _line2(_t('غير محسومة (تعادل/بيانات)', 'Non tranchés (égalité/données)', 'Unresolved (tie/data)'),
          '${r.unverified}'),
      const Divider(),
      _line2(_t('نسبة النجاح', 'Taux de réussite', 'Win rate'),
          rate == null ? '—' : '${rate.toStringAsFixed(1)}%${mg == null ? '' : '  (±${mg.toStringAsFixed(1)})'}',
          c: vc),
      if (be != null)
        _line2(
            _t('نسبة التعادل (عائد ${r.payout}%)', 'Seuil de rentabilité (gain ${r.payout}%)',
                'Breakeven (payout ${r.payout}%)'),
            '${be.toStringAsFixed(1)}%'),
      if (verdict.isNotEmpty) ...[
        const SizedBox(height: 6),
        Text(verdict, style: TextStyle(color: vc, fontSize: 13)),
      ],
      const SizedBox(height: 6),
      Text(r.cfg, style: const TextStyle(fontSize: 11, color: Colors.white38)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('الاختبار التاريخي', 'Test historique', 'Backtest')),
        backgroundColor: const Color(0xFF071230),
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _box([
            Text(
                _t('يشغّل المحرك نفسه على نحو يوم من شموع Pocket Option السابقة دون أي بيانات مستقبلية، وتُحسم كل صفقة بسعر الدخول والانتهاء من الشموع نفسها. النتيجة تخص فترة واحدة ولا تضمن المستقبل.',
                    "Exécute le même moteur sur environ un jour de bougies Pocket Option passées, sans données futures. Chaque trade est tranché avec les prix d'entrée et d'expiration des bougies. Résultat sur une seule période, sans garantie.",
                    'Runs the same engine on about one day of past Pocket Option candles with no future data. Each trade is settled with entry and expiry prices from the candles. One period only, no guarantee.'),
                style: const TextStyle(fontSize: 13, color: Colors.white70)),
          ]),
          _box([
            Text(_t('الزوج', 'Paire', 'Pair'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            OutlinedButton(
              onPressed: running ? null : _pick,
              child: Text(pair ?? _t('اختر زوج OTC', 'Choisir une paire OTC', 'Choose an OTC pair')),
            ),
            const SizedBox(height: 10),
            Text(_t('مدة الصفقة', 'Durée du trade', 'Trade duration'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Wrap(spacing: 8, runSpacing: 4, children: [
              for (final d in durs)
                ChoiceChip(
                  label: Text(durText(d)),
                  selected: duration == d,
                  onSelected: running ? null : (_) => setState(() => duration = d),
                ),
            ]),
            const SizedBox(height: 10),
            Text(_t('الدخول', 'Entrée', 'Entry'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            RadioListTile<int>(
              contentPadding: EdgeInsets.zero,
              value: 0,
              groupValue: lead,
              title: Text(_t('في الدقيقة التالية للإشارة', 'À la minute suivant le signal',
                  'At the minute after the signal'),
                  style: const TextStyle(fontSize: 14)),
              onChanged: running ? null : (v) => setState(() => lead = v ?? 0),
            ),
            RadioListTile<int>(
              contentPadding: EdgeInsets.zero,
              value: 60,
              groupValue: lead,
              title: Text(_t('بعد دقيقة إضافية', 'Une minute de plus', 'One extra minute'),
                  style: const TextStyle(fontSize: 14)),
              onChanged: running ? null : (v) => setState(() => lead = v ?? 60),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: (pair != null && !running) ? _run : null,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _blue, foregroundColor: Colors.white),
                  icon: const Icon(Icons.play_arrow),
                  label: Text(_t('ابدأ الاختبار', 'Lancer le test', 'Start test')),
                ),
              ),
              if (running) ...[
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => setState(() => cancel = true),
                  child: Text(_t('إلغاء', 'Annuler', 'Cancel')),
                ),
              ],
            ]),
            if (running) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(),
              const SizedBox(height: 6),
              Text(status, style: const TextStyle(fontSize: 12, color: Colors.white70)),
              Text(
                  _t('قد يستغرق جلب التاريخ والتحليل نحو دقيقتين.',
                      "Le chargement de l'historique et l'analyse peuvent prendre environ 2 minutes.",
                      'Loading history and analysis can take about 2 minutes.'),
                  style: const TextStyle(fontSize: 11, color: Colors.white38)),
            ],
            if (err != null) ...[
              const SizedBox(height: 8),
              Text(_errText(err!), style: const TextStyle(color: _red, fontSize: 13)),
            ],
          ]),
          if (result != null) _resultCard(result!),
          if (saved.isNotEmpty) ...[
            Row(children: [
              Expanded(
                child: Text(_t('نتائج سابقة', 'Résultats précédents', 'Previous results'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              TextButton(
                onPressed: running
                    ? null
                    : () async {
                        await BtStore.clear();
                        await _loadSaved();
                      },
                child: Text(_t('مسح', 'Effacer', 'Clear')),
              ),
            ]),
            for (final r in saved) _resultCard(r),
          ],
        ],
      ),
    );
  }
}
