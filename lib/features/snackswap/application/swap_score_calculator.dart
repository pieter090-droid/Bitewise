import 'dart:math' as math;

import 'package:bitewise/features/snackswap/domain/product_features.dart';
import 'package:bitewise/features/snackswap/domain/swap_score_result.dart';

class SwapScoreCalculator {
  const SwapScoreCalculator([this.weights = SwapScoreWeights.fallback]);

  /// Alleen bewaard voor API-compatibiliteit. Het model gebruikt exact
  /// 30/25/15/15/10/5; externe DB-gewichten worden niet toegepast.
  final SwapScoreWeights weights;

  static const expectedWeights = SwapScoreWeights(
    goalMatch: 30,
    nutritionImprovement: 25,
    dayContext: 15,
    similarity: 15,
    processingQuality: 10,
    dataQuality: 5,
  );

  SwapScoreResult score({
    required SwapCandidate source,
    required SwapCandidate candidate,
    required SwapGoal goal,
    SwapDayContext dayContext = const SwapDayContext(),
  }) {
    if (!_isEligibleCandidate(source, candidate)) {
      return _excluded(candidate, 'candidate_not_eligible');
    }
    if (_movesAwayFromGoal(source, candidate, goal)) {
      return _excluded(candidate, 'wrong_direction_for_goal');
    }
    return _calculate(source, candidate, goal, dayContext);
  }

  SwapScoreResult scoreCrossForm({
    required SwapCandidate source,
    required SwapCandidate candidate,
    required SwapGoal goal,
    SwapDayContext dayContext = const SwapDayContext(),
  }) {
    if (_hasSweetSavoryConflict(source.features, candidate.features)) {
      return _excluded(candidate, 'sweet_savory_conflict');
    }
    if (!_passesCrossFamilyNutritionGate(source, candidate)) {
      return _excluded(candidate, 'insufficient_cross_family_improvement');
    }
    return score(
      source: source,
      candidate: candidate,
      goal: goal,
      dayContext: dayContext,
    );
  }

  List<SwapScoreResult> rankCandidates({
    required SwapCandidate source,
    required List<SwapCandidate> candidates,
    required SwapGoal goal,
    SwapDayContext dayContext = const SwapDayContext(),
  }) =>
      (candidates
          .map(
            (c) => score(
              source: source,
              candidate: c,
              goal: goal,
              dayContext: dayContext,
            ),
          )
          .where((r) => !r.isExcluded)
          .toList()
        ..sort((a, b) => b.score.compareTo(a.score)));

  SwapScoreResult _calculate(
    SwapCandidate source,
    SwapCandidate candidate,
    SwapGoal goal,
    SwapDayContext dayContext,
  ) {
    final usesServingData = _canUseServingData(source, candidate);
    final goalMatch = _goalMatchScore(source, candidate, goal, usesServingData);
    final nutrition =
        _nutritionImprovementScore(source, candidate, usesServingData);
    final day = _dayContextScore(candidate, dayContext, usesServingData);
    final similarity = similarityScore(source.features, candidate.features);
    if (similarity < 45) {
      return _excluded(candidate, 'insufficient_similarity');
    }
    final processing = _processingQualityScore(source, candidate);
    final dataQuality = _dataQualityScore(candidate);

    final score = _clamp(
      goalMatch * .30 +
          nutrition * .25 +
          day * .15 +
          similarity * .15 +
          processing * .10 +
          dataQuality * .05,
      0,
      100,
    );

    final reasons = _reasonCodes(source, candidate, goal, usesServingData);
    final reason =
        _userReasonFor(source, candidate, goal, reasons, usesServingData);
    return SwapScoreResult(
      candidate: candidate,
      score: score,
      goalMatch: goalMatch,
      nutritionImprovement: nutrition,
      dayContext: day,
      similarity: similarity,
      processingQuality: processing,
      dataQuality: dataQuality,
      reasons: [reason],
      reasonCodes: reasons,
      userReason: reason,
      usesServingData: usesServingData,
    );
  }

