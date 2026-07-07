import 'dart:math' as math;

import 'package:bitewise/features/snackswap/domain/product_features.dart';
import 'package:bitewise/features/snackswap/domain/swap_score_result.dart';

/// Rule-based SwapScore-berekening — client-side Dart-implementatie van de
/// SQL-referentiefunctie `calculate_swap_score`/`calculate_similarity_score`
/// (zie `supabase/migrations/0009_swapscore_model.sql`).
///
/// Draait volledig lokaal op al opgehaalde Supabase-data: geen netwerk- of
/// AI-aanroep in dit pad. Belangrijkste regels (bewust zo, niet wijzigen
/// zonder de SQL-referentie ook aan te passen):
///  - Ontbrekende brondata wordt NOOIT als 0/false behandeld — dat onderdeel
///    telt dan neutraal mee (of wordt overgeslagen), nooit als "slecht".
///  - Harde poort: een kandidaat buiten hetzelfde `category_cluster` krijgt
///    score 0 en hoort NIET in de ranking te verschijnen.
///  - Allergeen-onvolledigheid is altijd een waarschuwing, nooit een
///    veiligheidsgarantie.
class SwapScoreCalculator {
  const SwapScoreCalculator(this.weights);

  final SwapScoreWeights weights;

  /// Berekent de score voor één kandidaat t.o.v. het bronproduct.
  SwapScoreResult score({
    required SwapCandidate source,
    required SwapCandidate candidate,
    required SwapGoal goal,
    SwapDayContext dayContext = const SwapDayContext(),
  }) {
    // Harde poort, drie lagen (fijn -> grof): swap_family leidend zodra
    // beide bekend zijn, anders snack_type, anders category_cluster als
    // laatste vangnet. Gebleken (via "Nutella vs. Merci-praline"): gelijk
    // snack_type/smaak/textuur maakt nog geen goede swap als de vorm
    // (smeersel vs. los stuk) verschilt -- swap_family vangt dat op.
    final sourceFamily = source.features.swapFamily;
    final candidateFamily = candidate.features.swapFamily;
    final sourceType = source.features.snackType;
    final candidateType = candidate.features.snackType;
    final gatePasses = sourceFamily != null && candidateFamily != null
        ? sourceFamily == candidateFamily
        : sourceType != null && candidateType != null
            ? sourceType == candidateType
            : source.features.categoryCluster != null &&
                source.features.categoryCluster == candidate.features.categoryCluster;

    if (!gatePasses) {
      return SwapScoreResult(
        candidate: candidate,
        score: 0,
        goalMatch: 0,
        nutritionImprovement: 0,
        dayContext: 0,
        similarity: 0,
        processingQuality: 0,
        dataQuality: 0,
        excludedReason: 'category_cluster_mismatch',
        warnings: const ['dit product is niet vergelijkbaar genoeg om als swap te tonen'],
      );
    }

    return _scoreWithoutGate(source: source, candidate: candidate, goal: goal, dayContext: dayContext);
  }

  /// Voor de "Andere opties"-groep: dezelfde berekening als [score], maar
  /// bewust ZONDER de swap_family/snack_type/category_cluster-poort. Alleen
  /// gebruiken voor kandidaten die de aanroeper al zelf heeft gefilterd op
  /// gelijke `product_form` (zelfde vorm, bv. smeerbaar) en een aantoonbare
  /// voedingsverbetering -- dus bewust cross-familie (bv. chocopasta ->
  /// smeerkaas), niet zomaar alles.
  SwapScoreResult scoreCrossForm({
    required SwapCandidate source,
    required SwapCandidate candidate,
    required SwapGoal goal,
    SwapDayContext dayContext = const SwapDayContext(),
  }) =>
      _scoreWithoutGate(source: source, candidate: candidate, goal: goal, dayContext: dayContext);

