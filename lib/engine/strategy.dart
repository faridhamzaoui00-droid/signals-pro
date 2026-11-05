import 'dart:math';
import 'cfg.dart';
import 'indicators.dart';
import 'patterns.dart';

class Reason {
  final String key;
  final String? v;
  const Reason(this.key, [this.v]);
}

class LastSignal {
  final String dir;
  final int tMs;
  final double price;
  const LastSignal(this.dir, this.tMs, this.price);
}

class EngineResult {
  final String type; // UP DOWN WAIT NA
  final int score;
  final double? price, adx, rsi, atr;
  final int? st;
  final Map<String, int> tf;
  final String sr;
  final List<Reason> reasons;
  final int tMs;
  const EngineResult({
    required this.type,
    this.score = 0,
    this.price,
    this.adx,
    this.rsi,
    this.atr,
    this.st,
    this.tf = const {},
    this.sr = 'sr_none',
    this.reasons = const [],
    required this.tMs,
  });
}

class _Snap {
  final int dir;
  final double price, atr, ema20, ema50, rsi, adx, lastBody;
  final int st;
  final bool lastBull, lastBear;
  final CandleInfo ci;
  final LevelInfo lv;
  const _Snap({
    required this.dir,
    required this.price,
    required this.atr,
    required this.ema20,
    required this.ema50,
    required this.rsi,
    required this.adx,
    required this.lastBody,
    required this.st,
    required this.lastBull,
    required this.lastBear,
    required this.ci,
    required this.lv,
  });
}

class Strategy {
  static const tfMs = {
    'M1': 60000,
    'M5': 300000,
    'M15': 900000,
    'M30': 1800000,
  };

  static List<String> tfsFor(int sec) {
    if (sec < 60) return [];
    if (sec <= 120) return ['M1', 'M5'];
    if (sec <= 300) return ['M1', 'M5', 'M15'];
    if (sec <= 540) return ['M5', 'M15'];
    return ['M5', 'M15', 'M30'];
  }

  static String? dataIssue(String name, List<Candle> c, int nowMs) {
    final ms = tfMs[name]!;
    if (c.length < 120) return 'data_short';
    final end = c.last.t + ms;
    if (end > nowMs + 2000) return 'data_future';
    if (nowMs - end > ms + 15000) return 'data_stale';
    for (var i = c.length - 60; i < c.length; i++) {
      final d = c[i].t - c[i - 1].t;
      if (d <= 0) return 'data_dup';
      if (d != ms) return 'data_gap';
    }
    return null;
  }

  static _Snap? _snap(List<Candle> c) {
    final closes = c.map((e) => e.c).toList();
    final e20 = Ind.ema(closes, Cfg.ema1).last;
    final e50 = Ind.ema(closes, Cfg.ema2).last;
    final r = Ind.rsi(closes, Cfg.rsiP).last;
    final a = Ind.atr(c, Cfg.atrP).last;
    final ax = Ind.adx(c, Cfg.adxP).last;
    final st = Ind.superTrend(c, p: Cfg.stP, m: Cfg.stM).dir.last;
    if (e20 == null ||
        e50 == null ||
        r == null ||
        a == null ||
        ax == null ||
        st == null ||
        a <= 0) {
      return null;
    }
    final last = c.last;
    int dir = 0;
    if (e20 > e50 && st == 1) dir = 1;
    if (e20 < e50 && st == -1) dir = -1;
    return _Snap(
      dir: dir,
      price: last.c,
      atr: a,
      ema20: e20,
      ema50: e50,
      rsi: r,
      adx: ax,
      lastBody: (last.c - last.o).abs(),
      st: st,
      lastBull: last.c > last.o,
      lastBear: last.c < last.o,
      ci: Patterns.candles(c, a),
      lv: Patterns.levels(c),
    );
  }

