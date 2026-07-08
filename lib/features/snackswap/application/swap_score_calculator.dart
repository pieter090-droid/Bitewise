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
    return _calculate(source, candidate, goal, dayContext);
  }

  SwapScoreResult scoreCrossForm({
    required SwapCandidate source,
    required SwapCandidate candidate,
    required SwapGoal goal,
    SwapDayContext dayContext = const SwapDayContext(),
  }) =>
      score(
        source: source,
        candidate: candidate,
        goal: goal,
        dayContext: dayContext,
      );

  List<SwapScoreResult> rankCandidates({
    required SwapCandidate source,
    required List<SwapCandidate> candidates,
    required SwapGoal goal,
    SwapDayContext dayContext = const SwapDayContext(),
  }) =>
      (candidates
          .map((c) => score(
                source: source,
                candidate: c,
                goal: goal,
                dayContext: dayContext,
              ))
          .where((r) => !r.isExcluded)
          .toList()
        ..sort((a, b) => b.score.compareTo(a.score)));

  SwapScoreResult _calculate(
    SwapCandidate source,
    SwapCandidate candidate,
    SwapGoal goal,
    SwapDayContext dayContext,
  ) {
    final goalMatch = _goalMatchScore(source, candidate, goal);
    final nutrition = _nutritionImprovementScore(source, candidate);
    final day = _dayContextScore(candidate, dayContext);
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

    final reasons = _reasonCodes(source, candidate, goal);
    final reason = _userReason(goal, reasons);
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
      usesServingData: false,
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

  static double _goalMatchScore(
    SwapCandidate source,
    SwapCandidate candidate,
    SwapGoal goal,
  ) {
    return switch (goal) {
      SwapGoal.minderKcal => _weighted([
          (_reduction(source.kcal100, candidate.kcal100), 70),
          (
            _average([
              _gain(source.protein100, candidate.protein100),
              _gain(source.fiber100, candidate.fiber100),
            ]),
            20
          ),
          (
            _average([
              _reduction(source.sugar100, candidate.sugar100),
              _reduction(source.fat100, candidate.fat100),
            ]),
            10
          ),
        ]),
      SwapGoal.minderSuiker => _weighted([
          (_reduction(source.sugar100, candidate.sugar100), 75),
          (_reduction(source.kcal100, candidate.kcal100), 15),
          (
            _average([
              _gain(source.protein100, candidate.protein100),
              _gain(source.fiber100, candidate.fiber100),
            ]),
            10
          ),
        ]),
      SwapGoal.meerEiwit => _weighted([
          (_gain(source.protein100, candidate.protein100), 75),
          (
            _average([
              _notHigher(source.sugar100, candidate.sugar100),
              _notHigher(source.saturatedFat100, candidate.saturatedFat100),
              _notHigher(source.salt100, candidate.salt100),
            ]),
            15
          ),
          (_kcalAcceptance(source.kcal100, candidate.kcal100), 10),
        ]),
      SwapGoal.besteOverall => _weighted([
          (_reduction(source.kcal100, candidate.kcal100), 20),
          (_reduction(source.sugar100, candidate.sugar100), 20),
          (_gain(source.protein100, candidate.protein100), 15),
          (_gain(source.fiber100, candidate.fiber100), 15),
          (
            _average([
              _reduction(source.salt100, candidate.salt100),
              _reduction(source.saturatedFat100, candidate.saturatedFat100),
            ]),
            15
          ),
          (
            _average([
              _nutriscoreImprovement(source, candidate),
              _novaImprovement(source, candidate),
            ]),
            15
          ),
        ]),
    };
  }

  static double _nutritionImprovementScore(
    SwapCandidate source,
    SwapCandidate candidate,
  ) =>
      _weighted([
        (_reduction(source.kcal100, candidate.kcal100), 20),
        (_reduction(source.sugar100, candidate.sugar100), 20),
        (_gain(source.protein100, candidate.protein100), 15),
        (_gain(source.fiber100, candidate.fiber100), 15),
        (_reduction(source.salt100, candidate.salt100), 10),
        (_reduction(source.saturatedFat100, candidate.saturatedFat100), 10),
        (
          _average([
            _reduction(source.fat100, candidate.fat100),
            _carbBalance(source.carbs100, candidate.carbs100),
          ]),
          10
        ),
      ]);

  static double _dayContextScore(
    SwapCandidate candidate,
    SwapDayContext context,
  ) {
    if (context.isEmpty) return 50;
    return _weighted([
      (
        _limitContextScore(
          used: context.dailyKcalUsed,
          goal: context.dailyKcalGoal,
          candidateValue: candidate.kcal100,
          lowerIsBetterAtLimit: true,
          typicalHigh: 600,
        ),
        25
      ),
      (
        _limitContextScore(
          used: context.dailySugarUsed,
          goal: context.dailySugarGoal,
          candidateValue: candidate.sugar100,
          lowerIsBetterAtLimit: true,
          typicalHigh: 60,
        ),
        25
      ),
      (
        _targetContextScore(
          used: context.dailyProteinUsed,
          goal: context.dailyProteinGoal,
          candidateValue: candidate.protein100,
          typicalHigh: 30,
        ),
        25
      ),
      (
        _targetContextScore(
          used: context.dailyFiberUsed,
          goal: context.dailyFiberGoal,
          candidateValue: candidate.fiber100,
          typicalHigh: 15,
        ),
        25
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
                a.secondaryConsumptionModes, b.secondaryConsumptionModes),
          ]),
          15
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
          15
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
              _ingredientCount(source),
              _ingredientCount(candidate),
            ),
          ]),
          20
        ),
        (_boolPositive(candidate.features.isLessProcessed), 15),
        (
          _average([
            _boolPenalty(candidate.features.hasSweeteners),
            _boolPenalty(candidate.features.hasPalmOil),
          ]),
          10
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
  ) {
    final codes = <String>[];
    if (_reduction(source.kcal100, candidate.kcal100) > 60) {
      codes.add('fewer_kcal');
    }
    if (_reduction(source.sugar100, candidate.sugar100) > 60) {
      codes.add('less_sugar');
    }
    if (_gain(source.protein100, candidate.protein100) > 60) {
      codes.add('more_protein');
    }
    if (_gain(source.fiber100, candidate.fiber100) > 60) {
      codes.add('more_fiber');
    }
    if (_novaImprovement(source, candidate) > 60) {
      codes.add('less_processed');
    }
    if (codes.isEmpty) codes.add(goal.value);
    return codes;
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
              100);

  static double _kcalAcceptance(double? source, double? candidate) {
    if (source == null || candidate == null) return 50;
    if (candidate <= source) return 100;
    return _clamp(
        100 - ((candidate - source) / math.max(source.abs(), 1) * 70), 0, 100);
  }

  static double _carbBalance(double? source, double? candidate) => source ==
              null ||
          candidate == null
      ? 50
      : _clamp(
          100 - ((candidate - source).abs() / math.max(source.abs(), 1) * 100),
          0,
          100);

  static double _novaImprovement(
          SwapCandidate source, SwapCandidate candidate) =>
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
