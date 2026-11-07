import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../history_page.dart';
import 'indicators.dart';
import 'po_client.dart';

export 'po_client.dart' show Fetch;

typedef ResolvedCb = void Function(
    SignalRecord rec, String result, double? entry, double? exit);

class DataSource {
  static const _s = FlutterSecureStorage();
  static const _per = {
    'M1': 60,
    'M2': 120,
    'M3': 180,
    'M5': 300,
    'M10': 600,
    'M15': 900,
    'M30': 1800,
  };

  static String _sym(String label) => label.replaceAll(' OTC', '_otc');
  static String _label(String sym) => sym.replaceAll('_otc', ' OTC');

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

  // ---------- حسم الصفقات ----------
  static final Set<int> _busy = <int>{};
  static final Map<int, int> _nextTry = <int, int>{};
  static bool _running = false;

  static int _endOf(SignalRecord r) {
    final secs = int.tryParse(r.duration) ?? 0;
    final auto = r.indicators.startsWith('[AUTO]');
    return auto
        ? (r.endAt ?? r.issuedAt + secs * 1000)
        : r.issuedAt + secs * 1000;
  }

  static void _retry(int id, int age) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final wait = age < 30000 ? 1500 : (age < 300000 ? 5000 : 30000);
    _nextTry[id] = now + wait;
  }

  static Future<void> resolvePending() => resolveDue();

  /// يحسم كل صفقة انتهت مدتها منذ ثانيتين أو أكثر من شموع Pocket Option.
  static Future<void> resolveDue({ResolvedCb? onResolved}) async {
    if (_running) return;
    _running = true;
    try {
      final all = await HistoryDb.all();
      final now = DateTime.now().millisecondsSinceEpoch;
      final due = <SignalRecord>[];
      for (final r in all) {
        if (r.result != 'PENDING' || r.id == null) continue;
        if (now < _endOf(r) + 2000) continue;
        if (now < (_nextTry[r.id!] ?? 0)) continue;
        due.add(r);
      }
      due.sort((a, b) => _endOf(a).compareTo(_endOf(b)));
      for (final r in due.take(8)) {
        await _resolveOne(r, onResolved);
      }
    } catch (_) {
    } finally {
      _running = false;
    }
  }

  static Future<void> _resolveOne(SignalRecord r, ResolvedCb? cb) async {
    final id = r.id!;
    if (!_busy.add(id)) return;
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final auto = r.indicators.startsWith('[AUTO]');
      final secs = int.tryParse(r.duration) ?? 0;
      final end = _endOf(r);
      final entryMs = end - secs * 1000;
      final age = now - end;
      var size = age ~/ 60000 + 10;
      if (size < 20) size = 20;
      if (size > 900) size = 900;

      final f = await candles(r.pair, 'M1', now, size: size);
      if (f.data == null) {
        if (age > 6 * 3600 * 1000) {
          await HistoryDb.setResult(id, 'UNVERIFIED', null, null);
          cb?.call(r, 'UNVERIFIED', null, null);
        } else {
          _retry(id, age);
        }
        return;
      }
      Candle? ent;
      Candle? atEnd;
      Candle? before;
      for (final c in f.data!) {
        if ((c.t - entryMs).abs() <= 5000) ent = c;
        if ((c.t - end).abs() <= 5000) atEnd = c;
        if ((c.t - (end - 60000)).abs() <= 5000) before = c;
      }
      final double? entryPrice = auto ? ent?.o : r.price;
      double? exitPrice;
      int? exitT;
      if (atEnd != null) {
        exitPrice = atEnd.o;
        exitT = atEnd.t;
      } else if (before != null && before.closed) {
        exitPrice = before.c;
        exitT = before.t + 60000;
      }
      if (entryPrice == null || exitPrice == null) {
        if (age > 6 * 3600 * 1000) {
          await HistoryDb.setResult(id, 'UNVERIFIED', null, null);
          cb?.call(r, 'UNVERIFIED', entryPrice, exitPrice);
        } else {
          _retry(id, age);
        }
        return;
      }
      if (exitPrice == entryPrice) {
        await HistoryDb.setResult(id, 'UNVERIFIED', exitT, exitPrice);
        cb?.call(r, 'UNVERIFIED', entryPrice, exitPrice);
        return;
      }
      final up = r.direction == 'UP';
      final win = up ? exitPrice > entryPrice : exitPrice < entryPrice;
      final res = win ? 'WIN' : 'LOSS';
      await HistoryDb.setResult(id, res, exitT, exitPrice);
      cb?.call(r, res, entryPrice, exitPrice);
    } catch (_) {
    } finally {
      _busy.remove(id);
    }
  }
}
