import 'package:flutter/material.dart';
import 'l10n.dart';

const _card = Color(0xFF0A1A3F);
const _line = Color(0xFF1F4FB5);
const _blue = Color(0xFF2E7BFF);
const _amber = Color(0xFFFFB020);

const Map<String, Map<String, String>> _i = {
  'title': {'ar': 'معلومات', 'fr': 'Infos', 'en': 'Info'},
  'what_t': {
    'ar': 'ما هو التطبيق؟',
    'fr': "Qu'est-ce que l'application ?",
    'en': 'What is this app?'
  },
  'what': {
    'ar': 'Farid Hamzaoui Signals Pro هو تطبيق لتحليل الأسواق باستخدام البيانات الرقمية والمؤشرات الفنية وتحليل عدة إطارات زمنية، بهدف تحديد الاتجاهات والفرص المحتملة.',
    'fr': "Farid Hamzaoui Signals Pro est une application d'analyse des marchés qui utilise des données numériques, des indicateurs techniques et l'analyse de plusieurs unités de temps pour repérer les tendances et les opportunités potentielles.",
    'en': 'Farid Hamzaoui Signals Pro is a market analysis app that uses digital data, technical indicators and multi-timeframe analysis to identify trends and potential opportunities.',
  },
  'how_t': {
    'ar': 'كيف يعمل التطبيق؟',
    'fr': "Comment fonctionne l'application ?",
    'en': 'How does it work?'
  },
  'how': {
    'ar': '1. تختار زوج التداول.\n2. تحدد مدة الصفقة.\n3. تضغط على «تحليل الآن».\n4. يجلب التطبيق بيانات السوق.\n5. يحلل المؤشرات والإطارات الزمنية.\n6. يعرض UP أو DOWN أو WAIT.',
    'fr': "1. Choisissez la paire.\n2. Définissez la durée du trade.\n3. Appuyez sur « Analyser maintenant ».\n4. L'application récupère les données du marché.\n5. Elle analyse les indicateurs et les unités de temps.\n6. Elle affiche UP, DOWN ou WAIT.",
    'en': '1. Choose the trading pair.\n2. Set the trade duration.\n3. Tap “Analyze now”.\n4. The app fetches market data.\n5. It analyzes indicators and timeframes.\n6. It shows UP, DOWN or WAIT.',
  },
  'strat_t': {
    'ar': 'ما الاستراتيجية المستخدمة؟ (Multi-Timeframe Pro)',
    'fr': 'Quelle stratégie ? (Multi-Timeframe Pro)',
    'en': 'Which strategy? (Multi-Timeframe Pro)'
  },
  'strat': {
    'ar': '• EMA 20 وEMA 50: متوسطان متحركان يحددان اتجاه السوق.\n• RSI 14: يقيس الزخم. فوق 52 يدعم الصعود وتحت 48 يدعم الهبوط، وما بينهما حياد.\n• ADX 14: يقيس قوة الاتجاه. لا تصدر إشارة إذا كان 20 أو أقل.\n• SuperTrend (ATR 10 × 3): يحدد الاتجاه الحالي صاعد أو هابط.\n• ATR 14: يقيس تذبذب السوق ويحدد المسافة المعقولة عن المستويات.\n• الدعم والمقاومة: تُكتشف من القمم والقيعان ومناطق الارتداد المتكررة.\n• إعادة الاختبار والاختراق الكاذب والرفض: تأكيدات عند المستويات.\n• تحليل الشموع: ابتلاع صاعد وهابط، شموع الرفض، شموع الاندفاع. ولا يكفي ظهور الشكل وحده.\n• توافق الإطارات الزمنية: M1 وM5 وM15 وM30 حسب مدة الصفقة، ويجب أن تتفق مع اتجاه الإشارة.\n• تقييم من 10 نقاط لقوة توافق الشروط.\n• شروط منع الإشارة: بيانات قديمة أو ناقصة، تعارض الإطارات، ADX لا يتجاوز 20، سوق عرضي، غياب شمعة تأكيد مغلقة، دعم أو مقاومة قريبة معاكسة، حركة مستهلكة، شمعة اندفاع متأخرة، تكرار الإشارة نفسها.',
    'fr': "• EMA 20 et EMA 50 : moyennes mobiles qui donnent la direction du marché.\n• RSI 14 : mesure l'élan. Au-dessus de 52 il soutient la hausse, en dessous de 48 la baisse, entre les deux : neutre.\n• ADX 14 : mesure la force de la tendance. Aucun signal s'il vaut 20 ou moins.\n• SuperTrend (ATR 10 × 3) : indique la tendance actuelle, haussière ou baissière.\n• ATR 14 : mesure la volatilité et fixe une distance raisonnable aux niveaux.\n• Support et résistance : détectés à partir des sommets, creux et zones de rebond répétées.\n• Retest, faux breakout et rejet : confirmations autour des niveaux.\n• Analyse des bougies : englobante haussière/baissière, bougies de rejet, bougies d'impulsion. La forme seule ne suffit pas.\n• Accord des unités de temps : M1, M5, M15 et M30 selon la durée, en accord avec la direction du signal.\n• Score sur 10 : force de l'alignement des conditions.\n• Conditions de blocage : données anciennes ou incomplètes, unités de temps en conflit, ADX ≤ 20, marché sans tendance, pas de bougie de confirmation clôturée, support ou résistance proche en sens inverse, mouvement épuisé, bougie d'impulsion tardive, même signal répété.",
    'en': '• EMA 20 and EMA 50: moving averages that give the market direction.\n• RSI 14: measures momentum. Above 52 supports a rise, below 48 supports a fall, in between is neutral.\n• ADX 14: measures trend strength. No signal if it is 20 or lower.\n• SuperTrend (ATR 10 × 3): shows the current trend, up or down.\n• ATR 14: measures volatility and sets a reasonable distance from levels.\n• Support and resistance: detected from swing highs, swing lows and repeated bounce zones.\n• Retest, false breakout and rejection: confirmations around levels.\n• Candle analysis: bullish/bearish engulfing, rejection candles, momentum candles. The shape alone is never enough.\n• Timeframe agreement: M1, M5, M15 and M30 depending on duration, matching the signal direction.\n• 10-point score: strength of condition alignment.\n• Blocking conditions: stale or incomplete data, conflicting timeframes, ADX ≤ 20, sideways market, no closed confirmation candle, nearby opposing support or resistance, exhausted move, late momentum candle, repeated identical signal.',
  },
  'score_t': {
    'ar': 'كيف يتم تقييم الإشارة؟',
    'fr': 'Comment le signal est-il évalué ?',
    'en': 'How is the signal scored?'
  },
  'score': {
    'ar': 'التقييم من 10 يعبر عن مدى توافق شروط الاستراتيجية، وليس نسبة احتمال نجاح الصفقة. أقل من 8 من 10 تكون النتيجة WAIT.',
    'fr': "Le score sur 10 exprime à quel point les conditions de la stratégie sont alignées. Ce n'est pas une probabilité de réussite. En dessous de 8 sur 10, le résultat est WAIT.",
    'en': 'The score out of 10 shows how well the strategy conditions line up. It is not a probability of success. Below 8 out of 10 the result is WAIT.',
  },
  'risk_t': {'ar': 'تنبيه المخاطر', 'fr': 'Avertissement sur les risques', 'en': 'Risk warning'},
  'risk': {
    'ar': 'الإشارات أدوات تحليل وليست ضماناً للربح، والنتائج التاريخية لا تضمن النتائج المستقبلية. قرار التداول وتنفيذه مسؤوليتك وحدك.',
    'fr': "Les signaux sont des outils d'analyse et non une garantie de gain. Les résultats passés ne garantissent pas les résultats futurs. La décision de trader et son exécution relèvent de votre seule responsabilité.",
    'en': 'Signals are analysis tools, not a guarantee of profit. Past results do not guarantee future results. The decision to trade and its execution are your sole responsibility.',
  },
};

String _s(String k) {
  final m = _i[k]!;
  return m[langNotifier.value] ?? m['en']!;
}

class InfoPage extends StatefulWidget {
  const InfoPage({super.key});
  @override
  State<InfoPage> createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage> {
  void _onLang() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    langNotifier.addListener(_onLang);
  }

  @override
  void dispose() {
    langNotifier.removeListener(_onLang);
    super.dispose();
  }

  Widget _section(String titleKey, String bodyKey,
      {IconData icon = Icons.info_outline, Color color = _blue}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.7)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.2), blurRadius: 10)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_s(titleKey),
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 10),
        Text(_s(bodyKey), style: const TextStyle(fontSize: 15, height: 1.6)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      children: [
        Text(_s('title'),
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 14),
        _section('what_t', 'what', icon: Icons.insights),
        _section('how_t', 'how', icon: Icons.touch_app),
        _section('strat_t', 'strat', icon: Icons.candlestick_chart),
        _section('score_t', 'score', icon: Icons.star),
        _section('risk_t', 'risk', icon: Icons.warning_amber, color: _amber),
      ],
    );
  }
}
