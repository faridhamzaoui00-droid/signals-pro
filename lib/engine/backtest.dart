import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'cfg.dart';
import 'indicators.dart';
import 'po_client.dart';
import 'strategy.dart';

class BtResult {
  final String pair, cfg;
  final int duration, lead, steps, skipped, signals, wins, losses, unverified;
  final int fromMs, toMs, candles;
  final int? payout;
  const BtResult({
    required this.pair,
    required this.cfg,
    required this.duration,
    required this.lead,
    required this.steps,
    required this.skipped,
    required this.signals,
    required this.wins,
    required this.losses,
    required this.unverified,
    required this.fromMs,
    required this.toMs,
    required this.candles,
    this.payout,
  });

  int get decided => wins + losses;
  double? get rate => decided == 0 ? null : wins * 100 / decided;

  double? get margin {
    final r = rate;
    if (r == null) return null;
    final p = r / 100;
    return 1.96 * sqrt(p * (1 - p) / decided) * 100;
  }

  double? get breakeven => payout == null ? null : 10000 / (100 + payout!);

  Map<String, dynamic> toJson() => {
        'pair': pair,
        'cfg': cfg,
        'duration': duration,
        'lead': lead,
        'steps': steps,
        'skipped': skipped,
        'signals': signals,
        'wins': wins,
        'losses': losses,
        'unverified': unverified,
        'fromMs': fromMs,
        'toMs': toMs,
        'candles': candles,
        'payout': payout,
      };

  static BtResult fromJson(Map<String, dynamic> m) => BtResult(
        pair: m['pair'] as String,
        cfg: (m['cfg'] ?? '') as String,
        duration: (m['duration'] as num).toInt(),
        lead: (m['lead'] as num).toInt(),
        steps: (m['steps'] as num).toInt(),
        skipped: (m['skipped'] as num).toInt(),
        signals: (m['signals'] as num).toInt(),
        wins: (m['wins'] as num).toInt(),
        losses: (m['losses'] as num).toInt(),
        unverified: (m['unverified'] as num).toInt(),
        fromMs: (m['fromMs'] as num).toInt(),
        toMs: (m['toMs'] as num).toInt(),
        candles: (m['candles'] as num).toInt(),
        payout: (m['payout'] as num?)?.toInt(),
      );
}

class BtStore {
  static const _k = 'bt_results';

  static Future<List<BtResult>> all() async {
    final out = <BtResult>[];
    try {
      final p = await SharedPreferences.getInstance();
      for (final s in p.getStringList(_k) ?? <String>[]) {
        try {
          out.add(BtResult.fromJson(jsonDecode(s) as Map<String, dynamic>));
        } catch (_) {}
      }
    } catch (_) {}
    return out;
  }

  static Future<void> add(BtResult r) async {
    try {
      final p = await SharedPreferences.getInstance();
      final list = p.getStringList(_k) ?? <String>[];
      list.insert(0, jsonEncode(r.toJson()));
      if (list.length > 30) list.removeRange(30, list.length);
      await p.setStringList(_k, list);
    } catch (_) {}
  }

  static Future<void> clear() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove(_k);
    } catch (_) {}
  }
}

class Backtest {
  static const tfMin = {'M1': 1, 'M5': 5, 'M15': 15, 'M30': 30};

