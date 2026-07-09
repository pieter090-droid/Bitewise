import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bitewise/features/snackswap/application/swap_score_calculator.dart';
import 'package:bitewise/features/snackswap/data/snackswap_service.dart';
import 'package:bitewise/features/snackswap/domain/product_features.dart';
import 'package:bitewise/features/snackswap/domain/swap_score_result.dart';
import 'package:bitewise/features/tracker/application/tracker_providers.dart';
import 'package:bitewise/features/tracker/domain/day_log.dart';

/// Rule-based aanbevelingsengine op basis van `product_features_resolved`.
/// Draait volledig lokaal
/// (geen AI-aanroep); parallel aan het bestaande `recommend_swaps`-pad, dat
/// ongemoeid blijft.
sealed class RuleBasedSwapOutcome {
  const RuleBasedSwapOutcome();
}

/// Het bronproduct is nog niet als swap-relevant/AI-verrijkt gemarkeerd, of
/// er zijn geen kandidaten binnen hetzelfde cluster/categorie gevonden.
class RuleBasedSwapNotFound extends RuleBasedSwapOutcome {
  const RuleBasedSwapNotFound();
}

class RuleBasedSwapError extends RuleBasedSwapOutcome {
  const RuleBasedSwapError(this.message);
  final String message;
}

class RuleBasedSwapFound extends RuleBasedSwapOutcome {
  const RuleBasedSwapFound(
      this.groups, this.allRanked, this.source, this.configs);
  final List<SwapRecommendationGroup> groups;

  /// Volledige, ongecapte, op score gesorteerde kandidatenlijst (incl. de
  /// cross-familie "Andere opties"-kandidaten) -- gebruikt door het
  /// categoriefilter op het scherm om [buildRecommendationGroups] opnieuw
  /// aan te roepen, geschaald naar één `snack_type`, los van de vaste
  /// 5-per-groep-limiet van [groups].
  final List<SwapScoreResult> allRanked;
  final SwapCandidate source;
  final List<Map<String, dynamic>> configs;
}

class SwapRecommendationGroup {
  const SwapRecommendationGroup({
    required this.slug,
    required this.label,
    required this.results,
  });
  final String slug;
  final String label;
  final List<SwapScoreResult> results;
}

/// Vertaalt het onboarding-doel naar het SwapGoal dat de calculator kent.
/// Leest een boolean-feature op naam voor lokale UI-groepering.
/// Onbekende kolomnaam -> null.
bool? _boolForColumn(ProductFeatures f, String? column) => switch (column) {
      'is_low_sugar' => f.isLowSugar,
      'is_high_protein' => f.isHighProtein,
      'is_low_kcal' => f.isLowKcal,
      'is_high_fiber' => f.isHighFiber,
      'is_less_processed' => f.isLessProcessed,
      _ => null,
    };

/// Bevestigt dat de kandidaat ook daadwerkelijk BETER is dan het bronproduct
/// op dit specifieke punt -- niet alleen absoluut "laag"/"hoog" op zichzelf.
///
/// Bug gevonden: "Minder kcal" toonde eerder kandidaten die zelf onder de
/// vaste drempel (bv. 150 kcal/100g) zaten, ook als het bronproduct fors
/// minder kcal had (bv. 80). De groepsnaam belooft een vergelijking t.o.v.
/// het bronproduct -- die vergelijking ontbrak volledig. Onbekend (een van
/// beide null) = kan niet bevestigen = hoort niet in deze groep, ook al is
/// de absolute vlag toevallig waar.
bool _relativeImprovement(
    String? column, SwapCandidate source, SwapCandidate candidate) {
  switch (column) {
    case 'is_low_sugar':
      final s = source.sugar100, c = candidate.sugar100;
      return s != null && c != null && c < s;
    case 'is_high_protein':
      final s = source.protein100, c = candidate.protein100;
      return s != null && c != null && c > s;
    case 'is_low_kcal':
      final s = source.kcal100, c = candidate.kcal100;
      return s != null && c != null && c < s;
    case 'is_less_processed':
      final s = source.features.processingQualityScore,
          c = candidate.features.processingQualityScore;
      return s != null && c != null && c > s;
    default:
      return true;
  }
}

