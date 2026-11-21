import 'dart:math' as math;
import 'core.dart';

class PsarOut {
  final List<double> sar;
  final List<int> trend; // 1 صاعد، -1 هابط
  final List<bool> flip;
  final double nextSar;
  const PsarOut(this.sar, this.trend, this.flip, this.nextSar);
}

/// Parabolic SAR (ويلدر)، يُحسب من شموع مغلقة فقط.
PsarOut psar(Bars b, double step, double maxAf) {
  final n = b.n;
  final sar = List<double>.filled(n, double.nan);
  final trend = List<int>.filled(n, 0);
  final flip = List<bool>.filled(n, false);
  var up = b.c[1] >= b.c[0];
  var ep = up ? b.h[1] : b.l[1];
  var af = step;
  sar[1] = up ? math.min(b.l[0], b.l[1]) : math.max(b.h[0], b.h[1]);
  trend[1] = up ? 1 : -1;
  for (var i = 2; i < n; i++) {
    var s = sar[i - 1] + af * (ep - sar[i - 1]);
    if (up) {
      s = math.min(s, math.min(b.l[i - 1], b.l[i - 2]));
      if (b.l[i] < s) {
        up = false;
        s = ep;
        ep = b.l[i];
        af = step;
        flip[i] = true;
      } else if (b.h[i] > ep) {
        ep = b.h[i];
        af = math.min(af + step, maxAf);
      }
    } else {
      s = math.max(s, math.max(b.h[i - 1], b.h[i - 2]));
      if (b.h[i] > s) {
        up = true;
        s = ep;
        ep = b.h[i];
        af = step;
        flip[i] = true;
      } else if (b.l[i] < ep) {
        ep = b.l[i];
        af = math.min(af + step, maxAf);
      }
    }
    sar[i] = s;
    trend[i] = up ? 1 : -1;
  }
  var nx = sar[n - 1] + af * (ep - sar[n - 1]);
  nx = trend[n - 1] == 1
      ? math.min(nx, math.min(b.l[n - 1], b.l[n - 2]))
      : math.max(nx, math.max(b.h[n - 1], b.h[n - 2]));
  return PsarOut(sar, trend, flip, nx);
}

/// Parabolic SAR Triple Dot.
/// النقطة 1 عند الانعكاس، النقطة 2 للتحليل (إغلاق شمعتها)، النقطة 3 للدخول (افتتاح الشمعة التالية).
class Strategy6 extends StrategyBase {
  Strategy6([Map<String, dynamic>? o]) : super(_d, o);
  static const Map<String, dynamic> _d = {
    'step': 0.02,
    'max_af': 0.2,
    'atr_period': 14,
    'min_dist_atr': 0.5,
    'flip_lookback': 20,
    'max_flips': 3,
    'min_prev_trend_bars': 4,
    'filter_mode': 'none', // none | ma | rsi
    'ma_period': 20,
    'ma_type': 'ema',
    'rsi_period': 14,
    'rsi_buy_above': 50.0,
    'rsi_sell_below': 50.0,
    'cooldown_bars': null,
    'expiry_seconds': null,
    'min_confidence': 5.0,
    'min_candles': 60,
  };
  @override
  String get id => 'STRATEGY_6';
  @override
  String get name => 'PSAR_TRIPLE_DOT';
  @override
  Map<String, dynamic> freshState() => <String, dynamic>{'cooldown_until': -1};

