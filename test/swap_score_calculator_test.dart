import 'package:bitewise/features/snackswap/application/swap_score_calculator.dart';
import 'package:bitewise/features/snackswap/application/rule_based_swap_provider.dart';
import 'package:bitewise/features/snackswap/domain/product_features.dart';
import 'package:bitewise/features/snackswap/domain/swap_score_result.dart';
import 'package:bitewise/features/tracker/domain/day_log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calculator = SwapScoreCalculator();

  group('kandidatenfilter', () {
    test('review_required kandidaat wordt niet getoond', () {
      final source = spread('source');
      final candidate = spread('candidate', status: 'review_required');

      final ranked = calculator.rankCandidates(
        source: source,
        candidates: [candidate],
        goal: SwapGoal.minderSuiker,
      );

      expect(ranked, isEmpty);
    });

    test('is_swap_relevant=false kandidaat wordt niet getoond', () {
      final source = spread('source');
      final candidate = spread('candidate', isSwapRelevant: false);

      final ranked = calculator.rankCandidates(
        source: source,
        candidates: [candidate],
        goal: SwapGoal.minderKcal,
      );

      expect(ranked, isEmpty);
    });

    test('classification_status=null kandidaat wordt niet getoond', () {
      final source = spread('source');
      final candidate = spread('candidate', status: null);

      final ranked = calculator.rankCandidates(
        source: source,
        candidates: [candidate],
        goal: SwapGoal.besteOverall,
      );

      expect(ranked, isEmpty);
    });

    test('classified + is_swap_relevant=true kandidaat mag meedoen', () {
      final source = spread('source', sugar: 50);
      final candidate = spread('candidate', sugar: 20);

      final ranked = calculator.rankCandidates(
        source: source,
        candidates: [candidate],
        goal: SwapGoal.minderSuiker,
      );

      expect(ranked, hasLength(1));
      expect(ranked.first.isExcluded, isFalse);
    });
  });

  group('doelen', () {
    test('Nutella minder suiker rankt lagere suiker spread hoger', () {
      final source = spread('nutella', sugar: 56, kcal: 540);
      final lowSugar = spread('low-sugar', sugar: 18, kcal: 520);
      final highSugar = spread('high-sugar', sugar: 45, kcal: 500);

      final ranked = calculator.rankCandidates(
        source: source,
        candidates: [highSugar, lowSugar],
        goal: SwapGoal.minderSuiker,
      );

      expect(ranked.first.candidate.barcode, 'low-sugar');
    });

    test(
      'Nutella minder kcal rankt lagere kcal vergelijkbare spread hoger',
      () {
        final source = spread('nutella', sugar: 50, kcal: 540);
        final lowKcal = spread('low-kcal', sugar: 45, kcal: 300);
        final highKcal = spread('high-kcal', sugar: 20, kcal: 610);

        final ranked = calculator.rankCandidates(
          source: source,
          candidates: [highKcal, lowKcal],
          goal: SwapGoal.minderKcal,
        );

        expect(ranked.first.candidate.barcode, 'low-kcal');
      },
    );

    test('Magnum minder kcal rankt lager-kcal dessert hoger', () {
      final source = iceCream('magnum', kcal: 310, sugar: 28);
      final lowKcal = iceCream('low-kcal-ice', kcal: 120, sugar: 15);
      final highKcal = iceCream('premium-ice', kcal: 330, sugar: 20);

      final ranked = calculator.rankCandidates(
        source: source,
        candidates: [highKcal, lowKcal],
        goal: SwapGoal.minderKcal,
      );

      expect(ranked.first.candidate.barcode, 'low-kcal-ice');
    });

    test('meer eiwit rankt eiwitrijkere vergelijkbare kandidaat hoger', () {
      final source = yoghurt('source', protein: 7, kcal: 120, sugar: 8);
      final highProtein = yoghurt('protein', protein: 18, kcal: 140, sugar: 6);
      final normal = yoghurt('normal', protein: 9, kcal: 110, sugar: 5);

      final ranked = calculator.rankCandidates(
        source: source,
        candidates: [normal, highProtein],
        goal: SwapGoal.meerEiwit,
      );

      expect(ranked.first.candidate.barcode, 'protein');
    });

    test('beste overall kiest gebalanceerd, niet alleen laagste kcal', () {
      final source = spread(
        'source',
        kcal: 540,
        sugar: 50,
        protein: 6,
        fiber: 2,
        salt: .3,
        saturatedFat: 12,
        nova: 4,
      );
      final onlyLowKcal = spread(
        'only-kcal',
        kcal: 250,
        sugar: 60,
        protein: 2,
        fiber: 0,
        salt: 1.2,
        saturatedFat: 20,
        nova: 4,
      );
      final balanced = spread(
        'balanced',
        kcal: 420,
        sugar: 20,
        protein: 8,
        fiber: 8,
        salt: .2,
        saturatedFat: 6,
        nova: 2,
      );

      final ranked = calculator.rankCandidates(
        source: source,
        candidates: [onlyLowKcal, balanced],
        goal: SwapGoal.besteOverall,
      );

      expect(ranked.first.candidate.barcode, 'balanced');
    });
  });

  group('rare swaps', () {
    // Gevonden bij de end-to-end test op live data: doel 'Minder kcal' op
    // Filet americain (193 kcal/100g) toonde Jamon serrano (324 kcal/100g)
    // met de tekst 'Past beter bij minder kcal'.
    test('doel Minder kcal weigert een kandidaat met meer kcal', () {
      final source = spread('filet-americain', kcal: 193, sugar: 1, protein: 14);
      final worse = spread('jamon-serrano', kcal: 324, sugar: 0.5, protein: 35);

      final ranked = calculator.rankCandidates(
        source: source,
        candidates: [worse],
        goal: SwapGoal.minderKcal,
      );

      expect(ranked, isEmpty);
      expect(
        calculator
            .score(source: source, candidate: worse, goal: SwapGoal.minderKcal)
            .excludedReason,
        'wrong_direction_for_goal',
      );
    });

    test('doel Minder suiker weigert een kandidaat met meer suiker', () {
      final source = spread('bron', sugar: 20);
      final worse = spread('zoeter', sugar: 40);

      expect(
        calculator.rankCandidates(
          source: source,
          candidates: [worse],
          goal: SwapGoal.minderSuiker,
        ),
        isEmpty,
      );
    });

    test('doel Meer eiwit weigert een kandidaat met minder eiwit', () {
      final source = spread('bron', protein: 20);
      final worse = spread('minder-eiwit', protein: 8);

      expect(
        calculator.rankCandidates(
          source: source,
          candidates: [worse],
          goal: SwapGoal.meerEiwit,
        ),
        isEmpty,
      );
    });

    test('gelijke doelas mag blijven, want de winst zit elders', () {
      final source = spread('bron', kcal: 200, sugar: 30);
      final gelijk = spread('gelijk-kcal', kcal: 200, sugar: 5);

      expect(
        calculator.rankCandidates(
          source: source,
          candidates: [gelijk],
          goal: SwapGoal.minderKcal,
        ),
        hasLength(1),
      );
    });

    test('ontbrekende doelwaarde sluit niets uit', () {
      final source = spread('bron', kcal: null);
      final kandidaat = spread('kandidaat', kcal: 900);

      expect(
        calculator.rankCandidates(
          source: source,
          candidates: [kandidaat],
          goal: SwapGoal.minderKcal,
        ),
        hasLength(1),
      );
    });

    test('beste overall kent geen richting en filtert dus niet', () {
      final source = spread('bron', kcal: 100);
      final kandidaat = spread('meer-kcal', kcal: 500, protein: 40, fiber: 12);

      expect(
        calculator.rankCandidates(
          source: source,
          candidates: [kandidaat],
          goal: SwapGoal.besteOverall,
        ),
        hasLength(1),
      );
    });

    test('tekst belooft het doel niet als de doelwinst niet gemeten is', () {
      final source = spread('bron', kcal: 300, sugar: 40, protein: 5);
      // Gelijke kcal (dus niet uitgesloten), winst zit in suiker.
      final kandidaat = spread('zelfde-kcal', kcal: 300, sugar: 2, protein: 5);

      final result = calculator.score(
        source: source,
        candidate: kandidaat,
        goal: SwapGoal.minderKcal,
      );

      expect(result.isExcluded, isFalse);
      expect(result.userReason, isNot(contains('Past beter bij minder kcal')));
      expect(result.userReason, contains('Scheelt suiker'));
    });

    test('echte kcal-winst onder de codedrempel behoudt de doelbelofte', () {
      // 193 -> 103 kcal is een halvering, maar haalt de reason-code
      // drempel (>60 op 0-100) niet. De tekst mag dan niet afzwakken.
      final source = spread('filet-americain', kcal: 193, protein: 14);
      final beter = spread('kipfilet', kcal: 103, protein: 16);

      final result = calculator.score(
        source: source,
        candidate: beter,
        goal: SwapGoal.minderKcal,
      );

      expect(result.isExcluded, isFalse);
      expect(result.userReason, contains('Past beter bij minder kcal'));
    });

    test('Andere opties blokkeert expliciete zoet-hartig botsing', () {
      final result = calculator.scoreCrossForm(
        source: spread('sweet-source'),
        candidate: product(
          'savory-candidate',
          family: 'savory_spreads',
          cluster: 'hartig',
          snackType: 'savory_spread',
          form: 'spread',
          mode: 'spread_on_bread',
          taste: const ['savory'],
          texture: const ['creamy'],
          moment: const ['breakfast'],
          isSweet: false,
          isSalty: true,
          kcal: 300,
          sugar: 2,
          protein: 8,
          fiber: 3,
          fat: 20,
          carbs: 8,
          salt: 1,
        ),
        goal: SwapGoal.minderSuiker,
      );

      expect(result.isExcluded, isTrue);
      expect(result.excludedReason, 'sweet_savory_conflict');
    });

    test('Andere opties gokt niet als zoet-hartig profiel onbekend is', () {
      final result = calculator.scoreCrossForm(
        source: product(
          'unknown-source',
          family: 'mixed_source',
          cluster: 'overig',
          snackType: 'spread',
          form: 'spread',
          mode: 'spread_on_bread',
          kcal: 500,
          sugar: 30,
          protein: 4,
          fiber: 2,
          fat: 25,
          carbs: 40,
        ),
        candidate: product(
          'unknown-candidate',
          family: 'mixed_candidate',
          cluster: 'overig',
          snackType: 'spread',
          form: 'spread',
          mode: 'spread_on_bread',
          kcal: 350,
          sugar: 15,
          protein: 6,
          fiber: 3,
          fat: 15,
          carbs: 30,
        ),
        goal: SwapGoal.minderKcal,
      );

      expect(result.excludedReason, isNot('sweet_savory_conflict'));
    });

    test('Andere opties weigert één kleine voedingsverbetering', () {
      final result = calculator.scoreCrossForm(
        source: crossFamilySpread('source', kcal: 500, sugar: 30, protein: 8),
        candidate: crossFamilySpread(
          'candidate',
          family: 'nut_butters',
          kcal: 500,
          sugar: 28,
          protein: 8,
        ),
        goal: SwapGoal.minderSuiker,
      );

      expect(result.isExcluded, isTrue);
      expect(result.excludedReason, 'insufficient_cross_family_improvement');
    });

    test('Andere opties accepteert verbetering op twee voedingsassen', () {
      final result = calculator.scoreCrossForm(
        source: crossFamilySpread('source', kcal: 500, sugar: 30, protein: 8),
        candidate: crossFamilySpread(
          'candidate',
          family: 'nut_butters',
          kcal: 430,
          sugar: 24,
          protein: 8,
        ),
        goal: SwapGoal.besteOverall,
      );

      expect(result.isExcluded, isFalse);
    });

    test('Andere opties weigert forse winst met duidelijke verslechtering', () {
      final result = calculator.scoreCrossForm(
        source: crossFamilySpread('source', kcal: 500, sugar: 30, protein: 8),
        candidate: crossFamilySpread(
          'candidate',
          family: 'nut_butters',
          kcal: 350,
          sugar: 40,
          protein: 8,
        ),
        goal: SwapGoal.minderKcal,
      );

      expect(result.isExcluded, isTrue);
      expect(result.excludedReason, 'insufficient_cross_family_improvement');
    });

    test('Andere opties accepteert forse winst zonder verslechtering', () {
      final result = calculator.scoreCrossForm(
        source: crossFamilySpread('source', kcal: 500, sugar: 30, protein: 8),
        candidate: crossFamilySpread(
          'candidate',
          family: 'nut_butters',
          kcal: 350,
          sugar: 30,
          protein: 8,
        ),
        goal: SwapGoal.minderKcal,
      );

      expect(result.isExcluded, isFalse);
    });

    test('Nutella naar water mag niet', () {
      final result = calculator.score(
        source: spread('nutella'),
        candidate: drink('water'),
        goal: SwapGoal.minderKcal,
      );

      expect(result.isExcluded, isTrue);
      expect(result.excludedReason, 'insufficient_similarity');
    });

    test('Magnum naar rauwe vis mag niet', () {
      final result = calculator.score(
        source: iceCream('magnum'),
        candidate: rawFish('raw-fish'),
        goal: SwapGoal.minderKcal,
      );

      expect(result.isExcluded, isTrue);
      expect(result.excludedReason, 'candidate_not_eligible');
    });

    test('zalm wrap naar fish_seafood/raw fish mag niet als snackadvies', () {
      final result = calculator.score(
        source: wrap('zalm-wrap'),
        candidate: rawFish('tonijnblik'),
        goal: SwapGoal.besteOverall,
      );

      expect(result.isExcluded, isTrue);
      expect(result.excludedReason, 'candidate_not_eligible');
    });
  });

  group('modelweging', () {
    test('gebruikt portiedata alleen als beide kanten kernvelden hebben', () {
      final result = calculator.score(
        source: servingSpread(
          'source',
          kcalServing: 270,
          sugarServing: 25,
          proteinServing: 3,
        ),
        candidate: servingSpread(
          'candidate',
          kcalServing: 90,
          sugarServing: 10,
          proteinServing: 5,
        ),
        goal: SwapGoal.minderKcal,
      );

      expect(result.usesServingData, isTrue);
      expect(result.reasonCodes, contains('fewer_kcal'));
    });

    test('valt volledig terug op 100g als een kern-portieveld ontbreekt', () {
      final result = calculator.score(
        source: servingSpread(
          'source',
          kcalServing: 270,
          sugarServing: 25,
          proteinServing: 3,
        ),
        candidate: servingSpread(
          'candidate',
          kcal: 300,
          kcalServing: 180,
          sugarServing: 10,
          proteinServing: null,
        ),
        goal: SwapGoal.minderKcal,
      );

      expect(result.usesServingData, isFalse);
      expect(result.reasonCodes, isNot(contains('fewer_kcal')));
    });

    test('hoofdformule gebruikt exact 30/25/15/15/10/5', () {
      expect(SwapScoreCalculator.expectedWeights.goalMatch, 30);
      expect(SwapScoreCalculator.expectedWeights.nutritionImprovement, 25);
      expect(SwapScoreCalculator.expectedWeights.dayContext, 15);
      expect(SwapScoreCalculator.expectedWeights.similarity, 15);
      expect(SwapScoreCalculator.expectedWeights.processingQuality, 10);
      expect(SwapScoreCalculator.expectedWeights.dataQuality, 5);

      final result = calculator.score(
        source: spread('source', sugar: 50, kcal: 500),
        candidate: spread('candidate', sugar: 20, kcal: 400),
        goal: SwapGoal.minderSuiker,
      );

      final recomputed = result.goalMatch * .30 +
          result.nutritionImprovement * .25 +
          result.dayContext * .15 +
          result.similarity * .15 +
          result.processingQuality * .10 +
          result.dataQuality * .05;
      expect(result.score, closeTo(recomputed, .0001));
    });

    test('interne minder-suiker subweging is 75/15/10', () {
      final source = spread(
        'source',
        sugar: 40,
        kcal: 500,
        protein: 5,
        fiber: 2,
      );
      final candidate = spread(
        'candidate',
        sugar: 20,
        kcal: 450,
        protein: 6,
        fiber: 3,
      );

      final result = calculator.score(
        source: source,
        candidate: candidate,
        goal: SwapGoal.minderSuiker,
      );

      // sugar reduction: 50, kcal reduction: 10,
      // protein gain: 20, fiber gain: 50 -> avg 35.
      final expectedGoalMatch = 50 * .75 + 10 * .15 + 35 * .10;
      expect(result.goalMatch, closeTo(expectedGoalMatch, .0001));
    });

    test('score blijft altijd tussen 0 en 100', () {
      final result = calculator.score(
        source: spread('source', kcal: 1000, sugar: 100, protein: 0),
        candidate: spread('candidate', kcal: 0, sugar: 0, protein: 100),
        goal: SwapGoal.besteOverall,
      );

      expect(result.score, inInclusiveRange(0, 100));
      expect(result.goalMatch, inInclusiveRange(0, 100));
      expect(result.nutritionImprovement, inInclusiveRange(0, 100));
      expect(result.dayContext, inInclusiveRange(0, 100));
      expect(result.similarity, inInclusiveRange(0, 100));
      expect(result.processingQuality, inInclusiveRange(0, 100));
      expect(result.dataQuality, inInclusiveRange(0, 100));
    });

    test('ontbrekende dagcontext scoort neutraal 50/100', () {
      final result = calculator.score(
        source: spread('source', sugar: 50),
        candidate: spread('candidate', sugar: 20),
        goal: SwapGoal.minderSuiker,
      );

      expect(result.dayContext, 50);
    });

    test(
      'suiker bijna op limiet verhoogt dagcontextscore voor suikerarme kandidaat',
      () {
        final source = spread('source', sugar: 50);
        final lowSugar = spread('low-sugar', sugar: 5);
        final highSugar = spread('high-sugar', sugar: 45);
        const context = SwapDayContext(dailySugarUsed: 38, dailySugarGoal: 40);

        final lowResult = calculator.score(
          source: source,
          candidate: lowSugar,
          goal: SwapGoal.minderSuiker,
          dayContext: context,
        );
        final highResult = calculator.score(
          source: source,
          candidate: highSugar,
          goal: SwapGoal.minderSuiker,
          dayContext: context,
        );

        expect(lowResult.dayContext, greaterThan(highResult.dayContext));
      },
    );

    test(
      'open eiwitdoel verhoogt dagcontextscore voor eiwitrijke kandidaat',
      () {
        final source = yoghurt('source', protein: 7, kcal: 120, sugar: 8);
        final highProtein = yoghurt(
          'high-protein',
          protein: 25,
          kcal: 140,
          sugar: 6,
        );
        final lowProtein = yoghurt(
          'low-protein',
          protein: 4,
          kcal: 110,
          sugar: 5,
        );
        const context = SwapDayContext(
          dailyProteinUsed: 40,
          dailyProteinGoal: 120,
        );

        final highResult = calculator.score(
          source: source,
          candidate: highProtein,
          goal: SwapGoal.meerEiwit,
          dayContext: context,
        );
        final lowResult = calculator.score(
          source: source,
          candidate: lowProtein,
          goal: SwapGoal.meerEiwit,
          dayContext: context,
        );

        expect(highResult.dayContext, greaterThan(lowResult.dayContext));
      },
    );

    test(
      'DailySummary wordt veilig gemapt naar SwapDayContext zonder vezels te verzinnen',
      () {
        const summary = DailySummary(
          kcal: 1200,
          protein: 55,
          sugar: 35,
          carbs: 140,
          calorieTarget: 2100,
          proteinTarget: 110,
          sugarLimit: 45,
          carbsTarget: 250,
        );

        final context = swapDayContextFromSummary(summary);

        expect(context.dailyKcalUsed, 1200);
        expect(context.dailyKcalGoal, 2100);
        expect(context.dailySugarUsed, 35);
        expect(context.dailySugarGoal, 45);
        expect(context.dailyProteinUsed, 55);
        expect(context.dailyProteinGoal, 110);
        expect(context.dailyFiberUsed, isNull);
        expect(context.dailyFiberGoal, isNull);
      },
    );
  });

  test('resolved view modelvelden worden gemapt naar ProductFeatures', () {
    final candidate = SwapCandidate.fromJoinedJson({
      'barcode': '123',
      'name': 'Resolved product',
      'classification_status': 'classified',
      'is_swap_relevant': true,
      'swap_family': 'chocolate_spreads',
      'is_sweet': true,
      'is_salty': false,
      'is_drink': false,
      'is_dairy': false,
      'is_chocolate': true,
      'is_crunchy': false,
      'is_less_processed': true,
    });

    expect(candidate.name, 'Resolved product');
    expect(candidate.features.classificationStatus, 'classified');
    expect(candidate.features.isSweet, isTrue);
    expect(candidate.features.isDrink, isFalse);
    expect(candidate.features.isChocolate, isTrue);
    expect(candidate.features.isLessProcessed, isTrue);
  });
}

