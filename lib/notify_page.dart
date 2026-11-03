import 'package:flutter/material.dart';
import 'engine/monitor.dart';
import 'engine/notify.dart';
import 'l10n.dart';
import 'l10n2.dart';
import 'pair_sheet.dart';

const _card = Color(0xFF0A1A3F);
const _line = Color(0xFF1F4FB5);
const _blue = Color(0xFF2E7BFF);
const _green = Color(0xFF2BE86F);
const _amber = Color(0xFFFFB020);

class NotifyPage extends StatefulWidget {
  const NotifyPage({super.key});
  @override
  State<NotifyPage> createState() => _NotifyPageState();
}

class _NotifyPageState extends State<NotifyPage> {
  static const durs = [
    60, 120, 180, 240, 300, 360, 420, 480, 540, 600, 660, 720, 780, 840, 900,
  ];

  void _r() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    langNotifier.addListener(_r);
    Monitor.I.changed.addListener(_r);
    Monitor.I.load().then((_) => _r());
  }

  @override
  void dispose() {
    langNotifier.removeListener(_r);
    Monitor.I.changed.removeListener(_r);
    super.dispose();
  }

  void _msg(String t) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  }

  Future<void> _toggle(bool v) async {
    if (v) {
      await Notifier.requestNotifications();
      final err = await Monitor.I.start();
      if (err != null) _msg(t2(err));
    } else {
      await Monitor.I.stop();
    }
    _r();
  }

  Future<void> _addPair() async {
    if (Monitor.I.pairs.length >= 5) {
      _msg(t2('nt_max'));
      return;
    }
    final p = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _card,
      builder: (_) => const PairSheet(),
    );
    if (p == null || Monitor.I.pairs.contains(p)) return;
    await Monitor.I.setConfig(newPairs: [...Monitor.I.pairs, p]);
    _r();
  }

  Future<void> _removePair(String p) async {
    await Monitor.I.setConfig(
        newPairs: Monitor.I.pairs.where((e) => e != p).toList());
    _r();
  }

  Widget _section(String title, IconData icon, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _line.withOpacity(0.7)),
        boxShadow: [BoxShadow(color: _line.withOpacity(0.25), blurRadius: 10)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: _blue, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Text(title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 10),
        ...children,
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = Monitor.I;
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      children: [
        Text(t2('nt_title'),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 14),
        _section(t2('nt_auto'), Icons.notifications_active, [
          Text(t2('nt_auto_desc'),
              style: const TextStyle(fontSize: 13, color: Colors.white70)),
          const SizedBox(height: 8),
          ValueListenableBuilder<bool>(
            valueListenable: m.running,
            builder: (_, on, __) => Row(children: [
              Expanded(
                child: Text(
                    '${t2('nt_status')}: ${on ? t2('nt_running') : t2('nt_stopped')}',
                    style: TextStyle(
                        fontSize: 16,
                        color: on ? _green : _amber,
                        fontWeight: FontWeight.bold)),
              ),
              Switch(value: on, onChanged: _toggle),
            ]),
          ),
        ]),
        _section(t2('nt_pairs'), Icons.candlestick_chart, [
          if (m.pairs.isEmpty)
            Text(t2('nt_no_pairs'),
                style: const TextStyle(color: Colors.white54))
          else
            Wrap(spacing: 8, runSpacing: 4, children: [
              for (final p in m.pairs)
                Chip(
                  label: Text(p),
                  onDeleted: () => _removePair(p),
                ),
            ]),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _addPair,
            icon: const Icon(Icons.add),
            label: Text(t2('nt_add_pair')),
          ),
        ]),
        _section(t2('nt_duration'), Icons.access_time, [
          Wrap(spacing: 8, runSpacing: 4, children: [
            for (final d in durs)
              ChoiceChip(
                label: Text(durText(d)),
                selected: m.duration == d,
                onSelected: (_) async {
                  await m.setConfig(newDuration: d);
                  _r();
                },
              ),
          ]),
          const SizedBox(height: 10),
          Text(t2('nt_lead'),
              style: const TextStyle(fontWeight: FontWeight.bold)),
          RadioListTile<int>(
            contentPadding: EdgeInsets.zero,
            value: 0,
            groupValue: m.lead,
            title: Text(t2('nt_lead0'), style: const TextStyle(fontSize: 14)),
            onChanged: (v) async {
              await m.setConfig(newLead: v);
              _r();
            },
          ),
          RadioListTile<int>(
            contentPadding: EdgeInsets.zero,
            value: 60,
            groupValue: m.lead,
            title: Text(t2('nt_lead60'), style: const TextStyle(fontSize: 14)),
            onChanged: (v) async {
              await m.setConfig(newLead: v);
              _r();
            },
          ),
        ]),
        _section(t2('nt_perm'), Icons.verified_user, [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () async {
                await Notifier.requestNotifications();
                _msg(t2('nt_perm_ok'));
              },
              child: Text(t2('nt_perm_notif')),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () async {
                await Notifier.requestBattery();
                _msg(t2('nt_perm_ok'));
              },
              child: Text(t2('nt_perm_batt')),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () =>
                  Notifier.show(1, t2('nt_test_title'), t2('nt_test_body')),
              style: ElevatedButton.styleFrom(
                  backgroundColor: _blue, foregroundColor: Colors.white),
              child: Text(t2('nt_test')),
            ),
          ),
        ]),
        _section(t2('nt_cycle_res'), Icons.list_alt, [
          ValueListenableBuilder<List<String>>(
            valueListenable: m.lines,
            builder: (_, ls, __) => Directionality(
              textDirection: TextDirection.ltr,
              child: SelectableText(ls.isEmpty ? '—' : ls.join('\n'),
                  style: const TextStyle(fontSize: 12, height: 1.5)),
            ),
          ),
        ]),
        Text(t2('nt_note'),
            style: const TextStyle(fontSize: 12, color: Colors.white54)),
      ],
    );
  }
}