  static bool _isEligibleCandidate(
    SwapCandidate source,
    SwapCandidate candidate,
  ) =>
      candidate.barcode != source.barcode &&
      candidate.features.classificationStatus == 'classified' &&
      candidate.features.isSwapRelevant &&
      candidate.features.swapFamily != null &&
      candidate.features.swapFamily!.isNotEmpty;

  /// Een expliciet zoet product mag niet als alternatief voor een expliciet
  /// hartig product worden getoond (en omgekeerd). Ontbrekende profieldata
  /// blijft bewust permissief: null is onbekend en dus geen reden om te
  /// gokken of een kandidaat te blokkeren.
  static bool _hasSweetSavoryConflict(
    ProductFeatures source,
    ProductFeatures candidate,
  ) {
    final sourceSweet = source.isSweet == true;
    final sourceSavory = source.isSalty == true && source.isSweet != true;
    final candidateSweet = candidate.isSweet == true;
    final candidateSavory =
        candidate.isSalty == true && candidate.isSweet != true;
    return (sourceSweet && candidateSavory) || (sourceSavory && candidateSweet);
  }

  /// Een gekozen doel heeft een richting. Een kandidaat die op precies die
  /// as de VERKEERDE kant op gaat hoort er niet bij, ook niet als hij op
  /// andere assen wint -- anders belooft de app "minder kcal" en toont hij
  /// een product met meer kcal (gevonden bij Filet americain -> Jamon
  /// serrano: 193 -> 324 kcal/100g). Ontbrekende waarden sluiten niets uit;
  /// gelijk blijven mag, want dan wint de kandidaat elders. `besteOverall`
  /// heeft geen richting en wordt niet gefilterd.
  /// De doelas moet op BEIDE grondslagen kloppen: per portie én per 100 g.
  /// Anders vliegen er kandidaten door die alleen winnen omdat hun portie
  /// groter is -- "meer eiwit" doordat je meer eet is geen zinnige swap, en
  /// omgekeerd oogt een kandidaat met meer kcal/100 g tegenstrijdig naast de
  /// waarden die het scherm toont.
  static bool _movesAwayFromGoal(
    SwapCandidate source,
    SwapCandidate candidate,
    SwapGoal goal,
  ) {
    if (goal == SwapGoal.besteOverall) return false;
    if (_worseOnGoalAxis(source, candidate, goal, false)) return true;
    if (_canUseServingData(source, candidate) &&
        _worseOnGoalAxis(source, candidate, goal, true)) {
      return true;
    }
    return false;
  }

  static bool _worseOnGoalAxis(
    SwapCandidate source,
    SwapCandidate candidate,
    SwapGoal goal,
    bool serving,
  ) {
    final (double? from, double? to, bool lowerIsBetter) = switch (goal) {
      SwapGoal.minderKcal => (
          _kcal(source, serving),
          _kcal(candidate, serving),
          true
        ),
      SwapGoal.minderSuiker => (
          _sugar(source, serving),
          _sugar(candidate, serving),
          true
        ),
      SwapGoal.meerEiwit => (
          _protein(source, serving),
          _protein(candidate, serving),
          false
        ),
      SwapGoal.besteOverall => (null, null, true),
    };
    if (from == null || to == null) return false;
    return lowerIsBetter ? to > from : to < from;
  }

  /// Cross-family suggesties vereisen twee verbeterde voedingsassen (>=10%)
  /// of één forse verbetering (>=25%) zonder een bekende as >10% te
  /// verslechteren. Ontbrekende waarden tellen niet mee.
  static bool _passesCrossFamilyNutritionGate(
    SwapCandidate source,
    SwapCandidate candidate,
  ) {
    final changes = <double>[
      _relativeAxisChange(source.kcal100, candidate.kcal100),
      _relativeAxisChange(source.sugar100, candidate.sugar100),
      _relativeAxisChange(source.salt100, candidate.salt100),
      _relativeAxisChange(
        source.saturatedFat100,
        candidate.saturatedFat100,
      ),
      _relativeAxisChange(
        source.protein100,
        candidate.protein100,
        higherIsBetter: true,
      ),
      _relativeAxisChange(
        source.fiber100,
        candidate.fiber100,
        higherIsBetter: true,
      ),
    ].where((change) => change.isFinite).toList();

    if (changes.where((change) => change >= 10).length >= 2) return true;
    return changes.any((change) => change >= 25) &&
        !changes.any((change) => change < -10);
  }

