import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'l10n.dart';

const _card = Color(0xFF0A1A3F);
const _line = Color(0xFF1F4FB5);
const _blue = Color(0xFF2E7BFF);
const _green = Color(0xFF2BE86F);
const _red = Color(0xFFFF4B5C);
const _amber = Color(0xFFFFB020);
const _grey = Color(0xFF7C8BA8);

String _t(String ar, String fr, String en) {
  final l = langNotifier.value;
  return l == 'ar' ? ar : (l == 'fr' ? fr : en);
}

class SignalRecord {
  final int? id;
  final String pair, market, direction, duration, indicators, reasons, result;
  final int issuedAt;
  final double? price;
  final int score;
  final int? endAt;
  final double? endPrice;

  const SignalRecord({
    this.id,
    required this.pair,
    required this.market,
    required this.direction,
    required this.duration,
    this.indicators = '',
    this.reasons = '',
    this.result = 'PENDING',
    required this.issuedAt,
    this.price,
    this.score = 0,
    this.endAt,
    this.endPrice,
  });

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'pair': pair,
        'market': market,
        'direction': direction,
        'duration': duration,
        'indicators': indicators,
        'reasons': reasons,
        'result': result,
        'issuedAt': issuedAt,
        'price': price,
        'score': score,
        'endAt': endAt,
        'endPrice': endPrice,
      };

  factory SignalRecord.fromMap(Map<String, Object?> m) => SignalRecord(
        id: m['id'] as int?,
        pair: (m['pair'] ?? '') as String,
        market: (m['market'] ?? '') as String,
        direction: (m['direction'] ?? '') as String,
        duration: (m['duration'] ?? '') as String,
        indicators: (m['indicators'] ?? '') as String,
        reasons: (m['reasons'] ?? '') as String,
        result: (m['result'] ?? 'PENDING') as String,
        issuedAt: (m['issuedAt'] ?? 0) as int,
        price: (m['price'] as num?)?.toDouble(),
        score: (m['score'] ?? 0) as int,
        endAt: m['endAt'] as int?,
        endPrice: (m['endPrice'] as num?)?.toDouble(),
      );
}

class HistoryDb {
  static Database? _db;