SwapCandidate spread(
  String barcode, {
  String? status = 'classified',
  bool isSwapRelevant = true,
  double? kcal = 540,
  double? sugar = 50,
  double? protein = 6,
  double? fiber = 2,
  double? fat = 30,
  double? carbs = 55,
  double? salt = .2,
  double? saturatedFat = 10,
  int? nova = 4,
}) =>
    product(
      barcode,
      family: 'chocolate_spreads',
      cluster: 'zoet',
      snackType: 'sweet_spread',
      form: 'spread',
      mode: 'spread_on_bread',
      taste: const ['chocolate', 'sweet'],
      texture: const ['creamy'],
      moment: const ['breakfast', 'snack'],
      isSweet: true,
      isChocolate: true,
      status: status,
      isSwapRelevant: isSwapRelevant,
      kcal: kcal,
      sugar: sugar,
      protein: protein,
      fiber: fiber,
      fat: fat,
      carbs: carbs,
      salt: salt,
      saturatedFat: saturatedFat,
      nova: nova,
    );

SwapCandidate servingSpread(
  String barcode, {
  double? kcal = 540,
  double? sugar = 50,
  double? protein = 6,
  double? kcalServing,
  double? sugarServing,
  double? proteinServing,
}) =>
    product(
      barcode,
      family: 'chocolate_spreads',
      cluster: 'zoet',
      snackType: 'sweet_spread',
      form: 'spread',
      mode: 'spread_on_bread',
      taste: const ['chocolate', 'sweet'],
      texture: const ['creamy'],
      moment: const ['breakfast', 'snack'],
      isSweet: true,
      kcal: kcal,
      sugar: sugar,
      protein: protein,
      fiber: 2,
      fat: 30,
      carbs: 55,
      servingQuantity: 50,
      kcalServing: kcalServing,
      sugarServing: sugarServing,
      proteinServing: proteinServing,
    );

