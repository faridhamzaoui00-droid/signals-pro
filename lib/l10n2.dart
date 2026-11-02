import 'l10n.dart';

const Map<String, Map<String, String>> _x = {
  'na_duration': {
    'ar': 'مدة 30 ثانية غير مدعومة: أصغر شمعة متاحة هي دقيقة واحدة',
    'fr': "Durée de 30 s non prise en charge : la plus petite bougie disponible dure 1 minute",
    'en': '30-second duration is unsupported: the smallest candle available is 1 minute',
  },
  'na_connection': {
    'ar': 'الاتصال بمصدر البيانات غير مستقر',
    'fr': 'Connexion à la source instable',
    'en': 'Data source connection is unstable',
  },
  'na_no_data': {
    'ar': 'لا توجد بيانات للإطار {v}',
    'fr': 'Aucune donnée pour {v}',
    'en': 'No data for {v}',
  },
  'na_no_key': {
    'ar': 'أدخل مفتاح مصدر البيانات في الإعدادات',
    'fr': 'Saisissez la clé de la source de données dans les Paramètres',
    'en': 'Enter the data source key in Settings',
  },
  'na_source_error': {
    'ar': 'تعذر جلب البيانات من المصدر',
    'fr': 'Impossible de récupérer les données de la source',
    'en': 'Could not fetch data from the source',
  },
  'na_limit': {
    'ar': 'تجاوزت حد الطلبات لدى المصدر، حاول بعد دقيقة',
    'fr': 'Limite de requêtes de la source atteinte, réessayez dans une minute',
    'en': 'Source request limit reached, try again in a minute',
  },
  'na_net': {
    'ar': 'لا يوجد اتصال بالإنترنت',
    'fr': 'Pas de connexion Internet',
    'en': 'No internet connection',
  },
  'data_short': {
    'ar': 'بيانات الإطار {v} غير كافية',
    'fr': 'Données insuffisantes pour {v}',
    'en': 'Not enough data for {v}',
  },
  'data_future': {
    'ar': 'بيانات الإطار {v} غير متزامنة مع ساعة الجهاز',
    'fr': "Données {v} non synchronisées avec l'horloge de l'appareil",
    'en': '{v} data is out of sync with the device clock',
  },
  'data_stale': {
    'ar': 'بيانات الإطار {v} قديمة (قد يكون السوق مغلقاً)',
    'fr': 'Données {v} anciennes (le marché est peut-être fermé)',
    'en': '{v} data is stale (the market may be closed)',
  },
  'data_dup': {
    'ar': 'شموع مكررة في الإطار {v}',
    'fr': 'Bougies dupliquées dans {v}',
    'en': 'Duplicate candles in {v}',
  },
  'data_gap': {
    'ar': 'شموع ناقصة في الإطار {v}',
    'fr': 'Bougies manquantes dans {v}',
    'en': 'Missing candles in {v}',
  },
  'blk_sideways': {
    'ar': 'السوق عرضي',
    'fr': 'Marché sans tendance',
    'en': 'Sideways market',
  },
  'blk_rsi': {
    'ar': 'RSI = {v} لا يؤيد الاتجاه',
    'fr': "RSI = {v} ne soutient pas la direction",
    'en': 'RSI = {v} does not support the direction',
  },
  'blk_adx': {
    'ar': 'ADX = {v} (يجب أن يتجاوز 20)',
    'fr': 'ADX = {v} (doit dépasser 20)',
    'en': 'ADX = {v} (must exceed 20)',
  },
  'blk_st': {
    'ar': 'SuperTrend يعاكس الاتجاه',
    'fr': 'SuperTrend va à contre-sens',
    'en': 'SuperTrend opposes the direction',
  },
  'blk_no_confirm': {
    'ar': 'لا توجد شمعة تأكيد مغلقة في الاتجاه',
    'fr': 'Pas de bougie de confirmation clôturée dans la direction',
    'en': 'No closed confirmation candle in the direction',
  },
  'blk_level_near': {
    'ar': 'مستوى قوي قريب في الاتجاه المعاكس',
    'fr': 'Niveau fort proche dans le sens opposé',
    'en': 'Strong opposing level nearby',
  },
  'blk_tf_conflict': {
    'ar': 'الإطار {v} يعاكس الاتجاه',
    'fr': 'Le cadre {v} est en conflit',
    'en': 'Timeframe {v} conflicts with the direction',
  },
  'blk_tf_unaligned': {
    'ar': 'الإطار {v} غير متوافق بعد',
    'fr': "Le cadre {v} n'est pas encore aligné",
    'en': 'Timeframe {v} is not aligned yet',
  },
  'blk_extended': {
    'ar': 'السعر ابتعد كثيراً عن EMA (حركة مستهلكة)',
    'fr': "Prix trop éloigné de l'EMA (mouvement épuisé)",
    'en': 'Price too far from EMA (exhausted move)',
  },
  'blk_late': {
    'ar': 'شمعة اندفاع متأخرة',
    'fr': "Bougie d'impulsion tardive",
    'en': 'Late momentum candle',
  },
  'blk_repeat': {
    'ar': 'إشارة مكررة دون تغير حقيقي',
    'fr': 'Signal répété sans changement réel',
    'en': 'Repeated signal without real change',
  },
  'wait_score': {
    'ar': 'التقييم {v}/10 أقل من 8',
    'fr': 'Score {v}/10 inférieur à 8',
    'en': 'Score {v}/10 is below 8',
  },
  'ok_ema': {
    'ar': 'EMA 20/50 متوافقان',
    'fr': 'EMA 20/50 alignées',
    'en': 'EMA 20/50 aligned',
  },
  'ok_rsi': {
    'ar': 'RSI يؤيد الاتجاه',
    'fr': 'RSI soutient la direction',
    'en': 'RSI supports the direction',
  },
  'ok_adx': {
    'ar': 'ADX أعلى من 20',
    'fr': 'ADX supérieur à 20',
    'en': 'ADX above 20',
  },
  'ok_st': {
    'ar': 'SuperTrend متوافق',
    'fr': 'SuperTrend aligné',
    'en': 'SuperTrend aligned',
  },
  'ok_candle': {
    'ar': 'شمعة تأكيد قوية',
    'fr': 'Bougie de confirmation forte',
    'en': 'Strong confirmation candle',
  },
  'ok_sr': {
    'ar': 'لا مستوى معاكس قريب',
    'fr': 'Aucun niveau opposé proche',
    'en': 'No opposing level nearby',
  },
  'ok_sr_mid': {
    'ar': 'مستوى معاكس بعيد نسبياً',
    'fr': 'Niveau opposé assez éloigné',
    'en': 'Opposing level fairly far',
  },
  'ok_retest': {
    'ar': 'إعادة اختبار أو رفض عند مستوى',
    'fr': 'Retest ou rejet sur un niveau',
    'en': 'Retest or rejection at a level',
  },
  'ok_tf': {
    'ar': 'الإطار {v} متوافق',
    'fr': 'Cadre {v} aligné',
    'en': 'Timeframe {v} aligned',
  },
  'sr_none': {
    'ar': 'لا مستوى واضح',
    'fr': 'Aucun niveau net',
    'en': 'No clear level',
  },
  'sr_support_strong': {
    'ar': 'منطقة دعم قوية',
    'fr': 'Forte zone de support',
    'en': 'Strong support zone',
  },
  'sr_support': {
    'ar': 'منطقة دعم',
    'fr': 'Zone de support',
    'en': 'Support zone',
  },
  'sr_res_strong': {
    'ar': 'منطقة مقاومة قوية',
    'fr': 'Forte zone de résistance',
    'en': 'Strong resistance zone',
  },
  'sr_res': {
    'ar': 'منطقة مقاومة',
    'fr': 'Zone de résistance',
    'en': 'Resistance zone',
  },
  'key_title': {
    'ar': 'مفتاح مصدر البيانات (Twelve Data)',
    'fr': 'Clé de la source de données (Twelve Data)',
    'en': 'Data source key (Twelve Data)',
  },
  'key_hint': {
    'ar': 'الصق مفتاح API هنا',
    'fr': "Collez la clé API ici",
    'en': 'Paste the API key here',
  },
  'key_saved': {
    'ar': 'المفتاح: محفوظ مشفراً على هذا الجهاز',
    'fr': 'Clé : enregistrée, chiffrée sur cet appareil',
    'en': 'Key: saved, encrypted on this device',
  },
  'key_missing': {
    'ar': 'المفتاح: غير محفوظ',
    'fr': 'Clé : non enregistrée',
    'en': 'Key: not saved',
  },
  'key_help': {
    'ar': 'احصل على مفتاح مجاني من twelvedata.com. المصدر خارجي، ولا يغطي OTC، وأسعاره ليست بالضرورة مطابقة لأسعار Pocket Option.',
    'fr': "Obtenez une clé gratuite sur twelvedata.com. Source externe, sans OTC, et ses prix ne sont pas forcément identiques à ceux de Pocket Option.",
    'en': 'Get a free key at twelvedata.com. This is an external source, it does not cover OTC, and its prices may differ from Pocket Option.',
  },
  'src_ready': {
    'ar': 'جاهز: المفتاح محفوظ',
    'fr': 'Prêt : clé enregistrée',
    'en': 'Ready: key saved',
  },
  'src_nokey': {
    'ar': 'غير جاهز: أدخل المفتاح',
    'fr': 'Non prêt : saisissez la clé',
    'en': 'Not ready: enter the key',
  },
  'ext_note': {
    'ar': 'بيانات خارجية (Twelve Data) وليست أسعار Pocket Option، ولا تشمل OTC',
    'fr': 'Données externes (Twelve Data), pas les prix de Pocket Option, sans OTC',
    'en': 'External data (Twelve Data), not Pocket Option prices, no OTC',
  },
  'pairs_title': {
    'ar': 'الأزواج المتاحة من المصدر',
    'fr': 'Paires disponibles depuis la source',
    'en': 'Pairs available from the source',
  },
  'pair_search': {
    'ar': 'ابحث عن زوج',
    'fr': 'Rechercher une paire',
    'en': 'Search a pair',
  },
  'pairs_none': {
    'ar': 'لا توجد أزواج مطابقة',
    'fr': 'Aucune paire correspondante',
    'en': 'No matching pairs',
  },
  'otc_note': {
    'ar': 'أزواج OTC غير مدعومة لأن المصدر لا يوفر بياناتها',
    'fr': "Les paires OTC ne sont pas prises en charge : la source ne fournit pas leurs données",
    'en': 'OTC pairs are unsupported because the source does not provide their data',
  },
};

String t2(String key, [String? v]) {
  final m = _x[key];
  final s = m == null ? tr(key) : (m[langNotifier.value] ?? m['en'] ?? key);
  return v == null ? s : s.replaceAll('{v}', v);
}
