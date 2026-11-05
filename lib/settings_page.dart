import 'dart:async';
import 'package:flutter/material.dart';
import 'backtest_page.dart';
import 'engine/cfg.dart';
import 'engine/po_client.dart';
import 'engine/po_probe.dart';
import 'l10n.dart';

const _card = Color(0xFF0A1A3F);
const _line = Color(0xFF1F4FB5);
const _blue = Color(0xFF2E7BFF);
const _green = Color(0xFF2BE86F);
const _amber = Color(0xFFFFB020);

String _t(String ar, String fr, String en) {
  final l = langNotifier.value;
  return l == 'ar' ? ar : (l == 'fr' ? fr : en);
}

String _err(String k) {
  switch (k) {
    case 'na_no_key':
      return _t('احفظ الـ SSID أولاً', "Enregistrez d'abord le SSID", 'Save the SSID first');
    case 'na_net':
      return _t('لا يوجد اتصال بالإنترنت أو الخادم', 'Pas de connexion Internet ou au serveur',
          'No internet or server connection');
  }
  return _t('تعذر الاتصال (قد يكون المفتاح منتهياً، انسخ SSID جديداً)',
      'Connexion impossible (clé peut-être expirée, copiez un nouveau SSID)',
      'Could not connect (the key may have expired, copy a fresh SSID)');
}

Widget _section(String title, IconData icon, List<Widget> children) {
  return Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _line.withOpacity(0.7)),
      boxShadow: [BoxShadow(color: _line.withOpacity(0.25), blurRadius: 10)],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, color: _blue, size: 26),
        const SizedBox(width: 8),
        Expanded(
          child: Text(title,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
        ),
      ]),
      const SizedBox(height: 10),
      ...children,
    ]),
  );
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  void _onLang() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    langNotifier.addListener(_onLang);
  }

  @override
  void dispose() {
    langNotifier.removeListener(_onLang);
    super.dispose();
  }

  Widget _langTile(String code, String label) {
    final sel = langNotifier.value == code;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(fontSize: 17)),
      trailing: sel
          ? const Icon(Icons.check_circle, color: _green)
          : const Icon(Icons.circle_outlined, color: Colors.white38),
      onTap: () => saveLang(code),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      children: [
        Text(tr('settings_title'),
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 14),
        _section(tr('lang_title'), Icons.language, [
          _langTile('ar', 'العربية'),
          _langTile('fr', 'Français'),
          _langTile('en', 'English'),
        ]),
        const PoProbeCard(),
        const _ConnCard(),
        const _CfgCard(),
        _section(_t('الاختبار التاريخي', 'Test historique', 'Backtest'), Icons.science, [
          Text(
              _t('اختبر الاستراتيجية على شموع OTC السابقة لتعرف نسبة نجاحها الفعلية قبل الاعتماد عليها.',
                  "Testez la stratégie sur des bougies OTC passées pour connaître son taux de réussite réel.",
                  'Test the strategy on past OTC candles to see its real win rate.'),
              style: const TextStyle(fontSize: 13, color: Colors.white70)),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const BacktestPage())),
              style: ElevatedButton.styleFrom(
                  backgroundColor: _blue, foregroundColor: Colors.white),
              icon: const Icon(Icons.science),
              label: Text(_t('فتح الاختبار التاريخي', 'Ouvrir le test historique',
                  'Open backtest')),
            ),
          ),
        ]),
        _section(tr('ver_title'), Icons.info_outline, [
          const Text('Farid Hamzaoui Signals Pro', style: TextStyle(fontSize: 16)),
          const SizedBox(height: 4),
          Text(tr('ver_number'), style: const TextStyle(color: Colors.white70)),
        ]),
      ],
    );
  }
}

class _ConnCard extends StatefulWidget {
  const _ConnCard();
  @override
  State<_ConnCard> createState() => _ConnCardState();
}

class _ConnCardState extends State<_ConnCard> {
  Timer? _timer;
  bool busy = false;
  String msg = '';

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _reconnect() async {
    setState(() {
      busy = true;
      msg = '';
    });
    final e = await PoClient.I.reconnect();
    if (!mounted) return;
    setState(() {
      busy = false;
      msg = e == null ? _t('تم الاتصال', 'Connecté', 'Connected') : _err(e);
    });
  }

  Future<void> _refresh() async {
    PoClient.I.clearCache();
    final e = await PoClient.I.connect();
    if (!mounted) return;
    setState(() => msg = e == null
        ? _t('تم مسح البيانات المخزنة، وستُجلب من جديد عند التحليل', 'Cache vidé, les données seront rechargées',
            'Cache cleared, data will be reloaded on the next analysis')
        : _err(e));
  }

