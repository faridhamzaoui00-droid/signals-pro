import 'dart:math' as math;
import 'core.dart';

// ======================= 1) MA20 + ZigZag + RSI =======================
class Strategy1 extends StrategyBase {
  Strategy1([Map<String, dynamic>? o]) : super(_d, o);
  static const Map<String, dynamic> _d = {
    'ma_period': 20,
    'ma_type': 'sma',
    'rsi_period': 14,
    'atr_period': 14,
    'rsi_sell_below': 50.0,
    'rsi_buy_above': 50.0,
    'zigzag_mode': 'atr',
    'zigzag_atr_mult': 1.5,
    'zigzag_percent': 0.05,
    'max_cross_age_bars': 8,
    'require_close_side': true,
    'expiry_seconds': 60,
    'min_confidence': 5.0,
    'min_candles': 80,
  };
  @override
  String get id => 'STRATEGY_1';
  @override
  String get name => 'MA20_ZIGZAG_RSI';

  @override
  StratResult doEvaluate(Bars df, String symbol, int tf) {
    final c = df.c, h = df.h, l = df.l;
    final ma = movingAverage(c, si('ma_period'), ss('ma_type'));
    final rsiV = rsiArr(c, si('rsi_period'));
    final atrV = atrArr(df, si('atr_period'));
    final last = df.n - 1;
    if (!(ma[last].isFinite && rsiV[last].isFinite && atrV[last].isFinite)) {
      return StratResult.wait('INDICATORS_NOT_READY');
    }
    final thr = zigzagThreshold(c, atrV, ss('zigzag_mode'), sd('zigzag_atr_mult'), sd('zigzag_percent'));
    final pivots = zigzagPivots(h, l, thr);
    int k = -1;
    for (var i = pivots.length - 1; i > 0; i--) {
      if (pivots[i].confirmedIndex == last) {
        k = i;
        break;
      }
    }
    if (k < 0) return StratResult.wait('NO_NEW_CONFIRMED_PIVOT');
    final p0 = pivots[k - 1], p1 = pivots[k];
    final cross = segmentMaCross(p0, p1, ma);
    if (cross == null) return StratResult.wait('NO_ZIGZAG_MA_CROSS');
    final age = last - cross.index;
    if (age > si('max_cross_age_bars')) return StratResult.wait('CROSS_TOO_OLD');
    final direction = cross.dir == 'DOWN' ? 'SELL' : 'BUY';
    final r = rsiV[last];
    if (direction == 'SELL') {
      if (!(r < sd('rsi_sell_below'))) return StratResult.wait('RSI_NOT_CONFIRMING');
      if (sb('require_close_side') && !(c[last] < ma[last])) return StratResult.wait('CLOSE_NOT_BELOW_MA');
    } else {
      if (!(r > sd('rsi_buy_above'))) return StratResult.wait('RSI_NOT_CONFIRMING');
      if (sb('require_close_side') && !(c[last] > ma[last])) return StratResult.wait('CLOSE_NOT_ABOVE_MA');
    }
    final a = atrV[last];
    final comps = <String, double>{
      'trend_strength': slopeAlignment(ma, a, direction),
      'zone_strength': clip01((p1.price - p0.price).abs() / a / 4.0),
      'candle_confirmation': clip01((c[last] - ma[last]).abs() / a / 0.5),
      'indicator_agreement': clip01((r - 50.0).abs() / 20.0),
    };
    final seq1 = df.seq[p1.index];
    final reason = 'ZigZag ${p0.kind}->${p1.kind} crossed MA${si('ma_period')} ${cross.dir} $age bar(s) ago; RSI=${r.toStringAsFixed(1)}';
    return emit(df, symbol, tf, direction, comps, reason, '$direction:pivot$seq1',
        {'rsi': r, 'cross_bars_ago': age});
  }
}

