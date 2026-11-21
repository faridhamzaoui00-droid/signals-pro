// نقل Dart للمحرك المرجعي (otc_strategies_engine). شموع مغلقة فقط.
import 'dart:math' as math;

double clip01(double x) {
  final m = x < 1.0 ? x : 1.0;
  return m > 0.0 ? m : 0.0;
}

double _rhe(double x) {
  final f = x.floorToDouble();
  final d = x - f;
  if (d < 0.5) return f;
  if (d > 0.5) return f + 1.0;
  return (f % 2.0 == 0.0) ? f : f + 1.0;
}

class Bars {
  final List<int> t;
  final List<double> o, h, l, c;
  final List<int> seq;
  Bars(this.t, this.o, this.h, this.l, this.c, this.seq);
  int get n => c.length;
  Bars window(int s, int e) => Bars(t.sublist(s, e), o.sublist(s, e),
      h.sublist(s, e), l.sublist(s, e), c.sublist(s, e), seq.sublist(s, e));
}

// ---------------- المؤشرات (مطابقة لـ pandas) ----------------
List<double> _ewm(List<double> x, double alpha, int minP) {
  final n = x.length;
  final out = List<double>.filled(n, double.nan);
  if (n == 0) return out;
  final oldFactor = 1.0 - alpha;
  var avg = x[0];
  var nobs = avg.isNaN ? 0 : 1;
  if (nobs >= minP) out[0] = avg;
  var oldWt = 1.0;
  for (var i = 1; i < n; i++) {
    final cur = x[i];
    final isObs = !cur.isNaN;
    if (isObs) nobs++;
    if (!avg.isNaN) {
      if (isObs) {
        oldWt *= oldFactor;
        if (avg != cur) {
          avg = ((oldWt * avg) + (alpha * cur)) / (oldWt + alpha);
        }
        oldWt = 1.0;
      }
    } else if (isObs) {
      avg = cur;
    }
    if (nobs >= minP) out[i] = avg;
  }
  return out;
}

List<double> sma(List<double> v, int w) {
  final n = v.length;
  final out = List<double>.filled(n, double.nan);
  var nobs = 0;
  var sumX = 0.0, compAdd = 0.0, compRem = 0.0;
  var nSame = 0;
  var prev = double.nan;
  void add(double val) {
    if (!val.isNaN) {
      nobs++;
      final y = val - compAdd;
      final t = sumX + y;
      compAdd = t - sumX - y;
      sumX = t;
      if (val == prev) {
        nSame++;
      } else {
        nSame = 1;
      }
      prev = val;
    }
  }

  void rem(double val) {
    if (!val.isNaN) {
      nobs--;
      final y = -val - compRem;
      final t = sumX + y;
      compRem = t - sumX - y;
      sumX = t;
    }
  }

  for (var i = 0; i < n; i++) {
    final e = i + 1;
    final s = e - w < 0 ? 0 : e - w;
    if (i == 0) {
      prev = v[s];
      nSame = 0;
      for (var j = s; j < e; j++) {
        add(v[j]);
      }
    } else {
      final ps = i - w < 0 ? 0 : i - w;
      for (var j = ps; j < s; j++) {
        rem(v[j]);
      }
      add(v[i]);
    }
    if (nobs >= w && nobs > 0) {
      var r = sumX / nobs;
      if (nSame >= nobs) r = prev;
      out[i] = r;
    }
  }
  return out;
}

List<double> ema(List<double> x, int p) => _ewm(x, 2.0 / (p + 1.0), p);

List<double> movingAverage(List<double> x, int p, String kind) {
  final k = kind.toLowerCase();
  if (k == 'ema') return ema(x, p);
  if (k == 'sma') return sma(x, p);
  throw ArgumentError('Unknown MA type: $kind');
}

