import 'dart:math' as math;

import 'package:bitewise/features/snackswap/domain/product_features.dart';
import 'package:bitewise/features/snackswap/domain/swap_score_result.dart';

class SwapScoreCalculator {
  const SwapScoreCalculator([this.weights = SwapScoreWeights.fallback]);

  // Behouden voor compatibiliteit met de bestaande configuratie. De vier
  // doel-formules hieronder hebben bewust hun eigen vaste gewichten.
  final SwapScoreWeights weights;

  SwapScoreResult score({
    required SwapCandidate source,
    required SwapCandidate candidate,
    required SwapGoal goal,
    SwapDayContext dayContext = const SwapDayContext(),
  }) {
    final sameFamily = source.features.swapFamily != null &&
            candidate.features.swapFamily != null
        ? source.features.swapFamily == candidate.features.swapFamily
        : source.features.snackType != null &&
                candidate.features.snackType != null
            ? source.features.snackType == candidate.features.snackType
            : source.features.categoryCluster != null &&
                source.features.categoryCluster ==
                    candidate.features.categoryCluster;
    if (!sameFamily) return _excluded(candidate, 'product_family_mismatch');
    return _calculate(source, candidate, goal);
  }

  SwapScoreResult scoreCrossForm({
    required SwapCandidate source,
    required SwapCandidate candidate,
    required SwapGoal goal,
    SwapDayContext dayContext = const SwapDayContext(),
  }) =>
      _calculate(source, candidate, goal);

  List<SwapScoreResult> rankCandidates({
    required SwapCandidate source,
    required List<SwapCandidate> candidates,
    required SwapGoal goal,
    SwapDayContext dayContext = const SwapDayContext(),
  }) =>
      (candidates
          .where((c) => c.barcode != source.barcode)
          .map((c) => score(source: source, candidate: c, goal: goal))
          .where((r) => !r.isExcluded)
          .toList()
        ..sort((a, b) => b.score.compareTo(a.score)));

  SwapScoreResult _calculate(
      SwapCandidate source, SwapCandidate candidate, SwapGoal goal) {
    final pair = _NutritionPair.of(source, candidate);
    final codes = <String>[];
    final warnings = <String>[];
    if (!pair.usesServing) {
      warnings
          .add('Vergeleken per 100g omdat betrouwbare portiedata ontbreekt');
    }

    final proteinGain = _gain(pair.source.protein, pair.candidate.protein);
    final kcalReduction = _reduction(pair.source.kcal, pair.candidate.kcal);
    final sugarReduction = _reduction(pair.source.sugar, pair.candidate.sugar);
    final fiberGain = _gain(pair.source.fiber, pair.candidate.fiber);
    final proteinRetention =
        _retention(pair.source.protein, pair.candidate.protein);
    final fiberRetention = _retention(pair.source.fiber, pair.candidate.fiber);
    final kcalRetention = _notHigher(pair.source.kcal, pair.candidate.kcal);
    final sugarRetention = _notHigher(pair.source.sugar, pair.candidate.sugar);
    final saltRetention = _notHigher(pair.source.salt, pair.candidate.salt);
    final satFatRetention =
        _notHigher(pair.source.saturatedFat, pair.candidate.saturatedFat);

    bool threshold = true;
    var hardPenalty = false;
    double score;
    switch (goal) {
      case SwapGoal.meerEiwit:
        threshold =
            _atLeastGain(pair.source.protein, pair.candidate.protein, .20, 2);
        hardPenalty =
            _increasesOver(pair.source.kcal, pair.candidate.kcal, .15) ||
                _increasesOver(pair.source.sugar, pair.candidate.sugar, .20) ||
                _increasesOver(pair.source.salt, pair.candidate.salt, .20);
        final densityGain = _proteinDensityGain(pair);
        score = proteinGain * 45 +
            densityGain * 25 +
            fiberGain * 10 +
            kcalRetention * 10 +
            _average([sugarRetention, saltRetention, satFatRetention]) * 10;
        if (proteinGain > 0) codes.add('more_protein');
      case SwapGoal.minderKcal:
        threshold =
            _atLeastReduction(pair.source.kcal, pair.candidate.kcal, .10, 25);
        hardPenalty =
            _dropsOver(pair.source.protein, pair.candidate.protein, .30) ||
                _dropsOver(pair.source.fiber, pair.candidate.fiber, .30) ||
                _increasesOver(pair.source.sugar, pair.candidate.sugar, .20);
        score = kcalReduction * 60 +
            proteinRetention * 15 +
            fiberRetention * 10 +
            _average([sugarRetention, saltRetention, satFatRetention]) * 15;
        if (kcalReduction > 0) codes.add('fewer_kcal');
      case SwapGoal.minderSuiker:
        threshold =
            _atLeastReduction(pair.source.sugar, pair.candidate.sugar, .20, 2);
        hardPenalty =
            _increasesOver(pair.source.kcal, pair.candidate.kcal, .15) ||
                _increasesOver(
                    pair.source.saturatedFat, pair.candidate.saturatedFat, .20);
        score = sugarReduction * 65 +
            kcalRetention * 15 +
            _average([proteinGain, fiberGain]) * 10 +
            _average([satFatRetention, saltRetention]) * 10;
        if (sugarReduction > 0) codes.add('less_sugar');
      case SwapGoal.besteOverall:
        final overall = _overallScore(source, candidate, pair);
        if (overall == null) {
          return _excluded(candidate, 'unsupported_category_cluster');
        }
        score = overall;
        threshold = score >= 8;
    }

    if (!threshold) {
      return _excluded(candidate, 'minimum_improvement_not_met');
    }
    if (hardPenalty) {
      return _excluded(candidate, 'hard_penalty');
    }
    final finalScore = _clamp(score, 0, 100);

    if (fiberGain > 0) codes.add('more_fiber');
    if (saltRetention > .5) codes.add('salt_preserved');
    final basis = pair.usesServing ? 'per portie' : 'per 100 gram';
    final reason = _userReason(goal, source, pair, basis);
    return SwapScoreResult(
      candidate: candidate,
      score: finalScore,
      goalMatch: finalScore,
      nutritionImprovement: finalScore,
      dayContext: 50,
      similarity: similarityScore(source.features, candidate.features),
      processingQuality: candidate.features.processingQualityScore ?? 50,
      dataQuality: _dataAvailability(pair),
      reasons: [reason],
      reasonCodes: codes,
      userReason: reason,
      usesServingData: pair.usesServing,
      warnings: warnings,
    );
  }

