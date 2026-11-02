import 'dart:math';

class Candle {
  final int t; // وقت فتح الشمعة بالمللي ثانية
  final double o, h, l, c;
  final bool closed; // true إذا كانت الشمعة مغلقة
  const Candle(this.t, this.o, this.h, this.l, this.c, {this.closed = true});
}

class StResult {
  final List<int?> dir; // 1 صاعد، -1 هابط
  final List<double?> line;
  const StResult(this.dir, this.line);
}

class Ind {
  static List<double?> ema(List<double> v, int p) {
    final out = List<double?>.filled(v.length, null);
    if (v.length < p) return out;
    double s = 0;
    for (var i = 0; i < p; i++) {
      s += v[i];
    }
    var prev = s / p;
    out[p - 1] = prev;
    final k = 2 / (p + 1);
    for (var i = p; i < v.length; i++) {
      prev = v[i] * k + prev * (1 - k);
      out[i] = prev;
    }
    return out;
  }

  static List<double?> rsi(List<double> c, int p) {
    final out = List<double?>.filled(c.length, null);
    if (c.length <= p) return out;
    double g = 0, l = 0;
    for (var i = 1; i <= p; i++) {
      final d = c[i] - c[i - 1];
      if (d > 0) {
        g += d;
      } else {
        l -= d;
      }
    }
    var ag = g / p, al = l / p;
    out[p] = al == 0 ? 100.0 : 100.0 - 100.0 / (1 + ag / al);
    for (var i = p + 1; i < c.length; i++) {
      final d = c[i] - c[i - 1];
      final gg = d > 0 ? d : 0.0;
      final ll = d < 0 ? -d : 0.0;
      ag = (ag * (p - 1) + gg) / p;
      al = (al * (p - 1) + ll) / p;
      out[i] = al == 0 ? 100.0 : 100.0 - 100.0 / (1 + ag / al);
    }
    return out;
  }

  static List<double> _tr(List<Candle> c) {
    final t = <double>[];
    for (var i = 0; i < c.length; i++) {
      if (i == 0) {
        t.add(c[0].h - c[0].l);
      } else {
        final pc = c[i - 1].c;
        t.add(max(c[i].h - c[i].l,
            max((c[i].h - pc).abs(), (c[i].l - pc).abs())));
      }
    }
    return t;
  }

  static List<double?> atr(List<Candle> c, int p) {
    final out = List<double?>.filled(c.length, null);
    if (c.length < p) return out;
    final tr = _tr(c);
    double s = 0;
    for (var i = 0; i < p; i++) {
      s += tr[i];
    }
    var prev = s / p;
    out[p - 1] = prev;
    for (var i = p; i < c.length; i++) {
      prev = (prev * (p - 1) + tr[i]) / p;
      out[i] = prev;
    }
    return out;
  }

  static List<double?> adx(List<Candle> c, int p) {
    final n = c.length;
    final out = List<double?>.filled(n, null);
    if (n < 2 * p) return out;
    final tr = _tr(c);
    final pdm = List<double>.filled(n, 0);
    final mdm = List<double>.filled(n, 0);
    for (var i = 1; i < n; i++) {
      final up = c[i].h - c[i - 1].h;
      final down = c[i - 1].l - c[i].l;
      pdm[i] = (up > down && up > 0) ? up : 0;
      mdm[i] = (down > up && down > 0) ? down : 0;
    }
    double sTr = 0, sP = 0, sM = 0;
    for (var i = 1; i <= p; i++) {
      sTr += tr[i];
      sP += pdm[i];
      sM += mdm[i];
    }
    double dxAt() {
      final pi = sTr == 0 ? 0.0 : 100 * sP / sTr;
      final mi = sTr == 0 ? 0.0 : 100 * sM / sTr;
      final s = pi + mi;
      return s == 0 ? 0.0 : 100 * (pi - mi).abs() / s;
    }

    final dx = List<double>.filled(n, 0);
    dx[p] = dxAt();
    for (var i = p + 1; i < n; i++) {
      sTr = sTr - sTr / p + tr[i];
      sP = sP - sP / p + pdm[i];
      sM = sM - sM / p + mdm[i];
      dx[i] = dxAt();
    }
    double s = 0;
    for (var i = p; i < 2 * p; i++) {
      s += dx[i];
    }
    var prev = s / p;
    out[2 * p - 1] = prev;
    for (var i = 2 * p; i < n; i++) {
      prev = (prev * (p - 1) + dx[i]) / p;
      out[i] = prev;
    }
    return out;
  }

  static StResult superTrend(List<Candle> c, {int p = 10, double m = 3}) {
    final n = c.length;
    final dir = List<int?>.filled(n, null);
    final line = List<double?>.filled(n, null);
    final a = atr(c, p);
    double fu = 0, fl = 0;
    int d = 1;
    var started = false;
    for (var i = 0; i < n; i++) {
      final av = a[i];
      if (av == null) continue;
      final hl2 = (c[i].h + c[i].l) / 2;
      final bu = hl2 + m * av;
      final bl = hl2 - m * av;
      if (!started) {
        fu = bu;
        fl = bl;
        d = c[i].c >= hl2 ? 1 : -1;
        started = true;
      } else {
        final pc = c[i - 1].c;
        final nfu = (bu < fu || pc > fu) ? bu : fu;
        final nfl = (bl > fl || pc < fl) ? bl : fl;
        fu = nfu;
        fl = nfl;
        if (d == -1 && c[i].c > fu) {
          d = 1;
        } else if (d == 1 && c[i].c < fl) {
          d = -1;
        }
      }
      dir[i] = d;
      line[i] = d == 1 ? fl : fu;
    }
    return StResult(dir, line);
  }
}