List<double> trueRange(Bars b) {
  final n = b.n;
  final tr = List<double>.filled(n, 0.0);
  for (var i = 0; i < n; i++) {
    if (i == 0) {
      tr[0] = b.h[0] - b.l[0];
    } else {
      final pc = b.c[i - 1];
      tr[i] = math.max(b.h[i] - b.l[i],
          math.max((b.h[i] - pc).abs(), (b.l[i] - pc).abs()));
    }
  }
  return tr;
}

List<double> atrArr(Bars b, int p) => _ewm(trueRange(b), 1.0 / p, p);

List<double> rsiArr(List<double> close, int period) {
  final n = close.length;
  final up = List<double>.filled(n, double.nan);
  final dn = List<double>.filled(n, double.nan);
  for (var i = 1; i < n; i++) {
    final d = close[i] - close[i - 1];
    up[i] = d > 0.0 ? d : 0.0;
    final nd = -d;
    dn[i] = nd > 0.0 ? nd : 0.0;
  }
  final alpha = 1.0 / period;
  final au = _ewm(up, alpha, period);
  final ad = _ewm(dn, alpha, period);
  final out = List<double>.filled(n, double.nan);
  for (var i = 0; i < n; i++) {
    final u = au[i], d = ad[i];
    final rs = u / (d == 0.0 ? double.nan : d);
    var o = 100.0 - 100.0 / (1.0 + rs);
    if (d == 0.0 && u > 0.0) o = 100.0;
    if (d == 0.0 && u == 0.0) o = 50.0;
    out[i] = o;
  }
  return out;
}

// ---------------- جودة البيانات والتقييم ----------------
double gapQuality(Bars df, int tfSeconds, {int window = 100}) {
  final n = df.n;
  final start = n > window ? n - window : 0;
  final len = n - start;
  if (len < 2) return 0.0;
  var missing = 0.0;
  for (var i = start + 1; i < n; i++) {
    final dt = (df.t[i] - df.t[i - 1]) / 1000.0;
    final m = _rhe(dt / tfSeconds) - 1.0;
    missing += m > 0.0 ? m : 0.0;
  }
  final gapQ = 1.0 - missing / (missing + len);
  var nanQ = 1.0;
  for (var i = start; i < n; i++) {
    if (df.o[i].isNaN || df.h[i].isNaN || df.l[i].isNaN || df.c[i].isNaN) {
      nanQ = 0.0;
      break;
    }
  }
  return clip01(gapQ * nanQ);
}

double dataQuality(Bars df, int tfSeconds) {
  final histQ = clip01(df.n / 120.0);
  return clip01(gapQuality(df, tfSeconds) * (0.5 + 0.5 * histQ));
}

double slopeAlignment(List<double> ma, double atrV, String direction,
    {int lookback = 5}) {
  final n = ma.length;
  if (n <= lookback || !ma[n - 1].isFinite || !ma[n - 1 - lookback].isFinite || atrV <= 0) {
    return 0.0;
  }
  var s = (ma[n - 1] - ma[n - 1 - lookback]) / (lookback * atrV);
  s = direction == 'BUY' ? s : -s;
  return clip01(s / 0.2);
}

const List<String> _kComps = [
  'trend_strength',
  'zone_strength',
  'candle_confirmation',
  'indicator_agreement',
  'data_quality',
];
const Map<String, double> _kDefW = {
  'trend_strength': 0.25,
  'zone_strength': 0.25,
  'candle_confirmation': 0.20,
  'indicator_agreement': 0.20,
  'data_quality': 0.10,
};

/// درجة 0..10 لتوافق الشروط، وليست نسبة ربح.
double computeConfidence(Map<String, double> comps, Map<String, double>? weights) {
  final w = Map<String, double>.from(_kDefW);
  if (weights != null) w.addAll(weights);
  var total = 0.0;
  for (final k in _kComps) {
    total += w[k]!;
  }
  if (total == 0.0) total = 1.0;
  var s = 0.0;
  for (final k in _kComps) {
    s += w[k]! * clip01(comps[k] ?? 0.0);
  }
  return 10.0 * s / total;
}

