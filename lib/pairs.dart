// قائمة أزواج Pocket Option المعتمدة (60 زوجاً). لا يُضاف إليها شيء من خارج الصور.
// الزوج العادي وزوج OTC أداتان منفصلتان.
const List<String> kPocketOptionPairs = <String>[
  'AED/CNY OTC',
  'AUD/CHF OTC',
  'CAD/CHF OTC',
  'CHF/JPY OTC',
  'EUR/JPY OTC',
  'KES/USD OTC',
  'MAD/USD OTC',
  'NGN/USD OTC',
  'OMR/CNY OTC',
  'QAR/CNY OTC',
  'USD/CHF OTC',
  'USD/DZD OTC',
  'USD/INR OTC',
  'USD/SGD OTC',
  'USD/THB OTC',
  'ZAR/USD OTC',
  'CHF/NOK OTC',
  'EUR/HUF OTC',
  'CAD/JPY OTC',
  'USD/CLP OTC',
  'EUR/CHF',
  'USD/CHF',
  'AUD/JPY',
  'AUD/CAD OTC',
  'AUD/USD',
  'LBP/USD OTC',
  'USD/CAD',
  'AUD/CAD',
  'AUD/USD OTC',
  'UAH/USD OTC',
  'USD/CNH OTC',
  'SAR/CNY OTC',
  'USD/JPY',
  'USD/MXN OTC',
  'USD/MYR OTC',
  'EUR/TRY OTC',
  'BHD/CNY OTC',
  'USD/EGP OTC',
  'USD/RUB OTC',
  'CAD/CHF',
  'EUR/JPY',
  'USD/JPY OTC',
  'USD/PKR OTC',
  'CHF/JPY',
  'EUR/USD',
  'USD/IDR OTC',
  'YER/USD OTC',
  'USD/ARS OTC',
  'USD/VND OTC',
  'TND/USD OTC',
  'USD/BRL OTC',
  'USD/CAD OTC',
  'USD/BDT OTC',
  'EUR/RUB OTC',
  'EUR/CHF OTC',
  'AUD/CHF',
  'USD/COP OTC',
  'EUR/USD OTC',
  'EUR/CAD',
  'EUR/AUD',
];

/// تحويل اسم الزوج كما يظهر في المنصة إلى رمزه: "EUR/USD OTC" -> "EURUSD_otc"
/// و"EUR/USD" -> "EURUSD". يقبل أيضاً الصيغة القديمة بدون شرطة ("EURUSD OTC").
String poSymbolOf(String label) =>
    label.replaceAll('/', '').replaceAll(' OTC', '_otc');

bool isOtcPair(String label) => label.endsWith(' OTC');

String _norm(String s) =>
    s.toLowerCase().replaceAll('/', '').replaceAll(' ', '').replaceAll('_', '');

/// يعيد الاسم المعتمد للزوج (يدعم الصيغة القديمة)، أو null إذا لم يكن في القائمة.
String? canonicalPair(String? label) {
  if (label == null) return null;
  final key = poSymbolOf(label.trim()).toLowerCase();
  for (final p in kPocketOptionPairs) {
    if (poSymbolOf(p).toLowerCase() == key) return p;
  }
  return null;
}

/// ترحيل قائمة محفوظة: يحوّل الصيغة القديمة ويحذف ما ليس في القائمة المعتمدة ويزيل التكرار.
List<String> migratePairs(List<String> saved) {
  final out = <String>[];
  for (final s in saved) {
    final c = canonicalPair(s);
    if (c != null && !out.contains(c)) out.add(c);
  }
  return out;
}

/// بحث لا يتأثر بالشرطة أو المسافات أو حالة الأحرف: "eurusd" يطابق "EUR/USD" و"EUR/USD OTC".
List<String> filterPairs(String query) {
  final q = _norm(query);
  if (q.isEmpty) return List<String>.from(kPocketOptionPairs);
  return kPocketOptionPairs.where((p) => _norm(p).contains(q)).toList();
}
