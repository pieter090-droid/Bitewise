import 'package:bitewise/features/snackswap/application/swap_score_calculator.dart';
import 'package:bitewise/features/snackswap/domain/product_features.dart';
import 'package:bitewise/features/snackswap/domain/swap_score_result.dart';
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

    test('Nutella minder kcal rankt lagere kcal vergelijkbare spread hoger',
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
    });

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