SwapCandidate crossFamilySpread(
  String barcode, {
  String family = 'chocolate_spreads',
  double? kcal,
  double? sugar,
  double? protein,
}) =>
    product(
      barcode,
      family: family,
      cluster: 'beleg',
      snackType: 'spread',
      form: 'spread',
      mode: 'spread_on_bread',
      taste: const ['creamy'],
      texture: const ['creamy'],
      moment: const ['breakfast'],
      kcal: kcal,
      sugar: sugar,
      protein: protein,
      fiber: 4,
      fat: 20,
      carbs: 25,
      salt: .2,
      saturatedFat: 5,
    );

SwapCandidate iceCream(
  String barcode, {
  double? kcal = 280,
  double? sugar = 25,
}) =>
    product(
      barcode,
      family: 'ice_cream_desserts',
      cluster: 'zuivel',
      snackType: 'ice_cream',
      form: 'ice_cream',
      mode: 'dessert',
      taste: const ['sweet', 'vanilla'],
      texture: const ['creamy'],
      moment: const ['dessert', 'snack'],
      isSweet: true,
      isDairy: true,
      kcal: kcal,
      sugar: sugar,
      protein: 4,
      fiber: 1,
      fat: 15,
      carbs: 30,
    );

SwapCandidate yoghurt(
  String barcode, {
  double? protein,
  double? kcal,
  double? sugar,
}) =>
    product(
      barcode,
      family: 'yoghurt_skyr_quark',
      cluster: 'zuivel',
      snackType: 'yoghurt',
      form: 'cup',
      mode: 'spoonable',
      taste: const ['dairy'],
      texture: const ['creamy'],
      moment: const ['breakfast', 'snack'],
      isDairy: true,
      protein: protein,
      kcal: kcal,
      sugar: sugar,
      fiber: 0,
      fat: 3,
      carbs: 8,
    );