  static EngineResult run({
    required Map<String, List<Candle>> data,
    required int durationSec,
    required int nowMs,
    required bool connectionOk,
    LastSignal? last,
  }) {
    EngineResult na(String key, [String? v]) =>
        EngineResult(type: 'NA', tMs: nowMs, reasons: [Reason(key, v)]);

    final tfs = tfsFor(durationSec);
    if (tfs.isEmpty) return na('na_duration');
    if (!connectionOk) return na('na_connection');

    final snaps = <String, _Snap>{};
    for (final n in tfs) {
      final raw = data[n];
      if (raw == null) return na('na_no_data', n);
      final c = raw.where((x) => x.closed).toList();
      final issue = dataIssue(n, c, nowMs);
      if (issue != null) return na(issue, n);
      final s = _snap(c);
      if (s == null) return na('data_short', n);
      snaps[n] = s;
    }

    final entryName = tfs.first;
    final e = snaps[entryName]!;
    final tfDirs = <String, int>{for (final n in tfs) n: snaps[n]!.dir};

    EngineResult wait(List<Reason> rs, int score, {String sr = 'sr_none'}) =>
        EngineResult(
          type: 'WAIT',
          score: score,
          price: e.price,
          adx: e.adx,
          rsi: e.rsi,
          atr: e.atr,
          st: e.st,
          tf: tfDirs,
          sr: sr,
          reasons: rs,
          tMs: nowMs,
        );

    final d = e.ema20 > e.ema50 ? 1 : (e.ema20 < e.ema50 ? -1 : 0);
    if (d == 0) return wait([const Reason('blk_sideways')], 0);

    final fails = <Reason>[];
    final oks = <Reason>[];
    var score = 0;

    score += 1;
    oks.add(const Reason('ok_ema'));

    final rsiOk = d == 1 ? e.rsi > Cfg.rsiUp : e.rsi < Cfg.rsiDown;
    if (rsiOk) {
      score += 1;
      oks.add(const Reason('ok_rsi'));
    } else {
      fails.add(Reason('blk_rsi', e.rsi.toStringAsFixed(1)));
    }

    final adxOk = e.adx > Cfg.adxMin;
    if (adxOk) {
      score += 1;
      oks.add(const Reason('ok_adx'));
    } else {
      fails.add(Reason('blk_adx', e.adx.toStringAsFixed(1)));
    }

    final stOk = e.st == d;
    if (stOk) {
      score += 1;
      oks.add(const Reason('ok_st'));
    } else {
      fails.add(const Reason('blk_st'));
    }

    if ((e.ema20 - e.ema50).abs() < 0.1 * e.atr) {
      fails.add(const Reason('blk_sideways'));
    }

    final lastDirOk = d == 1 ? e.lastBull : e.lastBear;
    if (!lastDirOk) fails.add(const Reason('blk_no_confirm'));
    final strong = d == 1
        ? (e.ci.bullEngulf || e.ci.momUp || e.ci.bullRej)
        : (e.ci.bearEngulf || e.ci.momDown || e.ci.bearRej);
    if (lastDirOk && strong) {
      score += 2;
      oks.add(const Reason('ok_candle'));
    }

    final zone = d == 1 ? e.lv.resistance : e.lv.support;
    final dist = d == 1 ? e.lv.resistDistAtr : e.lv.supportDistAtr;
    if (zone == null || dist == null || dist >= 1.5) {
      score += 2;
      oks.add(const Reason('ok_sr'));
    } else if (dist >= 0.8) {
      score += 1;
      oks.add(const Reason('ok_sr_mid'));
    } else if (zone.strong) {
      fails.add(const Reason('blk_level_near'));
    }

    final retest = d == 1
        ? (e.lv.bullRetest || e.lv.bullRej || e.lv.bullFalseBreak)
        : (e.lv.bearRetest || e.lv.bearRej || e.lv.bearFalseBreak);
    if (retest) {
      score += 2;
      oks.add(const Reason('ok_retest'));
    }

    for (final n in tfs.skip(1)) {
      final dn = snaps[n]!.dir;
      if (dn == -d) {
        fails.add(Reason('blk_tf_conflict', n));
      } else if (dn == 0) {
        fails.add(Reason('blk_tf_unaligned', n));
      } else {
        oks.add(Reason('ok_tf', n));
      }
    }

    if ((e.price - e.ema20).abs() > 2.5 * e.atr) {
      fails.add(const Reason('blk_extended'));
    }

    if (e.lastBody > 2 * e.atr) {
      fails.add(const Reason('blk_late'));
    }

    final dirStr = d == 1 ? 'UP' : 'DOWN';
    if (last != null &&
        last.dir == dirStr &&
        nowMs - last.tMs < 3 * (tfMs[entryName]!) &&
        (e.price - last.price).abs() < 0.5 * e.atr) {
      fails.add(const Reason('blk_repeat'));
    }

    final sp = e.lv.support;
    final rz = e.lv.resistance;
    String srKey = 'sr_none';
    if (d == 1 && sp != null) {
      srKey = sp.strong ? 'sr_support_strong' : 'sr_support';
    } else if (d == -1 && rz != null) {
      srKey = rz.strong ? 'sr_res_strong' : 'sr_res';
    }

    if (fails.isNotEmpty) return wait(fails, score, sr: srKey);
    if (score < Cfg.minScore) {
      return wait([Reason('wait_score', '$score')], score, sr: srKey);
    }

    return EngineResult(
      type: d == 1 ? 'UP' : 'DOWN',
      score: min(score, 10),
      price: e.price,
      adx: e.adx,
      rsi: e.rsi,
      atr: e.atr,
      st: e.st,
      tf: tfDirs,
      sr: srKey,
      reasons: oks,
      tMs: nowMs,
    );
  }
}
