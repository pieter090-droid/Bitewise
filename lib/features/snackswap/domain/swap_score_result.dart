import 'package:bitewise/features/snackswap/domain/product_features.dart';

/// De 6 gewichten uit `swap_score_weights` (som hoeft geen 100 te zijn —
/// [SwapScoreCalculator] normaliseert zelf).
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

  /// Redelijke standaardwaarden (identiek aan de seed in migratie 0009),
  /// alleen gebruikt als de config-tabel om wat voor reden niet bereikbaar is.
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
      goalMatch: n(json['weight_goal_match'], SwapScoreWeights.fallback.goalMatch),
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
  const SwapDayContext({this.kcalRemaining, this.sugarRemainingG});
  final double? kcalRemaining;
  final double? sugarRemainingG;
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
  final List<String> warnings;
  final String? excludedReason;

  bool get isExcluded => excludedReason != null;
}

/// De vijf gebruikersdoelen die de scorefunctie kent (zie migratie 0009).
enum SwapGoal {
  minderSuiker('minder_suiker'),
  afvallen('afvallen'),
  spieropbouw('spieropbouw'),
  gezonderEten('gezonder_eten'),
  gewichtBehouden('gewicht_behouden');

  const SwapGoal(this.value);
  final String value;
}