// ======================= 2) Market Structure + MA20 + S/R =======================
class Strategy2 extends StrategyBase {
  Strategy2([Map<String, dynamic>? o]) : super(_d, o);
  static const Map<String, dynamic> _d = {
    'ma_period': 20,
    'ma_type': 'ema',
    'atr_period': 14,
    'rsi_period': 14,
    'swing_left': 3,
    'swing_right': 3,
    'swing_lookback_bars': 150,
    'max_entry_wait_bars': 10,
    'ma_retest_margin_atr': 0.25,
    'level_zone_atr': 0.3,
    'min_room_atr': 1.2,
    'max_extension_atr': 2.5,
    'chop_lookback': 20,
    'chop_cross_limit': 6,
    'require_momentum': true,
    'rsi_sell_below': 50.0,
    'rsi_buy_above': 50.0,
    'expiry_seconds': 60,
    'min_confidence': 6.0,
    'min_candles': 100,
  };
  @override
  String get id => 'STRATEGY_2';
  @override
  String get name => 'MARKET_STRUCTURE_MA20_SR';
  @override
  Map<String, dynamic> freshState() => <String, dynamic>{'pending': null};

  List<double> _neg(List<double> x) => [for (final v in x) -v];

  @override
  StratResult doEvaluate(Bars df, String symbol, int tf) {
    final st = state(symbol, tf);
    final o = df.o, h = df.h, l = df.l, c = df.c;
    final ma = movingAverage(c, si('ma_period'), ss('ma_type'));
    final aArr = atrArr(df, si('atr_period'));
    final rsiA = rsiArr(c, si('rsi_period'));
    final n = df.n, last = n - 1;
    final a = aArr[last], m = ma[last];
    if (!(a.isFinite && a > 0 && m.isFinite) || !rsiA[last].isFinite) {
      return StratResult.wait('INDICATORS_NOT_READY');
    }
    final seq = df.seq[last];
    final swings = detectSwings(h, l, si('swing_left'), si('swing_right'))
        .where((s) => s.index >= n - si('swing_lookback_bars'))
        .toList();
    final ti = classifyTrend(swings);
    final event = structureEvent(c, swings, ti.trend);
    var p = st['pending'] as Map<String, dynamic>?;

    final cross = maCrossAt(c, ma, last);
    if (cross != null) {
      final want = cross == 'DOWN' ? 'SELL' : 'BUY';
      if ((want == 'SELL' && ti.trend == 'DOWN') || (want == 'BUY' && ti.trend == 'UP')) {
        st['pending'] = <String, dynamic>{'dir': want, 'break_seq': seq};
        return StratResult.wait('MA_BREAK_DETECTED_WAITING_ENTRY_ZONE');
      }
      if (p != null && p['dir'] != want) {
        st['pending'] = null;
        p = null;
      }
    }
    if (p == null) {
      return StratResult.wait(ti.trend == 'SIDEWAYS' ? 'SIDEWAYS_MARKET' : 'NO_MA_BREAK_SETUP');
    }
    final d = p['dir'] as String;
    if (ti.trend != (d == 'SELL' ? 'DOWN' : 'UP')) {
      st['pending'] = null;
      return StratResult.wait('STRUCTURE_CHANGED');
    }
    if (seq - (p['break_seq'] as int) > si('max_entry_wait_bars')) {
      st['pending'] = null;
      return StratResult.wait('ENTRY_ZONE_TIMEOUT');
    }
    if (countMaCrossings(c, ma, si('chop_lookback')) > si('chop_cross_limit')) {
      st['pending'] = null;
      return StratResult.wait('CHOPPY_MARKET');
    }

    // نعكس الأسعار للشراء فيعمل منطق البيع للجهتين
    List<double> O, H, L, C, M;
    List<Swing> hs, ls;
    double rsiS;
    if (d == 'SELL') {
      O = o; H = h; L = l; C = c; M = ma;
      hs = [for (final w in swings) if (w.kind == 'HIGH') Swing(w.index, w.price, 'HIGH', w.confirmedIndex)];
      ls = [for (final w in swings) if (w.kind == 'LOW') Swing(w.index, w.price, 'LOW', w.confirmedIndex)];
      rsiS = rsiA[last];
    } else {
      O = _neg(o); H = _neg(l); L = _neg(h); C = _neg(c); M = _neg(ma);
      hs = [for (final w in swings) if (w.kind == 'LOW') Swing(w.index, -w.price, 'HIGH', w.confirmedIndex)];
      ls = [for (final w in swings) if (w.kind == 'HIGH') Swing(w.index, -w.price, 'LOW', w.confirmedIndex)];
      rsiS = 100.0 - rsiA[last];
    }
    final margin = sd('ma_retest_margin_atr') * a;
    if (!(C[last] < M[last])) {
      st['pending'] = null;
      return StratResult.wait('BREAK_FAILED');
    }
    if (!(C[last] < O[last])) return StratResult.wait('NO_CONFIRMING_CANDLE');
    if (sb('require_momentum')) {
      final slopeOk = M[last] < M[last - 3];
      final thr = d == 'SELL' ? sd('rsi_sell_below') : 100.0 - sd('rsi_buy_above');
      if (!(rsiS < thr && slopeOk)) return StratResult.wait('MOMENTUM_NOT_CONFIRMING');
    }

    final zones = <String>[];
    if (H[last] >= M[last] - margin) zones.add('MA_RETEST');
    final lsTail = ls.sublist(math.max(0, ls.length - 5));
    for (final sw in lsTail) {
      var broken = false;
      for (var k = sw.index + 1; k < last; k++) {
        if (C[k] < sw.price - 0.1 * a) {
          broken = true;
          break;
        }
      }
      if (broken && H[last] >= sw.price - margin && H[last] <= sw.price + sd('level_zone_atr') * a && C[last] < sw.price) {
        zones.add('BROKEN_SUPPORT_RETEST');
        break;
      }
    }
    final hsTail = hs.sublist(math.max(0, hs.length - 3));
    for (final sw in hsTail) {
      final z = supplyDemandZone(O, H, L, C, sw, a);
      if (H[last] >= z[0] && C[last] <= (z[0] + z[1]) / 2.0 && sw.index < last - 1) {
        zones.add(d == 'SELL' ? 'SUPPLY_ZONE' : 'DEMAND_ZONE');
        break;
      }
    }
    if (zones.isEmpty) return StratResult.wait('WAITING_ENTRY_ZONE');
    if ((M[last] - C[last]) / a > sd('max_extension_atr')) return StratResult.wait('EXTENDED_MOVE_NO_ENTRY');
    double? keyLevel;
    for (final w in ls) {
      if (w.price < C[last] - 1e-12) {
        if (keyLevel == null || w.price > keyLevel) keyLevel = w.price;
      }
    }
    if (keyLevel != null && (C[last] - keyLevel) / a < sd('min_room_atr')) {
      return StratResult.wait('TOO_CLOSE_TO_OPPOSING_LEVEL');
    }

    final rej = detectRejection(O, H, L, C, last, 'SELL');
    double clarity;
    if (ti.structure == 'LH+LL') {
      clarity = ((ti.prevHigh - ti.lastHigh) / a + (ti.prevLow - ti.lastLow) / a) / 2.0;
    } else {
      clarity = ((ti.lastHigh - ti.prevHigh) / a + (ti.lastLow - ti.prevLow) / a) / 2.0;
    }
    final bos = (event != null && event.startsWith('BOS')) ? 0.2 : 0.0;
    final comps = <String, double>{
      'trend_strength': clip01(0.5 * clip01(clarity / 1.0) + 0.5 * slopeAlignment(ma, a, d) + bos),
      'zone_strength': zones.length >= 2 ? 1.0 : (zones[0] == 'MA_RETEST' ? 0.6 : 0.85),
      'candle_confirmation': clip01(0.5 * bodyFraction(O[last], H[last], L[last], C[last]) + 0.5 * (rej != null ? rej.strength : 0.3)),
      'indicator_agreement': 0.5 * clip01((50.0 - rsiS) / 15.0) + 0.5 * slopeAlignment(ma, a, d),
    };
    final reason = '${d == 'SELL' ? 'Downtrend' : 'Uptrend'} structure, MA${si('ma_period')} break, entry at ${zones.join('+')}';
    final res = emit(df, symbol, tf, d, comps, reason, '$d:break${p['break_seq']}',
        {'trend': ti.trend, 'zones': zones, 'event': event});
    if (res.isSignal || res.reason == 'LOW_CONFIDENCE') st['pending'] = null;
    return res;
  }
}