  Widget _row(String k, String v, {Color? c}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Expanded(child: Text(k, style: const TextStyle(color: Colors.white70, fontSize: 13))),
          Text(v, style: TextStyle(fontWeight: FontWeight.bold, color: c ?? Colors.white)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final p = PoClient.I;
    final on = p.connected.value;
    final age = p.lastTickMs == 0
        ? '—'
        : '${((DateTime.now().millisecondsSinceEpoch - p.lastTickMs) / 1000).round()} s';
    final otc = p.assets.where((a) => a.open && a.symbol.endsWith('_otc')).length;
    return _section(
        _t('حالة الاتصال والأسعار الحية', 'État de la connexion et prix en direct',
            'Connection and live prices'),
        Icons.speed,
        [
          _row(_t('الاتصال', 'Connexion', 'Connection'),
              on ? _t('متصل', 'Connecté', 'Connected') : _t('غير متصل', 'Déconnecté', 'Disconnected'),
              c: on ? _green : _amber),
          _row(_t('الزوج المراقَب', 'Paire suivie', 'Watched pair'), p.symbol ?? '—'),
          _row(_t('آخر سعر', 'Dernier prix', 'Last price'), p.lastPrice?.toString() ?? '—'),
          _row(_t('عمر آخر سعر', 'Âge du dernier prix', 'Last price age'), age),
          _row(_t('أزواج OTC المفتوحة', 'Paires OTC ouvertes', 'Open OTC pairs'), '$otc'),
          _row(_t('خطأ ساعة هاتفك', "Écart de l'horloge", 'Phone clock error'),
              '${(p.skewMs / 1000).toStringAsFixed(1)} s'),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: ElevatedButton(
                onPressed: busy ? null : _reconnect,
                style: ElevatedButton.styleFrom(
                    backgroundColor: _blue, foregroundColor: Colors.white),
                child: Text(_t('إعادة الاتصال', 'Reconnecter', 'Reconnect')),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: busy ? null : _refresh,
                child: Text(_t('تحديث البيانات', 'Actualiser les données', 'Refresh data')),
              ),
            ),
          ]),
          if (msg.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(msg, style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ]);
  }
}

class _CfgCard extends StatefulWidget {
  const _CfgCard();
  @override
  State<_CfgCard> createState() => _CfgCardState();
}

class _CfgCardState extends State<_CfgCard> {
  static const fields = <List<String>>[
    ['ema1', 'EMA السريع', 'EMA rapide', 'Fast EMA'],
    ['ema2', 'EMA البطيء', 'EMA lente', 'Slow EMA'],
    ['rsiP', 'فترة RSI', 'Période RSI', 'RSI period'],
    ['rsiUp', 'RSI للصعود (أكبر من)', 'RSI haussier (>)', 'RSI up (>)'],
    ['rsiDown', 'RSI للهبوط (أقل من)', 'RSI baissier (<)', 'RSI down (<)'],
    ['adxP', 'فترة ADX', 'Période ADX', 'ADX period'],
    ['adxMin', 'حد ADX الأدنى (أكبر من)', 'ADX minimum (>)', 'ADX minimum (>)'],
    ['stP', 'فترة ATR في SuperTrend', 'Période ATR SuperTrend', 'SuperTrend ATR period'],
    ['stM', 'مضاعف SuperTrend', 'Multiplicateur SuperTrend', 'SuperTrend multiplier'],
    ['atrP', 'فترة ATR', 'Période ATR', 'ATR period'],
    ['minScore', 'أدنى تقييم للإشارة (من 10)', 'Score minimum (sur 10)', 'Minimum score (of 10)'],
  ];

  final Map<String, TextEditingController> _c = {
    for (final f in fields) f[0]: TextEditingController(),
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    await Cfg.load();
    _fill();
  }

  void _fill() {
    for (final f in fields) {
      _c[f[0]]!.text = Cfg.get(f[0]);
    }
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    for (final f in fields) {
      Cfg.set(f[0], _c[f[0]]!.text);
    }
    await Cfg.save();
    _fill();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_t('تم حفظ إعدادات المؤشرات', 'Réglages enregistrés', 'Settings saved'))));
  }

  Future<void> _reset() async {
    await Cfg.reset();
    _fill();
  }

  @override
  Widget build(BuildContext context) {
    final l = langNotifier.value;
    final idx = l == 'ar' ? 1 : (l == 'fr' ? 2 : 3);
    return _section(
        _t('إعدادات المؤشرات', 'Réglages des indicateurs', 'Indicator settings'),
        Icons.tune,
        [
          Text(
              _t('القيم الافتراضية هي المواصفات الأصلية. غيّرها بحذر، وأعد الاختبار التاريخي بعد أي تغيير.',
                  "Les valeurs par défaut sont les spécifications d'origine. Modifiez avec prudence et relancez le test historique.",
                  'Defaults are the original specification. Change with care and re-run the backtest after any change.'),
              style: const TextStyle(fontSize: 12, color: Colors.white60)),
          const SizedBox(height: 8),
          for (final f in fields)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Expanded(child: Text(f[idx], style: const TextStyle(fontSize: 14))),
                SizedBox(
                  width: 90,
                  child: TextField(
                    controller: _c[f[0]],
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                        isDense: true, border: OutlineInputBorder()),
                  ),
                ),
              ]),
            ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                    backgroundColor: _blue, foregroundColor: Colors.white),
                child: Text(tr('ssid_save').isEmpty ? 'Save' : _t('حفظ', 'Enregistrer', 'Save')),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: _reset,
                child: Text(_t('استرجاع الافتراضي', 'Valeurs par défaut', 'Reset defaults')),
              ),
            ),
          ]),
        ]);
  }
}
