import 'package:flutter/material.dart';
import 'engine/indicators.dart';
import 'engine/po_client.dart';
import 'l10n.dart';
import 'pair_sheet.dart';
import 'pairs.dart';

String _t(String ar, String fr, String en) {
  final l = langNotifier.value;
  return l == 'ar' ? ar : (l == 'fr' ? fr : en);
}

/// يختبر هل يرجع المصدر شموعاً سليمة لفريمات 3 و5 و10 و15 و30 ثانية والدقيقة.
/// للقراءة فقط عبر الاتصال الحالي، ولا يغيّر شيئاً في التطبيق.
class FramesProbeCard extends StatefulWidget {
  const FramesProbeCard({super.key});
  @override
  State<FramesProbeCard> createState() => _FramesProbeCardState();
}

class _FramesProbeCardState extends State<FramesProbeCard> {
  static const periods = <int>[3, 5, 10, 15, 30, 60];
  String? pair;
  bool running = false;
  final lines = <String>[];

  String _tf(int p) => p < 60 ? 'S$p' : 'M${p ~/ 60}';

  Future<void> _pick() async {
    final p = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0A1A3F),
      builder: (_) => const PairSheet(),
    );
    if (p != null && mounted) setState(() => pair = p);
  }

  String _analyze(int p, Fetch<List<Candle>> f) {
    final d = f.data;
    if (d == null) return 'NO DATA (${f.error ?? '?'})';
    final closed = d.where((c) => c.closed).toList();
    if (closed.length < 2) return 'ISSUE | only ${d.length} candles';
    final ms = p * 1000;
    var gaps = 0;
    final from = closed.length > 60 ? closed.length - 60 : 1;
    for (var i = from; i < closed.length; i++) {
      if (closed[i].t - closed[i - 1].t != ms) gaps++;
    }
    final age =
        (DateTime.now().millisecondsSinceEpoch - (closed.last.t + ms)) / 1000;
    final ok = closed.length >= 100 && gaps == 0 && age <= p * 3 + 10;
    return '${ok ? 'OK' : 'ISSUE'} | candles ${closed.length} | gaps $gaps | last age ${age.toStringAsFixed(0)}s';
  }

  Future<void> _run() async {
    final pr = pair;
    if (pr == null || running) return;
    setState(() {
      running = true;
      lines.clear();
    });
    final sym = poSymbolOf(pr);
    for (final p in periods) {
      if (!mounted) return;
      setState(() => lines.add('${_tf(p)} ...'));
      String res;
      try {
        final f = await PoClient.I
            .candles(sym, p, count: 120)
            .timeout(const Duration(seconds: 90));
        res = _analyze(p, f);
      } catch (e) {
        res = 'FAILED / TIMEOUT';
      }
      if (!mounted) return;
      setState(() => lines[lines.length - 1] = '${_tf(p)}: $res');
    }
    if (mounted) setState(() => running = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1A3F),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1F4FB5).withOpacity(0.7)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.timer, color: Color(0xFF2E7BFF), size: 26),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
                _t('اختبار فريمات الثواني', 'Test des cadres en secondes',
                    'Seconds timeframes test'),
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 8),
        Text(
            _t('يتحقق هل يرجع مصدر Pocket Option شموعاً سليمة لفريمات 3 و5 و10 و15 و30 ثانية والدقيقة. للقراءة فقط ولا يغيّر شيئاً. اختر زوج OTC مفتوحاً.',
                "Vérifie si la source Pocket Option renvoie des bougies valides en 3, 5, 10, 15, 30 s et 1 min. Lecture seule. Choisissez une paire OTC ouverte.",
                'Checks whether the Pocket Option source returns valid candles for 3, 5, 10, 15, 30 s and 1 min. Read only. Pick an open OTC pair.'),
            style: const TextStyle(fontSize: 13, color: Colors.white70)),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: running ? null : _pick,
          child:
              Text(pair ?? _t('اختر زوجاً', 'Choisir une paire', 'Choose a pair')),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: (pair != null && !running) ? _run : null,
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7BFF),
                foregroundColor: Colors.white),
            icon: running
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.play_arrow),
            label: Text(_t('ابدأ الاختبار', 'Lancer le test', 'Start test')),
          ),
        ),
        if (lines.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: Colors.black38, borderRadius: BorderRadius.circular(10)),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: SelectableText(lines.join('\n'),
                  style: const TextStyle(
                      fontSize: 11, fontFamily: 'monospace', height: 1.5)),
            ),
          ),
        ],
      ]),
    );
  }
}