// ======================= 3) Triple Touch Reversal =======================
class _Cand {
  final double strength;
  final String direction;
  final ZoneState zs;
  final Rejection rej;
  final bool first;
  _Cand(this.strength, this.direction, this.zs, this.rej, this.first);
}

class Strategy3 extends StrategyBase {
  Strategy3([Map<String, dynamic>? o]) : super(_d, o);
  static const Map<String, dynamic> _d = {
    'ma_period': 20,
    'ma_type': 'ema',
    'atr_period': 14,
    'rsi_period': 14,
    'swing_left': 3,
    'swing_right': 3,
    'lookback_bars': 200,
    'zone_atr_mult': 0.35,
    'min_departure_atr': 0.8,
    'break_atr': 0.3,
    'target_touch': 3,
    'allow_first_retest': false,
    'first_retest_min_rejection': 0.75,
    'min_rejection_strength': 0.55,
    'require_close_confirmation': true,
    'chop_lookback': 20,
    'chop_cross_limit': 7,
    'expiry_seconds': 60,
    'min_confidence': 6.0,
    'min_candles': 60,
  };
  @override
  String get id => 'STRATEGY_3';
  @override
  String get name => 'TRIPLE_TOUCH_REVERSAL';

  @override
  StratResult doEvaluate(Bars df, String symbol, int tf) {
    final o = df.o, h = df.h, l = df.l, c = df.c;
    final aArr = atrArr(df, si('atr_period'));
    final ma = movingAverage(c, si('ma_period'), ss('ma_type'));
    final rArr = rsiArr(c, si('rsi_period'));
    final last = df.n - 1;
    if (!(aArr[last].isFinite && ma[last].isFinite && rArr[last].isFinite)) {
      return StratResult.wait('INDICATORS_NOT_READY');
    }
    final a = aArr[last];
    if (countMaCrossings(c, ma, si('chop_lookback')) > si('chop_cross_limit')) {
      return StratResult.wait('CHOPPY_RANDOM_MARKET');
    }
    final swings = detectSwings(h, l, si('swing_left'), si('swing_right'));
    final cands = <_Cand>[];
    final reasons = <String>[];
    for (final dk in const [['SELL', 'RESISTANCE'], ['BUY', 'SUPPORT']]) {
      final direction = dk[0], kind = dk[1];
      final states = findZoneStates(h, l, c, aArr, swings, kind,
          lookback: si('lookback_bars'),
          zoneAtrMult: sd('zone_atr_mult'),
          minDepartureAtr: sd('min_departure_atr'),
          breakAtr: sd('break_atr'));
      for (final zs in states) {
        if (!zs.active) continue;
        if (zs.broken) {
          reasons.add('ZONE_BROKEN_BY_CLOSE');
          continue;
        }
        final tn = zs.touchNo;
        final firstRetest = sb('allow_first_retest') && tn == 2 && si('target_touch') != 2;
        if (tn != si('target_touch') && !firstRetest) {
          reasons.add('TOUCH_${tn}_NOT_TARGET');
          continue;
        }
        final rej = detectRejection(o, h, l, c, last, direction);
        final need = firstRetest ? sd('first_retest_min_rejection') : sd('min_rejection_strength');
        if (rej == null || rej.strength < need) {
          reasons.add('NO_CONFIRMED_REJECTION');
          continue;
        }
        if (sb('require_close_confirmation')) {
          final ok = direction == 'SELL' ? c[last] < zs.zone.center : c[last] > zs.zone.center;
          if (!ok) {
            reasons.add('CLOSE_DOES_NOT_CONFIRM_REJECTION');
            continue;
          }
        }
        cands.add(_Cand(rej.strength, direction, zs, rej, firstRetest));
      }
    }
    if (cands.isEmpty) return StratResult.wait(reasons.isNotEmpty ? reasons[0] : 'NO_ACTIVE_ZONE');
    stableSortBy<_Cand>(cands, (x) => -x.strength);
    StratResult? res;
    for (final cd in cands) {
      final direction = cd.direction, zs = cd.zs, rej = cd.rej;
      final r = rArr[last];
      var rs = 0.0;
      for (final t in zs.touches) {
        rs += clip01(t.reboundAtr / (2 * sd('min_departure_atr')));
      }
      final rebound = zs.touches.isEmpty ? double.nan : rs / zs.touches.length;
      final starts = <int>[for (final t in zs.touches) t.startIndex, last];
      var spacing = 0.0;
      if (starts.length > 1) {
        var mn = starts[1] - starts[0];
        for (var i = 2; i < starts.length; i++) {
          final d = starts[i] - starts[i - 1];
          if (d < mn) mn = d;
        }
        spacing = clip01(mn / 6.0);
      }
      final turning = direction == 'SELL' ? (r < rArr[last - 1]) : (r > rArr[last - 1]);
      final stretch = clip01((direction == 'SELL' ? (r - 50.0) : (50.0 - r)) / 20.0);
      final comps = <String, double>{
        'trend_strength': 0.5 + 0.5 * slopeAlignment(ma, a, direction),
        'zone_strength': 0.6 * rebound + 0.4 * spacing,
        'candle_confirmation': rej.strength,
        'indicator_agreement': 0.5 * stretch + 0.5 * (turning ? 1.0 : 0.0),
      };
      final word = direction == 'SELL' ? 'resistance' : 'support';
      final reason = 'Touch #${zs.touchNo} of $word ${zs.zone.center.toStringAsFixed(5)}; ${rej.name} rejection confirmed on close';
      final key = '$direction:${zs.zone.center.toStringAsFixed(6)}:t${zs.touchNo}';
      res = emit(df, symbol, tf, direction, comps, reason, key,
          {'level': zs.zone.center, 'touch': zs.touchNo, 'rejection': rej.name});
      if (res.isSignal) return res;
    }
    return res!;
  }
}