// ---------------- القمم والقيعان والهيكل ----------------
class Swing {
  final int index;
  final double price;
  final String kind; // HIGH | LOW
  final int confirmedIndex;
  const Swing(this.index, this.price, this.kind, this.confirmedIndex);
}

List<Swing> detectSwings(List<double> high, List<double> low, int left, int right) {
  final n = high.length;
  final out = <Swing>[];
  for (var i = left; i < n - right; i++) {
    final h = high[i];
    var mp = high[i - left];
    for (var j = i - left + 1; j < i; j++) {
      if (high[j] > mp) mp = high[j];
    }
    var mn = high[i + 1];
    for (var j = i + 2; j <= i + right; j++) {
      if (high[j] > mn) mn = high[j];
    }
    if (h > mp && h >= mn) out.add(Swing(i, h, 'HIGH', i + right));
    final l = low[i];
    var lp = low[i - left];
    for (var j = i - left + 1; j < i; j++) {
      if (low[j] < lp) lp = low[j];
    }
    var ln = low[i + 1];
    for (var j = i + 2; j <= i + right; j++) {
      if (low[j] < ln) ln = low[j];
    }
    if (l < lp && l <= ln) out.add(Swing(i, l, 'LOW', i + right));
  }
  return out;
}

class TrendInfo {
  final String trend;
  final String structure;
  final double prevHigh, lastHigh, prevLow, lastLow;
  const TrendInfo(this.trend, this.structure, this.prevHigh, this.lastHigh,
      this.prevLow, this.lastLow);
}

TrendInfo classifyTrend(List<Swing> swings) {
  final highs = swings.where((s) => s.kind == 'HIGH').toList();
  final lows = swings.where((s) => s.kind == 'LOW').toList();
  if (highs.length < 2 || lows.length < 2) {
    return const TrendInfo('SIDEWAYS', '', double.nan, double.nan, double.nan, double.nan);
  }
  final h1 = highs[highs.length - 2], h2 = highs[highs.length - 1];
  final l1 = lows[lows.length - 2], l2 = lows[lows.length - 1];
  if (h2.price > h1.price && l2.price > l1.price) {
    return TrendInfo('UP', 'HH+HL', h1.price, h2.price, l1.price, l2.price);
  }
  if (h2.price < h1.price && l2.price < l1.price) {
    return TrendInfo('DOWN', 'LH+LL', h1.price, h2.price, l1.price, l2.price);
  }
  return TrendInfo('SIDEWAYS', 'MIXED', h1.price, h2.price, l1.price, l2.price);
}

String? structureEvent(List<double> close, List<Swing> swings, String trend) {
  final highs = swings.where((s) => s.kind == 'HIGH').toList();
  final lows = swings.where((s) => s.kind == 'LOW').toList();
  if (highs.isEmpty || lows.isEmpty || close.length < 2) return null;
  final c = close[close.length - 1], pc = close[close.length - 2];
  final lh = highs.last.price, ll = lows.last.price;
  final brokeUp = pc <= lh && lh < c;
  final brokeDn = pc >= ll && ll > c;
  if (trend == 'UP') return brokeUp ? 'BOS_BULLISH' : (brokeDn ? 'CHOCH_BEARISH' : null);
  if (trend == 'DOWN') return brokeDn ? 'BOS_BEARISH' : (brokeUp ? 'CHOCH_BULLISH' : null);
  return null;
}

String? maCrossAt(List<double> close, List<double> ma, int i) {
  if (i < 1 || !ma[i].isFinite || !ma[i - 1].isFinite) return null;
  if (close[i - 1] <= ma[i - 1] && close[i] > ma[i]) return 'UP';
  if (close[i - 1] >= ma[i - 1] && close[i] < ma[i]) return 'DOWN';
  return null;
}

int countMaCrossings(List<double> close, List<double> ma, int lookback) {
  final n = close.length;
  final s = n > lookback ? n - lookback : 0;
  var prevSide = 0;
  var cnt = 0;
  var have = false;
  for (var i = s; i < n; i++) {
    if (!ma[i].isFinite) continue;
    final d = close[i] - ma[i];
    final side = d > 0 ? 1 : (d < 0 ? -1 : 0);
    if (side == 0) continue;
    if (have && side != prevSide) cnt++;
    prevSide = side;
    have = true;
  }
  return cnt;
}

