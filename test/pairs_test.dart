import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals_pro/pairs.dart';
import 'package:signals_pro/selection_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('قائمة الأزواج', () {
    test('60 زوجاً بلا تكرار', () {
      expect(kPocketOptionPairs.length, 60);
      expect(kPocketOptionPairs.toSet().length, 60);
    });

    test('العادي وOTC أداتان منفصلتان', () {
      for (final p in ['EUR/USD', 'USD/JPY', 'USD/CHF', 'AUD/CAD', 'EUR/CHF', 'CAD/CHF', 'AUD/USD', 'EUR/JPY', 'CHF/JPY', 'USD/CAD']) {
        expect(kPocketOptionPairs.contains(p), true, reason: p);
        expect(kPocketOptionPairs.contains('$p OTC'), true, reason: '$p OTC');
      }
      expect(poSymbolOf('EUR/USD'), 'EURUSD');
      expect(poSymbolOf('EUR/USD OTC'), 'EURUSD_otc');
      expect(poSymbolOf('EUR/USD') == poSymbolOf('EUR/USD OTC'), false);
    });

    test('كل زوج في القائمة قابل للاختيار (يعيد نفسه كاسم معتمد)', () {
      for (final p in kPocketOptionPairs) {
        expect(canonicalPair(p), p);
      }
    });

    test('الأزواج القديمة المحذوفة لا تظهر', () {
      expect(canonicalPair('GBP/USD OTC'), null);
      expect(canonicalPair('GBPUSD OTC'), null);
      expect(kPocketOptionPairs.contains('GBP/USD OTC'), false);
    });

    test('البحث يعمل بدون شرطة وبدون حساسية للأحرف', () {
      final r = filterPairs('eurusd');
      expect(r.toSet(), {'EUR/USD', 'EUR/USD OTC'});
      expect(filterPairs('ngn'), ['NGN/USD OTC']);
      expect(filterPairs('otc').every((p) => p.endsWith(' OTC')), true);
      expect(filterPairs('').length, 60);
      expect(filterPairs('zzzz'), isEmpty);
    });

    test('ترحيل القائمة المحفوظة: صيغة قديمة تتحول، والمجهول يُحذف، بلا تكرار', () {
      expect(migratePairs(['EURUSD OTC', 'EUR/USD OTC', 'GBPUSD OTC', 'USDJPY']),
          ['EUR/USD OTC', 'USD/JPY']);
    });
  });

  group('حفظ الاختيارات', () {
    test('الزوج والمدة يُحفظان ويُستعادان', () async {
      SharedPreferences.setMockInitialValues({});
      await SelectionStore.savePair('EUR/USD OTC');
      await SelectionStore.saveDuration(300);
      final s = await SelectionStore.load();
      expect(s.pair, 'EUR/USD OTC');
      expect(s.duration, 300);
    });

    test('10 قراءات متتالية (بدل 10 تحليلات) لا تغيّر الاختيار', () async {
      SharedPreferences.setMockInitialValues({});
      await SelectionStore.savePair('USD/JPY');
      await SelectionStore.saveDuration(120);
      for (var i = 0; i < 10; i++) {
        final s = await SelectionStore.load();
        expect(s.pair, 'USD/JPY');
        expect(s.duration, 120);
      }
    });

    test('بدء نظيف: لا اختيار محفوظ', () async {
      SharedPreferences.setMockInitialValues({});
      final s = await SelectionStore.load();
      expect(s.pair, null);
      expect(s.duration, null);
    });

    test('قيم قديمة أو غير صالحة تُتجاهل ولا تعطل التطبيق', () async {
      SharedPreferences.setMockInitialValues({'sel_pair': 'GBP/USD OTC', 'sel_duration': 77});
      final s = await SelectionStore.load();
      expect(s.pair, null);
      expect(s.duration, null);
    });

    test('تغيير يدوي يستبدل القيمة السابقة فقط', () async {
      SharedPreferences.setMockInitialValues({});
      await SelectionStore.savePair('EUR/USD OTC');
      await SelectionStore.savePair('AUD/CAD');
      await SelectionStore.saveDuration(300);
      await SelectionStore.saveDuration(60);
      final s = await SelectionStore.load();
      expect(s.pair, 'AUD/CAD');
      expect(s.duration, 60);
    });
  });
}