// ======================= 4) MA20 Breakout & Retest =======================
class Strategy4 extends StrategyBase {
  Strategy4([Map<String, dynamic>? o]) : super(_d, o);
  static const Map<String, dynamic> _d = {
    'ma_period': 20,
    'ma_type': 'ema',
    'atr_period': 14,
    'rsi_period': 14,
    'min_bars_before_break': 3,
    'clear_close_atr': 0.1,
    'require_full_candle_beyond': false,
    'retest_margin_atr': 0.25,
    'max_retest_bars': 8,
    'max_confirm_bars': 5,
    'confirm_on_retest_bar': false,
    'chop_lookback': 20,
    'chop_cross_limit': 6,
    'cooldown_bars': null,
    'expiry_seconds': 60,
    'min_confidence': 5.0,
    'min_candles': 60,
  };
  @override
  String get id => 'STRATEGY_4';
  @override
  String get name => 'MA20_BREAKOUT_RETEST';
  @override
  Map<String, dynamic> freshState() =>
      <String, dynamic>{'pending': null, 'cooldown_until': -1};

  @override
  StratResult doEvaluate(Bars df, String symbol, int tf) {
    final st = state(symbol, tf);
    final o = df.o, h = df.h, l = df.l, c = df.c;
    final ma = movingAverage(c, si('ma_period'), ss('ma_type'));
    final aArr = atrArr(df, si('atr_period'));
    final rArr = rsiArr(c, si('rsi_period'));
    final last = df.n - 1;
    final a = aArr[last], m = ma[last];
    if (!(a.isFinite && a > 0 && m.isFinite)) return StratResult.wait('INDICATORS_NOT_READY');
    final seq = df.seq[last];
    if (seq <= (st['cooldown_until'] as int)) {
      st['pending'] = null;
      return StratResult.wait('COOLDOWN_AFTER_SIGNAL');
    }
    var p = st['pending'] as Map<String, dynamic>?;

    if (p == null) {
      final need = si('min_bars_before_break');
      final clear = sd('clear_close_atr') * a;
      var allBelow = true, allAbove = true;
      for (var k = last - need; k < last; k++) {
        if (!(c[k] < ma[k])) allBelow = false;
        if (!(c[k] > ma[k])) allAbove = false;
      }
      String d;
      if (allBelow && c[last] > m + clear && (!sb('require_full_candle_beyond') || l[last] > m)) {
        d = 'BUY';
      } else if (allAbove && c[last] < m - clear && (!sb('require_full_candle_beyond') || h[last] < m)) {
        d = 'SELL';
      } else {
        return StratResult.wait('NO_BREAKOUT');
      }
      var run = 0;
      for (var k = last - 1; k > math.max(last - 16, -1); k--) {
        if ((d == 'BUY' && c[k] < ma[k]) || (d == 'SELL' && c[k] > ma[k])) {
          run++;
        } else {
          break;
        }
      }
      st['pending'] = <String, dynamic>{
        'dir': d,
        'break_seq': seq,
        'retest_seq': null,
        'break_dist_atr': (c[last] - m).abs() / a,
        'bars_before': run,
        'retest_dist_atr': 0.0,
      };
      return StratResult.wait('BREAKOUT_DETECTED_WAITING_RETEST');
    }

    final d = p['dir'] as String;
    final sign = d == 'BUY' ? 1 : -1;
    final breakSeq = p['break_seq'] as int;
    if ((c[last] - m) * sign < 0) {
      st['pending'] = null;
      return StratResult.wait(seq - breakSeq <= 1 ? 'FAKE_BREAKOUT' : 'RETEST_FAILED');
    }
    if (countMaCrossings(c, ma, si('chop_lookback')) > si('chop_cross_limit')) {
      st['pending'] = null;
      return StratResult.wait('CHOPPY_AROUND_MA');
    }
    final margin = sd('retest_margin_atr') * a;
    final candleOk = d == 'BUY' ? c[last] > o[last] : c[last] < o[last];

    if (p['retest_seq'] == null) {
      if (seq - breakSeq > si('max_retest_bars')) {
        st['pending'] = null;
        return StratResult.wait('RETEST_TIMEOUT');
      }
      final touched = d == 'BUY' ? (l[last] <= m + margin) : (h[last] >= m - margin);
      if (!touched) return StratResult.wait('WAITING_RETEST');
      p['retest_seq'] = seq;
      p['retest_dist_atr'] = ((d == 'BUY' ? l[last] : h[last]) - m).abs() / a;
      if (!(sb('confirm_on_retest_bar') && candleOk)) {
        return StratResult.wait('RETEST_DETECTED_WAITING_CONFIRMATION');
      }
    } else {
      if (seq - (p['retest_seq'] as int) > si('max_confirm_bars')) {
        st['pending'] = null;
        return StratResult.wait('CONFIRMATION_TIMEOUT');
      }
      if (!candleOk) return StratResult.wait('WAITING_CONFIRMATION');
    }

    final r = rArr[last].isFinite ? rArr[last] : 50.0;
    final comps = <String, double>{
      'trend_strength': clip01(0.5 * clip01((p['break_dist_atr'] as double) / 1.0) + 0.5 * clip01((p['bars_before'] as int) / 8.0)),
      'zone_strength': clip01(1.0 - (p['retest_dist_atr'] as double) / math.max(sd('retest_margin_atr') * 2, 1e-9)),
      'candle_confirmation': clip01(0.6 * bodyFraction(o[last], h[last], l[last], c[last]) + 0.4 * clip01((c[last] - m).abs() / a / 0.5)),
      'indicator_agreement': 0.5 * slopeAlignment(ma, a, d) + 0.5 * clip01(((r - 50.0) * sign) / 15.0),
    };
    final word = d == 'BUY' ? 'upward' : 'downward';
    final reason = 'MA${si('ma_period')} $word breakout, successful retest and ${d == 'BUY' ? 'bullish' : 'bearish'} confirmation';
    final res = emit(df, symbol, tf, d, comps, reason, '$d:break$breakSeq',
        {'bars_from_breakout': seq - breakSeq});
    int cd;
    final cdv = settings['cooldown_bars'];
    if (cdv == null) {
      cd = math.max(1, (expiryFor(tf) / tf).ceil());
    } else {
      cd = (cdv as num).toInt();
    }
    if (res.isSignal) {
      st['cooldown_until'] = seq + cd;
      st['pending'] = null;
    } else if (res.reason == 'LOW_CONFIDENCE') {
      st['pending'] = null;
    }
    return res;
  }
}

