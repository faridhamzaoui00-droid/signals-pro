import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

final ValueNotifier<String> langNotifier = ValueNotifier<String>('ar');

Future<void> loadLang() async {
  try {
    final p = await SharedPreferences.getInstance();
    langNotifier.value = p.getString('lang') ?? 'ar';
  } catch (_) {}
}

Future<void> saveLang(String l) async {
  langNotifier.value = l;
  try {
    final p = await SharedPreferences.getInstance();
    await p.setString('lang', l);
  } catch (_) {}
}

TextDirection dirFor(String l) =>
    l == 'ar' ? TextDirection.rtl : TextDirection.ltr;

String tr(String key) {
  final m = _t[key];
  if (m == null) return key;
  return m[langNotifier.value] ?? m['en'] ?? key;
}

String durText(int sec) {
  final l = langNotifier.value;
  if (sec < 60) {
    if (l == 'ar') return '$sec ثانية';
    if (l == 'fr') return '$sec secondes';
    return '$sec seconds';
  }
  final m = sec ~/ 60;
  if (l == 'ar') {
    if (m <= 2) return '$m دقيقة';
    if (m <= 10) return '$m دقائق';
    return '$m دقيقة';
  }
  if (m == 1) return '1 minute';
  return '$m minutes';
}

String durFromStored(String s) {
  final n = int.tryParse(s);
  return n == null ? s : durText(n);
}

