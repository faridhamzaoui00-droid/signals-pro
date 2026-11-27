// منشئ الشروط (المراحل 3-4): شروط ومجموعات AND/OR متداخلة وتقييم على شموع مغلقة فقط.
import 'dart:convert';
import '../strat/core.dart';
import 'ind_lib.dart';

const kOps = ['>', '<', '>=', '<='];
const kKinds = ['cmp', 'crossUp', 'crossDown'];

abstract class Node {
  Map<String, dynamic> toJson();
  static Node fromJson(Map<String, dynamic> m) {
    final t = m['type'];
    if (t == 'cond') return Cond.fromJson(m);
    if (t == 'group') return Group.fromJson(m);
    throw FormatException('unknown node type: $t');
  }
}

/// شرط مفرد. المرجع: 'price.close' أو '<مفتاح المؤشر>.<المخرج>' مثل 'rsi1.value'.
/// إما right (سلسلة) أو level (رقم)، وليس الاثنين معاً.
class Cond extends Node {
  final String kind; // cmp | crossUp | crossDown
  final String left;
  final String? right;
  final double? level;
  final String op; // للمقارنة فقط
  Cond({required this.kind, required this.left, this.right, this.level, this.op = '>'}) {
    if (!kKinds.contains(kind)) throw FormatException('bad kind: $kind');
    if (!kOps.contains(op)) throw FormatException('bad op: $op');
    if ((right == null) == (level == null)) {
      throw const FormatException('condition needs exactly one of right/level');
    }
  }
  factory Cond.fromJson(Map<String, dynamic> m) => Cond(
        kind: m['kind'] as String,
        left: m['left'] as String,
        right: m['right'] as String?,
        level: (m['level'] as num?)?.toDouble(),
        op: (m['op'] ?? '>') as String,
      );
  @override
  Map<String, dynamic> toJson() => {
        'type': 'cond',
        'kind': kind,
        'left': left,
        if (right != null) 'right': right,
        if (level != null) 'level': level,
        'op': op,
      };
}

class Group extends Node {
  String op; // AND | OR
  final List<Node> items;
  Group(this.op, [List<Node>? items]) : items = items ?? <Node>[] {
    if (op != 'AND' && op != 'OR') throw FormatException('bad group op: $op');
  }
  factory Group.fromJson(Map<String, dynamic> m) => Group(
        m['op'] as String,
        [for (final x in (m['items'] as List)) Node.fromJson(Map<String, dynamic>.from(x as Map))],
      );
  @override
  Map<String, dynamic> toJson() => {
        'type': 'group',
        'op': op,
        'items': [for (final x in items) x.toJson()],
      };
}

/// نسخة مؤشر داخل استراتيجية (إعداداتها مستقلة عن أي استراتيجية أخرى).
class IndUse {
  final String key; // مثل rsi1
  final String id; // معرف المكتبة مثل rsi
  final Map<String, num> params;
  IndUse(this.key, this.id, [Map<String, num>? params]) : params = params ?? <String, num>{};
  Map<String, dynamic> toJson() => {'key': key, 'id': id, 'params': params};
  factory IndUse.fromJson(Map<String, dynamic> m) => IndUse(
        m['key'] as String,
        m['id'] as String,
        {for (final e in (m['params'] as Map).entries) e.key.toString(): e.value as num},
      );
}

class StrategyDef {
  String name;
  final List<IndUse> inds;
  Group up;
  Group down;
  StrategyDef(this.name, this.inds, this.up, this.down);
  Map<String, dynamic> toJson() => {
        'name': name,
        'inds': [for (final u in inds) u.toJson()],
        'up': up.toJson(),
        'down': down.toJson(),
      };
  String toJsonString() => jsonEncode(toJson());
  factory StrategyDef.fromJson(Map<String, dynamic> m) => StrategyDef(
        m['name'] as String,
        [for (final u in (m['inds'] as List)) IndUse.fromJson(Map<String, dynamic>.from(u as Map))],
        Group.fromJson(Map<String, dynamic>.from(m['up'] as Map)),
        Group.fromJson(Map<String, dynamic>.from(m['down'] as Map)),
      );
  factory StrategyDef.fromJsonString(String s) =>
      StrategyDef.fromJson(Map<String, dynamic>.from(jsonDecode(s) as Map));
}

