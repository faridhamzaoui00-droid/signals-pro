import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../history_page.dart';
import '../l10n.dart';
import '../l10n2.dart';
import 'cfg.dart';
import 'datasource.dart';
import 'indicators.dart';
import 'notify.dart';
import 'po_client.dart';
import 'po_probe.dart';
import 'strategy.dart';

String _t(String ar, String fr, String en) {
  final l = langNotifier.value;
  return l == 'ar' ? ar : (l == 'fr' ? fr : en);
}

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
  int lead = 60; // 0 = الدقيقة التالية للإشارة، 60 = بعدها بدقيقة
  DateTime? lastCycle;

  Timer? _timer;
  Timer? _resTimer;
  Timer? _wd;
  bool _resBusy = false;
  bool _wdBusy = false;
  int _lastBoundary = 0;
  int _nid = 1000;
  bool _busy = false;
  bool _loaded = false;

  int _failCount = 0;
  int _failCycles = 0;
  int _lastAlert = 0;
  int _lastReconnect = 0;
  int _cycleDoneMs = 0;
  int _startMs = 0;
  bool _alerted = false;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    await Cfg.load();
    final p = await SharedPreferences.getInstance();
    pairs = p.getStringList('mon_pairs') ?? <String>[];
    duration = p.getInt('mon_dur') ?? 300;
    lead = p.getInt('mon_lead') ?? 60;
    await Notifier.init();
    _startResolver();
    if (p.getBool('mon_on') ?? false) await start();
  }

  // حسم النتائج: يعمل دائماً، كل ثانية
  void _startResolver() {
    _resTimer?.cancel();
    _resTimer = Timer.periodic(const Duration(seconds: 1), (_) => _resolveTick());
  }

  Future<void> _resolveTick() async {
    if (_resBusy) return;
    _resBusy = true;
    try {
      await DataSource.resolveDue(onResolved: (rec, res, en, ex) {
        changed.value++;
        _notifyResult(rec, res, en, ex);
      });
    } catch (_) {
    } finally {
      _resBusy = false;
    }
  }

  void _notifyResult(SignalRecord r, String res, double? en, double? ex) {
    if (!r.indicators.startsWith('[AUTO]')) return;
    final icon = res == 'WIN' ? '✅' : (res == 'LOSS' ? '❌' : '➖');
    final label = res == 'WIN'
        ? tr('res_win')
        : (res == 'LOSS' ? tr('res_loss') : tr('res_unv'));
    final title = '$icon $label  ${r.pair}';
    final body = '${r.direction}  •  ${en ?? '—'} → ${ex ?? '—'}  •  '
        '${durText(int.tryParse(r.duration) ?? 0)}';
    Notifier.show(_nid++, title, body);
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
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final sNow = nowMs + PoClient.I.offsetMs;
    _lastBoundary = sNow ~/ 60000 * 60000;
    _startMs = nowMs;
    _cycleDoneMs = 0;
    _failCycles = 0;
    _alerted = false;
    await FgService.start(pairs.length);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    _wd?.cancel();
    _wd = Timer.periodic(const Duration(seconds: 20), (_) => _watch());
    lines.value = ['${_hm(nowMs)}  ▶ ${t2('nt_running')}'];
    return null;
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _wd?.cancel();
    _wd = null;
    running.value = false;
    await _save(on: false);
    await FgService.stop();
  }

  // ---------- الحارس والتنبيهات ----------
  void _alert(String title, String body) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastAlert < 900000) return;
    _lastAlert = now;
    _alerted = true;
    Notifier.show(9001, title, body);
  }

  void _recovered() {
    if (!_alerted) return;
    _alerted = false;
    Notifier.show(
        9002,
        _t('✅ عاد التحليل التلقائي للعمل', '✅ Analyse automatique rétablie',
            '✅ Auto analysis is working again'),
        _t('تم استئناف جلب البيانات والتحليل.', 'Le chargement des données a repris.',
            'Data loading and analysis resumed.'));
  }

  Future<void> _watch() async {
    if (!running.value || _wdBusy) return;
    _wdBusy = true;
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final tfs = Strategy.tfsFor(duration);
      final interval =
          tfs.isEmpty ? 300000 : (Strategy.tfMs[tfs.first] ?? 300000);
      final p = PoClient.I;
      final lost = !p.connected.value;
      final zombie = p.lastTickMs != 0 && now - p.lastTickMs > 90000;
      if ((lost || zombie) && now - _lastReconnect > 60000) {
        _lastReconnect = now;
        final e = await p.reconnect();
        p.lastTickMs = DateTime.now().millisecondsSinceEpoch;
        if (e != null) {
          _alert(
              _t('⚠️ انقطع الاتصال بـ Pocket Option',
                  '⚠️ Connexion à Pocket Option perdue',
                  '⚠️ Connection to Pocket Option lost'),
              _t('تعذرت إعادة الاتصال. قد يكون مفتاح الجلسة (SSID) منتهياً، انسخ مفتاحاً جديداً من المنصة وألصقه في الإعدادات.',
                  "La reconnexion a échoué. La clé de session (SSID) est peut-être expirée : copiez-en une nouvelle depuis la plateforme.",
                  'Reconnection failed. The session key (SSID) may have expired: copy a fresh one from the platform and paste it in Settings.'));
        }
      }
      final ref = _cycleDoneMs == 0 ? _startMs : _cycleDoneMs;
      if (now - ref > interval * 2 + 120000) {
        _alert(
            _t('⚠️ التحليل التلقائي متوقف', '⚠️ Analyse automatique arrêtée',
                '⚠️ Auto analysis stalled'),
            _t('لم تكتمل أي دورة تحليل منذ ${(now - ref) ~/ 60000} دقيقة. افتح التطبيق وتحقق من الاتصال.',
                "Aucun cycle d'analyse terminé depuis ${(now - ref) ~/ 60000} min. Ouvrez l'application et vérifiez la connexion.",
                'No analysis cycle completed for ${(now - ref) ~/ 60000} min. Open the app and check the connection.'));
      }
    } catch (_) {
    } finally {
      _wdBusy = false;
    }
  }

  Future<void> _onFailCycle() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastReconnect > 60000) {
      _lastReconnect = now;
      await PoClient.I.reconnect();
      PoClient.I.lastTickMs = DateTime.now().millisecondsSinceEpoch;
    }
    if (_failCycles >= 2) {
      _alert(
          _t('⚠️ التحليل التلقائي لا يتلقى بيانات', '⚠️ Aucune donnée reçue',
              '⚠️ Auto analysis is not receiving data'),
          _t('تعذر جلب البيانات من Pocket Option لدورتين متتاليتين. جرّب إعادة الاتصال من الإعدادات، وإن استمر فانسخ SSID جديداً.',
              "Impossible de récupérer les données de Pocket Option sur 2 cycles. Essayez Reconnecter dans les Paramètres, sinon copiez un nouveau SSID.",
              'Could not fetch data from Pocket Option for 2 cycles in a row. Try Reconnect in Settings, otherwise copy a fresh SSID.'));
    }
  }

  // ---------- دورة التحليل ----------
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
      _failCount = 0;
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
      _cycleDoneMs = DateTime.now().millisecondsSinceEpoch;
      if (pairs.isNotEmpty && _failCount >= pairs.length) {
        _failCycles++;
        await _onFailCycle();
      } else {
        _failCycles = 0;
        _recovered();
      }
    } catch (_) {}
  }

  Future<String> _analyzePair(String pair, List<String> tfs, int b, int tfMs,
      List<SignalRecord> hist) async {
    final data = <String, List<Candle>>{};
    for (final tf in tfs) {
      var f = await DataSource.candles(pair, tf, 0, size: 220);
      if (f.data == null) {
        await Future.delayed(const Duration(seconds: 2));
        f = await DataSource.candles(pair, tf, 0, size: 220);
      }
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
          _failCount++;
          return '$pair: ${t2('data_stale', tf)}';
        }
      }
      if (f.data == null) {
        _failCount++;
        return '$pair: ${t2(f.error ?? 'na_source_error')}';
      }
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

    final sNow = now + PoClient.I.offsetMs;
    final nextB = (sNow ~/ 60000 + 1) * 60000;
    final entryServer = nextB + (lead >= 60 ? 60000 : 0);
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