/// Voor de "Andere opties"-groep: is de kandidaat op minstens één punt
/// (kcal/suiker/eiwit) aantoonbaar beter dan het bronproduct? Dit is de enige
/// rechtvaardiging om een andere `swap_family` (bv. smeerkaas i.p.v.
/// chocopasta) toch te tonen -- puur "andere vorm" zonder verbetering is
/// geen zinnige suggestie.
bool _hasAnyNutritionImprovement(
    SwapCandidate source, SwapCandidate candidate) {
  final sSugar = source.sugar100, cSugar = candidate.sugar100;
  if (sSugar != null && cSugar != null && cSugar < sSugar) return true;
  final sKcal = source.kcal100, cKcal = candidate.kcal100;
  if (sKcal != null && cKcal != null && cKcal < sKcal) return true;
  final sProtein = source.protein100, cProtein = candidate.protein100;
  if (sProtein != null && cProtein != null && cProtein > sProtein) return true;
  return false;
}

/// Groepeert een (eventueel al op categorie gefilterde) kandidatenlijst
/// volgens een lokale UI-config -- Minder kcal/Meer eiwit/Minder suiker/
/// Overall, elk relatief t.o.v. [source] (zie
/// [_relativeImprovement]). Herbruikbaar: de hoofdweergave gebruikt dit met
/// de volledige kandidatenpool en limiet 5; het categoriefilter op het
/// scherm roept dit opnieuw aan met alleen kandidaten van één `snack_type`
/// en een ruimere limiet (bv. 10), zodat "Minder kcal binnen Zuivel" enz.
/// niet beperkt blijft tot wat toevallig in de top-5-overall zat.
List<SwapRecommendationGroup> buildRecommendationGroups({
  required List<Map<String, dynamic>> configs,
  required SwapCandidate source,
  required List<SwapScoreResult> ranked,
  int perGroupLimit = 5,
}) {
  final groups = <SwapRecommendationGroup>[];
  for (final config in configs) {
    final column = config['rule_column'] as String?;
    final tag = config['rule_swap_tag'] as String?;
    final direction = config['rule_direction'] as String?;

    List<SwapScoreResult> matches;
    if (column == null && tag == null && direction == null) {
      matches = ranked; // "Overall betere suggestie" = de algehele ranking.
    } else {
      matches = ranked.where((r) {
        if (column != null &&
            _boolForColumn(r.candidate.features, column) == true &&
            _relativeImprovement(column, source, r.candidate)) {
          return true;
        }
        if (tag != null && r.candidate.features.swapTags.contains(tag)) {
          return true;
        }
        if (direction != null &&
            r.candidate.features.recommendedSwapDirections
                .contains(direction)) {
          return true;
        }
        return false;
      }).toList();
    }
    if (matches.isEmpty) continue;
    groups.add(SwapRecommendationGroup(
      slug: config['slug'] as String,
      label: config['label'] as String,
      results: matches.take(perGroupLimit).toList(),
    ));
  }
  return groups;
}

const List<Map<String, dynamic>> fallbackGroupConfigs = [
  {'slug': 'minder_kcal', 'label': 'Minder kcal', 'rule_column': 'is_low_kcal'},
  {
    'slug': 'meer_eiwit',
    'label': 'Meer eiwit',
    'rule_column': 'is_high_protein'
  },
  {
    'slug': 'minder_suiker',
    'label': 'Minder suiker',
    'rule_column': 'is_low_sugar'
  },
  {'slug': 'beste_keuze_vandaag', 'label': 'Overall betere suggestie'},
];

SwapDayContext swapDayContextFromSummary(DailySummary summary) =>
    SwapDayContext(
      dailyKcalUsed: summary.kcal,
      dailyKcalGoal: summary.calorieTarget.toDouble(),
      dailySugarUsed: summary.sugar,
      dailySugarGoal: summary.sugarLimit.toDouble(),
      dailyProteinUsed: summary.protein,
      dailyProteinGoal: summary.proteinTarget.toDouble(),
      // De huidige tracker logt nog geen vezels. Bewust null laten: de
      // calculator behandelt dit onderdeel neutraal en verzint geen data.
      dailyFiberUsed: null,
      dailyFiberGoal: null,
    );