// ---------------- التقييم ----------------
bool _evalCond(Cond c, Map<String, List<double>> s, int i) {
  final a = s[c.left];
  if (a == null || i < 0 || i >= a.length) return false;
  List<double>? b;
  if (c.right != null) {
    b = s[c.right!];
    if (b == null || i >= b.length) return false;
  }
  final av = a[i];
  if (!av.isFinite) return false; // فترة تهيئة أو بيانات ناقصة: لا إشارة
  switch (c.kind) {
    case 'cmp':
      final bv = b != null ? b[i] : c.level!;
      if (!bv.isFinite) return false;
      switch (c.op) {
        case '>':
          return av > bv;
        case '<':
          return av < bv;
        case '>=':
          return av >= bv;
        default:
          return av <= bv;
      }
    case 'crossUp':
      return b != null ? crossUp(a, b, i) : crossAboveLevel(a, c.level!, i);
    case 'crossDown':
      return b != null ? crossDown(a, b, i) : crossBelowLevel(a, c.level!, i);
  }
  return false;
}

bool evalNode(Node n, Map<String, List<double>> s, int i) {
  if (n is Cond) return _evalCond(n, s, i);
  final g = n as Group;
  if (g.items.isEmpty) return false; // مجموعة فارغة لا تصدر إشارة
  if (g.op == 'AND') {
    for (final x in g.items) {
      if (!evalNode(x, s, i)) return false;
    }
    return true;
  }
  for (final x in g.items) {
    if (evalNode(x, s, i)) return true;
  }
  return false;
}

/// المراجع الناقصة في شجرة الشروط (للتحقق قبل الحفظ والتشغيل).
List<String> missingRefs(Node n, Set<String> have) {
  final out = <String>[];
  if (n is Cond) {
    if (!have.contains(n.left)) out.add(n.left);
    if (n.right != null && !have.contains(n.right!)) out.add(n.right!);
  } else {
    for (final x in (n as Group).items) {
      out.addAll(missingRefs(x, have));
    }
  }
  return out;
}

Map<String, List<double>> buildSeries(StrategyDef d, Bars b) {
  final s = <String, List<double>>{
    'price.open': b.o,
    'price.high': b.h,
    'price.low': b.l,
    'price.close': b.c,
  };
  for (final u in d.inds) {
    final def = kIndicatorLib.firstWhere((x) => x.id == u.id,
        orElse: () => throw ArgumentError('unknown indicator ${u.id}'));
    final out = def.calc(b, <String, num>{...def.params, ...u.params});
    for (final e in out.entries) {
      s['${u.key}.${e.key}'] = e.value;
    }
  }
  return s;
}

/// أخطاء التعريف: مفاتيح مكررة أو مراجع ناقصة. القائمة الفارغة = صالح.
List<String> validateStrategy(StrategyDef d, Map<String, List<double>> series) {
  final errs = <String>[];
  final keys = <String>{};
  for (final u in d.inds) {
    if (!keys.add(u.key)) errs.add('duplicate indicator key: ${u.key}');
  }
  final have = series.keys.toSet();
  errs.addAll(missingRefs(d.up, have).map((r) => 'UP: missing $r'));
  errs.addAll(missingRefs(d.down, have).map((r) => 'DOWN: missing $r'));
  return errs;
}

/// UP | DOWN | NONE | CONFLICT عند الشمعة i (يستعمل i و i-1 فقط).
String evalAt(StrategyDef d, Map<String, List<double>> s, int i) {
  final up = evalNode(d.up, s, i), dn = evalNode(d.down, s, i);
  if (up && dn) return 'CONFLICT';
  return up ? 'UP' : (dn ? 'DOWN' : 'NONE');
}

/// على آخر شمعة مغلقة في الشموع المعطاة.
String evalStrategy(StrategyDef d, Bars b) => evalAt(d, buildSeries(d, b), b.n - 1);