  static double _relativeAxisChange(
    double? source,
    double? candidate, {
    bool higherIsBetter = false,
  }) {
    if (source == null || candidate == null) return double.nan;
    final raw = higherIsBetter ? candidate - source : source - candidate;
    return raw / math.max(source.abs(), 1) * 100;
  }

  static double _goalMatchScore(
    SwapCandidate source,
    SwapCandidate candidate,
    SwapGoal goal,
    bool usesServingData,
  ) {
    return switch (goal) {
      SwapGoal.minderKcal => _weighted([
          (
            _reduction(_kcal(source, usesServingData),
                _kcal(candidate, usesServingData)),
            70
          ),
          (
            _average([
              _gain(_protein(source, usesServingData),
                  _protein(candidate, usesServingData)),
              _gain(_fiber(source, usesServingData),
                  _fiber(candidate, usesServingData)),
            ]),
            20,
          ),
          (
            _average([
              _reduction(_sugar(source, usesServingData),
                  _sugar(candidate, usesServingData)),
              _reduction(_fat(source, usesServingData),
                  _fat(candidate, usesServingData)),
            ]),
            10,
          ),
        ]),
      SwapGoal.minderSuiker => _weighted([
          (
            _reduction(_sugar(source, usesServingData),
                _sugar(candidate, usesServingData)),
            75
          ),
          (
            _reduction(_kcal(source, usesServingData),
                _kcal(candidate, usesServingData)),
            15
          ),
          (
            _average([
              _gain(_protein(source, usesServingData),
                  _protein(candidate, usesServingData)),
              _gain(_fiber(source, usesServingData),
                  _fiber(candidate, usesServingData)),
            ]),
            10,
          ),
        ]),
      SwapGoal.meerEiwit => _weighted([
          (
            _gain(_protein(source, usesServingData),
                _protein(candidate, usesServingData)),
            75
          ),
          (
            _average([
              _notHigher(_sugar(source, usesServingData),
                  _sugar(candidate, usesServingData)),
              _notHigher(_saturatedFat(source, usesServingData),
                  _saturatedFat(candidate, usesServingData)),
              _notHigher(_salt(source, usesServingData),
                  _salt(candidate, usesServingData)),
            ]),
            15,
          ),
          (
            _kcalAcceptance(_kcal(source, usesServingData),
                _kcal(candidate, usesServingData)),
            10
          ),
        ]),
      SwapGoal.besteOverall => _weighted([
          (
            _reduction(_kcal(source, usesServingData),
                _kcal(candidate, usesServingData)),
            20
          ),
          (
            _reduction(_sugar(source, usesServingData),
                _sugar(candidate, usesServingData)),
            20
          ),
          (
            _gain(_protein(source, usesServingData),
                _protein(candidate, usesServingData)),
            15
          ),
          (
            _gain(_fiber(source, usesServingData),
                _fiber(candidate, usesServingData)),
            15
          ),
          (
            _average([
              _reduction(_salt(source, usesServingData),
                  _salt(candidate, usesServingData)),
              _reduction(_saturatedFat(source, usesServingData),
                  _saturatedFat(candidate, usesServingData)),
            ]),
            15,
          ),
          (
            _average([
              _nutriscoreImprovement(source, candidate),
              _novaImprovement(source, candidate),
            ]),
            15,
          ),
        ]),
    };
  }