/// Berekent en groepeert swap-aanbevelingen voor een gescand product.
final ruleBasedSwapProvider = FutureProvider.family<
    RuleBasedSwapOutcome,
    ({
      String barcode,
      SwapGoal goal,
      bool useDayContext
    })>((ref, request) async {
  final service = ref.watch(snackSwapServiceProvider);
  final barcode = request.barcode;

  final source = await service.getCandidateByBarcode(barcode);
  if (source == null || !source.features.isSwapRelevant) {
    return const RuleBasedSwapNotFound();
  }

  final candidates = await service.getCandidatesForCluster(
    excludeBarcode: source.barcode,
    swapFamily: source.features.swapFamily,
    snackType: source.features.snackType,
    categoryCluster: source.features.categoryCluster,
    fallbackCategory: source.category,
  );
  if (candidates.isEmpty) return const RuleBasedSwapNotFound();

  final goal = request.goal;
  final dayContext = request.useDayContext
      ? swapDayContextFromSummary(ref.watch(dailySummaryProvider))
      : const SwapDayContext();

  final calculator = SwapScoreCalculator();
  final ranked = calculator.rankCandidates(
    source: source,
    candidates: candidates,
    goal: goal,
    dayContext: dayContext,
  );
  if (ranked.isEmpty) return const RuleBasedSwapNotFound();

  final configs = [
    {'slug': goal.value, 'label': goal.label},
  ];
  final groups = <SwapRecommendationGroup>[
    SwapRecommendationGroup(
      slug: 'directe_swaps',
      label: 'Directe swaps',
      results: ranked.take(8).toList(),
    ),
  ];

  // "Andere opties": bewust cross-familie (bv. chocopasta -> smeerkaas of
  // pindakaas), primair via de expliciete `related_families`-lijst uit
  // swap_family_mapping (bron van waarheid), met product_form als losser
  // vangnet. Alleen getoond als er een aantoonbare voedingsverbetering is.
  var otherOptions = <SwapScoreResult>[];
  final sourceForm = source.features.productForm;
  final sourceFamily = source.features.swapFamily;
  if (sourceForm != null && sourceForm.isNotEmpty) {
    final relatedFamilies = sourceFamily != null && sourceFamily.isNotEmpty
        ? await service.getRelatedFamilies(sourceFamily)
        : const <String>[];
    final otherFormCandidates = await service.getCandidatesForOtherForm(
      excludeBarcode: source.barcode,
      productForm: sourceForm,
      relatedFamilies: relatedFamilies,
      excludeSwapFamily: sourceFamily,
    );
    otherOptions = otherFormCandidates
        .where((c) =>
            c.features.productForm == null ||
            c.features.productForm == sourceForm)
        .where((c) =>
            c.features.consumptionMode == null ||
            source.features.consumptionMode == null ||
            c.features.consumptionMode == source.features.consumptionMode)
        .where((c) => _hasAnyNutritionImprovement(source, c))
        .map((c) => calculator.scoreCrossForm(
            source: source, candidate: c, goal: goal, dayContext: dayContext))
        // _hasAnyNutritionImprovement gate hierboven kijkt alleen naar
        // richting (bv. kcal omlaag), niet naar de harde-penalty-regels van
        // het gekozen doel (bv. eiwit >30% omlaag) -- zonder deze filter
        // konden kandidaten met score 0 en geen reason-tekst tussen de
        // echte suggesties staan (bv. "Aardbeien zero" bij Nutella +
        // Minder kcal: minder kcal, maar eiwit-hard-penalty).
        .where((r) => !r.isExcluded)
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    if (otherOptions.isNotEmpty) {
      groups.add(SwapRecommendationGroup(
        slug: 'andere_opties',
        label: 'Andere opties',
        results: otherOptions.take(5).toList(),
      ));
    }
  }

  if (groups.isEmpty) return const RuleBasedSwapNotFound();

  // Volledige lijst voor het categoriefilter: hoofdranking + cross-familie
  // opties, gededupliceerd op barcode, opnieuw op score gesorteerd.
  final seen = <String>{};
  final allRanked = [...ranked, ...otherOptions]
      .where((r) => seen.add(r.candidate.barcode))
      .toList()
    ..sort((a, b) => b.score.compareTo(a.score));

  return RuleBasedSwapFound(groups, allRanked, source, configs);
});
