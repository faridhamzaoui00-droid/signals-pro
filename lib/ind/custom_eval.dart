// المنطق النقي لقرار الاستراتيجية المخصصة. شموع مغلقة فقط، ولا بيانات مستقبلية.
import '../engine/indicators.dart' show Candle;
import '../strat/core.dart';
import 'cond.dart';

/// يحوّل الشموع إلى Bars: يحذف غير المغلقة والمكررة، ويرتب بالزمن، ويأخذ آخر maxBars.
Bars candlesToBars(List<Candle> candles, {int maxBars = 300}) {
  final cl = candles.where((x) => x.closed).toList()..sort((a, b) => a.t.compareTo(b.t));
  final u = <Candle>[];
  for (final x in cl) {
    if (u.isEmpty || x.t > u.last.t) u.add(x);
  }
  final s = u.length > maxBars ? u.length - maxBars : 0;
  final n = u.length - s;
  final t = List<int>.filled(n, 0);
  final o = List<double>.filled(n, 0), h = List<double>.filled(n, 0);
  final l = List<double>.filled(n, 0), cc = List<double>.filled(n, 0);
  final q = List<int>.filled(n, 0);
  for (var i = 0; i < n; i++) {
    final x = u[s + i];
    t[i] = x.t;
    o[i] = x.o;
    h[i] = x.h;
    l[i] = x.l;
    cc[i] = x.c;
    q[i] = s + i;
  }
  return Bars(t, o, h, l, cc, q);
}

/// القرار عند آخر شمعة مغلقة: UP | DOWN | NONE | CONFLICT | DATA_GAPS | ERROR.
/// ERROR عند تعذر حساب مؤشر (لا إشارة مبنية على حساب ناقص).
String decide(StrategyDef d, List<Candle> candles, {int? tfSec}) {
  try {
    final b = candlesToBars(candles);
    if (b.n < 2) return 'NONE';
    if (tfSec != null && gapQuality(b, tfSec) < 0.9) return 'DATA_GAPS';
    return evalStrategy(d, b);
  } catch (_) {
    return 'ERROR';
  }
}