// ---------------- أنماط الشموع ----------------
class Rejection {
  final String name, direction;
  final double strength;
  const Rejection(this.name, this.direction, this.strength);
}

double bodyFraction(double o, double h, double l, double c) {
  final r = h - l;
  return r <= 1e-12 ? 0.0 : (c - o).abs() / r;
}

Rejection? _bullPin(double o, double h, double l, double c) {
  final rng = h - l;
  final body = (c - o).abs();
  final upper = h - math.max(o, c);
  final lower = math.min(o, c) - l;
  if (rng <= 1e-12) return null;
  if (lower / rng < 0.5) return null;
  if (lower < 2.0 * math.max(body, 0.05 * rng)) return null;
  final loc = (c - l) / rng;
  if (loc < 0.6) return null;
  final name = upper / rng <= 0.2 ? 'HAMMER' : 'BULLISH_PIN_BAR';
  final strength =
      0.6 * clip01((lower / rng) / 0.75) + 0.4 * clip01((loc - 0.5) / 0.4);
  return Rejection(name, 'BUY', strength);
}

Rejection? _bullEngulf(double po, double pc, double o, double h, double l, double c) {
  if (!(pc < po && c > o)) return null;
  if (!(c >= po && o <= pc)) return null;
  final pb = po - pc, cb = c - o;
  if (pb <= 1e-12 || cb < pb) return null;
  final rng = h - l;
  final strength =
      0.5 * clip01(rng > 1e-12 ? cb / rng : 0.0) + 0.5 * clip01(cb / pb / 2.0);
  return Rejection('BULLISH_ENGULFING', 'BUY', strength);
}

Rejection? detectBullish(double? po, double? pc, double o, double h, double l, double c) {
  Rejection? best = _bullPin(o, h, l, c);
  if (po != null && pc != null) {
    final e = _bullEngulf(po, pc, o, h, l, c);
    if (e != null && (best == null || e.strength > best.strength)) best = e;
  }
  return best;
}

Rejection? detectBearish(double? po, double? pc, double o, double h, double l, double c) {
  final r = detectBullish(po == null ? null : -po, pc == null ? null : -pc, -o, -l, -h, -c);
  if (r == null) return null;
  const names = {
    'HAMMER': 'SHOOTING_STAR',
    'BULLISH_PIN_BAR': 'BEARISH_PIN_BAR',
    'BULLISH_ENGULFING': 'BEARISH_ENGULFING',
  };
  return Rejection(names[r.name]!, 'SELL', r.strength);
}

Rejection? detectRejection(List<double> o, List<double> h, List<double> l,
    List<double> c, int pos, String direction) {
  final po = pos >= 1 ? o[pos - 1] : null;
  final pc = pos >= 1 ? c[pos - 1] : null;
  return direction == 'BUY'
      ? detectBullish(po, pc, o[pos], h[pos], l[pos], c[pos])
      : detectBearish(po, pc, o[pos], h[pos], l[pos], c[pos]);
}

// ---------------- مناطق الدعم والمقاومة ----------------
class Zone {
  final String kind;
  final int originIndex;
  final double center, low, high;
  const Zone(this.kind, this.originIndex, this.center, this.low, this.high);
}

class Touch {
  final int startIndex;
  final double reboundAtr;
  const Touch(this.startIndex, this.reboundAtr);
}

class ZoneState {
  final Zone zone;
  final List<Touch> touches;
  final bool active, broken;
  const ZoneState(this.zone, this.touches, this.active, this.broken);
  int get touchNo => touches.length + 1;
}

double _atrAt(List<double> atr, int t, double fb) {
  final v = atr[t];
  return (v.isFinite && v > 0) ? v : fb;
}

class _Scan {
  final List<Touch> touches;
  final int curStart;
  final int? invalid;
  const _Scan(this.touches, this.curStart, this.invalid);
}