  @override
  StratResult doEvaluate(Bars df, String symbol, int tf) {
    final st = state(symbol, tf);
    final c = df.c;
    final last = df.n - 1;
    if (last < 4) return StratResult.wait('INSUFFICIENT_DATA');
    final seq = df.seq[last];
    if (seq <= (st['cooldown_until'] as int)) return StratResult.wait('COOLDOWN_AFTER_SIGNAL');
    final ps = psar(df, sd('step'), sd('max_af'));
    final r = last - 1;
    // انعكاس طازج عند الشمعة السابقة والنقطة الثانية على نفس الجهة
    if (!(ps.flip[r] && ps.trend[last] == ps.trend[r])) return StratResult.wait('NO_FRESH_REVERSAL');
    final up = ps.trend[last] == 1;
    final d = up ? 'BUY' : 'SELL';
    final aArr = atrArr(df, si('atr_period'));
    final a = aArr[last];
    if (!(a.isFinite && a > 0)) return StratResult.wait('INDICATORS_NOT_READY');

    final d1 = up ? c[r] - ps.sar[r] : ps.sar[r] - c[r];
    final d2 = up ? c[last] - ps.sar[last] : ps.sar[last] - c[last];
    final progress = up ? c[last] > c[r] : c[last] < c[r];
    if (!(d1 > 0 && d2 > 0 && progress)) return StratResult.wait('CLOSES_NOT_IN_DIRECTION');
    if (d2 < sd('min_dist_atr') * a) return StratResult.wait('DOT_TOO_CLOSE_TO_PRICE');
    if (!(d2 > d1)) return StratResult.wait('DISTANCE_NOT_WIDENING');

    var prevFlip = -1;
    for (var i = r - 1; i >= 1; i--) {
      if (ps.flip[i]) {
        prevFlip = i;
        break;
      }
    }
    final prevBars = prevFlip < 0 ? r : r - prevFlip;
    if (prevBars < si('min_prev_trend_bars')) return StratResult.wait('QUICK_REVERSAL');
    var flips = 0;
    for (var i = math.max(1, last - si('flip_lookback') + 1); i <= last; i++) {
      if (ps.flip[i]) flips++;
    }
    if (flips >= si('max_flips')) return StratResult.wait('SIDEWAYS_MARKET');

    final ma = movingAverage(c, si('ma_period'), ss('ma_type'));
    final rs = rsiArr(c, si('rsi_period'));
    final fm = ss('filter_mode');
    if (fm == 'ma') {
      if (!ma[last].isFinite) return StratResult.wait('INDICATORS_NOT_READY');
      final ok = up ? c[last] > ma[last] : c[last] < ma[last];
      if (!ok) return StratResult.wait('MA_FILTER_BLOCKED');
    } else if (fm == 'rsi') {
      if (!rs[last].isFinite) return StratResult.wait('INDICATORS_NOT_READY');
      final ok = up ? rs[last] > sd('rsi_buy_above') : rs[last] < sd('rsi_sell_below');
      if (!ok) return StratResult.wait('RSI_FILTER_BLOCKED');
    }

    final rv = rs[last].isFinite ? rs[last] : 50.0;
    final sign = up ? 1.0 : -1.0;
    final comps = <String, double>{
      'trend_strength': clip01(0.5 * clip01(prevBars / 8.0) + 0.5 * slopeAlignment(ma, a, d)),
      'zone_strength': clip01(d2 / a / 1.5),
      'candle_confirmation': clip01(0.6 * bodyFraction(df.o[last], df.h[last], df.l[last], c[last]) + 0.4 * clip01((c[last] - c[r]).abs() / a / 0.5)),
      'indicator_agreement': 0.5 * clip01(((rv - 50.0) * sign) / 15.0) + 0.5 * clip01((d2 - d1) / a / 0.3),
    };
    final reason = 'Parabolic SAR ${up ? 'below' : 'above'} price: dot1 after reversal, dot2 confirmed (distance ${(d2 / a).toStringAsFixed(2)} ATR and widening), enter on dot3';
    final res = emit(df, symbol, tf, d, comps, reason, '$d:flip${df.seq[r]}', {
      'dot1': ps.sar[r],
      'dot2': ps.sar[last],
      'dot3': ps.nextSar,
      'dist1_atr': d1 / a,
      'dist2_atr': d2 / a,
      'prev_trend_bars': prevBars,
    });
    if (res.isSignal) {
      final cdv = settings['cooldown_bars'];
      final cd = cdv == null ? math.max(1, (expiryFor(tf) / tf).ceil()) : (cdv as num).toInt();
      st['cooldown_until'] = seq + cd;
    }
    return res;
  }
}