  static double _nutritionImprovementScore(
    SwapCandidate source,
    SwapCandidate candidate,
    bool usesServingData,
  ) =>
      _weighted([
        (
          _reduction(_kcal(source, usesServingData),
              _kcal(candidate, usesServingData)),
          20
        ),
        (
          _reduction(_sugar(source, usesServingData),
              _sugar(candidate, usesServingData)),
          20
        ),
        (
          _gain(_protein(source, usesServingData),
              _protein(candidate, usesServingData)),
          15
        ),
        (
          _gain(_fiber(source, usesServingData),
              _fiber(candidate, usesServingData)),
          15
        ),
        (
          _reduction(_salt(source, usesServingData),
              _salt(candidate, usesServingData)),
          10
        ),
        (
          _reduction(_saturatedFat(source, usesServingData),
              _saturatedFat(candidate, usesServingData)),
          10
        ),
        (
          _average([
            _reduction(_fat(source, usesServingData),
                _fat(candidate, usesServingData)),
            _carbBalance(_carbs(source, usesServingData),
                _carbs(candidate, usesServingData)),
          ]),
          10,
        ),
      ]);

  static double _dayContextScore(
    SwapCandidate candidate,
    SwapDayContext context,
    bool usesServingData,
  ) {
    if (context.isEmpty) return 50;
    return _weighted([
      (
        _limitContextScore(
          used: context.dailyKcalUsed,
          goal: context.dailyKcalGoal,
          candidateValue: _kcal(candidate, usesServingData),
          lowerIsBetterAtLimit: true,
          typicalHigh: 600,
        ),
        25,
      ),
      (
        _limitContextScore(
          used: context.dailySugarUsed,
          goal: context.dailySugarGoal,
          candidateValue: _sugar(candidate, usesServingData),
          lowerIsBetterAtLimit: true,
          typicalHigh: 60,
        ),
        25,
      ),
      (
        _targetContextScore(
          used: context.dailyProteinUsed,
          goal: context.dailyProteinGoal,
          candidateValue: _protein(candidate, usesServingData),
          typicalHigh: 30,
        ),
        25,
      ),
      (
        _targetContextScore(
          used: context.dailyFiberUsed,
          goal: context.dailyFiberGoal,
          candidateValue: _fiber(candidate, usesServingData),
          typicalHigh: 15,
        ),
        25,
      ),
    ]);
  }

  static double similarityScore(ProductFeatures a, ProductFeatures b) =>
      _weighted([
        (_stringMatch(a.swapFamily, b.swapFamily), 35),
        (_stringMatch(a.categoryCluster, b.categoryCluster), 20),
        (_stringMatch(a.productForm, b.productForm), 15),
        (
          _average([
            _stringMatch(a.consumptionMode, b.consumptionMode),
            _listOverlap(a.usageContext, b.usageContext),
            _listOverlap(
              a.secondaryConsumptionModes,
              b.secondaryConsumptionModes,
            ),
          ]),
          15,
        ),
        (
          _average([
            _listOverlap(a.tasteProfile, b.tasteProfile),
            _listOverlap(a.textureProfile, b.textureProfile),
            _listOverlap(a.useMoment, b.useMoment),
            _boolMatch(a.isSweet, b.isSweet),
            _boolMatch(a.isSalty, b.isSalty),
            _boolMatch(a.isDrink, b.isDrink),
            _boolMatch(a.isDairy, b.isDairy),
            _boolMatch(a.isChocolate, b.isChocolate),
            _boolMatch(a.isCrunchy, b.isCrunchy),
          ]),
          15,
        ),
      ]);

  static double _processingQualityScore(
    SwapCandidate source,
    SwapCandidate candidate,
  ) =>
      _weighted([
        (_novaImprovement(source, candidate), 30),
        (_nutriscoreImprovement(source, candidate), 25),
        (
          _average([
            _reductionInt(source.additivesN, candidate.additivesN),
            _reductionInt(
                _ingredientCount(source), _ingredientCount(candidate)),
          ]),
          20,
        ),
        (_boolPositive(candidate.features.isLessProcessed), 15),
        (
          _average([
            _boolPenalty(candidate.features.hasSweeteners),
            _boolPenalty(candidate.features.hasPalmOil),
          ]),
          10,
        ),
      ]);

