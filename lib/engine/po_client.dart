import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'indicators.dart';
import 'po_probe.dart';

class Fetch<T> {
  final T? data;
  final String? error;
  const Fetch(this.data, this.error);
}

class PoAsset {
  final String symbol, name;
  final int payout;
  final bool open;
  const PoAsset(this.symbol, this.name, this.payout, this.open);
}

class PoClient {
  static final PoClient I = PoClient._();
  PoClient._();

  WebSocket? _ws;
  bool authed = false;
  bool _connecting = false;
  String? _lastEv;
  Completer<bool>? _authC;
  Completer<Map<String, dynamic>?>? _histC;
  String? _histAsset;
  String? _sym;
  final List<PoAsset> assets = [];
  int offsetMs = 0; // فرق ساعة المنصة عن ساعة الجهاز

  void _close() {
    try {
      _ws?.close();
    } catch (_) {}
    _ws = null;
    authed = false;
  }

  void _onClosed(WebSocket sock) {
    if (_ws == sock) {
      _ws = null;
      authed = false;
      _sym = null;
    }
    if (_authC != null && !_authC!.isCompleted) _authC!.complete(false);
    if (_histC != null && !_histC!.isCompleted) _histC!.complete(null);
  }

  void _markAuthed() {
    authed = true;
    if (_authC != null && !_authC!.isCompleted) _authC!.complete(true);
  }

  Future<String?> connect() async {
    if (_ws != null && authed) return null;
    if (_connecting) {
      for (var i = 0; i < 70 && _connecting; i++) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
      return (_ws != null && authed) ? null : 'na_source_error';
    }
    _connecting = true;
    try {
      final ssid = await PoProbe.read();
      if (ssid == null || ssid.isEmpty) return 'na_no_key';
      _close();
      final full = ssid.startsWith('42');
      final demo = ssid.contains('"isDemo":1') || !full;
      final auth = full
          ? ssid
          : '42["auth",{"session":"$ssid","isDemo":1,"uid":0,"platform":1}]';
      final hosts = demo
          ? ['demo-api-eu.po.market', 'api-eu.po.market', 'api-us-north.po.market']
          : ['api-eu.po.market', 'api-us-north.po.market', 'api-fr.po.market'];
      WebSocket? ws;
      for (final h in hosts) {
        try {
          ws = await WebSocket.connect(
            'wss://$h/socket.io/?EIO=4&transport=websocket',
            headers: {
              'Origin': 'https://pocketoption.com',
              'User-Agent':
                  'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/120 Mobile Safari/537.36',
            },
          ).timeout(const Duration(seconds: 8));
          break;
        } catch (_) {}
      }
      if (ws == null) return 'na_net';
      final WebSocket sock = ws;
      _ws = sock;
      authed = false;
      _sym = null;
      assets.clear();
      _authC = Completer<bool>();
      sock.listen(
        (m) => _onMsg(sock, m, auth),
        onDone: () => _onClosed(sock),
        onError: (_) => _onClosed(sock),
      );
      final ok = await _authC!.future
          .timeout(const Duration(seconds: 12), onTimeout: () => false);
      if (!ok) {
        _close();
        return 'na_source_error';
      }
      return null;
    } catch (_) {
      return 'na_source_error';
    } finally {
      _connecting = false;
    }
  }

  void _onMsg(WebSocket sock, dynamic m, String auth) {
    try {
      if (m is String) {
        if (m == '2') {
          sock.add('3');
          return;
        }
        if (m.startsWith('0')) {
          sock.add('40');
          return;
        }
        if (m.startsWith('40')) {
          sock.add(auth);
          return;
        }
        final ev = RegExp(r'\["([^"]+)"').firstMatch(m)?.group(1);
        if (ev == null) return;
        if (m.contains('_placeholder')) {
          _lastEv = ev;
        } else {
          _lastEv = null;
          if (ev == 'successauth') _markAuthed();
        }
      } else if (m is List<int>) {
        final ev = _lastEv;
        _lastEv = null;
        if (ev != null) _handle(ev, m);
      }
    } catch (_) {}
  }

  void _handle(String ev, List<int> bytes) {
    dynamic j;
    try {
      j = jsonDecode(utf8.decode(bytes, allowMalformed: true));
    } catch (_) {
      return;
    }
    if (ev == 'successauth') {
      _markAuthed();
    } else if (ev == 'updateAssets') {
      _parseAssets(j);
    } else if (ev == 'updateStream') {
      if (j is List && j.isNotEmpty && j[0] is List && (j[0] as List).length > 1) {
        final t = (j[0] as List)[1];
        if (t is num) {
          offsetMs = (t * 1000).round() - DateTime.now().millisecondsSinceEpoch;
        }
      }
    } else if (ev == 'loadHistoryPeriodFast' || ev == 'loadHistoryPeriod') {
      if (j is Map<String, dynamic> &&
          _histC != null &&
          !_histC!.isCompleted &&
          j['asset'] == _histAsset) {
        _histC!.complete(j);
      }
    }
  }

  void _parseAssets(dynamic j) {
    if (j is! List) return;
    final out = <PoAsset>[];
    for (final a in j) {
      if (a is List && a.length > 14 && a[1] is String) {
        out.add(PoAsset(a[1] as String, '${a[2]}',
            a[5] is num ? (a[5] as num).toInt() : 0, a[14] == true));
      }
    }
    assets
      ..clear()
      ..addAll(out);
  }

  Future<Fetch<List<Candle>>> candles(String sym, int period,
      {int count = 220}) async {
    final err = await connect();
    if (err != null) return Fetch<List<Candle>>(null, err);
    final ws = _ws;
    if (ws == null) return const Fetch<List<Candle>>(null, 'na_source_error');
    if (_sym != sym) {
      ws.add('42["changeSymbol",{"asset":"$sym","period":$period}]');
      _sym = sym;
      await Future.delayed(const Duration(milliseconds: 600));
    }
    final nowSec =
        (DateTime.now().millisecondsSinceEpoch + offsetMs) ~/ 1000;
    _histAsset = sym;
    _histC = Completer<Map<String, dynamic>?>();
    ws.add('42["loadHistoryPeriod",{"asset":"$sym","time":$nowSec,'
        '"index":${nowSec * 1000 + 123},"offset":${period * count},'
        '"period":$period}]');
    Map<String, dynamic>? r;
    try {
      r = await _histC!.future.timeout(const Duration(seconds: 12));
    } catch (_) {
      r = null;
    }
    if (r == null) return const Fetch<List<Candle>>(null, 'na_source_error');
    final d = r['data'];
    if (d is! List || d.isEmpty) {
      return const Fetch<List<Candle>>(null, 'na_source_error');
    }
    final out = <Candle>[];
    final seen = <int>{};
    for (final e in d) {
      if (e is! Map) continue;
      final t = e['time'], o = e['open'], h = e['high'], l = e['low'], c = e['close'];
      if (t is! num || o is! num || h is! num || l is! num || c is! num) {
        continue;
      }
      final ts = t.toInt();
      if (!seen.add(ts)) continue;
      out.add(Candle(ts * 1000, o.toDouble(), h.toDouble(), l.toDouble(),
          c.toDouble(),
          closed: ts + period <= nowSec));
    }
    out.sort((a, b) => a.t.compareTo(b.t));
    return Fetch<List<Candle>>(out, null);
  }
}
