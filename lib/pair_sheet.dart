import 'package:flutter/material.dart';
import 'engine/datasource.dart';
import 'l10n2.dart';

class PairSheet extends StatefulWidget {
  const PairSheet({super.key});
  @override
  State<PairSheet> createState() => _PairSheetState();
}

class _PairSheetState extends State<PairSheet> {
  List<String>? all;
  String? err;
  String q = '';
  bool busy = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final f = await DataSource.pairs();
    if (!mounted) return;
    setState(() {
      all = f.data;
      err = f.error;
      busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final list = (all ?? <String>[])
        .where((s) => s.toLowerCase().contains(q.toLowerCase()))
        .toList();
    Widget body;
    if (busy) {
      body = const Center(child: CircularProgressIndicator());
    } else if (err != null) {
      body = Center(child: Text(t2(err!), textAlign: TextAlign.center));
    } else if (list.isEmpty) {
      body = Center(child: Text(t2('pairs_none')));
    } else {
      body = ListView(children: [
        for (final s in list)
          ListTile(title: Text(s), onTap: () => Navigator.pop(context, s)),
      ]);
    }
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t2('pairs_title'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(t2('otc_note'),
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
