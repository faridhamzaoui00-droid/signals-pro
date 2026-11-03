import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../history_page.dart';
import 'indicators.dart';
import 'po_client.dart';

export 'po_client.dart' show Fetch;

class DataSource {
  static const _s = FlutterSecureStorage();

  static const _per = {'M1': 60, 'M5': 300, 'M15': 900, 'M30': 1800};

  // الأسماء المعروضة: "EURUSD OTC" والمعرّف الفعلي: "EURUSD_otc"
  static String _sym(String label) => label.replaceAll(' OTC', '_otc');
  static String _label(String sym) => sym.replaceAll('_otc', ' OTC');

  // مفتاح Twelve Data الاحتياطي (غير مستعمل في التحليل حالياً)
  static Future<String?> key() async {
    try {
      final k = await _s.read(key: 'td_key');
      return (k == null || k.isEmpty) ? null : k;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> hasKey() async => (await key()) != null;

  static Future<bool> saveKey(String v) async {
    try {
      await _s.write(key: 'td_key', value: v);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> deleteKey() async {
    try {
      await _s.delete(key: 'td_key');
    } catch (_) {}
  }

  static Future<Fetch<List<String>>> pairs() async {
    final err = await PoClient.I.connect();
    if (err != null) return Fetch<List<String>>(null, err);
    for (var i = 0; i < 10 && PoClient.I.assets.isEmpty; i++) {
      await Future.delayed(const Duration(milliseconds: 300));
    }
    final out = PoClient.I.assets
        .where((a) => a.open && a.symbol.endsWith('_otc'))
        .map((a) => _label(a.symbol))
        .toList()
      ..sort();
    if (out.isEmpty) return const Fetch<List<String>>(null, 'na_source_error');
    return Fetch<List<String>>(out, null);
  }

  static Future<Fetch<List<Candle>>> candles(String label, String tf, int nowMs,
      {int size = 220}) async {
    final p = _per[tf];
    if (p == null) return const Fetch<List<Candle>>(null, 'na_source_error');
    return PoClient.I.candles(_sym(label), p, count: size);
  }

  /// يحسم الصفقات المعلقة من شموع Pocket Option نفسها بعد انتهاء مدتها.
  /// التعادل أو غياب البيانات = UNVERIFIED وليس خسارة.
  static Future<void> resolvePending() async {
    try {
      final all = await HistoryDb.all();
      final now = DateTime.now().millisecondsSinceEpoch;
      var done = 0;
      for (final r in all) {
        if (done >= 3) break;
        if (r.result != 'PENDING' || r.id == null) continue;
        final secs = int.tryParse(r.duration) ?? 0;
        final end = r.issuedAt + secs * 1000;
        if (now < end + 90000) continue;
        if (r.price == null) {
          await HistoryDb.setResult(r.id!, 'UNVERIFIED', null, null);
          continue;
        }
        done++;
        final f = await candles(r.pair, 'M1', now, size: 300);
        if (f.data == null) continue;
        Candle? hit;
        for (final c in f.data!) {
          if (c.t >= end) {
            hit = c;
            break;
          }
        }
        if (hit == null) {
          if (now - end > 6 * 3600 * 1000) {
            await HistoryDb.setResult(r.id!, 'UNVERIFIED', null, null);
          }
          continue;
        }
        if (hit.t - end > 5 * 60 * 1000 || hit.o == r.price) {
          await HistoryDb.setResult(r.id!, 'UNVERIFIED', hit.t, hit.o);
          continue;
        }
        final up = r.direction == 'UP';
        final win = up ? hit.o > r.price! : hit.o < r.price!;
        await HistoryDb.setResult(r.id!, win ? 'WIN' : 'LOSS', hit.t, hit.o);
      }
    } catch (_) {}
  }
}
