import 'package:bitewise/features/snackswap/domain/product_features.dart';
import 'package:bitewise/features/snackswap/domain/swap_score_result.dart';

class SwapNutritionSnapshot {
  const SwapNutritionSnapshot({
    required this.amount,
    this.kcal,
    this.sugar,
    this.protein,
    this.fat,
    this.salt,
  });

  final double amount;
  final double? kcal;
  final double? sugar;
  final double? protein;
  final double? fat;
  final double? salt;
}

class SwapComparison {
  const SwapComparison({
    required this.source,
    required this.candidate,
    required this.usesServingData,
  });

  final SwapNutritionSnapshot source;
  final SwapNutritionSnapshot candidate;
  final bool usesServingData;

  factory SwapComparison.forResult({
    required SwapCandidate source,
    required SwapScoreResult result,
  }) {
    final candidate = result.candidate;
    final serving = result.usesServingData &&
        _hasServingCore(source) &&
        _hasServingCore(candidate);
    return SwapComparison(
      source: _snapshot(source, serving),
      candidate: _snapshot(candidate, serving),
      usesServingData: serving,
    );
  }

  double? get kcalSaved => _subtract(source.kcal, candidate.kcal);
  double? get sugarSaved => _subtract(source.sugar, candidate.sugar);
  double? get proteinGained => _subtract(candidate.protein, source.protein);
  double? get fatSaved => _subtract(source.fat, candidate.fat);
  double? get saltSaved => _subtract(source.salt, candidate.salt);

  static bool _hasServingCore(SwapCandidate item) =>
      item.servingQuantity != null &&
      item.servingQuantity! > 0 &&
      item.kcalServing != null &&
      item.sugarServing != null &&
      item.proteinServing != null;

  static SwapNutritionSnapshot _snapshot(SwapCandidate item, bool serving) {
    final amount = serving ? item.servingQuantity! : 100.0;
    double? scale(double? value) =>
        value == null ? null : value * amount / 100.0;
    return SwapNutritionSnapshot(
      amount: amount,
      kcal: serving ? item.kcalServing : item.kcal100,
      sugar: serving ? item.sugarServing : item.sugar100,
      protein: serving ? item.proteinServing : item.protein100,
      fat: scale(item.fat100),
      salt: serving ? item.saltServing ?? scale(item.salt100) : item.salt100,
    );
  }

  static double? _subtract(double? a, double? b) =>
      a == null || b == null ? null : a - b;
}
