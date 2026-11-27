import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals_pro/ind/cond.dart';
import 'package:signals_pro/ind/custom_store.dart';

CustomStrategy _mk(String name, {int period = 14, int duration = 60}) => CustomStrategy(
      id: CustomStore.newId(),
      name: name,
      tf: 'M1',
      duration: duration,
      def: StrategyDef(
        name,
        [IndUse('rsi1', 'rsi', {'period': period})],
        Group('AND', [Cond(kind: 'crossUp', left: 'rsi1.value', level: 30)]),
        Group('AND', [Cond(kind: 'crossDown', left: 'rsi1.value', level: 70)]),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('إنشاء ثم قراءة من التخزين (محاكاة إعادة التشغيل بقراءة جديدة)', () async {
    final s = _mk('RSI cross');
    expect(await CustomStore.upsert(s), isEmpty);
    final l = await CustomStore.all();
    expect(l.length, 1);
    expect(l[0].id, s.id);
    expect(l[0].name, 'RSI cross');
    expect(l[0].def.toJsonString(), s.def.toJsonString());
  });

  test('تعديل لا ينشئ نسخة جديدة', () async {
    final s = _mk('A');
    await CustomStore.upsert(s);
    s.name = 'A2';
    s.duration = 300;
    expect(await CustomStore.upsert(s), isEmpty);
    final l = await CustomStore.all();
    expect(l.length, 1);
    expect(l[0].name, 'A2');
    expect(l[0].duration, 300);
  });

  test('استقلال إعدادات استراتيجيتين: RSI 14 و RSI 21', () async {
    final a = _mk('A', period: 14), b = _mk('B', period: 21);
    await CustomStore.upsert(a);
    await CustomStore.upsert(b);
    final l = await CustomStore.all();
    final pa = l.firstWhere((x) => x.id == a.id).def.inds[0].params['period'];
    final pb = l.firstWhere((x) => x.id == b.id).def.inds[0].params['period'];
    expect(pa, 14);
    expect(pb, 21);
  });

  test('حذف', () async {
    final a = _mk('A'), b = _mk('B');
    await CustomStore.upsert(a);
    await CustomStore.upsert(b);
    await CustomStore.delete(a.id);
    final l = await CustomStore.all();
    expect(l.map((x) => x.id).toList(), [b.id]);
  });

  test('نسخ: معرف جديد وموقوفة، وتعديل النسخة لا يمس الأصل', () async {
    final a = _mk('A', period: 14);
    a.enabled = true;
    await CustomStore.upsert(a);
    final c = (await CustomStore.duplicate(a.id))!;
    expect(c.id == a.id, false);
    expect(c.name, 'A (copy)');
    expect(c.enabled, false);
    c.def.inds[0].params['period'] = 50;
    await CustomStore.upsert(c);
    final l = await CustomStore.all();
    expect(l.length, 2);
    expect(l.firstWhere((x) => x.id == a.id).def.inds[0].params['period'], 14);
    expect(l.firstWhere((x) => x.id == c.id).def.inds[0].params['period'], 50);
  });

  test('تشغيل وإيقاف يُحفظان', () async {
    final a = _mk('A');
    await CustomStore.upsert(a);
    expect(await CustomStore.setEnabled(a.id, true), true);
    expect((await CustomStore.all())[0].enabled, true);
    await CustomStore.setEnabled(a.id, false);
    expect((await CustomStore.all())[0].enabled, false);
    expect(await CustomStore.setEnabled('nope', true), false);
  });

  test('التحقق يمنع حفظ الاستراتيجية غير الصالحة', () async {
    final noName = _mk('   ');
    expect((await CustomStore.upsert(noName)).any((e) => e.contains('name')), true);

    final badDur = _mk('D', duration: 7);
    expect((await CustomStore.upsert(badDur)).any((e) => e.contains('duration')), true);

    final noInd = CustomStrategy(
        id: CustomStore.newId(),
        name: 'X',
        def: StrategyDef('X', [IndUse('q', 'nonexistent')], Group('AND', []), Group('AND', [])));
    expect((await CustomStore.upsert(noInd)).any((e) => e.contains('unknown indicator')), true);

    final noRef = CustomStrategy(
        id: CustomStore.newId(),
        name: 'Y',
        def: StrategyDef('Y', [],
            Group('AND', [Cond(kind: 'cmp', left: 'rsi9.value', level: 1)]), Group('AND', [])));
    expect((await CustomStore.upsert(noRef)).any((e) => e.contains('missing')), true);

    final noCond = CustomStrategy(
        id: CustomStore.newId(),
        name: 'Z',
        def: StrategyDef('Z', [IndUse('rsi1', 'rsi')], Group('AND', []), Group('AND', [])));
    expect((await CustomStore.upsert(noCond)).any((e) => e.contains('no entry')), true);

    expect(await CustomStore.all(), isEmpty); // لم يُحفظ شيء
  });

  test('تصدير ثم استيراد بمعرفات جديدة، وتجاهل غير الصالح', () async {
    await CustomStore.upsert(_mk('A'));
    await CustomStore.upsert(_mk('B', period: 21));
    final text = await CustomStore.exportJson();
    final oldIds = (await CustomStore.all()).map((x) => x.id).toSet();

    SharedPreferences.setMockInitialValues({});
    expect(await CustomStore.importJson(text), 2);
    final l = await CustomStore.all();
    expect(l.length, 2);
    expect(l.every((x) => !oldIds.contains(x.id)), true);
    expect(l.every((x) => !x.enabled), true);

    expect(await CustomStore.importJson('not json'), 0);
    expect(await CustomStore.importJson('[{"id":"x"}]'), 0);
    expect((await CustomStore.all()).length, 2);
  });

  test('تخزين تالف لا يعطّل التطبيق', () async {
    SharedPreferences.setMockInitialValues({'custom_strats_v1': 'not json'});
    expect(await CustomStore.all(), isEmpty);
    SharedPreferences.setMockInitialValues({'custom_strats_v1': '[{"bad":1}]'});
    expect(await CustomStore.all(), isEmpty);
  });
}