  SwapScoreResult _scoreWithoutGate({
    required SwapCandidate source,
    required SwapCandidate candidate,
    required SwapGoal goal,
    required SwapDayContext dayContext,
  }) {
    final nutrition = _nutritionImprovement(source, candidate);
    final goalMatch = _goalMatch(goal, source, candidate);
    final day = _dayContext(dayContext, source, candidate);
    final similarity = similarityScore(source.features, candidate.features);
    final processing = candidate.features.processingQualityScore ?? 50;
    final dataQuality = (candidate.features.dataQualityScore ?? 50) * 0.7 +
        (candidate.features.aiConfidence ?? 0.5) * 100 * 0.3;

    final totalWeight = weights.goalMatch +
        weights.nutritionImprovement +
        weights.dayContext +
        weights.similarity +
        weights.processingQuality +
        weights.dataQuality;
    final total = totalWeight <= 0
        ? 0.0
        : (goalMatch * weights.goalMatch +
                nutrition * weights.nutritionImprovement +
                day * weights.dayContext +
                similarity * weights.similarity +
                processing * weights.processingQuality +
                dataQuality * weights.dataQuality) /
            totalWeight;

    final reasons = <String>[];
    if (source.kcal100 != null &&
        candidate.kcal100 != null &&
        candidate.kcal100! < source.kcal100! &&
        source.kcal100! > 0) {
      final pct = (1 - candidate.kcal100! / source.kcal100!) * 100;
      reasons.add('${pct.round()}% minder kcal');
    }
    if (source.sugar100 != null &&
        candidate.sugar100 != null &&
        candidate.sugar100! < source.sugar100!) {
      final pct = (1 - candidate.sugar100! / source.sugar100!) * 100;
      reasons.add('${pct.round()}% minder suiker');
    }
    if (source.protein100 != null &&
        candidate.protein100 != null &&
        candidate.protein100! > source.protein100!) {
      reasons.add('${(candidate.protein100! - source.protein100!).round()}g meer eiwit');
    }

    final warnings = <String>[];
    final sourceAllergens = source.allergens;
    final candidateAllergens = candidate.allergens;
    if (sourceAllergens == null ||
        candidateAllergens == null ||
        candidateAllergens.trim().isEmpty) {
      warnings.add('allergeneninformatie is onvolledig -- controleer het etiket');
    } else if (candidateAllergens != sourceAllergens) {
      warnings.add('allergenen kunnen verschillen van het origineel -- controleer het etiket');
    }

    return SwapScoreResult(
      candidate: candidate,
      score: _clamp(total, 0, 100),
      goalMatch: goalMatch,
      nutritionImprovement: nutrition,
      dayContext: day,
      similarity: similarity,
      processingQuality: processing,
      dataQuality: dataQuality,
      reasons: reasons,
      warnings: warnings,
    );
  }

  /// Rangschikt en filtert kandidaten (sluit uitgesloten paren stilzwijgend uit).
  List<SwapScoreResult> rankCandidates({
    required SwapCandidate source,
    required List<SwapCandidate> candidates,
    required SwapGoal goal,
    SwapDayContext dayContext = const SwapDayContext(),
  }) {
    final results = candidates
        .where((c) => c.barcode != source.barcode)
        .map((c) => score(
              source: source,
              candidate: c,
              goal: goal,
              dayContext: dayContext,
            ))
        .where((r) => !r.isExcluded)
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    return results;
  }

  double _nutritionImprovement(SwapCandidate source, SwapCandidate candidate) {
    var delta = 0.0;
    final sSugar = source.sugar100, cSugar = candidate.sugar100;
    if (sSugar != null && cSugar != null && sSugar > 0) {
      delta += _clamp((sSugar - cSugar) / sSugar, -1, 1) * 40;
    }
    final sKcal = source.kcal100, cKcal = candidate.kcal100;
    if (sKcal != null && cKcal != null && sKcal > 0) {
      delta += _clamp((sKcal - cKcal) / sKcal, -1, 1) * 30;
    }
    final sProtein = source.protein100, cProtein = candidate.protein100;
    if (sProtein != null && cProtein != null) {
      delta += _clamp((cProtein - sProtein) / math.max(sProtein, 5), -1, 1) * 20;
    }
    final sFiber = source.fiber100, cFiber = candidate.fiber100;
    if (sFiber != null && cFiber != null) {
      delta += _clamp((cFiber - sFiber) / math.max(sFiber, 3), -1, 1) * 10;
    }
    return _clamp(50 + delta, 0, 100);
  }

