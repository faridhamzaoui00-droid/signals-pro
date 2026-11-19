import 'package:flutter/material.dart';
import 'engine/datasource.dart';
import 'engine/po_client.dart';
import 'l10n.dart';
import 'l10n2.dart';
import 'pairs.dart';

String _t(String ar, String fr, String en) {
  final l = langNotifier.value;
  return l == 'ar' ? ar : (l == 'fr' ? fr : en);
}

/// قائمة الأزواج المعتمدة كاملة. كل زوج قابل للاختيار دائماً.
/// العائد يُقرأ من مصدر البيانات عند توفره، وإلا تظهر N/A (لا يُحذف الزوج).
class PairSheet extends StatefulWidget {
  const PairSheet({super.key});
  @override
  State<PairSheet> createState() => _PairSheetState();
}

class _PairSheetState extends State<PairSheet> {
  String q = '';
  bool busy = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // يحدّث قائمة الأصول والعوائد من المصدر. فشل الاتصال لا يخفي الأزواج.
    try {
      await DataSource.pairs();
    } catch (_) {}
    if (!mounted) return;
    setState(() => busy = false);
  }

  PoAsset? _asset(String label) {
    final key = poSymbolOf(label).toLowerCase();
    for (final a in PoClient.I.assets) {
      if (a.symbol.toLowerCase() == key) return a;
    }
    return null;
  }

  Widget _status(String label) {
    final a = _asset(label);
    if (a == null || !a.open || a.payout <= 0) {
      return Text(_t('غير متاح', 'N/A', 'N/A'),
          style: const TextStyle(color: Colors.white38, fontSize: 13));
    }
    return Text('${a.payout}%',
        style: const TextStyle(
            color: Color(0xFF2BE86F), fontSize: 14, fontWeight: FontWeight.bold));
  }

  @override
  Widget build(BuildContext context) {
    final list = filterPairs(q);
    Widget body;
    if (list.isEmpty) {
      body = Center(child: Text(t2('pairs_none')));
    } else {
      body = ListView(children: [
        for (final s in list)
          ListTile(
            title: Text(s),
            trailing: _status(s),
            onTap: () => Navigator.pop(context, s),
          ),
      ]);
    }
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(t2('pairs_title'),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            if (busy)
              const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2)),
          ]),
          const SizedBox(height: 4),
          Text(
              _t('قائمة Pocket Option المعتمدة. يظهر العائد عندما يوفره المصدر، وغير متاح يعني أن الزوج غير مفتوح الآن.',
                  "Liste Pocket Option approuvée. Le gain s'affiche quand la source le fournit ; N/A = paire indisponible pour l'instant.",
                  'Approved Pocket Option list. Payout shows when the source provides it; N/A means currently unavailable.'),
              style: const TextStyle(fontSize: 12, color: Colors.white54)),
          const SizedBox(height: 8),
          TextField(
            onChanged: (v) => setState(() => q = v.trim()),
            decoration: InputDecoration(
              hintText: t2('pair_search'),
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: body),
        ]),
      ),
    );
  }
}
