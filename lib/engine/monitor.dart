import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../history_page.dart';
import '../l10n.dart';
import '../l10n2.dart';
import 'datasource.dart';
import 'indicators.dart';
import 'notify.dart';
import 'po_client.dart';
import 'po_probe.dart';
import 'strategy.dart';

String _hm(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  String t(int v) => v.toString().padLeft(2, '0');
  return '${t(d.hour)}:${t(d.minute)}:${t(d.second)}';
}

String _arr(int? v) => v == 1 ? '↑' : (v == -1 ? '↓' : '–');

class Monitor {
  static final Monitor I = Monitor._();
  Monitor._();

  final ValueNotifier<bool> running = ValueNotifier<bool>(false);
  final ValueNotifier<List<String>> lines =
      ValueNotifier<List<String>>(<String>[]);
  final ValueNotifier<int> changed = ValueNotifier<int>(0);

  List<String> pairs = <String>[];
  int duration = 300;
  int lead = 60; // 60 = الدخول بعد دقيقة من الإشارة، 0 = الشمعة التالية فوراً
  DateTime? lastCycle;

  Timer? _timer;
  int _lastBoundary = 0;
  int _nid = 1000;
  bool _busy = false;
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final p = await SharedPreferences.getInstance();
    pairs = p.getStringList('mon_pairs') ?? <String>[];
    duration = p.getInt('mon_dur') ?? 300;
    lead = p.getInt('mon_lead') ?? 60;
    await Notifier.init();
    if (p.getBool('mon_on') ?? false) await start();
  }

  Future<void> _save({bool? on}) async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList('mon_pairs', pairs);
    await p.setInt('mon_dur', duration);
    await p.setInt('mon_lead', lead);
    if (on != null) await p.setBool('mon_on', on);
  }

  Future<void> setConfig(
      {List<String>? newPairs, int? newDuration, int? newLead}) async {
    if (newPairs != null) pairs = newPairs;
    if (newDuration != null) duration = newDuration;
    if (newLead != null) lead = newLead;
    await _save();
    if (running.value) {
      await FgService.stop();
      await FgService.start(pairs.length);
    }
    changed.value++;
  }

  Future<String?> start() async {
    if (pairs.isEmpty) return 'nt_need_pair';
    if (!await PoProbe.has()) return 'nt_need_key';
    if (running.value) return null;
    running.value = true;
    await _save(on: true);
    PoClient.I.connect();
    final sNow = DateTime.now().millisecondsSinceEpoch + PoClient.I.offsetMs;
    _lastBoundary = sNow ~/ 60000 * 60000;
    await FgService.start(pairs.length);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    lines.value = [
      '${_hm(DateTime.now().millisecondsSinceEpoch)}  ▶ ${t2('nt_running')}'
    ];
    return null;
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    running.value = false;
    await _save(on: false);
    await FgService.stop();
  }

  void _onTick() {
    if (_busy || !running.value) return;
    final sNow = DateTime.now().millisecondsSinceEpoch + PoClient.I.offsetMs;
    final b = sNow ~/ 60000 * 60000;
    if (b <= _lastBoundary || sNow - b < 3000) return;
    _lastBoundary = b;
    _busy = true;
    _cycle(b).whenComplete(() => _busy = false);
  }

  Future<void> _cycle(int b) async {
    try {
      final tfs = Strategy.tfsFor(duration);
      if (tfs.isEmpty) {
        lines.value = [t2('na_duration')];
        return;
      }
      final tfMs = Strategy.tfMs[tfs.first]!;
      if (b % tfMs != 0) return;
      lastCycle = DateTime.now();
      var hist = <SignalRecord>[];
      try {
        hist = await HistoryDb.all();
      } catch (_) {}
      final out = <String>[
        '${_hm(DateTime.now().millisecondsSinceEpoch)}  ${tfs.first} → ${durText(duration)}'
      ];
      for (final pair in List<String>.from(pairs)) {
        if (!running.value) break;
        out.add(await _analyzePair(pair, tfs, b, tfMs, hist));
        lines.value = List<String>.from(out);
      }
      lines.value = List<String>.from(out);
    } catch (_) {}
  }

  Future<String> _analyzePair(String pair, List<String> tfs, int b, int tfMs,
      List<SignalRecord> hist) async {
    final data = <String, List<Candle>>{};
    for (final tf in tfs) {
      var f = await DataSource.candles(pair, tf, 0, size: 220);
      if (tf == tfs.first && f.data != null) {
        final expected = b - tfMs - PoClient.I.offsetMs;
        var fresh = false;
        for (var i = 0; i < 4; i++) {
          final cl = f.data!.where((c) => c.closed).toList();
          if (cl.isNotEmpty && cl.last.t >= expected - 2000) {
            fresh = true;
            break;
          }
          await Future.delayed(const Duration(seconds: 2));
          f = await DataSource.candles(pair, tf, 0, size: 220);
          if (f.data == null) break;
        }
        if (f.data != null && !fresh) {
          return '$pair: ${t2('data_stale', tf)}';
        }
      }
      if (f.data == null) return '$pair: ${t2(f.error ?? 'na_source_error')}';
      data[tf] = f.data!;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    LastSignal? last;
    for (final h in hist) {
      if (h.pair == pair) {
        last = LastSignal(h.direction, h.issuedAt, h.price ?? 0);
        break;
      }
    }
    final r = Strategy.run(
      data: data,
      durationSec: duration,
      nowMs: now,
      connectionOk: true,
      last: last,
    );
    final head =
        r.reasons.isEmpty ? '' : t2(r.reasons.first.key, r.reasons.first.v);
    if (r.type != 'UP' && r.type != 'DOWN') {
      return '$pair: ${r.type} ${r.score}/10  $head';
    }
    final dup = hist.any((h) =>
        h.pair == pair &&
        h.result == 'PENDING' &&
        h.indicators.startsWith('[AUTO]') &&
        (h.endAt ?? 0) > now);
    if (dup) return '$pair: ${r.type} (${t2('sg_live')})';

    final entryServer = lead >= 60 ? b + 60000 : b;
    final entryMs = entryServer - PoClient.I.offsetMs;
    final expiryMs = entryMs + duration * 1000;
    final ind = '[AUTO] RSI ${r.rsi?.toStringAsFixed(1)} | ADX '
        '${r.adx?.toStringAsFixed(1)} | ST ${_arr(r.st)} | ATR '
        '${r.atr?.toStringAsFixed(5)} | '
        '${r.tf.entries.map((e) => '${e.key}${_arr(e.value)}').join(' ')}';
    final rec = SignalRecord(
      pair: pair,
      market: 'OTC',
      direction: r.type,
      duration: '$duration',
      indicators: ind,
      reasons: r.reasons.map((x) => t2(x.key, x.v)).join(' • '),
      issuedAt: now,
      price: r.price,
      score: r.score,
      endAt: expiryMs,
    );
    try {
      await HistoryDb.insert(rec);
    } catch (_) {}
    hist.insert(0, rec);
    changed.value++;
    final title =
        '${r.type == 'UP' ? '▲ UP' : '▼ DOWN'}  $pair  (${r.score}/10)';
    final body = '${t2('lbl_entry')} ${_hm(entryMs)}  •  '
        '${t2('lbl_expiry')} ${_hm(expiryMs)}  •  ${durText(duration)}';
    await Notifier.show(_nid++, title, body);
    return '$pair: ${r.type} ${r.score}/10 → $body';
  }
}
