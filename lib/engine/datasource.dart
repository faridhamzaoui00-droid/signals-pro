import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../history_page.dart';
import 'indicators.dart';
import 'strategy.dart';

class Fetch<T> {
  final T? data;
  final String? error;
  const Fetch(this.data, this.error);
}

class DataSource {
  static const _s = FlutterSecureStorage();
  static List<String>? _pairs;
  static const _iv = {
    'M1': '1min',
    'M5': '5min',
    'M15': '15min',
    'M30': '30min',
  };

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
      _pairs = null;
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> deleteKey() async {
    try {
      await _s.delete(key: 'td_key');
    } catch (_) {}
    _pairs = null;
  }

  static Future<Fetch<Map<String, dynamic>>> _get(
      String path, Map<String, String> q) async {
    final k = await key();
    if (k == null) {
      return const Fetch<Map<String, dynamic>>(null, 'na_no_key');
    }
    try {
      final uri = Uri.https('api.twelvedata.com', path, {...q, 'apikey': k});
      final r = await http.get(uri).timeout(const Duration(seconds: 20));
      final m = jsonDecode(r.body);
      if (m is! Map<String, dynamic>) {
        return const Fetch<Map<String, dynamic>>(null, 'na_source_error');
      }
      if (m['status'] == 'error') {
        return Fetch<Map<String, dynamic>>(
            null, m['code'] == 429 ? 'na_limit' : 'na_source_error');
      }
      return Fetch<Map<String, dynamic>>(m, null);
    } catch (_) {
      return const Fetch<Map<String, dynamic>>(null, 'na_net');
    }
  }

  static Future<Fetch<List<String>>> pairs() async {
    if (_pairs != null) return Fetch<List<String>>(_pairs, null);
    final f = await _get('/forex_pairs', {});
    if (f.data == null) return Fetch<List<String>>(null, f.error);
    final d = f.data!['data'];
    if (d is! List) return const Fetch<List<String>>(null, 'na_source_error');
    final out = <String>[];
    for (final e in d) {
      if (e is Map && e['symbol'] is String) out.add(e['symbol'] as String);
    }
    out.sort();
    if (out.isEmpty) return const Fetch<List<String>>(null, 'na_source_error');
    _pairs = out;
    return Fetch<List<String>>(out, null);
  }

  static Future<Fetch<List<Candle>>> candles(
      String sym, String tf, int nowMs,
      {int size = 220}) async {
    final f = await _get('/time_series', {
      'symbol': sym,
      'interval': _iv[tf]!,
      'outputsize': '$size',
      'timezone': 'UTC',
    });
    if (f.data == null) return Fetch<List<Candle>>(null, f.error);
    final v = f.data!['values'];
    if (v is! List || v.isEmpty) {
      return const Fetch<List<Candle>>(null, 'na_source_error');
    }
    final ms = Strategy.tfMs[tf]!;
    final out = <Candle>[];
    for (final e in v) {
      if (e is! Map) continue;
      final raw = '${e['datetime']}'.replaceFirst(' ', 'T');
      final dt = DateTime.tryParse('${raw}Z');
      final o = double.tryParse('${e['open']}');
      final h = double.tryParse('${e['high']}');
      final l = double.tryParse('${e['low']}');
      final c = double.tryParse('${e['close']}');
      if (dt == null || o == null || h == null || l == null || c == null) {
        continue;
      }
      final t = dt.millisecondsSinceEpoch;
      out.add(Candle(t, o, h, l, c, closed: t + ms <= nowMs));
    }
    out.sort((a, b) => a.t.compareTo(b.t));
    return Fetch<List<Candle>>(out, null);
  }

  /// يحسم الصفقات المعلقة بعد انتهاء مدتها: يقارن سعر الإشارة
  /// بسعر افتتاح أول شمعة دقيقة بعد وقت الانتهاء. التعادل أو غياب
  /// البيانات يعني UNVERIFIED وليس خسارة.
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