  static Future<Database> _open() async {
    if (_db != null) return _db!;
    final path = p.join(await getDatabasesPath(), 'signals.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (d, v) => d.execute(
          'CREATE TABLE signals(id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'pair TEXT, market TEXT, direction TEXT, duration TEXT, '
          'indicators TEXT, reasons TEXT, result TEXT, issuedAt INTEGER, '
          'price REAL, score INTEGER, endAt INTEGER, endPrice REAL)'),
    );
    return _db!;
  }

  static Future<int> insert(SignalRecord r) async {
    final d = await _open();
    return d.insert('signals', r.toMap());
  }

  static Future<List<SignalRecord>> all() async {
    final d = await _open();
    final rows = await d.query('signals', orderBy: 'issuedAt DESC');
    return rows.map(SignalRecord.fromMap).toList();
  }

  static Future<void> setResult(
      int id, String result, int? endAt, double? endPrice) async {
    final d = await _open();
    await d.update(
        'signals', {'result': result, 'endAt': endAt, 'endPrice': endPrice},
        where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> deleteIds(List<int> ids) async {
    if (ids.isEmpty) return;
    final d = await _open();
    for (var i = 0; i < ids.length; i += 400) {
      final end = i + 400 > ids.length ? ids.length : i + 400;
      final chunk = ids.sublist(i, end);
      final marks = List.filled(chunk.length, '?').join(',');
      await d.delete('signals', where: 'id IN ($marks)', whereArgs: chunk);
    }
  }
}

String _resultLabel(String r) {
  switch (r) {
    case 'WIN':
      return tr('res_win');
    case 'LOSS':
      return tr('res_loss');
    case 'UNVERIFIED':
      return tr('res_unv');
    default:
      return tr('res_pending');
  }
}

Color _resultColor(String r) {
  switch (r) {
    case 'WIN':
      return _green;
    case 'LOSS':
      return _red;
    case 'UNVERIFIED':
      return _grey;
    default:
      return _amber;
  }
}

String _fmt(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  String t(int v) => v.toString().padLeft(2, '0');
  return '${d.year}-${t(d.month)}-${t(d.day)}  ${t(d.hour)}:${t(d.minute)}:${t(d.second)}';
}

String _marketName(String m) => m == 'OTC' ? 'OTC' : tr('market_regular');

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<SignalRecord> items = [];
  bool loading = true;
  String filter = 'all';
  String query = '';
  bool selectMode = false;
  final Set<int> sel = <int>{};

  Map<String, String> get filters => {
        'all': tr('f_all'),
        'WIN': tr('f_win'),
        'LOSS': tr('f_loss'),
        'PENDING': tr('f_pending'),
        'OTC': 'OTC',
        'REG': tr('market_regular'),
      };

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
    super.dispose();
  }

  Future<void> _load() async {
    List<SignalRecord> list = [];
    try {
      list = await HistoryDb.all();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      items = list;
      loading = false;
    });
  }

  List<SignalRecord> get shown {
    return items.where((r) {
      final okFilter = filter == 'all' ||
          r.result == filter ||
          (filter == 'OTC' && r.market == 'OTC') ||
          (filter == 'REG' && r.market != 'OTC');
      final okQuery = query.isEmpty ||
          r.pair.toLowerCase().contains(query.toLowerCase());
      return okFilter && okQuery;
    }).toList();
  }

  void _toggle(SignalRecord r) {
    final id = r.id;
    if (id == null) return;
    setState(() {
      if (sel.contains(id)) {
        sel.remove(id);
      } else {
        sel.add(id);
      }
    });
  }

  void _exitSel() {
    setState(() {
      selectMode = false;
      sel.clear();
    });
  }

  void _selectAll() {
    setState(() {
      sel.addAll(shown.where((r) => r.id != null).map((r) => r.id!));
    });
  }

  Future<void> _confirmDelete() async {
    final n = sel.length;
    if (n == 0) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        title: Text(_t('حذف الصفقات', 'Supprimer les trades', 'Delete trades')),
        content: Text(_t(
            'سيتم حذف $n صفقة نهائياً ولا يمكن التراجع، وستُعاد حسبة الإحصائيات من الصفقات المتبقية.',
            '$n trade(s) seront supprimés définitivement, sans retour possible. Les statistiques seront recalculées.',
            '$n trade(s) will be permanently deleted, with no undo. Statistics will be recalculated.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_t('إلغاء', 'Annuler', 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_t('حذف', 'Supprimer', 'Delete'),
                style: const TextStyle(color: _red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await HistoryDb.deleteIds(sel.toList());
    } catch (_) {}
    if (!mounted) return;
    sel.clear();
    selectMode = false;
    await _load();
  }

  Widget _stat(String label, String value, Color c) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.withOpacity(0.7)),
          boxShadow: [BoxShadow(color: c.withOpacity(0.2), blurRadius: 8)],
        ),
        child: Column(children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value,
                style: TextStyle(
                    color: c, fontSize: 24, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label,
                style: const TextStyle(fontSize: 13, color: Colors.white70)),
          ),
        ]),
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Text('$k: ', style: const TextStyle(color: Colors.white70)),
          Expanded(child: Text(v)),
        ]),
      );

  void _details(SignalRecord r) {
    final up = r.direction == 'UP';
    showModalBottomSheet(
      context: context,
      backgroundColor: _card,
      isScrollControlled: true,
      builder: (_) => Directionality(
        textDirection: dirFor(langNotifier.value),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: SingleChildScrollView(
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${r.pair}  (${_marketName(r.market)})',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  _row(tr('d_direction'),
                      up ? tr('main_up') : tr('main_down')),
                  _row(tr('duration_label'), durFromStored(r.duration)),
                  _row(tr('m_score'), '${r.score}/10'),
                  _row(tr('d_time'), _fmt(r.issuedAt)),
                  _row(tr('d_price'), r.price?.toString() ?? '—'),
                  _row(tr('d_end_time'),
                      r.endAt != null ? _fmt(r.endAt!) : '—'),
                  _row(tr('d_end_price'), r.endPrice?.toString() ?? '—'),
                  _row(tr('d_result'), _resultLabel(r.result)),
                  const Divider(),
                  Text(tr('d_indicators'),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(r.indicators.isEmpty ? '—' : r.indicators),
                  const SizedBox(height: 8),
                  Text(tr('d_reasons'),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(r.reasons.isEmpty ? '—' : r.reasons),
                  const SizedBox(height: 10),
                ]),
          ),
        ),
      ),
    );
  }

  Widget _tile(SignalRecord r) {
    final up = r.direction == 'UP';
    final c = _resultColor(r.result);
    final isSel = r.id != null && sel.contains(r.id);
    return InkWell(
      onTap: () {
        if (selectMode) {
          _toggle(r);
        } else {
          _details(r);
        }
      },
      onLongPress: () {
        setState(() => selectMode = true);
        _toggle(r);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSel ? _blue.withOpacity(0.18) : _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isSel ? _blue : _line.withOpacity(0.6),
              width: isSel ? 2 : 1),
        ),
        child: Row(children: [
          if (selectMode) ...[
            Icon(isSel ? Icons.check_circle : Icons.radio_button_unchecked,
                color: isSel ? _blue : Colors.white38),
            const SizedBox(width: 8),
          ],
          Icon(up ? Icons.north_east : Icons.south_east,
              color: up ? _green : _red, size: 30),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${r.pair}  •  ${_marketName(r.market)}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              Text('${_fmt(r.issuedAt)}  •  ${durFromStored(r.duration)}',
                  style: const TextStyle(fontSize: 12, color: Colors.white70)),
            ]),
          ),
          Column(children: [
            Text('${r.score}/10',
                style: const TextStyle(
                    color: _amber, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: c.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: c),
              ),
              child: Text(_resultLabel(r.result),
                  style: TextStyle(color: c, fontSize: 11)),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _selBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF071230),
        border: Border(top: BorderSide(color: _line.withOpacity(0.6))),
      ),
      child: Row(children: [
        Expanded(
          child: Text(
              '${sel.length} ${_t('محددة', 'sélectionnés', 'selected')}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        TextButton(
          onPressed: _selectAll,
          child: Text(_t('تحديد الكل', 'Tout sélectionner', 'Select all')),
        ),
        TextButton(
          onPressed: _exitSel,
          child: Text(_t('إلغاء', 'Annuler', 'Cancel')),
        ),
        ElevatedButton(
          onPressed: sel.isEmpty ? null : _confirmDelete,
          style: ElevatedButton.styleFrom(
              backgroundColor: _red, foregroundColor: Colors.white),
          child: Text(_t('حذف', 'Supprimer', 'Delete')),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wins = items.where((r) => r.result == 'WIN').length;
    final losses = items.where((r) => r.result == 'LOSS').length;
    final pending = items.where((r) => r.result == 'PENDING').length;
    final decided = wins + losses;
    final rate = decided == 0
        ? '—'
        : '${(wins * 100 / decided).toStringAsFixed(1)}%';
    final list = shown;
    final body = ListView(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(children: [
            Expanded(
              child: Text(tr('hist_title'),
                  style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.bold)),
            ),
            IconButton(
              tooltip: _t('تحديد وحذف', 'Sélectionner et supprimer',
                  'Select and delete'),
              onPressed: () {
                if (selectMode) {
                  _exitSel();
                } else {
                  setState(() => selectMode = true);
                }
              },
              icon: Icon(selectMode ? Icons.close : Icons.checklist,
                  color: selectMode ? _red : _blue),
            ),
          ]),
        ),
        const SizedBox(height: 8),
        Row(children: [
          _stat(tr('st_total'), '${items.length}', _blue),
          _stat(tr('st_win'), '$wins', _green),
          _stat(tr('st_loss'), '$losses', _red),
        ]),
        Row(children: [
          _stat(tr('st_pending'), '$pending', _amber),
          _stat(tr('st_rate'), rate, Colors.white),
        ]),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Text(tr('rate_note'),
              style: const TextStyle(fontSize: 11, color: Colors.white54)),
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final e in filters.entries)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text(e.value),
                  selected: filter == e.key,
                  onSelected: (_) => setState(() => filter = e.key),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 8),
        TextField(
          onChanged: (v) => setState(() => query = v.trim()),
          decoration: InputDecoration(
            hintText: tr('search_hint'),
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        if (loading)
          const Padding(
              padding: EdgeInsets.all(30),
              child: Center(child: CircularProgressIndicator()))
        else if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.all(30),
            child: Center(
                child: Text(tr('empty_hist'),
                    style: const TextStyle(color: Colors.white70))),
          )
        else
          for (final r in list) _tile(r),
      ],
    );
    return Column(children: [
      Expanded(child: body),
      if (selectMode) _selBar(),
    ]);
  }
}
