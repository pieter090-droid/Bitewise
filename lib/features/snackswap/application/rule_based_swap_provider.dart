import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bitewise/features/onboarding/data/user_goals_repository.dart';
import 'package:bitewise/features/onboarding/domain/goal_type.dart';
import 'package:bitewise/features/snackswap/application/swap_score_calculator.dart';
import 'package:bitewise/features/snackswap/data/snackswap_service.dart';
import 'package:bitewise/features/snackswap/domain/product_features.dart';
import 'package:bitewise/features/snackswap/domain/swap_score_result.dart';
import 'package:bitewise/features/tracker/application/tracker_providers.dart';

/// Nieuwe, rule-based aanbevelingsengine op basis van `product_features` +
/// `swap_score_weights`/`swap_recommendation_groups`. Draait volledig lokaal
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
  const RuleBasedSwapFound(this.groups);
  final List<SwapRecommendationGroup> groups;
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
SwapGoal swapGoalForGoalType(GoalType type) => switch (type) {
      GoalType.loseWeight => SwapGoal.afvallen,
      GoalType.maintain => SwapGoal.gewichtBehouden,
      GoalType.buildMuscle => SwapGoal.spieropbouw,
      GoalType.lessSugar => SwapGoal.minderSuiker,
    };

/// Leest een boolean-feature op naam (voor groep-regels uit
/// `swap_recommendation_groups.rule_column`). Onbekende kolomnaam -> null.
bool? _boolForColumn(ProductFeatures f, String? column) => switch (column) {
      'is_low_sugar' => f.isLowSugar,
      'is_high_protein' => f.isHighProtein,
      'is_low_kcal' => f.isLowKcal,
      'is_high_fiber' => f.isHighFiber,
      'is_less_processed' => f.isLessProcessed,
      _ => null,
    };

/// Berekent en groepeert swap-aanbevelingen voor een gescand product.
final ruleBasedSwapProvider =
    FutureProvider.family<RuleBasedSwapOutcome, String>((ref, barcode) async {
  final service = ref.watch(snackSwapServiceProvider);

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

  final weights = await service.getActiveWeights();
  final groupConfigs = await service.getRecommendationGroups();

  final userGoal = ref.read(activeGoalProvider).valueOrNull;
  final goal =
      userGoal != null ? swapGoalForGoalType(userGoal.goalType) : SwapGoal.gezonderEten;

  final summary = ref.read(dailySummaryProvider);
  final dayContext = SwapDayContext(
    kcalRemaining: summary.remainingKcal,
    sugarRemainingG: (summary.sugarLimit - summary.sugar).toDouble(),
  );

  final calculator = SwapScoreCalculator(weights);
  final ranked = calculator.rankCandidates(
    source: source,
    candidates: candidates,
    goal: goal,
    dayContext: dayContext,
  );
  if (ranked.isEmpty) return const RuleBasedSwapNotFound();

  const fallbackGroups = [
    {'slug': 'beste_keuze_vandaag', 'label': 'Beste keuze voor vandaag'},
    {'slug': 'minder_suiker', 'label': 'Minder suiker', 'rule_column': 'is_low_sugar'},
    {'slug': 'meer_eiwit', 'label': 'Meer eiwit', 'rule_column': 'is_high_protein'},
    {'slug': 'minder_kcal', 'label': 'Minder kcal', 'rule_column': 'is_low_kcal'},
    {'slug': 'minder_bewerkt', 'label': 'Minder bewerkt', 'rule_column': 'is_less_processed'},
  ];
  final configs = groupConfigs.isNotEmpty ? groupConfigs : fallbackGroups;

  final groups = <SwapRecommendationGroup>[];
  for (final config in configs) {
    final column = config['rule_column'] as String?;
    final tag = config['rule_swap_tag'] as String?;
    final direction = config['rule_direction'] as String?;

    List<SwapScoreResult> matches;
    if (column == null && tag == null && direction == null) {
      matches = ranked; // "Beste keuze voor vandaag" = de algehele ranking.
    } else {
      matches = ranked.where((r) {
        if (column != null && _boolForColumn(r.candidate.features, column) == true) {
          return true;
        }
        if (tag != null && r.candidate.features.swapTags.contains(tag)) return true;
        if (direction != null &&
            r.candidate.features.recommendedSwapDirections.contains(direction)) {
          return true;
        }
        return false;
      }).toList();
    }
    if (matches.isEmpty) continue;
    groups.add(SwapRecommendationGroup(
      slug: config['slug'] as String,
      label: config['label'] as String,
      results: matches.take(5).toList(),
    ));
  }

  if (groups.isEmpty) return const RuleBasedSwapNotFound();
  return RuleBasedSwapFound(groups);
});
