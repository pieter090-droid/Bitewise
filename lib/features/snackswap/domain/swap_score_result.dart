import 'package:bitewise/features/snackswap/domain/product_features.dart';

/// De vaste 6 hoofdgewichten van het SwapScore-model.
class SwapScoreWeights {
  const SwapScoreWeights({
    required this.goalMatch,
    required this.nutritionImprovement,
    required this.dayContext,
    required this.similarity,
    required this.processingQuality,
    required this.dataQuality,
  });

  final double goalMatch;
  final double nutritionImprovement;
  final double dayContext;
  final double similarity;
  final double processingQuality;
  final double dataQuality;

  /// Exacte hoofdweging: 30/25/15/15/10/5.
  static const fallback = SwapScoreWeights(
    goalMatch: 30,
    nutritionImprovement: 25,
    dayContext: 15,
    similarity: 15,
    processingQuality: 10,
    dataQuality: 5,
  );

  factory SwapScoreWeights.fromJson(Map<String, dynamic> json) {
    double n(Object? v, double fallback) =>
        v == null ? fallback : (v as num).toDouble();
    return SwapScoreWeights(
      goalMatch:
          n(json['weight_goal_match'], SwapScoreWeights.fallback.goalMatch),
      nutritionImprovement: n(json['weight_nutrition_improvement'],
          SwapScoreWeights.fallback.nutritionImprovement),
      dayContext:
          n(json['weight_day_context'], SwapScoreWeights.fallback.dayContext),
      similarity:
          n(json['weight_similarity'], SwapScoreWeights.fallback.similarity),
      processingQuality: n(json['weight_processing_quality'],
          SwapScoreWeights.fallback.processingQuality),
      dataQuality:
          n(json['weight_data_quality'], SwapScoreWeights.fallback.dataQuality),
    );
  }
}

/// Dagcontext voor het scoren (resterende ruimte vandaag). Elk veld is
/// optioneel: ontbrekend = neutraal meewegen, nooit hard afstraffen.
class SwapDayContext {
  const SwapDayContext({
    this.dailyKcalUsed,
    this.dailyKcalGoal,
    this.dailySugarUsed,
    this.dailySugarGoal,
    this.dailyProteinUsed,
    this.dailyProteinGoal,
    this.dailyFiberUsed,
    this.dailyFiberGoal,
  });

  final double? dailyKcalUsed;
  final double? dailyKcalGoal;
  final double? dailySugarUsed;
  final double? dailySugarGoal;
  final double? dailyProteinUsed;
  final double? dailyProteinGoal;
  final double? dailyFiberUsed;
  final double? dailyFiberGoal;

  bool get isEmpty =>
      dailyKcalUsed == null &&
      dailyKcalGoal == null &&
      dailySugarUsed == null &&
      dailySugarGoal == null &&
      dailyProteinUsed == null &&
      dailyProteinGoal == null &&
      dailyFiberUsed == null &&
      dailyFiberGoal == null;
}

/// Eén berekende swap-uitkomst: score + transparante onderbouwing.
class SwapScoreResult {
  const SwapScoreResult({
    required this.candidate,
    required this.score,
    required this.goalMatch,
    required this.nutritionImprovement,
    required this.dayContext,
    required this.similarity,
    required this.processingQuality,
    required this.dataQuality,
    this.reasons = const [],
    this.reasonCodes = const [],
    this.userReason,
    this.usesServingData = false,
    this.warnings = const [],
    this.excludedReason,
  });

  final SwapCandidate candidate;

  /// 0-100. `0` met een gevulde [excludedReason] betekent: hoort niet in de
  /// ranking (bv. ander category_cluster) — nooit tonen als "slechte match".
  final double score;

  final double goalMatch;
  final double nutritionImprovement;
  final double dayContext;
  final double similarity;
  final double processingQuality;
  final double dataQuality;

  final List<String> reasons;
  final List<String> reasonCodes;
  final String? userReason;
  final bool usesServingData;
  final List<String> warnings;
  final String? excludedReason;

  bool get isExcluded => excludedReason != null;
}

/// De vier expliciete doelen uit de SnackSwap-keuzestap.
enum SwapGoal {
  meerEiwit('meer_eiwit', 'Meer eiwit'),
  minderKcal('minder_kcal', 'Minder kcal'),
  minderSuiker('minder_suiker', 'Minder suiker'),
  besteOverall('beste_overall', 'Beste overall swap');

  const SwapGoal(this.value, this.label);
  final String value;
  final String label;
}