SwapCandidate drink(String barcode) => product(
      barcode,
      family: 'water',
      cluster: 'drank',
      snackType: 'water',
      form: 'drink',
      mode: 'drink',
      taste: const ['neutral'],
      texture: const ['liquid'],
      moment: const ['drink'],
      isDrink: true,
      kcal: 0,
      sugar: 0,
      protein: 0,
      fiber: 0,
      fat: 0,
      carbs: 0,
    );

SwapCandidate rawFish(String barcode) => product(
      barcode,
      family: 'fish_seafood',
      cluster: 'maaltijd',
      snackType: 'raw_fish',
      form: 'raw_piece',
      mode: 'cook_first',
      isSwapRelevant: false,
      kcal: 140,
      sugar: 0,
      protein: 22,
      fiber: 0,
      fat: 5,
      carbs: 0,
    );

SwapCandidate wrap(String barcode) => product(
      barcode,
      family: 'sandwiches_wraps',
      cluster: 'maaltijd',
      snackType: 'wrap',
      form: 'wrap',
      mode: 'ready_to_eat',
      taste: const ['savory'],
      texture: const ['soft'],
      moment: const ['lunch'],
      kcal: 240,
      sugar: 3,
      protein: 12,
      fiber: 4,
      fat: 8,
      carbs: 30,
    );

