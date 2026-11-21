import 'package:flutter/material.dart';
import 'engine/cfg.dart';
import 'engine/monitor.dart';
import 'l10n.dart';
import 'pair_sheet.dart';
import 'strat/runner.dart';

String _t(String ar, String fr, String en) {
  final l = langNotifier.value;
  return l == 'ar' ? ar : (l == 'fr' ? fr : en);
}

const _card = Color(0xFF0A1A3F);
const _line = Color(0xFF1F4FB5);
const _blue = Color(0xFF2E7BFF);
const _green = Color(0xFF2BE86F);
const _amber = Color(0xFFFFB020);

class StrategiesPage extends StatefulWidget {
  const StrategiesPage({super.key});
  @override
  State<StrategiesPage> createState() => _StrategiesPageState();
}

class _StrategiesPageState extends State<StrategiesPage> {
  final R = StratRunner.I;

  void _r() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    langNotifier.addListener(_r);
    R.changed.addListener(_r);
    R.load().then((_) => _r());
  }

  @override
  void dispose() {
    langNotifier.removeListener(_r);
    R.changed.removeListener(_r);
    super.dispose();
  }

  void _openSettings(StratInfo info) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _card,
      builder: (_) => _SettingsSheet(info: info),
    );
  }

  Future<void> _test(StratInfo info) async {
    final c = R.cfg[info.id]!;
    final pairs = c.pairs.isNotEmpty ? c.pairs : Monitor.I.pairs;
    if (pairs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_t('اختر زوجاً في إعدادات الاستراتيجية أو في التحليل التلقائي أولاً.',
              "Choisissez d'abord une paire dans les réglages ou l'analyse automatique.",
              'Pick a pair in the strategy settings or in auto analysis first.'))));
      return;
    }
    var cancel = false;
    final progress = ValueNotifier<String>('…');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: _card,
        title: Text(info.title),
        content: ValueListenableBuilder<String>(
          valueListenable: progress,
          builder: (_, v, __) => Text(v),
        ),
        actions: [
          TextButton(
              onPressed: () => cancel = true,
              child: Text(_t('إلغاء', 'Annuler', 'Cancel'))),
        ],
      ),
    );
    final res = await R.backtest(info.id, pairs.first, (s) => progress.value = s, () => cancel);
    if (!mounted) return;
    Navigator.of(context).pop();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _card,
        title: Text(info.title),
        content: SingleChildScrollView(child: Text(res)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(_t('إغلاق', 'Fermer', 'Close'))),
        ],
      ),
    );
  }

  Widget _cardFor(StratInfo info) {
    final c = R.cfg[info.id];
    if (c == null) return const SizedBox.shrink();
    final pairsTxt = c.pairs.isNotEmpty
        ? '${c.pairs.length}'
        : _t('الأزواج المراقبة', 'paires surveillées', 'watched pairs');
    final st = R.statusFor(info.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: (c.enabled ? _green : _line).withOpacity(0.7)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(info.title,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ),
          Switch(value: c.enabled, onChanged: (v) => R.setEnabled(info.id, v)),
        ]),
        Text(info.desc, style: const TextStyle(fontSize: 13, color: Colors.white70)),
        const SizedBox(height: 6),
        Text('${c.tf} • ${durText(c.duration)} • ${_t('تقييم ≥', 'score ≥', 'score ≥')} ${c.minScore}/10 • $pairsTxt',
            style: const TextStyle(fontSize: 12, color: Colors.white54)),
        if (c.enabled && st.isNotEmpty) ...[
          const SizedBox(height: 4),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(st, style: const TextStyle(fontSize: 11, color: Colors.white38)),
          ),
        ],
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _openSettings(info),
              icon: const Icon(Icons.tune, size: 18),
              label: Text(_t('إعدادات', 'Réglages', 'Settings')),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _test(info),
              style: ElevatedButton.styleFrom(backgroundColor: _blue, foregroundColor: Colors.white),
              icon: const Icon(Icons.science, size: 18),
              label: Text(_t('اختبر هذه الاستراتيجية', 'Tester', 'Test this strategy'),
                  overflow: TextOverflow.ellipsis),
            ),
          ),
        ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      children: [
        Text(_t('الاستراتيجيات', 'Stratégies', 'Strategies'),
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _amber.withOpacity(0.7)),
          ),
          child: Text(
              _t('تنبيه: هذه الاستراتيجيات تحتاج اختباراً تاريخياً قبل الاعتماد عليها، ولا تضمن أرباحاً. درجة التقييم من 10 تعني توافق الشروط وليست نسبة نجاح. وهي منفصلة عن الاستراتيجية الحالية في الرئيسية. وتعمل والتطبيق مفتوح.',
                  "Attention : ces stratégies exigent un test historique avant usage et ne garantissent aucun gain. Le score sur 10 mesure l'accord des conditions, pas un taux de réussite. Elles sont séparées de la stratégie actuelle et fonctionnent application ouverte.",
                  'Warning: these strategies need a backtest before you rely on them and guarantee no profit. The score out of 10 shows how many conditions agree, not a win rate. They are separate from the current strategy and run while the app is open.'),
              style: const TextStyle(fontSize: 12, color: _amber)),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () => R.setAll(true),
              style: ElevatedButton.styleFrom(backgroundColor: _green, foregroundColor: Colors.black),
              child: Text(_t('تفعيل الكل', 'Tout activer', 'Enable all')),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: () => R.setAll(false),
              child: Text(_t('إيقاف الكل', 'Tout arrêter', 'Disable all')),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        for (final s in kStrategies) _cardFor(s),
      ],
    );
  }
}

