import 'dart:async';
import 'package:flutter/material.dart';
import 'engine/datasource.dart';
import 'engine/monitor.dart';
import 'history_page.dart';
import 'l10n.dart';
import 'l10n2.dart';

const _card = Color(0xFF0A1A3F);
const _line = Color(0xFF1F4FB5);
const _blue = Color(0xFF2E7BFF);
const _green = Color(0xFF2BE86F);
const _red = Color(0xFFFF4B5C);
const _amber = Color(0xFFFFB020);
const _grey = Color(0xFF7C8BA8);

String _hm(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  String t(int v) => v.toString().padLeft(2, '0');
  return '${t(d.hour)}:${t(d.minute)}:${t(d.second)}';
}

String _cd(int ms) {
  final s = (ms / 1000).ceil();
  String t(int v) => v.toString().padLeft(2, '0');
  return '${t(s ~/ 60)}:${t(s % 60)}';
}

class SignalsPage extends StatefulWidget {
  const SignalsPage({super.key});
  @override
  State<SignalsPage> createState() => _SignalsPageState();
}

class _SignalsPageState extends State<SignalsPage> {
  List<SignalRecord> items = [];
  Timer? _timer;
  int _tick = 0;

  void _r() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    langNotifier.addListener(_r);
    Monitor.I.changed.addListener(_reload);
    _reload();
    DataSource.resolvePending().then((_) => _reload());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _tick++;
      if (_tick % 45 == 0) {
        DataSource.resolvePending().then((_) => _reload());
      }
      _r();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    langNotifier.removeListener(_r);
    Monitor.I.changed.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    List<SignalRecord> all = [];
    try {
      all = await HistoryDb.all();
    } catch (_) {}
    final auto = all.where((r) => r.indicators.startsWith('[AUTO]')).toList();
    if (!mounted) return;
    setState(() => items = auto.take(100).toList());
  }

  Widget _tile(SignalRecord r) {
    final up = r.direction == 'UP';
    final dur = int.tryParse(r.duration) ?? 0;
    final exp = r.endAt ?? 0;
    final entry = exp - dur * 1000;
    final now = DateTime.now().millisecondsSinceEpoch;
    String status;
    Color c;
    if (r.result == 'PENDING') {
      if (now < entry) {
        status = '${t2('sg_upcoming')}  ${_cd(entry - now)}';
        c = _amber;
      } else if (now < exp) {
        status = '${t2('sg_live')}  ${_cd(exp - now)}';
        c = _blue;
      } else {
        status = tr('res_pending');
        c = _amber;
      }
    } else if (r.result == 'WIN') {
      status = tr('res_win');
      c = _green;
    } else if (r.result == 'LOSS') {
      status = tr('res_loss');
      c = _red;
    } else {
      status = tr('res_unv');
      c = _grey;
    }
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: (up ? _green : _red).withOpacity(0.7)),
        boxShadow: [
          BoxShadow(color: (up ? _green : _red).withOpacity(0.15), blurRadius: 10)
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(up ? Icons.north_east : Icons.south_east,
              color: up ? _green : _red, size: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Text('${up ? 'UP' : 'DOWN'}  •  ${r.pair}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Text('${r.score}/10',
              style: const TextStyle(
                  color: _amber, fontSize: 18, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 8),
        Text(
            '${t2('lbl_entry')}: ${_hm(entry)}   ${t2('lbl_expiry')}: ${_hm(exp)}   ${durText(dur)}',
            style: const TextStyle(fontSize: 14)),
        const SizedBox(height: 4),
        Text(r.reasons,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: Colors.white60)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: c.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: c),
          ),
          child: Text(status, style: TextStyle(color: c, fontSize: 13)),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      children: [
        Text(t2('sg_title'),
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(t2('sg_note'),
            style: const TextStyle(fontSize: 12, color: Colors.white54)),
        const SizedBox(height: 8),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.all(40),
            child: Center(
                child: Text(t2('sg_empty'),
                    style: const TextStyle(color: Colors.white70))),
          )
        else
          for (final r in items) _tile(r),
      ],
    );
  }
}
