import 'package:bitewise/features/snackswap/domain/swap_score_result.dart';

/// Voedingswaarden die als één consistente portie in het dagboek belanden.
class SwapLogPortion {
  const SwapLogPortion({
    required this.grams,
    required this.kcal,
    required this.protein,
    required this.sugar,
    required this.carbs,
    required this.fat,
  });

  final double grams;
  final double kcal;
  final double protein;
  final double sugar;
  final double carbs;
  final double fat;
}

SwapLogPortion swapLogPortionFor(SwapScoreResult result) {
  final item = result.candidate;
  final useServing = result.usesServingData &&
      item.servingQuantity != null &&
      item.servingQuantity! > 0 &&
      item.kcalServing != null &&
      item.proteinServing != null &&
      item.sugarServing != null;
  final grams = useServing ? item.servingQuantity! : 100.0;
  double scaled100(double? value) => (value ?? 0) * grams / 100;

  return SwapLogPortion(
    grams: grams,
    kcal: useServing ? item.kcalServing! : item.kcal100 ?? 0,
    protein: useServing ? item.proteinServing! : item.protein100 ?? 0,
    sugar: useServing ? item.sugarServing! : item.sugar100 ?? 0,
    carbs: scaled100(item.carbs100),
    fat: scaled100(item.fat100),
  );
}
