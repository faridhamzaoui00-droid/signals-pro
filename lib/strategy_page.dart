import 'package:flutter/material.dart';
import 'backtest_page.dart';
import 'engine/cfg.dart';
import 'l10n.dart';

String _t(String ar, String fr, String en) {
  final l = langNotifier.value;
  return l == 'ar' ? ar : (l == 'fr' ? fr : en);
}

const _card = Color(0xFF0A1A3F);
const _line = Color(0xFF1F4FB5);
const _blue = Color(0xFF2E7BFF);
const _amber = Color(0xFFFFB020);

class StrategyPage extends StatefulWidget {
  const StrategyPage({super.key});
  @override
  State<StrategyPage> createState() => _StrategyPageState();
}

class _StrategyPageState extends State<StrategyPage> {
  void _r() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    langNotifier.addListener(_r);
    Cfg.load().then((_) => _r());
  }

  @override
  void dispose() {
    langNotifier.removeListener(_r);
    super.dispose();
  }

  void _msg(String t) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  }

  Future<void> _toggle(String key, bool v) async {
    final before = Cfg.get(key);
    Cfg.set(key, v ? '1' : '0');
    if (!Cfg.anyOn) {
      Cfg.set(key, before);
      _msg(_t('يجب إبقاء عنصر واحد على الأقل مفعّلاً', 'Gardez au moins un élément actif',
          'Keep at least one element enabled'));
      return;
    }
    await Cfg.save();
    _r();
  }

  Future<void> _toggleTf(String t, bool v) async {
    final cur = List<String>.from(Cfg.tfs);
    if (v) {
      if (!cur.contains(t)) cur.add(t);
    } else {
      cur.remove(t);
    }
    if (cur.isEmpty) {
      _msg(_t('اختر فريماً واحداً على الأقل', 'Choisissez au moins un cadre',
          'Choose at least one timeframe'));
      return;
    }
    Cfg.set('tfs', cur.join(','));
    await Cfg.save();
    _r();
  }

  Widget _box(String title, IconData icon, List<Widget> children) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _line.withOpacity(0.7)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: _blue, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 8),
          ...children,
        ]),
      );

  Widget _sw(String key, bool value, String title, String sub) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      value: value,
      onChanged: (v) => _toggle(key, v),
      title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      subtitle: Text(sub, style: const TextStyle(fontSize: 12, color: Colors.white54)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('الاستراتيجية', 'Stratégie', 'Strategy')),
        backgroundColor: const Color(0xFF071230),
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _box(_t('الحالية', 'Actuelle', 'Current'), Icons.tune, [
            Text(Cfg.summary(), style: const TextStyle(fontSize: 13)),
          ]),
          _box(_t('قوالب جاهزة', 'Modèles', 'Presets'), Icons.auto_awesome, [
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    Cfg.presetOriginal();
                    await Cfg.save();
                    _r();
                  },
                  child: Text(_t('الأصلية (الكل)', 'Originale (tout)', 'Original (all)')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    Cfg.presetEmaRsi();
                    await Cfg.save();
                    _r();
                  },
                  child: const Text('EMA + RSI • M5'),
                ),
              ),
            ]),
          ]),
          _box(_t('المؤشرات العاملة', 'Éléments actifs', 'Active elements'), Icons.functions, [
            _sw('useEma', Cfg.useEma, 'EMA ${Cfg.ema1}/${Cfg.ema2}',
                _t('يحدد الاتجاه', 'Donne la direction', 'Sets the direction')),
            _sw('useRsi', Cfg.useRsi, 'RSI ${Cfg.rsiP}',
                _t('الزخم: يؤكد الاتجاه', 'Élan : confirme la direction', 'Momentum: confirms direction')),
            _sw('useAdx', Cfg.useAdx, 'ADX ${Cfg.adxP}',
                _t('يستبعد السوق العرضي', 'Écarte le marché sans tendance', 'Filters out sideways markets')),
            _sw('useSt', Cfg.useSt, 'SuperTrend ${Cfg.stP}×${Cfg.stM}',
                _t('اتجاه إضافي', 'Tendance supplémentaire', 'Extra trend filter')),
            _sw('useCandle', Cfg.useCandle, _t('أنماط الشموع', 'Motifs de bougies', 'Candle patterns'),
                _t('شمعة تأكيد مغلقة قوية', 'Bougie de confirmation clôturée', 'Closed confirmation candle')),
            _sw('useSr', Cfg.useSr, _t('الدعم والمقاومة', 'Support et résistance', 'Support & resistance'),
                _t('المستويات وإعادة الاختبار والرفض', 'Niveaux, retest, rejet', 'Levels, retest, rejection')),
          ]),
          _box(_t('الفريمات', 'Cadres', 'Timeframes'), Icons.timeline, [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: Cfg.autoTf,
              onChanged: (v) async {
                Cfg.set('autoTf', v ? '1' : '0');
                await Cfg.save();
                _r();
              },
              title: Text(
                  _t('تلقائي حسب مدة الصفقة', 'Automatique selon la durée', 'Automatic by trade duration'),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              subtitle: Text(
                  _t('الجدول الأصلي: 1-2 د: M1+M5 • 3-5 د: +M15 • 6-9 د: M5+M15 • 10-15 د: M5+M15+M30',
                      "Tableau d'origine : 1-2 min M1+M5 • 3-5 min +M15 • 6-9 min M5+M15 • 10-15 min M5+M15+M30",
                      'Original table: 1-2 min M1+M5 • 3-5 min +M15 • 6-9 min M5+M15 • 10-15 min M5+M15+M30'),
                  style: const TextStyle(fontSize: 11, color: Colors.white54)),
            ),
            if (!Cfg.autoTf) ...[
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 4, children: [
                for (final t in Cfg.allTfs)
                  FilterChip(
                    label: Text('$t • ${durText(Cfg.tfMinutes(t) * 60)}'),
                    selected: Cfg.tfs.contains(t),
                    onSelected: (v) => _toggleTf(t, v),
                  ),
              ]),
              const SizedBox(height: 6),
              Text(
                  _t('أصغر فريم تختاره هو فريم الدخول والتأكيد، والأكبر منه للتوافق. ومدة الصفقة مستقلة عنها، وتختارها من الرئيسية.',
                      "Le plus petit cadre choisi sert à l'entrée et à la confirmation, les plus grands à la concordance. La durée du trade est indépendante.",
                      'The smallest chosen timeframe is the entry/confirmation frame, larger ones are for agreement. Trade duration is independent.'),
                  style: const TextStyle(fontSize: 12, color: Colors.white54)),
            ],
          ]),
          _box(_t('تنبيه', 'Attention', 'Warning'), Icons.warning_amber, [
            Text(
                _t('إيقاف عناصر يزيل شروط منع كانت تحميك، فتزيد الإشارات ولا تتحسن جودتها بالضرورة. جرّب أي استراتيجية بالاختبار التاريخي قبل الاعتماد عليها.',
                    "Désactiver des éléments retire des protections : plus de signaux, pas forcément de meilleurs. Testez avec le test historique avant d'utiliser.",
                    'Disabling elements removes protections: more signals, not necessarily better ones. Test with the backtest before relying on it.'),
                style: const TextStyle(fontSize: 13, color: _amber)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const BacktestPage())),
                style: ElevatedButton.styleFrom(
                    backgroundColor: _blue, foregroundColor: Colors.white),
                icon: const Icon(Icons.science),
                label: Text(_t('اختبر هذه الاستراتيجية', 'Tester cette stratégie', 'Test this strategy')),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
