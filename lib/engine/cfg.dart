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

  static bool useEma = true;
  static bool useRsi = true;
  static bool useAdx = true;
  static bool useSt = true;
  static bool useCandle = true;
  static bool useSr = true;
  static bool autoTf = true;
  static List<String> tfs = <String>['M1', 'M5', 'M15'];

  static bool _loaded = false;

  static const allTfs = ['M1', 'M2', 'M3', 'M5', 'M10', 'M15', 'M30'];
  static const _tfMin = {
    'M1': 1, 'M2': 2, 'M3': 3, 'M5': 5, 'M10': 10, 'M15': 15, 'M30': 30,
  };
  static int tfMinutes(String t) => _tfMin[t] ?? 0;

  static const keys = [
    'ema1', 'ema2', 'rsiP', 'rsiUp', 'rsiDown', 'adxP', 'adxMin',
    'stP', 'stM', 'atrP', 'minScore',
    'useEma', 'useRsi', 'useAdx', 'useSt', 'useCandle', 'useSr', 'autoTf', 'tfs',
  ];

  static bool get anyOn =>
      useEma || useRsi || useAdx || useSt || useCandle || useSr;

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
      case 'useEma':
        return useEma ? '1' : '0';
      case 'useRsi':
        return useRsi ? '1' : '0';
      case 'useAdx':
        return useAdx ? '1' : '0';
      case 'useSt':
        return useSt ? '1' : '0';
      case 'useCandle':
        return useCandle ? '1' : '0';
      case 'useSr':
        return useSr ? '1' : '0';
      case 'autoTf':
        return autoTf ? '1' : '0';
      case 'tfs':
        return tfs.join(',');
    }
    return '';
  }

  static void set(String k, String raw) {
    final s0 = raw.trim();
    final s = s0.replaceAll(',', '.');
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
      case 'useEma':
        useEma = s0 != '0';
        break;
      case 'useRsi':
        useRsi = s0 != '0';
        break;
      case 'useAdx':
        useAdx = s0 != '0';
        break;
      case 'useSt':
        useSt = s0 != '0';
        break;
      case 'useCandle':
        useCandle = s0 != '0';
        break;
      case 'useSr':
        useSr = s0 != '0';
        break;
      case 'autoTf':
        autoTf = s0 != '0';
        break;
      case 'tfs':
        final l = s0
            .split(',')
            .map((e) => e.trim())
            .where((e) => _tfMin.containsKey(e))
            .toSet()
            .toList();
        l.sort((a, b) => _tfMin[a]!.compareTo(_tfMin[b]!));
        tfs = l.isEmpty ? <String>['M5'] : l;
        break;
    }
  }

  static void presetOriginal() {
    useEma = true;
    useRsi = true;
    useAdx = true;
    useSt = true;
    useCandle = true;
    useSr = true;
    autoTf = true;
    tfs = <String>['M1', 'M5', 'M15'];
  }

  static void presetEmaRsi() {
    useEma = true;
    useRsi = true;
    useAdx = false;
    useSt = false;
    useCandle = false;
    useSr = false;
    autoTf = false;
    tfs = <String>['M5'];
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
      if (!anyOn) presetOriginal();
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
    presetOriginal();
    await save();
  }

  static String summary() {
    final on = <String>[];
    if (useEma) on.add('EMA $ema1/$ema2');
    if (useRsi) on.add('RSI $rsiP ($rsiDown/$rsiUp)');
    if (useAdx) on.add('ADX $adxP >$adxMin');
    if (useSt) on.add('ST $stP×$stM');
    if (useCandle) on.add('Candles');
    if (useSr) on.add('S/R');
    final tf = autoTf ? 'auto' : tfs.join('+');
    return '${on.join(' • ')} | TF $tf | ≥$minScore/10';
  }

  static String activeLine() {
    final on = <String>[];
    if (useEma) on.add('EMA');
    if (useRsi) on.add('RSI');
    if (useAdx) on.add('ADX');
    if (useSt) on.add('ST');
    if (useCandle) on.add('Candles');
    if (useSr) on.add('S/R');
    final tf = autoTf ? 'Auto' : tfs.join('+');
    return '${on.join(' + ')}  •  $tf';
  }
}