  static double _dataQualityScore(SwapCandidate candidate) => _weighted([
        (_scoreField(candidate.features.dataQualityScore), 40),
        (_scoreField(candidate.completeness), 30),
        (_confidenceField(candidate.features.aiConfidence), 20),
        (_statesTagsScore(candidate.statesTags), 10),
      ]);

  static List<String> _reasonCodes(
    SwapCandidate source,
    SwapCandidate candidate,
    SwapGoal goal,
    bool usesServingData,
  ) {
    final codes = <String>[];
    if (_reduction(
          _kcal(source, usesServingData),
          _kcal(candidate, usesServingData),
        ) >
        60) {
      codes.add('fewer_kcal');
    }
    if (_reduction(
          _sugar(source, usesServingData),
          _sugar(candidate, usesServingData),
        ) >
        60) {
      codes.add('less_sugar');
    }
    if (_gain(
          _protein(source, usesServingData),
          _protein(candidate, usesServingData),
        ) >
        60) {
      codes.add('more_protein');
    }
    if (_gain(
          _fiber(source, usesServingData),
          _fiber(candidate, usesServingData),
        ) >
        60) {
      codes.add('more_fiber');
    }
    if (_novaImprovement(source, candidate) > 60) {
      codes.add('less_processed');
    }
    if (codes.isEmpty) codes.add(goal.value);
    return codes;
  }

  static bool _canUseServingData(
    SwapCandidate source,
    SwapCandidate candidate,
  ) =>
      _hasComparableServing(source) && _hasComparableServing(candidate);

  static bool _hasComparableServing(SwapCandidate candidate) =>
      candidate.servingQuantity != null &&
      candidate.servingQuantity! > 0 &&
      candidate.kcalServing != null &&
      candidate.sugarServing != null &&
      candidate.proteinServing != null;

  static double? _kcal(SwapCandidate candidate, bool serving) =>
      serving ? candidate.kcalServing : candidate.kcal100;
  static double? _sugar(SwapCandidate candidate, bool serving) =>
      serving ? candidate.sugarServing : candidate.sugar100;
  static double? _protein(SwapCandidate candidate, bool serving) =>
      serving ? candidate.proteinServing : candidate.protein100;
  static double? _fiber(SwapCandidate candidate, bool serving) =>
      serving ? candidate.fiberServing : candidate.fiber100;
  static double? _salt(SwapCandidate candidate, bool serving) =>
      serving ? candidate.saltServing : candidate.salt100;
  static double? _saturatedFat(SwapCandidate candidate, bool serving) =>
      serving ? candidate.saturatedFatServing : candidate.saturatedFat100;

  // Er bestaan geen betrouwbare portievelden voor vet en koolhydraten. Laat
  // die assen neutraal meetellen in plaats van portie- en 100g-data te mengen.
  static double? _fat(SwapCandidate candidate, bool serving) =>
      serving ? null : candidate.fat100;
  static double? _carbs(SwapCandidate candidate, bool serving) =>
      serving ? null : candidate.carbs100;

