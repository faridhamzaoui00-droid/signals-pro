// حفظ الاستراتيجيات المخصصة وإدارتها (CRUD) في التخزين الدائم.
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../engine/cfg.dart';
import '../selection_store.dart';
import '../strat/core.dart';
import 'cond.dart';
import 'ind_lib.dart';

class CustomStrategy {
  final String id;
  String name, desc, tf;
  bool enabled;
  int duration; // ثوانٍ
  List<String> pairs;
  StrategyDef def;
  CustomStrategy({
    required this.id,
    required this.name,
    this.desc = '',
    this.enabled = false,
    this.tf = 'M1',
    this.duration = 60,
    List<String>? pairs,
    required this.def,
  }) : pairs = pairs ?? <String>[];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'desc': desc,
        'enabled': enabled,
        'tf': tf,
        'duration': duration,
        'pairs': pairs,
        'def': def.toJson(),
      };

  factory CustomStrategy.fromJson(Map<String, dynamic> m) => CustomStrategy(
        id: m['id'] as String,
        name: m['name'] as String,
        desc: (m['desc'] ?? '') as String,
        enabled: (m['enabled'] ?? false) as bool,
        tf: (m['tf'] ?? 'M1') as String,
        duration: ((m['duration'] ?? 60) as num).toInt(),
        pairs: [for (final x in ((m['pairs'] ?? []) as List)) x.toString()],
        def: StrategyDef.fromJson(Map<String, dynamic>.from(m['def'] as Map)),
      );
}

/// أخطاء التحقق. القائمة الفارغة = صالحة للحفظ والتشغيل.
List<String> validateCustom(CustomStrategy s) {
  final e = <String>[];
  if (s.name.trim().isEmpty) e.add('name is empty');
  if (!Cfg.allTfs.contains(s.tf)) e.add('unknown timeframe ${s.tf}');
  if (!SelectionStore.durations.contains(s.duration)) e.add('unsupported duration ${s.duration}');
  for (final u in s.def.inds) {
    if (!kIndicatorLib.any((d) => d.id == u.id)) e.add('unknown indicator ${u.id}');
  }
  if (e.isEmpty) {
    final probe = Bars([0], [1], [1], [1], [1], [0]);
    e.addAll(validateStrategy(s.def, buildSeries(s.def, probe)));
  }
  if (s.def.up.items.isEmpty && s.def.down.items.isEmpty) e.add('no entry conditions');
  return e;
}

class CustomStore {
  static const key = 'custom_strats_v1';
  static int _n = 0;
  static String newId() => 'c${DateTime.now().microsecondsSinceEpoch}_${_n++}';

  static Future<List<CustomStrategy>> all() async {
    final out = <CustomStrategy>[];
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(key);
      if (raw == null) return out;
      for (final x in (jsonDecode(raw) as List)) {
        try {
          out.add(CustomStrategy.fromJson(Map<String, dynamic>.from(x as Map)));
        } catch (_) {}
      }
    } catch (_) {}
    return out;
  }

  static Future<void> _save(List<CustomStrategy> l) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(key, jsonEncode([for (final s in l) s.toJson()]));
  }

  /// إنشاء أو تعديل. يرجع قائمة الأخطاء (الفارغة = حُفظت).
  static Future<List<String>> upsert(CustomStrategy s) async {
    final errs = validateCustom(s);
    if (errs.isNotEmpty) return errs;
    final l = await all();
    final i = l.indexWhere((x) => x.id == s.id);
    if (i >= 0) {
      l[i] = s;
    } else {
      l.add(s);
    }
    await _save(l);
    return <String>[];
  }

  static Future<void> delete(String id) async {
    final l = await all();
    l.removeWhere((x) => x.id == id);
    await _save(l);
  }

  static CustomStrategy _copyOf(CustomStrategy src, {String? name}) {
    final m = Map<String, dynamic>.from(jsonDecode(jsonEncode(src.toJson())) as Map);
    m['id'] = newId();
    m['name'] = name ?? src.name;
    m['enabled'] = false;
    return CustomStrategy.fromJson(m);
  }

  static Future<CustomStrategy?> duplicate(String id) async {
    final l = await all();
    final i = l.indexWhere((x) => x.id == id);
    if (i < 0) return null;
    final c = _copyOf(l[i], name: '${l[i].name} (copy)');
    l.add(c);
    await _save(l);
    return c;
  }

  static Future<bool> setEnabled(String id, bool v) async {
    final l = await all();
    final i = l.indexWhere((x) => x.id == id);
    if (i < 0) return false;
    l[i].enabled = v;
    await _save(l);
    return true;
  }

  static Future<String> exportJson() async =>
      jsonEncode([for (final s in await all()) s.toJson()]);

  /// يستورد بمعرفات جديدة وبحالة موقوفة، ويتجاهل غير الصالح. يرجع عدد المستورد.
  static Future<int> importJson(String text) async {
    List raw;
    try {
      raw = jsonDecode(text) as List;
    } catch (_) {
      return 0;
    }
    final l = await all();
    var n = 0;
    for (final x in raw) {
      try {
        final c = _copyOf(CustomStrategy.fromJson(Map<String, dynamic>.from(x as Map)));
        if (validateCustom(c).isEmpty) {
          l.add(c);
          n++;
        }
      } catch (_) {}
    }
    await _save(l);
    return n;
  }
}
