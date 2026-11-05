import 'package:shared_preferences/shared_preferences.dart';

class Cfg {
  static int ema1 = 20;
  static int ema2 = 50;
  static int rsiP = 14;
  static int adxP = 14;
  static int atrP = 14;
  static int stP = 10;
  static int minScore = 8;
  static double stM = 3;
  static double rsiUp = 52;
  static double rsiDown = 48;
  static double adxMin = 20;
  static bool _loaded = false;

  static const keys = [
    'ema1', 'ema2', 'rsiP', 'rsiUp', 'rsiDown', 'adxP', 'adxMin',
    'stP', 'stM', 'atrP', 'minScore',
  ];

  static int _ci(int v, int lo, int hi) => v < lo ? lo : (v > hi ? hi : v);
  static double _cd(double v, double lo, double hi) =>
      v < lo ? lo : (v > hi ? hi : v);

  static String get(String k) {
    switch (k) {
      case 'ema1':
        return '$ema1';
      case 'ema2':
        return '$ema2';
      case 'rsiP':
        return '$rsiP';
      case 'rsiUp':
        return '$rsiUp';
      case 'rsiDown':
        return '$rsiDown';
      case 'adxP':
        return '$adxP';
      case 'adxMin':
        return '$adxMin';
      case 'stP':
        return '$stP';
      case 'stM':
        return '$stM';
      case 'atrP':
        return '$atrP';
      case 'minScore':
        return '$minScore';
    }
    return '';
  }

  static void set(String k, String raw) {
    final s = raw.trim().replaceAll(',', '.');
    final i = int.tryParse(s);
    final d = double.tryParse(s);
    switch (k) {
      case 'ema1':
        if (i != null) ema1 = _ci(i, 2, 100);
        break;
      case 'ema2':
        if (i != null) ema2 = _ci(i, 3, 100);
        break;
      case 'rsiP':
        if (i != null) rsiP = _ci(i, 2, 60);
        break;
      case 'rsiUp':
        if (d != null) rsiUp = _cd(d, 50, 90);
        break;
      case 'rsiDown':
        if (d != null) rsiDown = _cd(d, 10, 50);
        break;
      case 'adxP':
        if (i != null) adxP = _ci(i, 2, 50);
        break;
      case 'adxMin':
        if (d != null) adxMin = _cd(d, 5, 60);
        break;
      case 'stP':
        if (i != null) stP = _ci(i, 2, 60);
        break;
      case 'stM':
        if (d != null) stM = _cd(d, 0.5, 10);
        break;
      case 'atrP':
        if (i != null) atrP = _ci(i, 2, 60);
        break;
      case 'minScore':
        if (i != null) minScore = _ci(i, 1, 10);
        break;
    }
  }

  static Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final p = await SharedPreferences.getInstance();
      for (final k in keys) {
        final v = p.getString('cfg_$k');
        if (v != null) set(k, v);
      }
    } catch (_) {}
  }

  static Future<void> save() async {
    try {
      final p = await SharedPreferences.getInstance();
      for (final k in keys) {
        await p.setString('cfg_$k', get(k));
      }
    } catch (_) {}
  }

  static Future<void> reset() async {
    ema1 = 20;
    ema2 = 50;
    rsiP = 14;
    adxP = 14;
    atrP = 14;
    stP = 10;
    stM = 3;
    rsiUp = 52;
    rsiDown = 48;
    adxMin = 20;
    minScore = 8;
    await save();
  }

  static String summary() =>
      'EMA $ema1/$ema2 • RSI $rsiP ($rsiDown/$rsiUp) • ADX $adxP >$adxMin • '
      'ST $stP×$stM • ATR $atrP • ≥$minScore';
}