  /// De doelbelofte mag alleen worden uitgesproken als de kandidaat op de
  /// doelas ook echt wint. Dat toetsen we aan de werkelijke waarden, niet
  /// aan de reason-codes: die hebben een drempel van >60 op een 0-100
  /// schaal, dus een halvering van de calorieën haalt hem soms niet en dan
  /// zou de tekst onterecht afzwakken. Wint de kandidaat alleen elders, dan
  /// benoemen we dát in plaats van het doel te beloven.
  static String _userReasonFor(
    SwapCandidate source,
    SwapCandidate candidate,
    SwapGoal goal,
    List<String> codes,
    bool usesServingData,
  ) {
    if (!_improvesGoalAxis(source, candidate, goal, usesServingData)) {
      return switch (codes.firstWhere(
        (c) => c != goal.value,
        orElse: () => '',
      )) {
        'fewer_kcal' => 'Scheelt calorieën en blijft vergelijkbaar genoeg '
            'met het originele product.',
        'less_sugar' => 'Scheelt suiker en blijft vergelijkbaar genoeg met '
            'het originele product.',
        'more_protein' => 'Levert meer eiwit en blijft vergelijkbaar genoeg '
            'met het originele product.',
        'more_fiber' => 'Levert meer vezels en blijft vergelijkbaar genoeg '
            'met het originele product.',
        'less_processed' => 'Is minder bewerkt en blijft vergelijkbaar '
            'genoeg met het originele product.',
        _ => 'Een vergelijkbaar alternatief voor dit product.',
      };
    }
    return _userReason(goal, codes);
  }

  /// Wint de kandidaat iets op precies de as van het gekozen doel?
  /// Ontbrekende waarden gelden als "niet aantoonbaar beter".
  static bool _improvesGoalAxis(
    SwapCandidate source,
    SwapCandidate candidate,
    SwapGoal goal,
    bool serving,
  ) {
    final (double? from, double? to, bool lowerIsBetter) = switch (goal) {
      SwapGoal.minderKcal => (
          _kcal(source, serving),
          _kcal(candidate, serving),
          true
        ),
      SwapGoal.minderSuiker => (
          _sugar(source, serving),
          _sugar(candidate, serving),
          true
        ),
      SwapGoal.meerEiwit => (
          _protein(source, serving),
          _protein(candidate, serving),
          false
        ),
      // Beste overall belooft geen enkele as, dus altijd toegestaan.
      SwapGoal.besteOverall => (null, null, true),
    };
    if (goal == SwapGoal.besteOverall) return true;
    if (from == null || to == null) return false;
    return lowerIsBetter ? to < from : to > from;
  }

  static String _userReason(SwapGoal goal, List<String> codes) {
    final base = switch (goal) {
      SwapGoal.minderKcal => 'Past beter bij minder kcal',
      SwapGoal.minderSuiker => 'Past beter bij minder suiker',
      SwapGoal.meerEiwit => 'Past beter bij meer eiwit',
      SwapGoal.besteOverall => 'Heeft de beste balans voor deze swap',
    };
    return '$base en blijft vergelijkbaar genoeg met het originele product.';
  }

  static double _limitContextScore({
    required double? used,
    required double? goal,
    required double? candidateValue,
    required bool lowerIsBetterAtLimit,
    required double typicalHigh,
  }) {
    if (used == null || goal == null || goal <= 0 || candidateValue == null) {
      return 50;
    }
    final pressure = _clamp(used / goal, 0, 1);
    final valueScore =
        lowerIsBetterAtLimit ? 100 - _scale(candidateValue, typicalHigh) : 50;
    return 50 * (1 - pressure) + valueScore * pressure;
  }

  static double _targetContextScore({
    required double? used,
    required double? goal,
    required double? candidateValue,
    required double typicalHigh,
  }) {
    if (used == null || goal == null || goal <= 0 || candidateValue == null) {
      return 50;
    }
    final need = _clamp(1 - used / goal, 0, 1);
    final valueScore = _scale(candidateValue, typicalHigh);
    return 50 * (1 - need) + valueScore * need;
  }

  static int? _ingredientCount(SwapCandidate c) =>
      c.features.ingredientCount ??
      (c.ingredientsTags.isNotEmpty ? c.ingredientsTags.length : null) ??
      _ingredientCountFromText(c.ingredientsText);

  static int? _ingredientCountFromText(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    return text.split(',').where((part) => part.trim().isNotEmpty).length;
  }

  static double _gain(double? source, double? candidate) => source == null ||
          candidate == null
      ? 50
      : _clamp((candidate - source) / math.max(source.abs(), 1) * 100, 0, 100);

