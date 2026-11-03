import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../l10n.dart';

String _t(String ar, String fr, String en) {
  final l = langNotifier.value;
  return l == 'ar' ? ar : (l == 'fr' ? fr : en);
}

class PoProbe {
  static const _s = FlutterSecureStorage();

  static Future<bool> has() async {
    try {
      final v = await _s.read(key: 'po_ssid');
      return v != null && v.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> save(String v) async {
    try {
      await _s.write(key: 'po_ssid', value: v);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> delete() async {
    try {
      await _s.delete(key: 'po_ssid');
    } catch (_) {}
  }

  static Future<String?> read() async {
    try {
      return await _s.read(key: 'po_ssid');
    } catch (_) {
      return null;
    }
  }

  static String _redact(String s, String secret) {
    var out = s;
    final m = RegExp(r'"session":"([^"]+)"').firstMatch(secret);
    if (m != null) out = out.replaceAll(m.group(1)!, '***');
    return out.replaceAll(secret, '***');
  }

  static String _trunc(String s, int n) =>
      s.length <= n ? s : '${s.substring(0, n)}…';

  static String _event(String m) {
    final r = RegExp(r'\["([^"]+)"').firstMatch(m);
    return r?.group(1) ?? '?';
  }

  static Future<void> run(String ssid, void Function(String) log) async {
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
        log('→ $h');
        ws = await WebSocket.connect(
          'wss://$h/socket.io/?EIO=4&transport=websocket',
          headers: {
            'Origin': 'https://pocketoption.com',
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/120 Mobile Safari/537.36',
          },
        ).timeout(const Duration(seconds: 8));
        log('✔ WebSocket: $h');
        break;
      } catch (e) {
        log('✘ ${e.runtimeType}');
      }
    }
    if (ws == null) {
      log(_t('لم ينجح الاتصال بأي خادم', 'Aucun serveur joignable',
          'No server reachable'));
      return;
    }
    final WebSocket sock = ws;
    final seen = <String, int>{};
    var symSent = false;
    final done = Completer<void>();

    void sendSym() {
      if (symSent) return;
      symSent = true;
      sock.add('42["changeSymbol",{"asset":"EURUSD_otc","period":60}]');
      log('→ changeSymbol EURUSD_otc');
    }

    final sub = sock.listen((m) {
      try {
        if (m is String) {
          if (m == '2') {
            sock.add('3');
            return;
          }
          if (m.startsWith('0')) {
            log('✔ handshake');
            sock.add('40');
            return;
          }
          if (m.startsWith('40')) {
            log('✔ socket.io → auth');
            sock.add(auth);
            return;
          }
          final ev = _event(m);
          seen[ev] = (seen[ev] ?? 0) + 1;
          if (seen[ev] == 1) {
            log('حدث/event: $ev | ${_redact(_trunc(m, 150), ssid)}');
          }
          if (ev == 'successauth') sendSym();
        } else if (m is List<int>) {
          seen['(binary)'] = (seen['(binary)'] ?? 0) + 1;
          if (seen['(binary)'] == 1) {
            final txt = String.fromCharCodes(m.take(180));
            log('binary ${m.length}B | ${_redact(_trunc(txt, 150), ssid)}');
          }
        }
      } catch (_) {}
    }, onDone: () {
      log('× ${_t('أُغلق الاتصال', 'Connexion fermée', 'Connection closed')}');
      if (!done.isCompleted) done.complete();
    }, onError: (e) {
      log('× ${e.runtimeType}');
      if (!done.isCompleted) done.complete();
    });

    Timer(const Duration(seconds: 6), sendSym);
    Timer(const Duration(seconds: 16), () {
      if (!done.isCompleted) done.complete();
    });
    await done.future;
    await sub.cancel();
    try {
      await sock.close();
    } catch (_) {}
    log('— ${_t('الملخص', 'Résumé', 'Summary')} —');
    if (seen.isEmpty) {
      log(_t('لم تصل أي رسائل بعد المصافحة', 'Aucun message reçu après la poignée de main',
          'No messages received after handshake'));
    } else {
      for (final e in seen.entries) {
        log('${e.key} × ${e.value}');
      }
    }
  }
}

class PoProbeCard extends StatefulWidget {
  const PoProbeCard({super.key});
  @override
  State<PoProbeCard> createState() => _PoProbeCardState();
}

class _PoProbeCardState extends State<PoProbeCard> {
  final _ctrl = TextEditingController();
  bool has = false;
  bool hide = true;
  bool running = false;
  final lines = <String>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final h = await PoProbe.has();
    if (!mounted) return;
    setState(() => has = h);
  }

  Future<void> _save() async {
    final v = _ctrl.text.trim();
    if (v.isEmpty) return;
    final ok = await PoProbe.save(v);
    if (!mounted) return;
    if (ok) _ctrl.clear();
    setState(() => has = ok);
  }

  Future<void> _delete() async {
    await PoProbe.delete();
    if (!mounted) return;
    setState(() => has = false);
  }

  Future<void> _test() async {
    final s = await PoProbe.read();
    if (s == null || running) return;
    setState(() {
      running = true;
      lines.clear();
    });
    await PoProbe.run(s, (l) {
      if (mounted) setState(() => lines.add(l));
    });
    if (mounted) setState(() => running = false);
  }

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF2E7BFF);
    const green = Color(0xFF2BE86F);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1A3F),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1F4FB5).withOpacity(0.7)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.sensors, color: blue, size: 26),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
                _t('Pocket Option (مفتاح الجلسة SSID)',
                    'Pocket Option (clé de session SSID)',
                    'Pocket Option (session key SSID)'),
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 8),
        Text(
            has
                ? _t('محفوظ مشفراً على هذا الجهاز', 'Enregistrée, chiffrée sur cet appareil',
                    'Saved, encrypted on this device')
                : _t('غير محفوظ', 'Non enregistrée', 'Not saved'),
            style: TextStyle(color: has ? green : Colors.white70)),
        const SizedBox(height: 8),
        TextField(
          controller: _ctrl,
          obscureText: hide,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            hintText: _t('الصق الـ SSID كاملاً هنا (يبدأ بـ 42)',
                'Collez le SSID complet ici (commence par 42)',
                'Paste the full SSID here (starts with 42)'),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            suffixIcon: IconButton(
              icon: Icon(hide ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => hide = !hide),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                  backgroundColor: blue, foregroundColor: Colors.white),
              child: Text(tr('ssid_save')),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: has ? _delete : null,
              child: Text(tr('ssid_delete')),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: (has && !running) ? _test : null,
            icon: running
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.network_check),
            label: Text(_t('اختبار الاتصال بـ Pocket Option',
                'Tester la connexion Pocket Option', 'Test Pocket Option connection')),
          ),
        ),
        const SizedBox(height: 6),
        Text(
            _t('لا ترسل هذا المفتاح لأحد، ولا تلصقه في أي محادثة.',
                'Ne partagez jamais cette clé et ne la collez dans aucune conversation.',
                'Never share this key or paste it in any chat.'),
            style: const TextStyle(fontSize: 12, color: Colors.white54)),
        if (lines.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 280),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: Colors.black38, borderRadius: BorderRadius.circular(10)),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: SingleChildScrollView(
                child: SelectableText(lines.join('\n'),
                    style: const TextStyle(
                        fontSize: 11, fontFamily: 'monospace', height: 1.4)),
              ),
            ),
          ),
        ],
      ]),
    );
  }
}
