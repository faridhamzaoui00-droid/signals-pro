import 'package:flutter_test/flutter_test.dart';
import 'package:signals_pro/ind/cond.dart';
import 'package:signals_pro/strat/core.dart';

Bars _closes(List<double> c) => Bars(
    List<int>.generate(c.length, (i) => 1700000000000 + i * 60000),
    List<double>.from(c), List<double>.from(c), List<double>.from(c), List<double>.from(c),
    List<int>.generate(c.length, (i) => i));

Cond _cmp(String l, String op, double level) => Cond(kind: 'cmp', left: l, level: level, op: op);

void main() {
  final s = <String, List<double>>{
    'x': [1.0, 2.0, 3.0],
    'y': [3.0, 2.0, 1.0],
    'n': [double.nan, 2.0, 3.0],
  };

  test('شرط المقارنة وفترة التهيئة (NaN = غير متحقق)', () {
    expect(evalNode(_cmp('x', '>', 2), s, 2), true);
    expect(evalNode(_cmp('x', '>', 2), s, 1), false);
    expect(evalNode(_cmp('x', '>=', 2), s, 1), true);
    expect(evalNode(_cmp('y', '<', 2), s, 2), true);
    expect(evalNode(_cmp('n', '<', 100), s, 0), false); // NaN
    expect(evalNode(_cmp('zzz', '>', 0), s, 1), false); // مرجع ناقص
  });

  test('التقاطع بين سلسلتين وبمستوى', () {
    final up = Cond(kind: 'crossUp', left: 'x', right: 'y');
    final dn = Cond(kind: 'crossDown', left: 'x', right: 'y');
    final xs = {'x': [1.0, 2.0, 3.0, 2.0, 1.0], 'y': [2.0, 2.0, 2.0, 2.0, 2.0]};
    expect(evalNode(up, xs, 2), true);
    expect(evalNode(up, xs, 1), false);
    expect(evalNode(dn, xs, 4), true);
    expect(evalNode(Cond(kind: 'crossUp', left: 'x', level: 2.5), xs, 2), true);
    expect(evalNode(Cond(kind: 'crossDown', left: 'x', level: 1.5), xs, 4), true);
  });

  test('AND / OR / مجموعات متداخلة', () {
    final c1 = _cmp('x', '>', 2); // عند 2: صحيح
    final c2 = _cmp('y', '>', 2); // عند 2: خاطئ
    expect(evalNode(Group('AND', [c1, c2]), s, 2), false);
    expect(evalNode(Group('OR', [c1, c2]), s, 2), true);
    expect(evalNode(Group('OR', [Group('AND', [c1, c2]), c1]), s, 2), true);
    expect(evalNode(Group('AND', [Group('OR', [c1, c2]), c2]), s, 2), false);
    expect(evalNode(Group('AND', [Group('OR', [c1, c2]), Group('OR', [c1])]), s, 2), true);
    expect(evalNode(Group('AND', []), s, 2), false); // فارغة لا تصدر إشارة
    expect(evalNode(Group('OR', []), s, 2), false);
  });

  test('استراتيجية كاملة: السعر يعبر SMA3 صعوداً => UP، ولا DOWN', () {
    final d = StrategyDef(
      'test',
      [IndUse('sma1', 'sma', {'period': 3})],
      Group('AND', [Cond(kind: 'crossUp', left: 'price.close', right: 'sma1.value')]),
      Group('AND', [Cond(kind: 'crossDown', left: 'price.close', right: 'sma1.value')]),
    );
    final b = _closes([10, 10, 10, 10, 9, 12]);
    expect(evalStrategy(d, b), 'UP');
    // عند الشمعة 4 السعر تحت المتوسط وليس هناك تقاطع جديد
    expect(evalAt(d, buildSeries(d, b), 3), 'NONE');
    // قبل اكتمال فترة التهيئة لا إشارة
    expect(evalAt(d, buildSeries(d, b), 1), 'NONE');
  });

  test('تعارض UP و DOWN: لا إشارة ويُعلن التعارض', () {
    final d = StrategyDef('conflict', [],
        Group('AND', [_cmp('price.close', '>', 0)]),
        Group('OR', [_cmp('price.close', '>', 1)]));
    expect(evalStrategy(d, _closes([5, 6, 7])), 'CONFLICT');
  });

  test('استقلال إعدادات نسختين من المؤشر نفسه في استراتيجية واحدة', () {
    final d = StrategyDef('two', [
      IndUse('sma_fast', 'sma', {'period': 2}),
      IndUse('sma_slow', 'sma', {'period': 4}),
    ], Group('AND', []), Group('AND', []));
    final ser = buildSeries(d, _closes([1, 2, 3, 4, 5, 6]));
    expect(ser['sma_fast.value']![5], closeTo(5.5, 1e-12));
    expect(ser['sma_slow.value']![5], closeTo(4.5, 1e-12));
  });

  test('التحقق: مراجع ناقصة ومفاتيح مكررة ومؤشر غير موجود', () {
    final d = StrategyDef('bad', [IndUse('a', 'sma'), IndUse('a', 'ema')],
        Group('AND', [_cmp('nope.value', '>', 1)]), Group('AND', []));
    final ser = buildSeries(StrategyDef('x', [IndUse('a', 'sma')], Group('AND', []), Group('AND', [])),
        _closes([1, 2, 3]));
    final errs = validateStrategy(d, ser);
    expect(errs.any((e) => e.contains('duplicate')), true);
    expect(errs.any((e) => e.contains('missing nope.value')), true);
    expect(() => buildSeries(StrategyDef('u', [IndUse('q', 'nonexistent')], Group('AND', []), Group('AND', [])), _closes([1, 2])),
        throwsArgumentError);
  });

  test('JSON: حفظ واستعادة يعطيان الشجرة نفسها، وشرط غير صالح يُرفض', () {
    final d = StrategyDef('roundtrip', [
      IndUse('rsi1', 'rsi', {'period': 14}),
      IndUse('macd1', 'macd', {'fast': 12, 'slow': 26, 'signal': 9}),
    ],
        Group('OR', [
          Group('AND', [
            Cond(kind: 'crossUp', left: 'rsi1.value', level: 30),
            Cond(kind: 'crossUp', left: 'macd1.macd', right: 'macd1.signal'),
          ]),
          Group('AND', [_cmp('price.close', '>', 1.1)]),
        ]),
        Group('AND', [Cond(kind: 'crossDown', left: 'rsi1.value', level: 70)]));
    final back = StrategyDef.fromJsonString(d.toJsonString());
    expect(back.toJsonString(), d.toJsonString());
    expect(() => Cond(kind: 'cmp', left: 'x'), throwsFormatException); // لا right ولا level
    expect(() => Cond(kind: 'cmp', left: 'x', right: 'y', level: 1), throwsFormatException);
    expect(() => Cond(kind: 'weird', left: 'x', level: 1), throwsFormatException);
    expect(() => Group('XOR'), throwsFormatException);
  });
}
