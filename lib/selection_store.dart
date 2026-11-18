import 'package:shared_preferences/shared_preferences.dart';
import 'pairs.dart';

/// اختيارات المستخدم الدائمة في الشاشة الرئيسية (الزوج + مدة الصفقة).
/// تُحفظ فور التغيير في SharedPreferences (تخزين دائم على الجهاز، لا ينتهي بمرور الأيام
/// ولا يُمسح بإعادة تشغيل الهاتف). لا تُمسّ إلا عندما يغيّرها المستخدم يدوياً.
class SavedSelection {
  final String? pair;
  final int? duration;
  const SavedSelection(this.pair, this.duration);
}

class SelectionStore {
  static const kPair = 'sel_pair';
  static const kDuration = 'sel_duration';

  /// المدد المسموحة (نفس قائمة الشاشة الرئيسية).
  static const durations = <int>[
    30, 60, 120, 180, 240, 300, 360, 420, 480, 540, 600, 660, 720, 780, 840, 900,
  ];

  static Future<SavedSelection> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final pair = canonicalPair(p.getString(kPair));
      final d = p.getInt(kDuration);
      return SavedSelection(pair, (d != null && durations.contains(d)) ? d : null);
    } catch (_) {
      return const SavedSelection(null, null);
    }
  }

  static Future<void> savePair(String pair) async {
    try {
      final c = canonicalPair(pair);
      if (c == null) return;
      final p = await SharedPreferences.getInstance();
      await p.setString(kPair, c);
    } catch (_) {}
  }

  static Future<void> saveDuration(int seconds) async {
    try {
      if (!durations.contains(seconds)) return;
      final p = await SharedPreferences.getInstance();
      await p.setInt(kDuration, seconds);
    } catch (_) {}
  }
}
