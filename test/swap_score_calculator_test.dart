import 'package:bitewise/features/snackswap/application/swap_score_calculator.dart';
import 'package:bitewise/features/snackswap/domain/product_features.dart';
import 'package:bitewise/features/snackswap/domain/swap_score_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calculator = SwapScoreCalculator();

  test('meer eiwit vereist minimaal 20 procent of 2 gram winst', () {
    final source = product('a', protein: 10, kcal: 200);
    final tooSmall = product('b', protein: 11, kcal: 200);
    final enough = product('c', protein: 12, kcal: 200);

    expect(
        calculator
            .score(
                source: source, candidate: tooSmall, goal: SwapGoal.meerEiwit)
            .isExcluded,
        isTrue);
    final result = calculator.score(
        source: source, candidate: enough, goal: SwapGoal.meerEiwit);
    expect(result.isExcluded, isFalse);
    expect(result.reasonCodes, contains('more_protein'));
  });

  test('gebruikt portiedata wanneer beide porties betrouwbaar zijn', () {
    final source =
        product('a', kcal: 400, servingQuantity: 30, kcalServing: 120);
    final candidate =
        product('b', kcal: 350, servingQuantity: 30, kcalServing: 90);
    final result = calculator.score(
        source: source, candidate: candidate, goal: SwapGoal.minderKcal);
    expect(result.isExcluded, isFalse);
    expect(result.usesServingData, isTrue);
  });

  test('900 gram broodportie valt terug op per 100 gram', () {
    final source = product('a',
        family: 'bread_bakery',
        kcal: 250,
        servingQuantity: 900,
        kcalServing: 2250);
    final candidate = product('b',
        family: 'bread_bakery',
        kcal: 200,
        servingQuantity: 35,
        kcalServing: 70);
    final result = calculator.score(
        source: source, candidate: candidate, goal: SwapGoal.minderKcal);
    expect(result.isExcluded, isFalse);
    expect(result.usesServingData, isFalse);
  });

  test('ontbrekende niet-doeldata is neutraal en veroorzaakt geen penalty', () {
    final source = product('a', sugar: 20);
    final candidate = product('b', sugar: 10);
    final result = calculator.score(
        source: source, candidate: candidate, goal: SwapGoal.minderSuiker);
    expect(result.isExcluded, isFalse);
    expect(result.score, greaterThan(0));
  });

  test('overall databeschikbaarheid is vijf procent en verzadigt score niet',
      () {
    final source = product('a', kcal: 500, sugar: 50, protein: 5, fiber: 2);
    final candidate = product('b', kcal: 450, sugar: 40, protein: 6, fiber: 3);
    final result = calculator.score(
        source: source, candidate: candidate, goal: SwapGoal.besteOverall);
    expect(result.isExcluded, isFalse);
    expect(result.score, lessThan(100));
  });
}

SwapCandidate product(
  String barcode, {
  String family = 'test_family',
  double? kcal,
  double? protein,
  double? sugar,
  double? fiber,
  double? salt,
  double? saturatedFat,
  double? servingQuantity,
  double? kcalServing,
  double? proteinServing,
  double? sugarServing,
}) =>
    SwapCandidate(
      barcode: barcode,
      name: barcode,
      kcal100: kcal,
      protein100: protein,
      sugar100: sugar,
      fiber100: fiber,
      salt100: salt,
      saturatedFat100: saturatedFat,
      servingQuantity: servingQuantity,
      kcalServing: kcalServing,
      proteinServing: proteinServing,
      sugarServing: sugarServing,
      features: ProductFeatures(
          barcode: barcode, swapFamily: family, isSwapRelevant: true),
    );