  static List<Candle> _agg(List<Candle> m1, int min, int skew) {
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
      var hi = g.first.h;
      var lo = g.first.l;
      for (final c in g) {
        if (c.h > hi) hi = c.h;
        if (c.l < lo) lo = c.l;
      }
      out.add(Candle(b - skew, g.first.o, hi, lo, g.last.c));
    }
    return out;
  }

  static Future<Fetch<BtResult>> run({
    required String label,
    required int duration,
    required int lead,
    required void Function(String) status,
    required bool Function() cancelled,
  }) async {
    await Cfg.load();
    final sym = label.replaceAll(' OTC', '_otc');
    final tfs = Strategy.tfsFor(duration);
    if (tfs.isEmpty) return const Fetch<BtResult>(null, 'na_duration');

    var maxMin = 1;
    for (final t in tfs) {
      final m = tfMin[t]!;
      if (m > maxMin) maxMin = m;
    }
    final warm = 130 * maxMin;
    final tail = duration ~/ 60 + 6;
    final total = min(warm + 1440 + tail, 9000);

    status('0 / $total');
    final f = await PoClient.I.deepHistory(sym, total, (n) {
      status('${n} / $total');
    });
    if (f.data == null) return Fetch<BtResult>(null, f.error ?? 'na_source_error');
    if (cancelled()) return const Fetch<BtResult>(null, 'bt_cancel');

    final all = f.data!.where((c) => c.closed).toList();
    if (all.length < warm + 300) {
      return Fetch<BtResult>(null, 'bt_short:${all.length}');
    }
    final skew = PoClient.I.skewMs;
    final lastBase = all.last.t + skew;
    final open = <int, double>{for (final c in all) c.t + skew: c.o};

    final ser = <String, List<Candle>>{};
    for (final t in tfs) {
      ser[t] = t == 'M1' ? all : _agg(all, tfMin[t]!, skew);
    }
    final e = ser[tfs.first]!;
    final entryMs = tfMin[tfs.first]! * 60000;
    final t0 = all.first.t + skew + 132 * maxMin * 60000;
    final ptr = <String, int>{for (final t in tfs) t: 0};

    var steps = 0, skipped = 0, signals = 0, wins = 0, losses = 0, unv = 0;
    int? firstEnd;
    int? lastEnd;
    int? pendingUntil;
    LastSignal? lastSig;

    for (var k = 0; k < e.length; k++) {
      if ((k & 31) == 0) {
        if (cancelled()) return const Fetch<BtResult>(null, 'bt_cancel');
        status('${_pct(k, e.length)}%  •  $signals');
        await Future.delayed(Duration.zero);
      }
      final end = e[k].t + entryMs;
      final endTrue = end + skew;
      if (endTrue < t0) continue;
      final entryTrue =
          ((endTrue + 15000) ~/ 60000 + 1) * 60000 + (lead >= 60 ? 60000 : 0);
      final exitTrue = entryTrue + duration * 1000;
      if (exitTrue + 60000 > lastBase) break;
      if (pendingUntil != null && end < pendingUntil) continue;

      final data = <String, List<Candle>>{};
      for (final t in tfs) {
        final l = ser[t]!;
        final ms = tfMin[t]! * 60000;
        var p = ptr[t]!;
        while (p < l.length && l[p].t + ms <= end) {
          p++;
        }
        ptr[t] = p;
        data[t] = l.sublist(p > 220 ? p - 220 : 0, p);
      }
      steps++;
      firstEnd ??= endTrue;
      lastEnd = endTrue;
      final r = Strategy.run(
        data: data,
        durationSec: duration,
        nowMs: end + 1000,
        connectionOk: true,
        last: lastSig,
      );
      if (r.type == 'NA') {
        skipped++;
        continue;
      }
      if (r.type != 'UP' && r.type != 'DOWN') continue;
      signals++;
      pendingUntil = exitTrue - skew;
      lastSig = LastSignal(r.type, end, r.price ?? 0);
      final eo = open[entryTrue];
      final xo = open[exitTrue];
      if (eo == null || xo == null || eo == xo) {
        unv++;
        continue;
      }
      final win = r.type == 'UP' ? xo > eo : xo < eo;
      if (win) {
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
    return Fetch<BtResult>(
      BtResult(
        pair: label,
        cfg: Cfg.summary(),
        duration: duration,
        lead: lead,
        steps: steps,
        skipped: skipped,
        signals: signals,
        wins: wins,
        losses: losses,
        unverified: unv,
        fromMs: firstEnd ?? 0,
        toMs: lastEnd ?? 0,
        candles: all.length,
        payout: payout,
      ),
      null,
    );
  }

  static int _pct(int k, int n) => n == 0 ? 0 : (k * 100 ~/ n);
}