  static double? _overallScore(
      SwapCandidate source, SwapCandidate candidate, _NutritionPair p) {
    final cluster = source.features.categoryCluster;
    final sugar = _reduction(p.source.sugar, p.candidate.sugar);
    final kcal = _reduction(p.source.kcal, p.candidate.kcal);
    final protein = _gain(p.source.protein, p.candidate.protein);
    final fiber = _gain(p.source.fiber, p.candidate.fiber);
    final salt = _reduction(p.source.salt, p.candidate.salt);
    final sat = _reduction(p.source.saturatedFat, p.candidate.saturatedFat);
    final similarity =
        similarityScore(source.features, candidate.features) / 100;
    return switch (cluster) {
      'beverages' =>
        sugar * 45 + kcal * 35 + sat * 5 + salt * 5 + similarity * 10,
      'sweet_snacks' =>
        sugar * 35 + kcal * 25 + sat * 20 + fiber * 10 + protein * 5 + salt * 5,
      'savory_snacks' =>
        kcal * 25 + salt * 30 + sat * 20 + fiber * 15 + protein * 10,
      'dairy' =>
        protein * 25 + sugar * 25 + kcal * 20 + sat * 15 + fiber * 5 + salt * 5,
      'bakery_grains' => fiber * 30 +
          protein * 20 +
          kcal * 15 +
          sugar * 15 +
          salt * 15 +
          sat * 5,
      'spreads_sauces' => kcal * 25 +
          sugar * 25 +
          sat * 20 +
          protein * 10 +
          fiber * 10 +
          salt * 10,
      'meals' => kcal * 25 + protein * 20 + salt * 25 + sat * 15 + fiber * 15,
      _ => null,
    };
  }

  static String _userReason(
      SwapGoal goal, SwapCandidate source, _NutritionPair p, String basis) {
    final family = source.features.swapFamily != null
        ? 'Dit blijft een vergelijkbaar product'
        : 'Dit alternatief';
    return switch (goal) {
      SwapGoal.meerEiwit =>
        '$family, maar bevat meer eiwit $basis zonder onnodige achteruitgang.',
      SwapGoal.minderKcal => '$family en levert minder kcal $basis.',
      SwapGoal.minderSuiker => '$family en bevat minder suiker $basis.',
      SwapGoal.besteOverall => '$family met een betere voedingsbalans $basis.',
    };
  }