const Map<String, Map<String, String>> _t = {
  'nav_home': {'ar': 'الرئيسية', 'fr': 'Accueil', 'en': 'Home'},
  'nav_history': {'ar': 'السجل', 'fr': 'Historique', 'en': 'History'},
  'nav_settings': {'ar': 'الإعدادات', 'fr': 'Paramètres', 'en': 'Settings'},
  'nav_info': {'ar': 'معلومات', 'fr': 'Infos', 'en': 'Info'},
  'tagline': {
    'ar': 'تحليل ذكي .. قرارات أدق .. فرص أفضل',
    'fr': 'Analyse intelligente .. Décisions plus précises',
    'en': 'Smart analysis .. Sharper decisions',
  },
  'connected': {'ar': 'متصل', 'fr': 'Connecté', 'en': 'Connected'},
  'disconnected': {'ar': 'غير متصل', 'fr': 'Déconnecté', 'en': 'Disconnected'},
  'data_source': {
    'ar': 'مصدر البيانات',
    'fr': 'Source de données',
    'en': 'Data source'
  },
  'last_update': {
    'ar': 'آخر تحديث',
    'fr': 'Dernière mise à jour',
    'en': 'Last update'
  },
  'pair_label': {
    'ar': 'زوج التداول',
    'fr': 'Paire de trading',
    'en': 'Trading pair'
  },
  'pair_hint': {
    'ar': 'اختر الزوج',
    'fr': 'Choisir la paire',
    'en': 'Select pair'
  },
  'duration_label': {
    'ar': 'مدة الصفقة',
    'fr': 'Durée du trade',
    'en': 'Trade duration'
  },
  'analyze_now': {
    'ar': 'تحليل الآن',
    'fr': 'Analyser maintenant',
    'en': 'Analyze now'
  },
  'pick_pair_first': {
    'ar': 'اختر زوج التداول أولاً',
    'fr': "Choisissez d'abord une paire",
    'en': 'Select a trading pair first',
  },
  'pairs_unavailable': {
    'ar': 'قائمة الأزواج تُجلب من مصدر البيانات، وهو غير متصل بعد. لن تظهر أزواج غير مدعومة.',
    'fr': "La liste des paires provient de la source de données, qui n'est pas encore connectée. Aucune paire non prise en charge ne sera affichée.",
    'en': 'The pair list comes from the data source, which is not connected yet. Unsupported pairs will never be shown.',
  },
  'preview_banner': {
    'ar': 'معاينة تصميم: بيانات تجريبية وليست إشارة حقيقية',
    'fr': 'Aperçu du design : données de test, pas un vrai signal',
    'en': 'Design preview: sample data, not a real signal',
  },
  'na_reason': {
    'ar': 'مصدر البيانات غير متصل، لا توجد إشارة',
    'fr': 'Source de données non connectée, aucun signal',
    'en': 'Data source not connected, no signal',
  },
  'sample_sr': {
    'ar': 'منطقة دعم قوية',
    'fr': 'Forte zone de support',
    'en': 'Strong support zone'
  },
  'sample_reason': {
    'ar': 'ارتداد من الدعم + توافق المؤشرات',
    'fr': 'Rebond sur le support + indicateurs alignés',
    'en': 'Bounce from support + aligned indicators',
  },
  'badge_strong': {
    'ar': 'إشارة قوية',
    'fr': 'Signal fort',
    'en': 'Strong signal'
  },
  'badge_vstrong': {
    'ar': 'إشارة قوية جداً',
    'fr': 'Signal très fort',
    'en': 'Very strong signal'
  },
  'badge_excellent': {
    'ar': 'توافق ممتاز',
    'fr': 'Alignement excellent',
    'en': 'Excellent alignment'
  },
  'badge_wait': {
    'ar': 'لا توجد فرصة',
    'fr': "Pas d'opportunité",
    'en': 'No opportunity'
  },
  'badge_na': {
    'ar': 'بيانات غير متاحة',
    'fr': 'Données indisponibles',
    'en': 'Data unavailable'
  },
  'badge_ready': {'ar': 'جاهز', 'fr': 'Prêt', 'en': 'Ready'},
  'main_up': {'ar': 'UP – صاعد', 'fr': 'UP – Haussier', 'en': 'UP – Bullish'},
  'main_down': {
    'ar': 'DOWN – هابط',
    'fr': 'DOWN – Baissier',
    'en': 'DOWN – Bearish'
  },
  'main_wait': {
    'ar': 'WAIT – انتظر',
    'fr': 'WAIT – Attendre',
    'en': 'WAIT – Hold off'
  },
  'main_none': {
    'ar': 'بانتظار التحليل',
    'fr': "En attente d'analyse",
    'en': 'Waiting for analysis'
  },
  'chip_rate': {
    'ar': 'نسبة النجاح التاريخية',
    'fr': 'Taux de réussite historique',
    'en': 'Historical win rate'
  },
  'chip_nodata': {
    'ar': 'بيانات غير كافية لنسبة النجاح',
    'fr': 'Données insuffisantes pour le taux',
    'en': 'Not enough data for a win rate',
  },
  'chip_pick': {
    'ar': 'اختر الزوج ثم اضغط تحليل',
    'fr': 'Choisissez la paire puis Analyser',
    'en': 'Select a pair, then Analyze',
  },
  'details_title': {
    'ar': 'تفاصيل التحليل',
    'fr': "Détails de l'analyse",
    'en': 'Analysis details'
  },
  'tf_up': {'ar': 'صاعد', 'fr': 'Haussier', 'en': 'Up'},
  'tf_down': {'ar': 'هابط', 'fr': 'Baissier', 'en': 'Down'},
  'tf_buy': {
    'ar': 'تأكيد شراء',
    'fr': 'Confirmation achat',
    'en': 'Buy confirmation'
  },
  'tf_sell': {
    'ar': 'تأكيد بيع',
    'fr': 'Confirmation vente',
    'en': 'Sell confirmation'
  },
  'm_score': {'ar': 'التقييم', 'fr': 'Score', 'en': 'Score'},
  'sr_label': {
    'ar': 'الدعم والمقاومة',
    'fr': 'Support et résistance',
    'en': 'Support & resistance'
  },
  'main_reason': {
    'ar': 'السبب الرئيسي',
    'fr': 'Raison principale',
    'en': 'Main reason'
  },
  'footer_duration': {
    'ar': 'مدة الصفقة',
    'fr': 'Durée du trade',
    'en': 'Trade duration'
  },
  'footer_market': {
    'ar': 'نوع السوق',
    'fr': 'Type de marché',
    'en': 'Market type'
  },
  'market_regular': {
    'ar': 'السوق العادي',
    'fr': 'Marché régulier',
    'en': 'Regular market'
  },
  'settings_title': {
    'ar': 'الإعدادات',
    'fr': 'Paramètres',
    'en': 'Settings'
  },
  'lang_title': {'ar': 'اللغة', 'fr': 'Langue', 'en': 'Language'},
  'ds_status': {'ar': 'الحالة', 'fr': 'État', 'en': 'Status'},
  'ssid_saved': {
    'ar': 'مفتاح الجلسة (SSID): محفوظ مشفراً على هذا الجهاز',
    'fr': 'Clé de session (SSID) : enregistrée, chiffrée sur cet appareil',
    'en': 'Session key (SSID): saved, encrypted on this device',
  },
  'ssid_missing': {
    'ar': 'مفتاح الجلسة (SSID): غير محفوظ',
    'fr': 'Clé de session (SSID) : non enregistrée',
    'en': 'Session key (SSID): not saved',
  },
  'ssid_hint': {
    'ar': 'الصق مفتاح الجلسة هنا',
    'fr': 'Collez la clé de session ici',
    'en': 'Paste the session key here',
  },
  'ssid_save': {
    'ar': 'حفظ المفتاح',
    'fr': 'Enregistrer la clé',
    'en': 'Save key'
  },
  'ssid_delete': {
    'ar': 'حذف المفتاح',
    'fr': 'Supprimer la clé',
    'en': 'Delete key'
  },
  'ssid_note': {
    'ar': 'لا ترسل هذا المفتاح لأحد. يبقى على هاتفك فقط ولا يُكتب في الكود.',
    'fr': "Ne partagez cette clé avec personne. Elle reste uniquement sur votre téléphone et n'est jamais écrite dans le code.",
    'en': 'Never share this key. It stays on your phone only and is never written in the code.',
  },
  'ssid_paste_first': {
    'ar': 'الصق المفتاح أولاً',
    'fr': "Collez d'abord la clé",
    'en': 'Paste the key first'
  },
  'ssid_fail': {
    'ar': 'تعذر الحفظ على هذا الجهاز',
    'fr': "Impossible d'enregistrer sur cet appareil",
    'en': 'Could not save on this device',
  },
  'ssid_ok': {
    'ar': 'تم حفظ المفتاح مشفراً على هذا الجهاز',
    'fr': 'Clé enregistrée et chiffrée sur cet appareil',
    'en': 'Key saved and encrypted on this device',
  },
  'ssid_deleted': {
    'ar': 'تم حذف المفتاح',
    'fr': 'Clé supprimée',
    'en': 'Key deleted'
  },
  'ver_title': {
    'ar': 'معلومات الإصدار',
    'fr': 'Informations de version',
    'en': 'Version info'
  },
  'ver_number': {
    'ar': 'الإصدار 1.0.0',
    'fr': 'Version 1.0.0',
    'en': 'Version 1.0.0'
  },
  'hist_title': {'ar': 'السجل', 'fr': 'Historique', 'en': 'History'},
  'st_total': {
    'ar': 'إجمالي الإشارات',
    'fr': 'Total des signaux',
    'en': 'Total signals'
  },
  'st_win': {'ar': 'رابحة', 'fr': 'Gagnants', 'en': 'Wins'},
  'st_loss': {'ar': 'خاسرة', 'fr': 'Perdants', 'en': 'Losses'},
  'st_pending': {'ar': 'قيد الانتظار', 'fr': 'En attente', 'en': 'Pending'},
  'st_rate': {
    'ar': 'نسبة النجاح الفعلية',
    'fr': 'Taux de réussite réel',
    'en': 'Actual win rate'
  },
  'rate_note': {
    'ar': 'تُحسب النسبة من الإشارات المحسومة فقط: الرابحة ÷ (الرابحة + الخاسرة).',
    'fr': 'Le taux compte uniquement les signaux tranchés : gagnants ÷ (gagnants + perdants).',
    'en': 'The rate counts decided signals only: wins ÷ (wins + losses).',
  },
  'f_all': {
    'ar': 'جميع الإشارات',
    'fr': 'Tous les signaux',
    'en': 'All signals'
  },
  'f_win': {'ar': 'الرابحة', 'fr': 'Gagnants', 'en': 'Wins'},
  'f_loss': {'ar': 'الخاسرة', 'fr': 'Perdants', 'en': 'Losses'},
  'f_pending': {'ar': 'قيد الانتظار', 'fr': 'En attente', 'en': 'Pending'},
  'search_hint': {
    'ar': 'بحث حسب الزوج',
    'fr': 'Rechercher par paire',
    'en': 'Search by pair'
  },
  'empty_hist': {
    'ar': 'لا توجد إشارات بعد',
    'fr': 'Aucun signal pour le moment',
    'en': 'No signals yet'
  },
  'd_direction': {'ar': 'الاتجاه', 'fr': 'Direction', 'en': 'Direction'},
  'd_time': {
    'ar': 'وقت الإشارة',
    'fr': 'Heure du signal',
    'en': 'Signal time'
  },
  'd_price': {
    'ar': 'السعر وقت الإشارة',
    'fr': 'Prix au moment du signal',
    'en': 'Price at signal'
  },
  'd_end_time': {
    'ar': 'وقت الانتهاء',
    'fr': 'Heure de fin',
    'en': 'End time'
  },
  'd_end_price': {
    'ar': 'السعر عند الانتهاء',
    'fr': 'Prix à la fin',
    'en': 'End price'
  },
  'd_result': {'ar': 'النتيجة', 'fr': 'Résultat', 'en': 'Result'},
  'd_indicators': {'ar': 'المؤشرات', 'fr': 'Indicateurs', 'en': 'Indicators'},
  'd_reasons': {
    'ar': 'أسباب الإشارة',
    'fr': 'Raisons du signal',
    'en': 'Signal reasons'
  },
  'res_win': {'ar': 'رابحة', 'fr': 'Gagnant', 'en': 'Win'},
  'res_loss': {'ar': 'خاسرة', 'fr': 'Perdant', 'en': 'Loss'},
  'res_unv': {
    'ar': 'غير قابلة للتحقق',
    'fr': 'Non vérifiable',
    'en': 'Unverifiable'
  },
  'res_pending': {
    'ar': 'قيد الانتظار',
    'fr': 'En attente',
    'en': 'Pending'
  },
};