  static double _reduction(double? source, double? candidate) =>
      source == null || candidate == null
          ? 50
          : _clamp(
              (source - candidate) / math.max(source.abs(), 1) * 100, 0, 100);

  static double _reductionInt(int? source, int? candidate) => source == null ||
          candidate == null
      ? 50
      : _clamp((source - candidate) / math.max(source.abs(), 1) * 100, 0, 100);

  static double _notHigher(double? source, double? candidate) =>
      source == null || candidate == null
          ? 50
          : _clamp(
              100 -
                  math.max(0, candidate - source) /
                      math.max(source.abs(), 1) *
                      100,
              0,
              100,
            );

  static double _kcalAcceptance(double? source, double? candidate) {
    if (source == null || candidate == null) return 50;
    if (candidate <= source) return 100;
    return _clamp(
      100 - ((candidate - source) / math.max(source.abs(), 1) * 70),
      0,
      100,
    );
  }

  static double _carbBalance(double? source, double? candidate) =>
      source == null || candidate == null
          ? 50
          : _clamp(
              100 -
                  ((candidate - source).abs() /
                      math.max(source.abs(), 1) *
                      100),
              0,
              100,
            );

  static double _novaImprovement(
    SwapCandidate source,
    SwapCandidate candidate,
  ) =>
      _reductionInt(source.novaGroup, candidate.novaGroup);

  static double _nutriscoreImprovement(
    SwapCandidate source,
    SwapCandidate candidate,
  ) {
    final sourceScore =
        source.nutriscoreScore ?? _nutriscoreGradeValue(source.nutriscoreGrade);
    final candidateScore = candidate.nutriscoreScore ??
        _nutriscoreGradeValue(candidate.nutriscoreGrade);
    return _reduction(sourceScore, candidateScore);
  }

  static double? _nutriscoreGradeValue(String? grade) =>
      switch (grade?.toLowerCase()) {
        'a' => 1,
        'b' => 2,
        'c' => 3,
        'd' => 4,
        'e' => 5,
        _ => null,
      };

  static double _stringMatch(String? a, String? b) =>
      a == null || b == null ? 50 : (a == b ? 100 : 0);

  static double _listOverlap(List<String> a, List<String> b) {
    if (a.isEmpty || b.isEmpty) return 50;
    final left = a.map((e) => e.toLowerCase()).toSet();
    final right = b.map((e) => e.toLowerCase()).toSet();
    return left.intersection(right).isEmpty ? 0 : 100;
  }

  static double _boolMatch(bool? a, bool? b) =>
      a == null || b == null ? 50 : (a == b ? 100 : 0);

  static double _boolPositive(bool? value) =>
      value == null ? 50 : (value ? 100 : 0);

  static double _boolPenalty(bool? value) =>
      value == null ? 50 : (value ? 0 : 100);

  static double _scoreField(double? value) {
    if (value == null) return 50;
    return _clamp(value <= 1 ? value * 100 : value, 0, 100);
  }

  static double _confidenceField(double? value) => _scoreField(value);

  static double _statesTagsScore(List<String> tags) => tags.isEmpty ? 50 : 100;

  static double _scale(double value, double high) =>
      _clamp(value / high * 100, 0, 100);

  static double _average(List<double> values) =>
      values.reduce((a, b) => a + b) / values.length;

  static double _weighted(List<(double score, double weight)> items) {
    final total = items.fold<double>(0, (sum, item) => sum + item.$2);
    if (total <= 0) return 50;
    return _clamp(
      items.fold<double>(0, (sum, item) => sum + item.$1 * item.$2) / total,
      0,
      100,
    );
  }

  static SwapScoreResult _excluded(SwapCandidate c, String reason) =>
      SwapScoreResult(
        candidate: c,
        score: 0,
        goalMatch: 0,
        nutritionImprovement: 0,
        dayContext: 0,
        similarity: 0,
        processingQuality: 0,
        dataQuality: 0,
        excludedReason: reason,
      );

  static double _clamp(double v, double min, double max) =>
      v < min ? min : (v > max ? max : v);
}
