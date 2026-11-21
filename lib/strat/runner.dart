import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../engine/cfg.dart';
import '../engine/datasource.dart';
import '../engine/indicators.dart';
import '../engine/monitor.dart';
import '../engine/notify.dart';
import '../engine/po_client.dart';
import '../history_page.dart';
import '../l10n.dart';
import '../pairs.dart';
import 'core.dart';
import 'psar.dart';
import 'strategies.dart';

String _t(String ar, String fr, String en) {
  final l = langNotifier.value;
  return l == 'ar' ? ar : (l == 'fr' ? fr : en);
}

class StratInfo {
  final String id, title, ar, fr, en;
  final int defScore;
  const StratInfo(this.id, this.title, this.ar, this.fr, this.en, this.defScore);
  String get desc => _t(ar, fr, en);
}

const List<StratInfo> kStrategies = [
  StratInfo('STRATEGY_1', 'MA20 + ZigZag + RSI',
      'تقاطع خط ZigZag مع المتوسط MA20 يؤكده RSI وإغلاق الشمعة.',
      "Croisement ZigZag / MA20 confirmé par le RSI et la clôture.",
      'ZigZag crossing MA20, confirmed by RSI and the candle close.', 5),
  StratInfo('STRATEGY_2', 'Market Structure + MA20 + S/R',
      'هيكل السوق (قمم وقيعان) + كسر MA20 + دخول عند إعادة اختبار منطقة.',
      "Structure de marché + cassure MA20 + entrée sur retest de zone.",
      'Market structure + MA20 break + entry on a zone retest.', 6),
  StratInfo('STRATEGY_3', 'Triple Touch Reversal',
      'انعكاس عند اللمسة الثالثة لدعم أو مقاومة مع شمعة رفض.',
      "Retournement à la 3e touche d'un support/résistance avec bougie de rejet.",
      'Reversal on the 3rd touch of support/resistance with a rejection candle.', 6),
  StratInfo('STRATEGY_4', 'MA20 Breakout & Retest',
      'اختراق MA20 ثم إعادة اختبار ثم شمعة تأكيد.',
      "Cassure MA20, retest puis bougie de confirmation.",
      'MA20 breakout, retest, then a confirmation candle.', 5),
  StratInfo('STRATEGY_5', 'Multi-Touch S/R Reversal',
      'انعكاس عند لمسات متعددة لدعم/مقاومة، ويتكيّف مع الفريم.',
      "Retournement sur touches multiples, adapté au cadre.",
      'Reversal on multiple S/R touches, adapted to the timeframe.', 6),
  StratInfo('STRATEGY_6', 'Parabolic SAR Triple Dot',
      'ثلاث نقاط SAR بعد الانعكاس: الأولى بعد الانعكاس، الثانية للتحليل، الثالثة للدخول.',
      "Trois points SAR : après inversion, analyse, entrée.",
      'Three SAR dots: after the reversal, analysis, entry.', 5),
];

StrategyBase makeStrategy(String id, Map<String, dynamic> o) {
  switch (id) {
    case 'STRATEGY_1':
      return Strategy1(o);
    case 'STRATEGY_2':
      return Strategy2(o);
    case 'STRATEGY_3':
      return Strategy3(o);
    case 'STRATEGY_4':
      return Strategy4(o);
    case 'STRATEGY_5':
      return Strategy5(o);
    default:
      return Strategy6(o);
  }
}

class StratCfg {
  bool enabled;
  List<String> pairs;
  String tf;
  int duration;
  int minScore;
  Map<String, dynamic> extra;
  StratCfg(
      {this.enabled = false,
      List<String>? pairs,
      this.tf = 'M1',
      this.duration = 60,
      this.minScore = 6,
      Map<String, dynamic>? extra})
      : pairs = pairs ?? <String>[],
        extra = extra ?? <String, dynamic>{};

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'pairs': pairs,
        'tf': tf,
        'duration': duration,
        'minScore': minScore,
        'extra': extra,
      };

  static StratCfg fromJson(Map<String, dynamic> m, int defScore) => StratCfg(
        enabled: (m['enabled'] ?? false) as bool,
        pairs: [for (final x in (m['pairs'] ?? []) as List) x.toString()],
        tf: (m['tf'] ?? 'M1') as String,
        duration: ((m['duration'] ?? 60) as num).toInt(),
        minScore: ((m['minScore'] ?? defScore) as num).toInt(),
        extra: Map<String, dynamic>.from((m['extra'] ?? {}) as Map),
      );
}