// ======================= 5) Multi-Touch S/R Reversal =======================
class Strategy5 extends StrategyBase {
  Strategy5([Map<String, dynamic>? o]) : super(_d, o);
  static const Map<String, dynamic> _d = {
    'ma_period': 20,
    'ma_type': 'ema',
    'atr_period': 14,
    'rsi_period': 14,
    'profiles': {
      '5': {'swing': 4, 'zone_atr_mult': 0.60, 'min_departure_atr': 1.0, 'min_rejection': 0.70, 'lookback': 240, 'max_push_atr': 2.0},
      '15': {'swing': 4, 'zone_atr_mult': 0.50, 'min_departure_atr': 0.9, 'min_rejection': 0.65, 'lookback': 220, 'max_push_atr': 2.2},
      '30': {'swing': 3, 'zone_atr_mult': 0.45, 'min_departure_atr': 0.9, 'min_rejection': 0.60, 'lookback': 200, 'max_push_atr': 2.4},
      '60': {'swing': 3, 'zone_atr_mult': 0.40, 'min_departure_atr': 0.8, 'min_rejection': 0.55, 'lookback': 200, 'max_push_atr': 2.5},
      '300': {'swing': 3, 'zone_atr_mult': 0.35, 'min_departure_atr': 0.7, 'min_rejection': 0.55, 'lookback': 180, 'max_push_atr': 2.5},
      '900': {'swing': 2, 'zone_atr_mult': 0.30, 'min_departure_atr': 0.6, 'min_rejection': 0.50, 'lookback': 150, 'max_push_atr': 2.8},
    },
    'fallback_profile': {'swing': 3, 'zone_atr_mult': 0.40, 'min_departure_atr': 0.8, 'min_rejection': 0.55, 'lookback': 200, 'max_push_atr': 2.5},
    'break_atr': 0.3,
    'allowed_touches': [2, 3],
    'first_retest_min_rejection': 0.75,
    'first_retest_min_rebound_atr': 1.5,
    'push_lookback': 3,
    'weights': {
      'trend_strength': 0.20,
      'zone_strength': 0.30,
      'candle_confirmation': 0.25,
      'indicator_agreement': 0.15,
      'data_quality': 0.10,
    },
    'expiry_seconds': null,
    'min_confidence': 6.0,
    'min_candles': 60,
  };
  @override
  String get id => 'STRATEGY_5';
  @override
  String get name => 'MULTI_TOUCH_REVERSAL';