SwapCandidate product(
  String barcode, {
  required String family,
  required String cluster,
  required String snackType,
  required String form,
  required String mode,
  String? status = 'classified',
  bool isSwapRelevant = true,
  List<String> taste = const [],
  List<String> texture = const [],
  List<String> moment = const [],
  bool? isSweet,
  bool? isSalty,
  bool? isDrink,
  bool? isDairy,
  bool? isChocolate,
  bool? isCrunchy,
  double? kcal,
  double? sugar,
  double? protein,
  double? fiber,
  double? fat,
  double? carbs,
  double? salt,
  double? saturatedFat,
  double? servingQuantity,
  double? kcalServing,
  double? sugarServing,
  double? proteinServing,
  double? fiberServing,
  double? saltServing,
  double? saturatedFatServing,
  int? nova,
  String? nutriscoreGrade = 'c',
  double? dataQuality = 90,
  double? aiConfidence = .9,
  double? completeness = 90,
}) =>
    SwapCandidate(
      barcode: barcode,
      name: barcode,
      kcal100: kcal,
      sugar100: sugar,
      protein100: protein,
      fiber100: fiber,
      fat100: fat,
      carbs100: carbs,
      salt100: salt,
      saturatedFat100: saturatedFat,
      servingQuantity: servingQuantity,
      kcalServing: kcalServing,
      sugarServing: sugarServing,
      proteinServing: proteinServing,
      fiberServing: fiberServing,
      saltServing: saltServing,
      saturatedFatServing: saturatedFatServing,
      novaGroup: nova,
      nutriscoreGrade: nutriscoreGrade,
      completeness: completeness,
      features: ProductFeatures(
        barcode: barcode,
        classificationStatus: status,
        swapFamily: family,
        categoryCluster: cluster,
        snackType: snackType,
        productForm: form,
        consumptionMode: mode,
        usageContext: moment,
        tasteProfile: taste,
        textureProfile: texture,
        useMoment: moment,
        isSweet: isSweet,
        isSalty: isSalty,
        isDrink: isDrink,
        isDairy: isDairy,
        isChocolate: isChocolate,
        isCrunchy: isCrunchy,
        isSwapRelevant: isSwapRelevant,
        dataQualityScore: dataQuality,
        aiConfidence: aiConfidence,
      ),
    );
