import 'package:bitewise/features/snackswap/application/swap_log_portion.dart';
import 'package:bitewise/features/snackswap/domain/product_features.dart';
import 'package:bitewise/features/snackswap/domain/swap_score_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('logt een betrouwbare portie met dezelfde voedingsgrondslag', () {
    final portion = swapLogPortionFor(_result(
      usesServingData: true,
      servingQuantity: 30,
      kcalServing: 150,
      proteinServing: 3,
      sugarServing: 12,
    ));

    expect(portion.grams, 30);
    expect(portion.kcal, 150);
    expect(portion.protein, 3);
    expect(portion.sugar, 12);
    expect(portion.carbs, 18);
    expect(portion.fat, 6);
  });

  test('valt zonder complete portiedata veilig terug op 100 gram', () {
    final portion = swapLogPortionFor(_result(
      usesServingData: true,
      servingQuantity: 30,
      kcalServing: 150,
      proteinServing: 3,
    ));

    expect(portion.grams, 100);
    expect(portion.kcal, 500);
    expect(portion.protein, 10);
    expect(portion.sugar, 40);
    expect(portion.carbs, 60);
    expect(portion.fat, 20);
  });
}

SwapScoreResult _result({
  required bool usesServingData,
  double? servingQuantity,
  double? kcalServing,
  double? proteinServing,
  double? sugarServing,
}) {
  return SwapScoreResult(
    candidate: SwapCandidate(
      barcode: 'test',
      name: 'Testproduct',
      kcal100: 500,
      protein100: 10,
      sugar100: 40,
      carbs100: 60,
      fat100: 20,
      servingQuantity: servingQuantity,
      kcalServing: kcalServing,
      proteinServing: proteinServing,
      sugarServing: sugarServing,
      features: const ProductFeatures(barcode: 'test'),
    ),
    score: 50,
    goalMatch: 50,
    nutritionImprovement: 50,
    dayContext: 50,
    similarity: 50,
    processingQuality: 50,
    dataQuality: 50,
    usesServingData: usesServingData,
  );
}