  static double _proteinDensityGain(_NutritionPair p) {
    final sk = p.source.kcal, ck = p.candidate.kcal;
    final sp = p.source.protein, cp = p.candidate.protein;
    if (sk == null ||
        ck == null ||
        sp == null ||
        cp == null ||
        sk <= 0 ||
        ck <= 0) {
      return .5;
    }
    return _clamp(
        ((cp / ck * 100) - (sp / sk * 100)) / math.max(sp / sk * 100, 1), 0, 1);
  }

  static double _gain(double? s, double? c) => s == null || c == null
      ? .5
      : _clamp((c - s) / math.max(s.abs(), 1), 0, 1);
  static double _reduction(double? s, double? c) => s == null || c == null
      ? .5
      : _clamp((s - c) / math.max(s.abs(), 1), 0, 1);
  static double _retention(double? s, double? c) =>
      s == null || c == null ? .5 : _clamp(c / math.max(s, .1), 0, 1);
  static double _notHigher(double? s, double? c) => s == null || c == null
      ? .5
      : _clamp(1 - math.max(0, c - s) / math.max(s.abs(), 1), 0, 1);
  static bool _atLeastGain(double? s, double? c, double pct, double absolute) =>
      s != null &&
      c != null &&
      ((s > 0 && c >= s * (1 + pct)) || c - s >= absolute);
  static bool _atLeastReduction(
          double? s, double? c, double pct, double absolute) =>
      s != null &&
      c != null &&
      ((s > 0 && c <= s * (1 - pct)) || s - c >= absolute);
  static bool _increasesOver(double? s, double? c, double limit) =>
      s != null && c != null && s > 0 && c > s * (1 + limit);
  static bool _dropsOver(double? s, double? c, double limit) =>
      s != null && c != null && s > 0 && c < s * (1 - limit);
  static double _average(List<double> values) =>
      values.reduce((a, b) => a + b) / values.length;
  static double _dataAvailability(_NutritionPair p) {
    final values = [
      p.candidate.kcal,
      p.candidate.protein,
      p.candidate.sugar,
      p.candidate.fiber,
      p.candidate.salt,
      p.candidate.saturatedFat
    ];
    return values.where((v) => v != null).length / values.length * 100;
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

  static double similarityScore(ProductFeatures a, ProductFeatures b) {
    double match(String? x, String? y) =>
        x == null || y == null ? .5 : (x == y ? 1 : 0);
    return (match(a.swapFamily, b.swapFamily) * 50 +
        match(a.productForm, b.productForm) * 30 +
        match(a.consumptionMode, b.consumptionMode) * 20);
  }

  static double _clamp(double v, double min, double max) =>
      v < min ? min : (v > max ? max : v);
}

class _NutritionPair {
  const _NutritionPair(this.source, this.candidate, this.usesServing);
  final _Nutrition source;
  final _Nutrition candidate;
  final bool usesServing;

  factory _NutritionPair.of(SwapCandidate s, SwapCandidate c) {
    final useServing = _plausibleServing(s) &&
        _plausibleServing(c) &&
        s.kcalServing != null &&
        c.kcalServing != null;
    return _NutritionPair(
        _Nutrition.of(s, useServing), _Nutrition.of(c, useServing), useServing);
  }

  static bool _plausibleServing(SwapCandidate c) {
    final q = c.servingQuantity;
    if (q == null || q <= 0) {
      return false;
    }
    final max = c.features.swapFamily == 'bread_bakery' ? 150.0 : 500.0;
    return q <= max;
  }
}

class _Nutrition {
  const _Nutrition(this.kcal, this.protein, this.sugar, this.fiber, this.salt,
      this.saturatedFat);
  final double? kcal, protein, sugar, fiber, salt, saturatedFat;
  factory _Nutrition.of(SwapCandidate c, bool serving) => serving
      ? _Nutrition(c.kcalServing, c.proteinServing, c.sugarServing,
          c.fiberServing, c.saltServing, c.saturatedFatServing)
      : _Nutrition(c.kcal100, c.protein100, c.sugar100, c.fiber100, c.salt100,
          c.saturatedFat100);
}
