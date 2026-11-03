import 'package:flutter/material.dart';
import 'engine/datasource.dart';
import 'engine/po_probe.dart';
import 'l10n.dart';
import 'l10n2.dart';

const _card = Color(0xFF0A1A3F);
const _line = Color(0xFF1F4FB5);
const _blue = Color(0xFF2E7BFF);
const _green = Color(0xFF2BE86F);
const _amber = Color(0xFFFFB020);
const _red = Color(0xFFFF4B5C);

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _ctrl = TextEditingController();
  bool hasKey = false;
  bool hide = true;

  void _onLang() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    langNotifier.addListener(_onLang);
    _load();
  }

  @override
  void dispose() {
    langNotifier.removeListener(_onLang);
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final h = await DataSource.hasKey();
    if (!mounted) return;
    setState(() => hasKey = h);
  }

  void _msg(String t) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  }

  Future<void> _save() async {
    final v = _ctrl.text.trim();
    if (v.isEmpty) {
      _msg(tr('ssid_paste_first'));
      return;
    }
    final ok = await DataSource.saveKey(v);
    if (!mounted) return;
    if (!ok) {
      _msg(tr('ssid_fail'));
      return;
    }
    _ctrl.clear();
    setState(() => hasKey = true);
    _msg(tr('ssid_ok'));
  }

  Future<void> _delete() async {
    await DataSource.deleteKey();
    if (!mounted) return;
    setState(() => hasKey = false);
    _msg(tr('ssid_deleted'));
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
          Icon(icon, color: _blue, size: 26),
          const SizedBox(width: 8),
          Expanded(
            child: Text(title,
                style:
                    const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 10),
        ...children,
      ]),
    );
  }

  Widget _langTile(String code, String label) {
    final sel = langNotifier.value == code;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(fontSize: 17)),
      trailing: sel
          ? const Icon(Icons.check_circle, color: _green)
          : const Icon(Icons.circle_outlined, color: Colors.white38),
      onTap: () => saveLang(code),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sc = hasKey ? _green : _amber;
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      children: [
        Text(tr('settings_title'),
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 14),
        _section(tr('lang_title'), Icons.language, [
          _langTile('ar', 'العربية'),
          _langTile('fr', 'Français'),
          _langTile('en', 'English'),
        ]),
        const PoProbeCard(),
        _section(t2('key_title'), Icons.sensors, [
          Row(children: [
            Icon(hasKey ? Icons.verified_user : Icons.gpp_maybe,
                color: sc, size: 22),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                  '${tr('ds_status')}: ${hasKey ? t2('src_ready') : t2('src_nokey')}',
                  style: TextStyle(color: sc, fontSize: 16)),
            ),
          ]),
          const SizedBox(height: 6),
          Text(hasKey ? t2('key_saved') : t2('key_missing'),
              style: TextStyle(
                  fontSize: 14, color: hasKey ? _green : Colors.white70)),
          const SizedBox(height: 10),
          TextField(
            controller: _ctrl,
            obscureText: hide,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              hintText: t2('key_hint'),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              suffixIcon: IconButton(
                icon: Icon(hide ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => hide = !hide),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                    backgroundColor: _blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                child: Text(tr('ssid_save')),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: hasKey ? _delete : null,
                style: OutlinedButton.styleFrom(
                    foregroundColor: _red,
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                child: Text(tr('ssid_delete')),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Text(t2('key_help'),
              style: const TextStyle(fontSize: 12, color: Colors.white54)),
        ]),
        _section(tr('ver_title'), Icons.info_outline, [
          const Text('Farid Hamzaoui Signals Pro',
              style: TextStyle(fontSize: 16)),
          const SizedBox(height: 4),
          Text(tr('ver_number'), style: const TextStyle(color: Colors.white70)),
        ]),
      ],
    );
  }
}