_Scan _scanZone(Zone z, List<double> high, List<double> low, List<double> close,
    List<double> atr, int end, double minDep, double breakAtr, double fb) {
  final touches = <Touch>[];
  var curStart = -1;
  var curDepth = 0.0;
  for (var t = z.originIndex; t < end; t++) {
    final a = _atrAt(atr, t, fb);
    bool touching;
    double depth;
    bool separated;
    if (z.kind == 'RESISTANCE') {
      if (close[t] > z.high + breakAtr * a) return _Scan(touches, curStart, t);
      touching = high[t] >= z.low;
      depth = (z.low - low[t]) / a;
      separated = high[t] < z.low;
    } else {
      if (close[t] < z.low - breakAtr * a) return _Scan(touches, curStart, t);
      touching = low[t] <= z.high;
      depth = (high[t] - z.high) / a;
      separated = low[t] > z.high;
    }
    if (curStart < 0) {
      if (touching) {
        curStart = t;
        curDepth = depth > 0.0 ? depth : 0.0;
      }
    } else {
      if (depth > curDepth) curDepth = depth;
      if (separated && curDepth >= minDep) {
        touches.add(Touch(curStart, curDepth));
        curStart = -1;
      }
    }
  }
  return _Scan(touches, curStart, null);
}

void stableSortBy<T>(List<T> l, double Function(T) key) {
  for (var i = 1; i < l.length; i++) {
    final x = l[i];
    final kx = key(x);
    var j = i - 1;
    while (j >= 0 && key(l[j]) > kx) {
      l[j + 1] = l[j];
      j--;
    }
    l[j + 1] = x;
  }
}

List<ZoneState> findZoneStates(List<double> high, List<double> low,
    List<double> close, List<double> atr, List<Swing> swings, String kind,
    {required int lookback,
    required double zoneAtrMult,
    required double minDepartureAtr,
    required double breakAtr,
    int maxZones = 6,
    int maxTouchBars = 3,
    double nearAtr = 3.0}) {
  final n = close.length;
  final end = n - 1;
  final r0 = (end >= 1 && atr[end - 1].isFinite) ? atr[end - 1] : atr[end];
  if (!r0.isFinite || r0 <= 0) return <ZoneState>[];
  final ref = r0;
  final tol = ref * zoneAtrMult;
  final want = kind == 'RESISTANCE' ? 'HIGH' : 'LOW';
  final zones = <Zone>[];
  for (final s in swings) {
    if (s.kind != want || s.index < n - lookback || s.index >= end) continue;
    var dup = false;
    for (final z in zones) {
      if ((s.price - z.center).abs() <= tol) {
        dup = true;
        break;
      }
    }
    if (dup) continue;
    zones.add(Zone(kind, s.index, s.price, s.price - tol, s.price + tol));
  }
  final states = <ZoneState>[];
  for (final z in zones) {
    if (kind == 'RESISTANCE' && high[end] < z.low - nearAtr * ref) continue;
    if (kind == 'SUPPORT' && low[end] > z.high + nearAtr * ref) continue;
    final sc = _scanZone(z, high, low, close, atr, end, minDepartureAtr, breakAtr, ref);
    if (sc.invalid != null) continue;
    final a = _atrAt(atr, end, ref);
    bool touching;
    bool broken;
    if (kind == 'RESISTANCE') {
      touching = high[end] >= z.low;
      broken = close[end] > z.high + breakAtr * a;
    } else {
      touching = low[end] <= z.high;
      broken = close[end] < z.low - breakAtr * a;
    }
    final active = touching || (sc.curStart >= 0 && end - sc.curStart <= maxTouchBars);
    states.add(ZoneState(z, sc.touches, active, broken));
  }
  stableSortBy<ZoneState>(states, (s) => (s.zone.center - close[end]).abs());
  return states.length > maxZones ? states.sublist(0, maxZones) : states;
}