  double _goalMatch(SwapGoal goal, SwapCandidate source, SwapCandidate candidate) {
    switch (goal) {
      case SwapGoal.minderSuiker:
        final cSugar = candidate.sugar100;
        final sSugar = source.sugar100;
        if (cSugar == null) return 50;
        if (sSugar == null || sSugar == 0) return 50;
        return _clamp(50 + (1 - cSugar / math.max(sSugar, 0.1)) * 50, 0, 100);
      case SwapGoal.afvallen:
        final cKcal = candidate.kcal100;
        final sKcal = source.kcal100;
        if (cKcal == null) return 50;
        if (sKcal == null || sKcal == 0) return 50;
        return _clamp(50 + (1 - cKcal / math.max(sKcal, 1)) * 50, 0, 100);
      case SwapGoal.spieropbouw:
        final cProtein = candidate.protein100;
        if (cProtein == null) return 50;
        return _clamp(50 + (cProtein - (source.protein100 ?? 0)) * 3, 0, 100);
      case SwapGoal.gezonderEten:
        return candidate.features.processingQualityScore ?? 50;
      case SwapGoal.gewichtBehouden:
        final sKcal = source.kcal100;
        final cKcal = candidate.kcal100;
        if (sKcal == null || cKcal == null) return 50;
        return 100 - math.min(100, (sKcal - cKcal).abs());
    }
  }

  double _dayContext(SwapDayContext ctx, SwapCandidate source, SwapCandidate candidate) {
    var value = 50.0;
    final kcalRemaining = ctx.kcalRemaining;
    final cKcal = candidate.kcal100;
    if (kcalRemaining != null && cKcal != null) {
      final sourceKcal = source.kcal100 ?? (cKcal + 1);
      value = (kcalRemaining < 300 && cKcal < sourceKcal) ? 90 : 50;
    }
    final sugarRemaining = ctx.sugarRemainingG;
    final cSugar = candidate.sugar100;
    final sSugar = source.sugar100;
    if (sugarRemaining != null &&
        cSugar != null &&
        sugarRemaining < 10 &&
        sSugar != null &&
        cSugar < sSugar) {
      value = math.min(100, value + 20);
    }
    return value;
  }

  /// Vergelijkbaarheid (0-100): eigen, herbruikbare functie -- ook nodig voor
  /// de UX-groep "Zelfde smaak, kleinere portie".
  ///
  /// swap_family/product_form/consumption_mode (20/15/10%) wegen zwaarder
  /// dan smaak/textuur/moment (30/15/10%) omdat ze het daadwerkelijke
  /// gebruik onderscheiden (bv. smeersel vs. los stuk) -- textuur alleen
  /// kan overlappen zonder een goede swap te zijn (Nutella/bonbon: allebei
  /// "romig/plakkerig"). Onbekend (`null` op een van beide) telt neutraal
  /// (0.5) mee, nooit als mismatch.
  static double similarityScore(ProductFeatures a, ProductFeatures b) {
    final familyMatch = _matchOrNull(a.swapFamily, b.swapFamily);
    final formMatch = _matchOrNull(a.productForm, b.productForm);
    final modeMatch = _matchOrNull(a.consumptionMode, b.consumptionMode);
    final taste = _overlapRatio(a.tasteProfile, b.tasteProfile);
    final texture = _overlapRatio(a.textureProfile, b.textureProfile);
    final moment = _overlapRatio(a.useMoment, b.useMoment);

    final value = (familyMatch == true ? 1 : (familyMatch == null ? 0.5 : 0)) * 20 +
        (formMatch == true ? 1 : (formMatch == null ? 0.5 : 0)) * 15 +
        (modeMatch == true ? 1 : (modeMatch == null ? 0.5 : 0)) * 10 +
        (taste ?? 0.5) * 30 +
        (texture ?? 0.5) * 15 +
        (moment ?? 0.5) * 10;
    return _clamp(value, 0, 100);
  }

  /// `true`/`false` als beide bekend zijn, anders `null` (onbekend, telt
  /// neutraal mee -- nooit als mismatch bestraft).
  static bool? _matchOrNull(String? a, String? b) =>
      a != null && b != null ? a == b : null;

  /// Jaccard-achtige overlap; `null` als een van beide leeg/onbekend is
  /// (neutraal meewegen i.p.v. als 0 straffen).
  static double? _overlapRatio(List<String> a, List<String> b) {
    if (a.isEmpty || b.isEmpty) return null;
    final bSet = b.toSet();
    final overlap = a.where(bSet.contains).length;
    return overlap / math.max(a.length, b.length);
  }

  static double _clamp(double v, double min, double max) =>
      v < min ? min : (v > max ? max : v);
}
