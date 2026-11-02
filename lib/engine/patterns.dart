import 'dart:math';
import 'indicators.dart';

class Zone {
  double low, high;
  int touches;
  int lastIdx;
  Zone(this.low, this.high, this.touches, this.lastIdx);
  double get mid => (low + high) / 2;
  bool get strong => touches >= 2;
}

class CandleInfo {
  final bool bullEngulf, bearEngulf, bullRej, bearRej, momUp, momDown;
  const CandleInfo({
    this.bullEngulf = false,
    this.bearEngulf = false,
    this.bullRej = false,
    this.bearRej = false,
    this.momUp = false,
    this.momDown = false,
  });
}

class LevelInfo {
  final Zone? support, resistance;
  final double? supportDistAtr, resistDistAtr;
  final bool breakoutUp,
      breakdown,
      bullRetest,
      bearRetest,
      bullFalseBreak,
      bearFalseBreak,
      bullRej,
      bearRej;
  const LevelInfo({
    this.support,
    this.resistance,
    this.supportDistAtr,
    this.resistDistAtr,
    this.breakoutUp = false,
    this.breakdown = false,
    this.bullRetest = false,
    this.bearRetest = false,
    this.bullFalseBreak = false,
    this.bearFalseBreak = false,
    this.bullRej = false,
    this.bearRej = false,
  });
}

class Patterns {
  /// تحليل آخر شمعتين مغلقتين فقط.
  static CandleInfo candles(List<Candle> c, double atr) {
    final n = c.length;
    if (n < 2) return const CandleInfo();
    final a = c[n - 2];
    final b = c[n - 1];
    final range = b.h - b.l;
    final body = (b.c - b.o).abs();
    final lower = min(b.o, b.c) - b.l;
    final upper = b.h - max(b.o, b.c);
    final prevBody = (a.c - a.o).abs();

    final bullEngulf = a.c < a.o &&
        b.c > b.o &&
        b.o <= a.c &&
        b.c >= a.o &&
        body > prevBody;
    final bearEngulf = a.c > a.o &&
        b.c < b.o &&
        b.o >= a.c &&
        b.c <= a.o &&
        body > prevBody;
    final bullRej = range > 0 && lower >= 2 * body && lower >= 0.5 * range;
    final bearRej = range > 0 && upper >= 2 * body && upper >= 0.5 * range;
    final strongBody = range > 0 && body >= atr && body >= 0.7 * range;
    return CandleInfo(
      bullEngulf: bullEngulf,
      bearEngulf: bearEngulf,
      bullRej: bullRej,
      bearRej: bearRej,
      momUp: strongBody && b.c > b.o,
      momDown: strongBody && b.c < b.o,
    );
  }

  /// مناطق الدعم والمقاومة من القمم والقيعان المؤكدة فقط.
  static List<Zone> zones(List<Candle> c, double atr, {int k = 3}) {
    final n = c.length;
    final pts = <List<num>>[];
    for (var i = k; i < n - k; i++) {
      var hi = true, lo = true;
      for (var j = i - k; j <= i + k; j++) {
        if (j == i) continue;
        if (c[j].h >= c[i].h) hi = false;
        if (c[j].l <= c[i].l) lo = false;
      }
      if (hi) pts.add([c[i].h, i]);
      if (lo) pts.add([c[i].l, i]);
    }
    pts.sort((a, b) => a[0].compareTo(b[0]));
    final out = <Zone>[];
    final tol = 0.5 * atr;
    for (final pt in pts) {
      final price = pt[0].toDouble();
      final idx = pt[1].toInt();
      if (out.isNotEmpty &&
          price - out.last.high <= tol &&
          price - out.last.low <= atr) {
        final z = out.last;
        z.high = price;
        z.touches++;
        if (idx > z.lastIdx) z.lastIdx = idx;
      } else {
        out.add(Zone(price, price, 1, idx));
      }
    }
    return out;
  }

  /// يجب تمرير شموع مغلقة فقط. آخر عنصر هو شمعة التأكيد.
  static LevelInfo levels(List<Candle> c, {int k = 3}) {
    final n = c.length;
    if (n < 40) return const LevelInfo();
    final atrList = Ind.atr(c, 14);
    final atr = atrList[n - 1];
    if (atr == null || atr <= 0) return const LevelInfo();

    final zs = zones(c, atr, k: k);
    final b = c[n - 1];
    final p = c[n - 2];
    final price = b.c;
    final ci = candles(c, atr);

    Zone? sup, res;
    for (final z in zs) {
      if (z.mid <= price) {
        if (sup == null || z.mid > sup.mid) sup = z;
      } else {
        if (res == null || z.mid < res.mid) res = z;
      }
    }

    var bu = false,
        bd = false,
        br = false,
        ber = false,
        bf = false,
        bef = false,
        brj = false,
        berj = false;

    for (final z in zs) {
      if (p.c <= z.high && b.c > z.high) bu = true;
      if (p.c >= z.low && b.c < z.low) bd = true;

      for (var j = max(1, n - 12); j <= n - 3; j++) {
        if (c[j].c > z.high &&
            c[j - 1].c <= z.high &&
            b.l <= z.high + 0.25 * atr &&
            b.c > z.high) {
          br = true;
        }
        if (c[j].c < z.low &&
            c[j - 1].c >= z.low &&
            b.h >= z.low - 0.25 * atr &&
            b.c < z.low) {
          ber = true;
        }
      }

      for (var j = n - 3; j <= n - 1; j++) {
        if (c[j].l < z.low - 0.1 * atr && b.c > z.low && b.c > b.o) bf = true;
        if (c[j].h > z.high + 0.1 * atr && b.c < z.high && b.c < b.o) bef = true;
      }

      if (ci.bullRej &&
          b.l <= z.high + 0.1 * atr &&
          b.l >= z.low - 0.5 * atr &&
          b.c > z.high) {
        brj = true;
      }
      if (ci.bearRej &&
          b.h >= z.low - 0.1 * atr &&
          b.h <= z.high + 0.5 * atr &&
          b.c < z.low) {
        berj = true;
      }
    }

    return LevelInfo(
      support: sup,
      resistance: res,
      supportDistAtr: sup == null ? null : max(0.0, (price - sup.high) / atr),
      resistDistAtr: res == null ? null : max(0.0, (res.low - price) / atr),
      breakoutUp: bu,
      breakdown: bd,
      bullRetest: br,
      bearRetest: ber,
      bullFalseBreak: bf,
      bearFalseBreak: bef,
      bullRej: brj,
      bearRej: berj,
    );
  }
}