List<double> supplyDemandZone(List<double> o, List<double> h, List<double> l,
    List<double> c, Swing sw, double atrV) {
  const minThick = 0.3, pad = 0.1;
  final i = sw.index;
  if (sw.kind == 'HIGH') {
    var lo = math.max(o[i], c[i]);
    final hi = h[i];
    lo = math.min(lo, hi - minThick * atrV);
    return [lo - pad * atrV, hi + pad * atrV];
  }
  final hi0 = math.min(o[i], c[i]);
  final lo = l[i];
  final hi = math.max(hi0, lo + minThick * atrV);
  return [lo - pad * atrV, hi + pad * atrV];
}

// ---------------- ZigZag ----------------
class Pivot {
  final int index;
  final double price;
  final String kind;
  final int confirmedIndex;
  const Pivot(this.index, this.price, this.kind, this.confirmedIndex);
}

List<double> zigzagThreshold(List<double> close, List<double> atrV, String mode,
    double mult, double pct) {
  if (mode == 'atr') return [for (final a in atrV) a * mult];
  if (mode == 'percent') return [for (final c in close) c * (pct / 100.0)];
  throw ArgumentError('Unknown zigzag mode $mode');
}

List<Pivot> zigzagPivots(List<double> high, List<double> low, List<double> thr) {
  final n = high.length;
  final pivots = <Pivot>[];
  if (n < 2) return pivots;
  var direction = 0;
  var hiI = 0, loI = 0;
  var hi = high[0], lo = low[0];
  for (var i = 1; i < n; i++) {
    final t = thr[i];
    if (!t.isFinite || t <= 0) {
      if (high[i] > hi) {
        hi = high[i];
        hiI = i;
      }
      if (low[i] < lo) {
        lo = low[i];
        loI = i;
      }
      continue;
    }
    var newHi = false, newLo = false;
    if (high[i] > hi) {
      hi = high[i];
      hiI = i;
      newHi = true;
    }
    if (low[i] < lo) {
      lo = low[i];
      loI = i;
      newLo = true;
    }
    if (direction == 0) {
      if (hi - low[i] >= t && !newHi) {
        pivots.add(Pivot(hiI, hi, 'HIGH', i));
        direction = -1;
        lo = low[i];
        loI = i;
      } else if (high[i] - lo >= t && !newLo) {
        pivots.add(Pivot(loI, lo, 'LOW', i));
        direction = 1;
        hi = high[i];
        hiI = i;
      }
    } else if (direction == 1) {
      if (hi - low[i] >= t && !newHi) {
        pivots.add(Pivot(hiI, hi, 'HIGH', i));
        direction = -1;
        lo = low[i];
        loI = i;
      }
    } else {
      if (high[i] - lo >= t && !newLo) {
        pivots.add(Pivot(loI, lo, 'LOW', i));
        direction = 1;
        hi = high[i];
        hiI = i;
      }
    }
  }
  return pivots;
}

class Cross {
  final int index;
  final String dir;
  const Cross(this.index, this.dir);
}

Cross? segmentMaCross(Pivot p0, Pivot p1, List<double> ma) {
  final span = p1.index - p0.index;
  if (span <= 0) return null;
  final ts = <int>[];
  final ds = <double>[];
  for (var t = p0.index; t <= p1.index; t++) {
    final zz = p0.price + (p1.price - p0.price) * (t - p0.index) / span;
    final d = zz - ma[t];
    if (d.isFinite) {
      ts.add(t);
      ds.add(d);
    }
  }
  if (ts.length < 2) return null;
  if (p0.kind == 'HIGH' && p1.kind == 'LOW' && ds[0] > 0) {
    for (var i = 0; i < ds.length; i++) {
      if (ds[i] < 0) return Cross(ts[i], 'DOWN');
    }
  }
  if (p0.kind == 'LOW' && p1.kind == 'HIGH' && ds[0] < 0) {
    for (var i = 0; i < ds.length; i++) {
      if (ds[i] > 0) return Cross(ts[i], 'UP');
    }
  }
  return null;
}