  @override
  StratResult doEvaluate(Bars df, String symbol, int tf) {
    final profiles = settings['profiles'] as Map;
    final pf = (profiles['$tf'] ?? settings['fallback_profile']) as Map;
    double pd(String k) => (pf[k] as num).toDouble();
    int pi(String k) => (pf[k] as num).toInt();
    final o = df.o, h = df.h, l = df.l, c = df.c;
    final aArr = atrArr(df, si('atr_period'));
    final ma = movingAverage(c, si('ma_period'), ss('ma_type'));
    final rArr = rsiArr(c, si('rsi_period'));
    final last = df.n - 1;
    if (!(aArr[last].isFinite && ma[last].isFinite && rArr[last].isFinite)) {
      return StratResult.wait('INDICATORS_NOT_READY');
    }
    final a = aArr[last];
    final swings = detectSwings(h, l, pi('swing'), pi('swing'));
    final lb = si('push_lookback');
    final allowed = [for (final x in (settings['allowed_touches'] as List)) (x as num).toInt()];
    final cands = <_Cand>[];
    final reasons = <String>[];
    for (final dk in const [['SELL', 'RESISTANCE'], ['BUY', 'SUPPORT']]) {
      final direction = dk[0], kind = dk[1];
      var push = (c[last - 1] - c[last - 1 - lb]) / a;
      push = direction == 'SELL' ? push : -push;
      final states = findZoneStates(h, l, c, aArr, swings, kind,
          lookback: pi('lookback'),
          zoneAtrMult: pd('zone_atr_mult'),
          minDepartureAtr: pd('min_departure_atr'),
          breakAtr: sd('break_atr'));
      for (final zs in states) {
        if (!zs.active) continue;
        if (zs.broken) {
          reasons.add('ZONE_INVALIDATED_BY_BREAKOUT');
          continue;
        }
        final tn = zs.touchNo;
        if (!allowed.contains(tn)) {
          reasons.add('TOUCH_${tn}_NOT_ALLOWED');
          continue;
        }
        if (push >= pd('max_push_atr')) {
          reasons.add('STRONG_BREAKOUT_MOMENTUM');
          continue;
        }
        final rej = detectRejection(o, h, l, c, last, direction);
        double need;
        if (tn == 2) {
          need = math.max(sd('first_retest_min_rejection'), pd('min_rejection'));
          var mnR = zs.touches[0].reboundAtr;
          for (final t in zs.touches) {
            if (t.reboundAtr < mnR) mnR = t.reboundAtr;
          }
          if (mnR < sd('first_retest_min_rebound_atr')) {
            reasons.add('FIRST_REBOUND_TOO_WEAK');
            continue;
          }
        } else {
          need = pd('min_rejection');
        }
        if (rej == null || rej.strength < need) {
          reasons.add('NO_VALID_REJECTION_CANDLE');
          continue;
        }
        cands.add(_Cand(rej.strength, direction, zs, rej, false));
      }
    }
    if (cands.isEmpty) return StratResult.wait(reasons.isNotEmpty ? reasons[0] : 'NO_ACTIVE_ZONE');
    stableSortBy<_Cand>(cands, (x) => -x.strength);
    StratResult? res;
    for (final cd in cands) {
      final direction = cd.direction, zs = cd.zs, rej = cd.rej;
      final r = rArr[last];
      final tn = zs.touchNo;
      var rs = 0.0;
      for (final t in zs.touches) {
        rs += clip01(t.reboundAtr / (2 * pd('min_departure_atr')));
      }
      final rebound = zs.touches.isEmpty ? double.nan : rs / zs.touches.length;
      final touchesScore = clip01((tn - 1) / 2.0);
      final align = slopeAlignment(ma, a, direction);
      final counter = slopeAlignment(ma, a, direction == 'SELL' ? 'BUY' : 'SELL');
      final comps = <String, double>{
        'trend_strength': clip01(0.6 + 0.4 * align - 0.4 * counter),
        'zone_strength': 0.5 * rebound + 0.5 * touchesScore,
        'candle_confirmation': rej.strength,
        'indicator_agreement': clip01((direction == 'SELL' ? (r - 50.0) : (50.0 - r)) / 20.0),
      };
      final word = direction == 'SELL' ? 'resistance' : 'support';
      final reason = 'Touch #$tn of $word ${zs.zone.center.toStringAsFixed(5)}; ${rej.name} rejection (strength ${rej.strength.toStringAsFixed(2)})';
      final key = '$direction:${zs.zone.center.toStringAsFixed(6)}:t$tn';
      res = emit(df, symbol, tf, direction, comps, reason, key,
          {'zone': zs.zone.center, 'touch': tn, 'rejection': rej.name});
      if (res.isSignal) return res;
    }
    return res!;
  }
}