class _SettingsSheet extends StatefulWidget {
  final StratInfo info;
  const _SettingsSheet({required this.info});
  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  final R = StratRunner.I;
  static const durs = [5, 10, 15, 30, 60, 120, 180, 240, 300, 420, 600, 900];
  late final TextEditingController _step;
  late final TextEditingController _maxAf;

  StratCfg get c => R.cfg[widget.info.id]!;
  bool get isPsar => widget.info.id == 'STRATEGY_6';

  @override
  void initState() {
    super.initState();
    _step = TextEditingController(text: '${c.extra['step'] ?? 0.02}');
    _maxAf = TextEditingController(text: '${c.extra['max_af'] ?? 0.2}');
  }

  @override
  void dispose() {
    _step.dispose();
    _maxAf.dispose();
    super.dispose();
  }

  Future<void> _addPair() async {
    if (c.pairs.length >= 5) return;
    final p = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _card,
      builder: (_) => const PairSheet(),
    );
    if (p == null || c.pairs.contains(p)) return;
    await R.update(widget.info.id, pairs: [...c.pairs, p]);
    if (mounted) setState(() {});
  }

  Future<void> _savePsar() async {
    final s = double.tryParse(_step.text.trim().replaceAll(',', '.'));
    final m = double.tryParse(_maxAf.text.trim().replaceAll(',', '.'));
    final ex = Map<String, dynamic>.from(c.extra);
    if (s != null && s > 0 && s < 1) ex['step'] = s;
    if (m != null && m > 0 && m < 1) ex['max_af'] = m;
    await R.update(widget.info.id, extra: ex);
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_t('تم الحفظ', 'Enregistré', 'Saved'))));
    }
  }

  Widget _h(String t) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      );

  @override
  Widget build(BuildContext context) {
    final id = widget.info.id;
    final filter = (c.extra['filter_mode'] ?? 'none') as String;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.info.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            _h(_t('الأزواج (حتى 5)', 'Paires (max 5)', 'Pairs (up to 5)')),
            if (c.pairs.isEmpty)
              Text(_t('افتراضي: الأزواج المراقبة في التحليل التلقائي', 'Par défaut : paires surveillées', 'Default: pairs watched by auto analysis'),
                  style: const TextStyle(fontSize: 12, color: Colors.white54)),
            Wrap(spacing: 8, children: [
              for (final p in c.pairs)
                Chip(
                  label: Text(p),
                  onDeleted: () async {
                    await R.update(id, pairs: c.pairs.where((e) => e != p).toList());
                    if (mounted) setState(() {});
                  },
                ),
            ]),
            OutlinedButton.icon(
              onPressed: _addPair,
              icon: const Icon(Icons.add),
              label: Text(_t('إضافة زوج', 'Ajouter une paire', 'Add a pair')),
            ),
            _h(_t('فريم التحليل', 'Cadre', 'Timeframe')),
            Wrap(spacing: 8, runSpacing: 4, children: [
              for (final t in Cfg.allTfs)
                ChoiceChip(
                  label: Text(t),
                  selected: c.tf == t,
                  onSelected: (_) async {
                    await R.update(id, tf: t);
                    if (mounted) setState(() {});
                  },
                ),
            ]),
            _h(_t('مدة الصفقة', 'Durée du trade', 'Trade duration')),
            Wrap(spacing: 8, runSpacing: 4, children: [
              for (final d in durs)
                ChoiceChip(
                  label: Text(durText(d)),
                  selected: c.duration == d,
                  onSelected: (_) async {
                    await R.update(id, duration: d);
                    if (mounted) setState(() {});
                  },
                ),
            ]),
            _h('${_t('الحد الأدنى للتقييم', 'Score minimum', 'Minimum score')}: ${c.minScore}/10'),
            Slider(
              value: c.minScore.toDouble(),
              min: 1,
              max: 10,
              divisions: 9,
              label: '${c.minScore}',
              onChanged: (v) => setState(() => c.minScore = v.round()),
              onChangeEnd: (v) async {
                await R.update(id, minScore: v.round());
                if (mounted) setState(() {});
              },
            ),
            if (isPsar) ...[
              _h('Parabolic SAR'),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _step,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Step', isDense: true, border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _maxAf,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Max', isDense: true, border: OutlineInputBorder()),
                  ),
                ),
              ]),
              _h(_t('فلتر اختياري', 'Filtre optionnel', 'Optional filter')),
              Wrap(spacing: 8, children: [
                for (final f in const ['none', 'ma', 'rsi'])
                  ChoiceChip(
                    label: Text(f == 'none' ? _t('بدون', 'Aucun', 'None') : (f == 'ma' ? 'MA20' : 'RSI')),
                    selected: filter == f,
                    onSelected: (_) async {
                      final ex = Map<String, dynamic>.from(c.extra);
                      ex['filter_mode'] = f;
                      await R.update(id, extra: ex);
                      if (mounted) setState(() {});
                    },
                  ),
              ]),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _savePsar,
                style: ElevatedButton.styleFrom(backgroundColor: _blue, foregroundColor: Colors.white),
                child: Text(_t('حفظ Step و Max', 'Enregistrer Step/Max', 'Save Step & Max')),
              ),
            ],
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }
}