// ---------------- الإشارة والاستراتيجية الأساسية ----------------
class StratSignal {
  final String strategyId, strategyName, symbol, direction, reason, dedupeKey;
  final int tfSec, expirySec, closeTimeMs;
  final double entryPrice, confidence;
  final Map<String, dynamic> details;
  const StratSignal({
    required this.strategyId,
    required this.strategyName,
    required this.symbol,
    required this.direction,
    required this.reason,
    required this.dedupeKey,
    required this.tfSec,
    required this.expirySec,
    required this.closeTimeMs,
    required this.entryPrice,
    required this.confidence,
    required this.details,
  });
}

class StratResult {
  final StratSignal? signal;
  final String status, reason;
  const StratResult._(this.signal, this.status, this.reason);
  factory StratResult.wait(String reason) => StratResult._(null, 'WAIT', reason);
  factory StratResult.emit(StratSignal s) => StratResult._(s, 'SIGNAL', 'SIGNAL');
  bool get isSignal => signal != null;
}

abstract class StrategyBase {
  final Map<String, dynamic> settings;
  final Map<String, Map<String, dynamic>> _states = {};

  StrategyBase(Map<String, dynamic> defaults, Map<String, dynamic>? over)
      : settings = <String, dynamic>{...defaults, ...?over};

  String get id;
  String get name;

  int si(String k) => (settings[k] as num).toInt();
  double sd(String k) => (settings[k] as num).toDouble();
  bool sb(String k) => settings[k] as bool;
  String ss(String k) => settings[k] as String;

  int get minCandles => si('min_candles');

  int expiryFor(int tf) {
    final e = settings['expiry_seconds'];
    if (e == null) return tf;
    final v = (e as num).toInt();
    return v != 0 ? v : tf;
  }

  Map<String, dynamic> freshState() => <String, dynamic>{};

  Map<String, dynamic> state(String symbol, int tf) {
    return _states.putIfAbsent('$symbol|$tf', () {
      final st = freshState();
      st['emitted'] = <String>{};
      return st;
    });
  }

  void reset([String? symbol]) {
    if (symbol == null) {
      _states.clear();
    } else {
      _states.removeWhere((k, v) => k.startsWith('$symbol|'));
    }
  }

  StratResult evaluate(Bars df, String symbol, int tf) {
    if (df.n < minCandles) return StratResult.wait('INSUFFICIENT_DATA');
    return doEvaluate(df, symbol, tf);
  }

  StratResult doEvaluate(Bars df, String symbol, int tf);

  StratResult emit(Bars df, String symbol, int tf, String direction,
      Map<String, double> comps, String reason, String key,
      Map<String, dynamic> details,
      {Map<String, double>? weights}) {
    final st = state(symbol, tf);
    final emitted = st['emitted'] as Set<String>;
    if (emitted.contains(key)) return StratResult.wait('DUPLICATE_SIGNAL');
    final cm = Map<String, double>.from(comps);
    cm.putIfAbsent('data_quality', () => dataQuality(df, tf));
    Map<String, double>? w = weights;
    if (w == null) {
      final sw = settings['weights'];
      if (sw is Map) {
        w = {
          for (final e in sw.entries) e.key.toString(): (e.value as num).toDouble()
        };
      }
    }
    final score = computeConfidence(cm, w);
    final minC = settings['min_confidence'] == null ? 0.0 : sd('min_confidence');
    if (score < minC) return StratResult.wait('LOW_CONFIDENCE');
    emitted.add(key);
    while (emitted.length > 300) {
      emitted.remove(emitted.first);
    }
    final last = df.n - 1;
    final sig = StratSignal(
      strategyId: id,
      strategyName: name,
      symbol: symbol,
      direction: direction,
      reason: reason,
      dedupeKey: key,
      tfSec: tf,
      expirySec: expiryFor(tf),
      closeTimeMs: df.t[last] + tf * 1000,
      entryPrice: df.c[last],
      confidence: score,
      details: details,
    );
    return StratResult.emit(sig);
  }
}
