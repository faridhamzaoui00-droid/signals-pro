// المشغّل الحي للاستراتيجيات المخصصة (يعمل والتطبيق مفتوح).
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../engine/cfg.dart';
import '../engine/datasource.dart';
import '../engine/monitor.dart';
import '../engine/notify.dart';
import '../engine/po_client.dart';
import '../history_page.dart';
import '../l10n.dart';
import '../pairs.dart';
import 'custom_eval.dart';
import 'custom_store.dart';

String _t(String ar, String fr, String en) {
  final l = langNotifier.value;
  return l == 'ar' ? ar : (l == 'fr' ? fr : en);
}

class CustomRunner {
  static final CustomRunner I = CustomRunner._();
  CustomRunner._();

  final ValueNotifier<int> changed = ValueNotifier<int>(0);
  List<CustomStrategy> list = <CustomStrategy>[];
  final Map<String, String> status = {};
  final Map<String, int> _lastB = {}, _lastT = {}, _cool = {}, _tries = {};
  final Set<String> _busy = {};
  Timer? _timer;
  bool _loaded = false;
  int _nid = 7000;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    await Cfg.load();
    await reload();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  /// يُستدعى بعد أي إنشاء أو تعديل أو حذف أو تشغيل.
  Future<void> reload() async {
    list = await CustomStore.all();
    final ids = list.map((s) => s.id).toSet();
    for (final m in [_lastB, _lastT, _cool, _tries]) {
      m.removeWhere((k, v) => !ids.contains(k.split('|').first));
    }
    status.removeWhere((k, v) => !ids.contains(k.split('|').first));
    changed.value++;
  }

  /// بعد تعديل استراتيجية: تبدأ حالتها من جديد.
  void reset(String id) {
    for (final m in [_lastB, _lastT, _cool, _tries]) {
      m.removeWhere((k, v) => k.startsWith('$id|'));
    }
    status.removeWhere((k, v) => k.startsWith('$id|'));
  }

  List<String> pairsFor(CustomStrategy s) {
    final src = s.pairs.isNotEmpty ? s.pairs : Monitor.I.pairs;
    return src.length > 5 ? src.sublist(0, 5) : List<String>.from(src);
  }

  String statusFor(String id) {
    final xs = [
      for (final e in status.entries)
        if (e.key.startsWith('$id|')) '${e.key.substring(id.length + 1)}: ${e.value}'
    ];
    return xs.join('\n');
  }

  void _tick() {
    if (!list.any((s) => s.enabled)) return;
    final off = PoClient.I.offsetMs;
    final sNow = DateTime.now().millisecondsSinceEpoch + off;
    for (final s in list) {
      if (!s.enabled) continue;
      final tfMs = Cfg.tfSeconds(s.tf) * 1000;
      if (tfMs <= 0) continue;
      final b = sNow ~/ tfMs * tfMs;
      final delay = tfMs >= 60000 ? 3000 : 1500;
      if (sNow - b < delay) continue;
      for (final pair in pairsFor(s)) {
        final key = '${s.id}|$pair';
        if (_busy.contains(key)) continue;
        if ((_lastB[key] ?? 0) >= b) continue;
        _busy.add(key);
        _run(s, pair, b, key);
      }
    }
  }

  Future<void> _run(CustomStrategy s, String pair, int b, String key) async {
    try {
      final ok = await _process(s, pair, b, key);
      if (ok) {
        _lastB[key] = b;
        _tries[key] = 0;
      } else {
        final t = (_tries[key] ?? 0) + 1;
        _tries[key] = t;
        if (t >= 4) {
          _lastB[key] = b;
          _tries[key] = 0;
        }
      }
    } catch (_) {
      _lastB[key] = b;
    } finally {
      _busy.remove(key);
      changed.value++;
    }
  }

  Future<bool> _process(CustomStrategy s, String pair, int bServer, String key) async {
    final tfSec = Cfg.tfSeconds(s.tf);
    final tfMs = tfSec * 1000;
    final f = await DataSource.candles(pair, s.tf, 0, size: 220);
    if (f.data == null) {
      status[key] = 'N/A ${f.error ?? ''}';
      return false;
    }
    var lastClosed = -1;
    var closedCount = 0;
    for (final x in f.data!) {
      if (x.closed) {
        closedCount++;
        if (x.t > lastClosed) lastClosed = x.t;
      }
    }
    if (closedCount < 30) {
      status[key] = _t('بيانات غير كافية', 'Données insuffisantes', 'Not enough data');
      return false;
    }
    final expected = bServer - tfMs - PoClient.I.offsetMs;
    if (lastClosed < expected - 2000) {
      status[key] = _t('بيانات قديمة', 'Données anciennes', 'Stale data');
      return false;
    }
    if ((_lastT[key] ?? -1) >= lastClosed) return true; // هذه الشمعة قُيّمت
    final r = decide(s.def, f.data!, tfSec: tfSec);
    _lastT[key] = lastClosed;
    status[key] = r;
    if (r != 'UP' && r != 'DOWN') return true;
    if (lastClosed < (_cool[key] ?? -1)) {
      status[key] = 'COOLDOWN';
      return true;
    }
    final cd = (s.duration * 1000 / tfMs).ceil();
    final emitted = await _emit(s, pair, r, f.data!);
    if (emitted) _cool[key] = lastClosed + (cd < 1 ? 1 : cd) * tfMs;
    return true;
  }

  Future<bool> _emit(CustomStrategy s, String pair, String dir, List<dynamic> candles) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    var hist = <SignalRecord>[];
    try {
      hist = await HistoryDb.all();
    } catch (_) {}
    final tag = '[STRAT:C_${s.id}]'; // يبدأ بـ [STRAT: فيُستثنى من نسبة نجاح الاستراتيجية الحالية
    final dup = hist.any((h) =>
        h.pair == pair && h.result == 'PENDING' && h.indicators.contains(tag) && (h.endAt ?? 0) > now);
    if (dup) {
      status['${s.id}|$pair'] = 'DUPLICATE';
      return false;
    }
    double price = 0;
    var bestT = -1;
    for (final x in candles) {
      if (x.closed && x.t > bestT) {
        bestT = x.t;
        price = x.c;
      }
    }
    final off = PoClient.I.offsetMs;
    final sNow = now + off;
    final step = s.duration >= 60 ? 60000 : 5000;
    final entryMs = ((sNow ~/ step) + 1) * step - off;
    final expiryMs = entryMs + s.duration * 1000;
    final up = dir == 'UP';
    final rec = SignalRecord(
      pair: pair,
      market: isOtcPair(pair) ? 'OTC' : 'REG',
      direction: dir,
      duration: '${s.duration}',
      indicators: '[AUTO]$tag ${s.tf} | ${s.name}',
      reasons: s.name,
      issuedAt: now,
      price: price,
      score: 0, // لا توجد درجة تقييم للمخصصة (لم تُخترع)
      endAt: expiryMs,
    );
    try {
      await HistoryDb.insert(rec);
    } catch (_) {}
    Monitor.I.changed.value++;
    final title = '${up ? '▲ UP' : '▼ DOWN'}  $pair • ${s.name}';
    final body =
        '${_t('الدخول', 'Entrée', 'Entry')} ${_hm(entryMs)}  •  ${_t('الانتهاء', 'Expiration', 'Expiry')} ${_hm(expiryMs)}  •  ${durText(s.duration)}';
    await Notifier.show(_nid++, title, body);
    return true;
  }

  String _hm(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    String t(int v) => v.toString().padLeft(2, '0');
    return '${t(d.hour)}:${t(d.minute)}:${t(d.second)}';
  }
}