class StratRunner {
  static final StratRunner I = StratRunner._();
  StratRunner._();

  final ValueNotifier<int> changed = ValueNotifier<int>(0);
  final Map<String, StratCfg> cfg = {};
  final Map<String, String> status = {};
  final Map<String, StrategyBase> _inst = {};
  final Map<String, int> _lastB = {};
  final Map<String, int> _lastT = {};
  final Map<String, int> _anchor = {};
  final Map<String, int> _tries = {};
  final Set<String> _busy = {};
  Timer? _timer;
  bool _loaded = false;
  int _nid = 5000;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    for (final s in kStrategies) {
      cfg[s.id] = StratCfg(minScore: s.defScore);
    }
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString('strat_cfg');
      if (raw != null) {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        for (final s in kStrategies) {
          final x = m[s.id];
          if (x is Map) cfg[s.id] = StratCfg.fromJson(Map<String, dynamic>.from(x), s.defScore);
        }
      }
    } catch (_) {}
    await Cfg.load();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    changed.value++;
  }

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('strat_cfg', jsonEncode({for (final e in cfg.entries) e.key: e.value.toJson()}));
    } catch (_) {}
  }

  void _resetId(String id) {
    _inst.remove(id);
    for (final m in [_lastB, _lastT, _anchor, _tries]) {
      m.removeWhere((k, v) => k.startsWith('$id|'));
    }
    status.removeWhere((k, v) => k.startsWith('$id|'));
  }

  bool get anyEnabled => cfg.values.any((c) => c.enabled);

  Future<void> setEnabled(String id, bool v) async {
    final c = cfg[id]!;
    if (c.enabled == v) return;
    c.enabled = v;
    _resetId(id);
    await _save();
    changed.value++;
  }

  Future<void> setAll(bool v) async {
    for (final s in kStrategies) {
      final c = cfg[s.id]!;
      if (c.enabled != v) {
        c.enabled = v;
        _resetId(s.id);
      }
    }
    await _save();
    changed.value++;
  }

  Future<void> update(String id,
      {List<String>? pairs, String? tf, int? duration, int? minScore, Map<String, dynamic>? extra}) async {
    final c = cfg[id]!;
    if (pairs != null) c.pairs = pairs;
    if (tf != null) c.tf = tf;
    if (duration != null) c.duration = duration;
    if (minScore != null) c.minScore = minScore;
    if (extra != null) c.extra = extra;
    _resetId(id);
    await _save();
    changed.value++;
  }

  Map<String, dynamic> _over(String id) {
    final c = cfg[id]!;
    final o = <String, dynamic>{
      'min_confidence': c.minScore.toDouble(),
      'expiry_seconds': c.duration,
    };
    o.addAll(c.extra);
    return o;
  }

  StrategyBase _get(String id) => _inst.putIfAbsent(id, () => makeStrategy(id, _over(id)));

  List<String> pairsFor(StratCfg c) {
    final src = c.pairs.isNotEmpty ? c.pairs : Monitor.I.pairs;
    return src.length > 5 ? src.sublist(0, 5) : List<String>.from(src);
  }

  String statusFor(String id) {
    final xs = [for (final e in status.entries) if (e.key.startsWith('$id|')) '${e.key.substring(id.length + 1)}: ${e.value}'];
    return xs.join('\n');
  }

  // ---------------- الحلقة الحية ----------------
  void _tick() {
    if (!anyEnabled) return;
    final off = PoClient.I.offsetMs;
    final sNow = DateTime.now().millisecondsSinceEpoch + off;
    for (final info in kStrategies) {
      final c = cfg[info.id]!;
      if (!c.enabled) continue;
      final tfMs = Cfg.tfSeconds(c.tf) * 1000;
      if (tfMs <= 0) continue;
      final b = sNow ~/ tfMs * tfMs;
      final delay = tfMs >= 60000 ? 3000 : 1500;
      if (sNow - b < delay) continue;
      for (final pair in pairsFor(c)) {
        final key = '${info.id}|$pair';
        if (_busy.contains(key)) continue;
        if ((_lastB[key] ?? 0) >= b) continue;
        _busy.add(key);
        _run(info, c, pair, b, key);
      }
    }
  }

  Future<void> _run(StratInfo info, StratCfg c, String pair, int b, String key) async {
    try {
      final ok = await _process(info, c, pair, b, key);
      if (ok) {
        _lastB[key] = b;
        _tries[key] = 0;
      } else {
        final t = (_tries[key] ?? 0) + 1;
        _tries[key] = t;
        if (t >= 4) {
          _lastB[key] = b;
          _tries[key] = 0;
        }
      }
    } catch (_) {
      _lastB[key] = b;
    } finally {
      _busy.remove(key);
      changed.value++;
    }
  }

  Bars _bars(List<Candle> cl, int s, int e, int anchor, int tfMs) {
    final n = e - s;
    final t = List<int>.filled(n, 0);
    final o = List<double>.filled(n, 0), h = List<double>.filled(n, 0);
    final l = List<double>.filled(n, 0), c = List<double>.filled(n, 0);
    final q = List<int>.filled(n, 0);
    for (var i = 0; i < n; i++) {
      final x = cl[s + i];
      t[i] = x.t;
      o[i] = x.o;
      h[i] = x.h;
      l[i] = x.l;
      c[i] = x.c;
      q[i] = ((x.t - anchor) / tfMs).round();
    }
    return Bars(t, o, h, l, c, q);
  }

  Future<bool> _process(StratInfo info, StratCfg c, String pair, int bServer, String key) async {
    final tfSec = Cfg.tfSeconds(c.tf);
    final tfMs = tfSec * 1000;
    final f = await DataSource.candles(pair, c.tf, 0, size: 220);
    if (f.data == null) {
      status[key] = 'N/A ${f.error ?? ''}';
      return false;
    }
    final cl = f.data!.where((x) => x.closed).toList()..sort((a, b) => a.t.compareTo(b.t));
    if (cl.length < 30) {
      status[key] = _t('بيانات غير كافية', 'Données insuffisantes', 'Not enough data');
      return false;
    }
    final expected = bServer - tfMs - PoClient.I.offsetMs;
    if (cl.last.t < expected - 2000) {
      status[key] = _t('بيانات قديمة', 'Données anciennes', 'Stale data');
      return false;
    }
    final anchor = _anchor.putIfAbsent(key, () => cl.first.t);
    final lastT = _lastT[key] ?? -1;
    final strat = _get(info.id);
    var count = 0;
    for (var k = 0; k < cl.length; k++) {
      if (cl[k].t <= lastT) continue;
      final s = math.max(0, k + 1 - 300);
      final win = _bars(cl, s, k + 1, anchor, tfMs);
      final isLast = k == cl.length - 1;
      final r = strat.evaluate(win, pair, tfSec);
      if (isLast) {
        if (r.isSignal) {
          if (gapQuality(win, tfSec) < 0.9) {
            status[key] = 'DATA_GAPS';
          } else {
            status[key] = 'SIGNAL ${r.signal!.direction}';
            await _emitSignal(info, c, pair, r.signal!);
          }
        } else {
          status[key] = r.reason;
        }
      }
      count++;
      if (count % 20 == 0) await Future.delayed(Duration.zero);
    }
    _lastT[key] = cl.last.t;
    return true;
  }

  Future<void> _emitSignal(StratInfo info, StratCfg c, String pair, StratSignal s) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    var hist = <SignalRecord>[];
    try {
      hist = await HistoryDb.all();
    } catch (_) {}
    final tag = '[STRAT:${info.id}]';
    final dup = hist.any((h) =>
        h.pair == pair && h.result == 'PENDING' && h.indicators.contains(tag) && (h.endAt ?? 0) > now);
    if (dup) return;
    final off = PoClient.I.offsetMs;
    final sNow = now + off;
    final step = c.duration >= 60 ? 60000 : 5000;
    final entryMs = ((sNow ~/ step) + 1) * step - off;
    final expiryMs = entryMs + c.duration * 1000;
    final up = s.direction == 'BUY';
    final score = math.min(10, math.max(0, s.confidence.round()));
    final rec = SignalRecord(
      pair: pair,
      market: isOtcPair(pair) ? 'OTC' : 'REG',
      direction: up ? 'UP' : 'DOWN',
      duration: '${c.duration}',
      indicators: '[AUTO]$tag ${c.tf} | conf ${s.confidence.toStringAsFixed(1)}/10',
      reasons: '${info.title}: ${s.reason}',
      issuedAt: now,
      price: s.entryPrice,
      score: score,
      endAt: expiryMs,
    );
    try {
      await HistoryDb.insert(rec);
    } catch (_) {}
    Monitor.I.changed.value++;
    final title = '${up ? '▲ UP' : '▼ DOWN'}  $pair  ($score/10) • ${info.title}';
    final body = '${_t('الدخول', 'Entrée', 'Entry')} ${_hm(entryMs)}  •  ${_t('الانتهاء', 'Expiration', 'Expiry')} ${_hm(expiryMs)}  •  ${durText(c.duration)}';
    await Notifier.show(_nid++, title, body);
  }

  String _hm(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    String t(int v) => v.toString().padLeft(2, '0');
    return '${t(d.hour)}:${t(d.minute)}:${t(d.second)}';
  }

  // ---------------- الاختبار التاريخي (شموع الدقيقة فقط) ----------------
  List<Candle> _agg(List<Candle> m1, int min, int skew) {
    final ms = min * 60000;
    final groups = <int, List<Candle>>{};
    for (final c in m1) {
      final b = (c.t + skew) ~/ ms * ms;
      (groups[b] ??= <Candle>[]).add(c);
    }
    final keys = groups.keys.toList()..sort();
    final out = <Candle>[];
    for (final b in keys) {
      final g = groups[b]!;
      if (g.length != min) continue;
      var hi = g.first.h, lo = g.first.l;
      for (final c in g) {
        if (c.h > hi) hi = c.h;
        if (c.l < lo) lo = c.l;
      }
      out.add(Candle(b - skew, g.first.o, hi, lo, g.last.c));
    }
    return out;
  }

  Future<String> backtest(String id, String pair, void Function(String) status0, bool Function() cancelled) async {
    final c = cfg[id]!;
    final tfSec = Cfg.tfSeconds(c.tf);
    if (tfSec < 60 || c.duration < 60) {
      return _t('الاختبار التاريخي يُبنى من شموع الدقيقة، فلا يدعم فريمات أو مدد أقصر من دقيقة.',
          "Le test historique repose sur des bougies d'une minute : cadres/durées < 1 min non pris en charge.",
          'The backtest is built from 1-minute candles: timeframes/durations under 1 minute are not supported.');
    }
    final tfMin = tfSec ~/ 60;
    final sym = poSymbolOf(pair);
    final warm = 130 * tfMin;
    final total = math.min(warm + 1440 + c.duration ~/ 60 + 6, 9000);
    status0('0 / $total');
    final f = await PoClient.I.deepHistory(sym, total, (n) => status0('$n / $total'));
    if (f.data == null) {
      return _t('تعذر جلب التاريخ من المصدر (${f.error ?? ''}).', "Historique indisponible (${f.error ?? ''}).",
          'Could not fetch history (${f.error ?? ''}).');
    }
    if (cancelled()) return _t('أُلغي الاختبار.', 'Test annulé.', 'Test cancelled.');
    final all = f.data!.where((x) => x.closed).toList();
    if (all.length < warm + 300) {
      return _t('التاريخ المتاح قصير (${all.length} شمعة فقط).', "Historique trop court (${all.length} bougies).",
          'Available history is too short (${all.length} candles).');
    }
    final skew = PoClient.I.skewMs;
    final lastBase = all.last.t + skew;
    final open = <int, double>{for (final x in all) x.t + skew: x.o};
    final ser = tfMin == 1 ? all : _agg(all, tfMin, skew);
    final strat = makeStrategy(id, _over(id));
    final tfMs = tfSec * 1000;
    var signals = 0, wins = 0, losses = 0, unv = 0;
    int pendingUntil = 0;
    for (var k = 0; k < ser.length; k++) {
      if ((k & 31) == 0) {
        if (cancelled()) return _t('أُلغي الاختبار.', 'Test annulé.', 'Test cancelled.');
        status0('${ser.length == 0 ? 0 : k * 100 ~/ ser.length}%  •  $signals');
        await Future.delayed(Duration.zero);
      }
      final win = _bars(ser, math.max(0, k + 1 - 300), k + 1, ser.first.t, tfMs);
      final r = strat.evaluate(win, pair, tfSec);
      if (!r.isSignal) continue;
      final endTrue = ser[k].t + tfMs + skew;
      if (endTrue < pendingUntil) continue;
      final entryTrue = ((endTrue + 15000) ~/ 60000 + 1) * 60000;
      final exitTrue = entryTrue + c.duration * 1000;
      if (exitTrue + 60000 > lastBase) break;
      signals++;
      pendingUntil = exitTrue;
      final eo = open[entryTrue], xo = open[exitTrue];
      if (eo == null || xo == null || eo == xo) {
        unv++;
        continue;
      }
      final up = r.signal!.direction == 'BUY';
      if (up ? xo > eo : xo < eo) {
        wins++;
      } else {
        losses++;
      }
    }
    int? payout;
    for (final a in PoClient.I.assets) {
      if (a.symbol == sym) {
        payout = a.payout;
        break;
      }
    }
    final decided = wins + losses;
    final sb = StringBuffer();
    sb.writeln('$pair • ${c.tf} • ${durText(c.duration)}');
    sb.writeln('${_t('إشارات', 'Signaux', 'Signals')}: $signals');
    sb.writeln('${_t('رابحة', 'Gagnants', 'Wins')}: $wins   ${_t('خاسرة', 'Perdants', 'Losses')}: $losses   ${_t('غير محسومة', 'Non tranchés', 'Unresolved')}: $unv');
    if (decided == 0) {
      sb.writeln(_t('لا صفقات محسومة، فلا توجد نسبة نجاح.', 'Aucun trade tranché : pas de taux.', 'No decided trades: no win rate.'));
    } else {
      final rate = wins * 100 / decided;
      final p = rate / 100;
      final margin = 1.96 * math.sqrt(p * (1 - p) / decided) * 100;
      sb.writeln('${_t('نسبة النجاح', 'Taux de réussite', 'Win rate')}: ${rate.toStringAsFixed(1)}%  (±${margin.toStringAsFixed(1)})');
      if (payout != null) {
        sb.writeln('${_t('نسبة التعادل', 'Seuil de rentabilité', 'Breakeven')} ($payout%): ${(10000 / (100 + payout)).toStringAsFixed(1)}%');
      }
      if (decided < 30) {
        sb.writeln(_t('عدد الصفقات قليل (أقل من 30)، فالنتيجة غير موثوقة.', 'Moins de 30 trades : résultat peu fiable.', 'Fewer than 30 trades: not reliable.'));
      }
    }
    sb.writeln(_t('فترة واحدة فقط ولا تضمن المستقبل.', 'Une seule période, sans garantie.', 'One period only, no guarantee.'));
    return sb.toString();
  }
}
