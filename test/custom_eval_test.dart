import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:signals_pro/engine/indicators.dart';
import 'package:signals_pro/ind/cond.dart';
import 'package:signals_pro/ind/custom_eval.dart';

List<Candle> _wave(int n) {
  final out = <Candle>[];
  var prev = 1.1;
  for (var i = 0; i < n; i++) {
    final c = 1.1 + 0.01 * math.sin(i / 5.0) + 0.001 * math.cos(i * 1.7);
    final o = prev;
    out.add(Candle(1700000000000 + i * 60000, o, math.max(o, c) + 0.0002, math.min(o, c) - 0.0002, c));
    prev = c;
  }
  return out;
}

StrategyDef _cross({int period = 5}) => StrategyDef(
      'x',
      [IndUse('sma1', 'sma', {'period': period})],
      Group('AND', [Cond(kind: 'crossUp', left: 'price.close', right: 'sma1.value')]),
      Group('AND', [Cond(kind: 'crossDown', left: 'price.close', right: 'sma1.value')]),
    );

void main() {
  test('لا بيانات مستقبلية: القرار عند الشمعة k لا يتأثر بما بعدها', () {
    final d = _cross();
    final cs = _wave(150);
    final ser = buildSeries(d, candlesToBars(cs));
    var ups = 0, downs = 0;
    for (var k = 10; k < cs.length; k++) {
      final trunc = decide(d, cs.sublist(0, k + 1));
      expect(trunc, evalAt(d, ser, k), reason: 'k=$k');
      if (trunc == 'UP') ups++;
      if (trunc == 'DOWN') downs++;
    }
    expect(ups > 0, true);
    expect(downs > 0, true);
  });

  test('الشمعة غير المغلقة لا تُستعمل أبداً', () {
    final d = _cross();
    final cs = _wave(100);
    final base = decide(d, cs);
    final extra = [...cs, Candle(cs.last.t + 60000, 1.1, 5.0, 0.5, 5.0, closed: false)];
    expect(decide(d, extra), base);
  });

  test('ترتيب عشوائي وتكرار الشموع لا يغيران القرار', () {
    final d = _cross();
    final cs = _wave(100);
    final base = decide(d, cs);
    expect(decide(d, cs.reversed.toList()), base);
    expect(decide(d, [...cs, cs.last, cs[50]]), base);
  });

  test('فجوات في البيانات: لا إشارة (DATA_GAPS)، والبيانات السليمة لا تُرفض', () {
    final d = _cross();
    final cs = _wave(105);
    final gap = [for (var i = 0; i < cs.length; i++) if (i < 60 || i.isEven) cs[i]];
    expect(decide(d, gap, tfSec: 60), 'DATA_GAPS');
    expect(decide(d, cs, tfSec: 60) != 'DATA_GAPS', true);
  });

  test('تعذر الحساب أو نقص الشموع أو فترة التهيئة: لا إشارة', () {
    final bad = StrategyDef('u', [IndUse('q', 'nonexistent')], Group('AND', []), Group('AND', []));
    expect(decide(bad, _wave(50)), 'ERROR');
    expect(decide(_cross(), <Candle>[]), 'NONE');
    expect(decide(_cross(), _wave(1)), 'NONE');
    expect(decide(_cross(period: 50), _wave(20)), 'NONE');
  });

  test('تعارض UP و DOWN يُعلن ولا يصدر إشارة', () {
    final d = StrategyDef(
        'c',
        [],
        Group('AND', [Cond(kind: 'cmp', left: 'price.close', level: 0)]),
        Group('OR', [Cond(kind: 'cmp', left: 'price.close', level: 1)]));
    expect(decide(d, _wave(10)), 'CONFLICT');
  });
}
