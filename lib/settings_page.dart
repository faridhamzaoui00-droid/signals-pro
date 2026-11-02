import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final _storage = const FlutterSecureStorage();
  final _ctrl = TextEditingController();
  String lang = 'ar';
  bool hasSsid = false;
  bool hide = true;

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
    final p = await SharedPreferences.getInstance();
    String? s;
    try {
      s = await _storage.read(key: 'ssid');
    } catch (_) {
      s = null;
    }
    if (!mounted) return;
    setState(() {
      lang = p.getString('lang') ?? 'ar';
      hasSsid = s != null && s.isNotEmpty;
    });
  }

  Future<void> _setLang(String l) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('lang', l);
    if (!mounted) return;
    setState(() => lang = l);
  }

  void _msg(String t) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  }

  Future<void> _saveSsid() async {
    final v = _ctrl.text.trim();
    if (v.isEmpty) {
      _msg('الصق المفتاح أولاً');
      return;
    }
    try {
      await _storage.write(key: 'ssid', value: v);
    } catch (_) {
      _msg('تعذر الحفظ على هذا الجهاز');
      return;
    }
    _ctrl.clear();
    if (!mounted) return;
    setState(() => hasSsid = true);
    _msg('تم حفظ المفتاح مشفراً على هذا الجهاز');
  }

  Future<void> _deleteSsid() async {
    try {
      await _storage.delete(key: 'ssid');
    } catch (_) {}
    if (!mounted) return;
    setState(() => hasSsid = false);
    _msg('تم حذف المفتاح');
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
          Text(title,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 10),
        ...children,
      ]),
    );
  }

  Widget _langTile(String code, String label) {
    final sel = lang == code;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(fontSize: 17)),
      trailing: sel
          ? const Icon(Icons.check_circle, color: _green)
          : const Icon(Icons.circle_outlined, color: Colors.white38),
      onTap: () => _setLang(code),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      children: [
        const Text('الإعدادات',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 14),
        _section('اللغة', Icons.language, [
          _langTile('ar', 'العربية'),
          _langTile('fr', 'Français'),
          _langTile('en', 'English'),
          const Text('ترجمة كل عناصر التطبيق تُضاف في خطوة لاحقة.',
              style: TextStyle(fontSize: 12, color: Colors.white54)),
        ]),
        _section('مصدر البيانات', Icons.sensors, [
          Row(children: const [
            Icon(Icons.gpp_maybe, color: _amber, size: 22),
            SizedBox(width: 6),
            Text('الحالة: غير متصل',
                style: TextStyle(color: _amber, fontSize: 16)),
          ]),
          const SizedBox(height: 6),
          Text(
              hasSsid
                  ? 'مفتاح الجلسة (SSID): محفوظ مشفراً على هذا الجهاز'
                  : 'مفتاح الجلسة (SSID): غير محفوظ',
              style: TextStyle(
                  fontSize: 14, color: hasSsid ? _green : Colors.white70)),
          const SizedBox(height: 10),
          TextField(
            controller: _ctrl,
            obscureText: hide,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              hintText: 'الصق مفتاح الجلسة هنا',
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
                onPressed: _saveSsid,
                style: ElevatedButton.styleFrom(
                    backgroundColor: _blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('حفظ المفتاح'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: hasSsid ? _deleteSsid : null,
                style: OutlinedButton.styleFrom(
                    foregroundColor: _red,
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('حذف المفتاح'),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          const Text(
              'لا ترسل هذا المفتاح لأحد. يبقى على هاتفك فقط ولا يُكتب في الكود.',
              style: TextStyle(fontSize: 12, color: Colors.white54)),
        ]),
        _section('معلومات الإصدار', Icons.info_outline, [
          const Text('Farid Hamzaoui Signals Pro',
              style: TextStyle(fontSize: 16)),
          const SizedBox(height: 4),
          const Text('الإصدار 1.0.0', style: TextStyle(color: Colors.white70)),
        ]),
      ],
    );
  }
}
