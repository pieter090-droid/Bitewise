import 'package:flutter_test/flutter_test.dart';

import 'package:bitewise/features/snackswap/domain/product_features.dart';
import 'package:bitewise/features/snackswap/domain/swap_comparison.dart';
import 'package:bitewise/features/snackswap/domain/swap_score_result.dart';

void main() {
  test('vergelijkt twee complete porties op hun eigen portiegrootte', () {
    final source = _candidate('bron',
        serving: 40, kcalServing: 200, sugarServing: 15, proteinServing: 3);
    final result = _result(
      _candidate('swap',
          serving: 30, kcalServing: 120, sugarServing: 6, proteinServing: 7),
      serving: true,
    );

    final c = SwapComparison.forResult(source: source, result: result);
    expect(c.usesServingData, isTrue);
    expect(c.kcalSaved, 80);
    expect(c.sugarSaved, 9);
    expect(c.proteinGained, 4);
    expect(c.source.amount, 40);
    expect(c.candidate.amount, 30);
  });

  test('valt volledig terug op 100 g als een portie onvolledig is', () {
    final source = _candidate('bron',
        serving: 40, kcalServing: 200, sugarServing: 15, proteinServing: 3);
    final result = _result(_candidate('swap'), serving: true);

    final c = SwapComparison.forResult(source: source, result: result);
    expect(c.usesServingData, isFalse);
    expect(c.kcalSaved, 100);
    expect(c.sugarSaved, 10);
    expect(c.proteinGained, 5);
  });

  test('ontbrekende voeding blijft onbekend en wordt geen nul', () {
    final source = _candidate('bron', sugar100: null);
    final result = _result(_candidate('swap'), serving: false);
    final c = SwapComparison.forResult(source: source, result: result);
    expect(c.source.sugar, isNull);
    expect(c.sugarSaved, isNull);
  });
}

SwapCandidate _candidate(
  String barcode, {
  double kcal100 = 300,
  double? sugar100 = 20,
  double protein100 = 5,
  double? serving,
  double? kcalServing,
  double? sugarServing,
  double? proteinServing,
}) =>
    SwapCandidate(
      barcode: barcode,
      name: barcode,
      kcal100: barcode == 'swap' ? 200 : kcal100,
      sugar100: barcode == 'swap' ? 10 : sugar100,
      protein100: barcode == 'swap' ? 10 : protein100,
      servingQuantity: serving,
      kcalServing: kcalServing,
      sugarServing: sugarServing,
      proteinServing: proteinServing,
      features: ProductFeatures(barcode: barcode),
    );

SwapScoreResult _result(SwapCandidate candidate, {required bool serving}) =>
    SwapScoreResult(
      candidate: candidate,
      score: 80,
      goalMatch: 80,
      nutritionImprovement: 80,
      dayContext: 50,
      similarity: 80,
      processingQuality: 50,
      dataQuality: 80,
      usesServingData: serving,
    );
