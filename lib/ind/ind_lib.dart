// مكتبة المؤشرات (المرحلة 2): كل مؤشر بمعرّف وإعدادات مستقلة ودالة حساب.
// كل الحسابات على شموع مغلقة فقط، والقيمة NaN قبل اكتمال فترة التهيئة.
import 'dart:math' as math;
import '../strat/core.dart';

typedef IndCalc = Map<String, List<double>> Function(Bars b, Map<String, num> p);

class IndDef {
  final String id, name, category, desc;
  final Map<String, num> params; // الإعدادات الافتراضية (كل استراتيجية تحمل نسختها)
  final IndCalc calc;
  IndDef(this.id, this.name, this.category, this.desc, this.params, this.calc);
}

// ---------------- التقاطعات (بلا بيانات مستقبلية: تقارن الشمعة i و i-1 فقط) ----------------
bool _f(double v) => v.isFinite;

bool crossUp(List<double> a, List<double> b, int i) =>
    i >= 1 && _f(a[i - 1]) && _f(b[i - 1]) && _f(a[i]) && _f(b[i]) && a[i - 1] <= b[i - 1] && a[i] > b[i];

bool crossDown(List<double> a, List<double> b, int i) =>
    i >= 1 && _f(a[i - 1]) && _f(b[i - 1]) && _f(a[i]) && _f(b[i]) && a[i - 1] >= b[i - 1] && a[i] < b[i];

bool crossAboveLevel(List<double> a, double level, int i) =>
    i >= 1 && _f(a[i - 1]) && _f(a[i]) && a[i - 1] <= level && a[i] > level;

bool crossBelowLevel(List<double> a, double level, int i) =>
    i >= 1 && _f(a[i - 1]) && _f(a[i]) && a[i - 1] >= level && a[i] < level;

// ---------------- الحسابات ----------------
List<double> wma(List<double> x, int p) {
  final n = x.length;
  final out = List<double>.filled(n, double.nan);
  final den = p * (p + 1) / 2.0;
  for (var i = p - 1; i < n; i++) {
    var s = 0.0;
    var ok = true;
    for (var k = 0; k < p; k++) {
      final v = x[i - p + 1 + k];
      if (v.isNaN) {
        ok = false;
        break;
      }
      s += v * (k + 1);
    }
    if (ok) out[i] = s / den;
  }
  return out;
}

Map<String, List<double>> macdCalc(List<double> c, int fast, int slow, int signal) {
  final f = ema(c, fast), s = ema(c, slow);
  final m = List<double>.generate(c.length, (i) => f[i] - s[i]);
  final sg = ema(m, signal);
  final h = List<double>.generate(c.length, (i) => m[i] - sg[i]);
  return {'macd': m, 'signal': sg, 'hist': h};
}

/// بولينجر: الانحراف المعياري للمجتمع (القسمة على الفترة)، كما في TradingView.
Map<String, List<double>> bollingerCalc(List<double> c, int period, double dev) {
  final n = c.length;
  List<double> nan() => List<double>.filled(n, double.nan);
  final mid = nan(), up = nan(), lo = nan(), pctb = nan(), bw = nan();
  for (var i = period - 1; i < n; i++) {
    var s = 0.0;
    var ok = true;
    for (var k = 0; k < period; k++) {
      final v = c[i - period + 1 + k];
      if (v.isNaN) {
        ok = false;
        break;
      }
      s += v;
    }
    if (!ok) continue;
    final m = s / period;
    var q = 0.0;
    for (var k = 0; k < period; k++) {
      final d = c[i - period + 1 + k] - m;
      q += d * d;
    }
    final sd = math.sqrt(q / period);
    mid[i] = m;
    up[i] = m + dev * sd;
    lo[i] = m - dev * sd;
    final w = up[i] - lo[i];
    pctb[i] = w == 0.0 ? double.nan : (c[i] - lo[i]) / w;
    bw[i] = m == 0.0 ? double.nan : w / m;
  }
  return {'mid': mid, 'upper': up, 'lower': lo, 'pctb': pctb, 'bw': bw};
}

/// ستوكاستيك: %K الخام، و%D متوسط بسيط. عند تساوي أعلى وأدنى سعر لا توجد قيمة (NaN).
Map<String, List<double>> stochasticCalc(Bars b, int kP, int dP) {
  final n = b.n;
  final k = List<double>.filled(n, double.nan);
  for (var i = kP - 1; i < n; i++) {
    var hh = b.h[i], ll = b.l[i];
    for (var j = i - kP + 1; j < i; j++) {
      if (b.h[j] > hh) hh = b.h[j];
      if (b.l[j] < ll) ll = b.l[j];
    }
    final den = hh - ll;
    k[i] = den == 0.0 ? double.nan : 100.0 * (b.c[i] - ll) / den;
  }
  return {'k': k, 'd': sma(k, dP)};
}

int _i(Map<String, num> p, String k, num d) => (p[k] ?? d).toInt();
double _d(Map<String, num> p, String k, num d) => (p[k] ?? d).toDouble();

// ---------------- السجل ----------------
// لا يُضاف مؤشر هنا إلا بعد تنفيذ معادلته واختباره بقيم مرجعية.
final List<IndDef> kIndicatorLib = <IndDef>[
  IndDef('sma', 'SMA', 'trend', 'Simple moving average', {'period': 20},
      (b, p) => {'value': sma(b.c, _i(p, 'period', 20))}),
  IndDef('ema', 'EMA', 'trend', 'Exponential moving average', {'period': 20},
      (b, p) => {'value': ema(b.c, _i(p, 'period', 20))}),
  IndDef('wma', 'WMA', 'trend', 'Weighted moving average', {'period': 20},
      (b, p) => {'value': wma(b.c, _i(p, 'period', 20))}),
  IndDef('rsi', 'RSI', 'momentum', 'Relative strength index (Wilder)',
      {'period': 14, 'overbought': 70, 'oversold': 30},
      (b, p) => {'value': rsiArr(b.c, _i(p, 'period', 14))}),
  IndDef('macd', 'MACD', 'momentum', 'Moving average convergence divergence',
      {'fast': 12, 'slow': 26, 'signal': 9},
      (b, p) => macdCalc(b.c, _i(p, 'fast', 12), _i(p, 'slow', 26), _i(p, 'signal', 9))),
  IndDef('stochastic', 'Stochastic', 'momentum', 'Stochastic oscillator %K/%D',
      {'k': 14, 'd': 3, 'overbought': 80, 'oversold': 20},
      (b, p) => stochasticCalc(b, _i(p, 'k', 14), _i(p, 'd', 3))),
  IndDef('bollinger', 'Bollinger Bands', 'volatility', 'Bands, %B and bandwidth',
      {'period': 20, 'dev': 2},
      (b, p) => bollingerCalc(b.c, _i(p, 'period', 20), _d(p, 'dev', 2))),
  IndDef('atr', 'ATR', 'volatility', 'Average true range (Wilder)', {'period': 14},
      (b, p) => {'value': atrArr(b, _i(p, 'period', 14))}),
];
