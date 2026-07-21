import 'dart:io';

import 'package:bitewise/features/snackswap/application/swap_score_calculator.dart';
import 'package:bitewise/features/snackswap/domain/product_features.dart';
import 'package:bitewise/features/snackswap/domain/swap_score_result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _url = 'https://ulgfgawoulkyumfzqgrc.supabase.co';

void main() {
  final key = Platform.environment['LIVE_SUPABASE_ANON_KEY'] ?? '';

  test(
    'ieder relevant catalogusproduct houdt de vier doelvangrails',
    () async {
      final client = SupabaseClient(_url, key);
      const calculator = SwapScoreCalculator();
      final all = <SwapCandidate>[];

      for (var from = 0;; from += 1000) {
        final rows = await client
            .from('product_features_resolved')
            .select()
            .order('barcode')
            .range(from, from + 999) as List;
        all.addAll(rows.map((row) => SwapCandidate.fromJoinedJson(
            (row as Map).cast<String, dynamic>())));
        if (rows.length < 1000) break;
      }

      expect(all.length, 15130);
      expect(all.map((p) => p.barcode).toSet().length, all.length);

      final relevant = all
          .where((p) =>
              p.features.classificationStatus == 'classified' &&
              p.features.isSwapRelevant &&
              (p.features.swapFamily?.isNotEmpty ?? false))
          .toList();
      final byFamily = <String, List<SwapCandidate>>{};
      for (final product in relevant) {
        byFamily
            .putIfAbsent(product.features.swapFamily!, () => [])
            .add(product);
      }
      for (final family in byFamily.values) {
        family.sort(_qualityThenBarcode);
      }

      final violations = <String>[];
      final emptyReasons = <String, int>{};
      var runs = 0;
      var nonEmptyRuns = 0;
      var pairs = 0;
      var servingPairs = 0;

      for (final source in relevant) {
        final family = byFamily[source.features.swapFamily!]!;
        for (final goal in SwapGoal.values) {
          runs++;
          final candidates = _appPool(source, family, goal);
          final ranked = calculator.rankCandidates(
            source: source,
            candidates: candidates,
            goal: goal,
          );

          if (ranked.isEmpty) {
            final reason = _emptyReason(source, family, candidates, goal);
            emptyReasons.update(reason, (n) => n + 1, ifAbsent: () => 1);
            if (reason == 'unexplained') {
              violations.add('${source.barcode} ${source.name}: '
                  '${goal.value} leeg met bruikbare kandidaten');
            }
            continue;
          }
          nonEmptyRuns++;

          for (final result in ranked.take(5)) {
            pairs++;
            if (result.usesServingData) servingPairs++;
            final candidate = result.candidate;
            if (candidate.features.swapFamily != source.features.swapFamily) {
              violations.add('${source.barcode}: family mismatch naar '
                  '${candidate.barcode}');
            }
            if (candidate.features.classificationStatus != 'classified' ||
                !candidate.features.isSwapRelevant) {
              violations.add('${source.barcode}: ongeldige kandidaat '
                  '${candidate.barcode}');
            }

            final (from, to, lower) = _axis(source, candidate, goal, false);
            if (from != null && to != null) {
              final wrong = lower ? to > from : to < from;
              if (wrong) {
                violations.add('${source.barcode}: ${goal.value} 100g '
                    '$from -> $to (${candidate.barcode})');
              }
            }
            if (result.usesServingData) {
              final (fromServing, toServing, lowerServing) =
                  _axis(source, candidate, goal, true);
              if (fromServing != null && toServing != null) {
                final wrong = lowerServing
                    ? toServing > fromServing
                    : toServing < fromServing;
                if (wrong) {
                  violations.add('${source.barcode}: ${goal.value} portie '
                      '$fromServing -> $toServing (${candidate.barcode})');
                }
              }
            }

            final promises =
                result.userReason?.startsWith('Past beter') == true;
            final (promiseFrom, promiseTo, promiseLower) = _axis(
              source,
              candidate,
              goal,
              result.usesServingData,
            );
            if (promises && promiseFrom != null && promiseTo != null) {
              final improves = promiseLower
                  ? promiseTo < promiseFrom
                  : promiseTo > promiseFrom;
              if (!improves) {
                violations.add('${source.barcode}: onterechte doelbelofte '
                    '${goal.value} naar ${candidate.barcode}');
              }
            }
          }
        }
      }

      // ignore: avoid_print
      print('volledige matrix: ${relevant.length} bronnen, $runs runs, '
          '$nonEmptyRuns niet-leeg, $pairs paren, $servingPairs portieparen, '
          'lege redenen=$emptyReasons');
      expect(violations, isEmpty,
          reason:
              'catalogusbrede swapfouten:\n${violations.take(100).join('\n')}');
    },
    skip: key.isEmpty
        ? 'LIVE_SUPABASE_ANON_KEY ontbreekt; volledige matrix overgeslagen.'
        : false,
    timeout: const Timeout(Duration(minutes: 15)),
  );

  test(
    'andere opties houdt cross-family vangrails voor iedere bron en doel',
    () async {
      final client = SupabaseClient(_url, key);
      const calculator = SwapScoreCalculator();
      final all = <SwapCandidate>[];
      for (var from = 0;; from += 1000) {
        final rows = await client
            .from('product_features_resolved')
            .select()
            .order('barcode')
            .range(from, from + 999) as List;
        all.addAll(rows.map((row) => SwapCandidate.fromJoinedJson(
            (row as Map).cast<String, dynamic>())));
        if (rows.length < 1000) break;
      }
      final mappingRows = await client
          .from('swap_family_mapping')
          .select('swap_family,related_families') as List;
      final related = <String, List<String>>{
        for (final row in mappingRows)
          (row as Map)['swap_family'].toString():
              ((row['related_families'] as List?) ?? const [])
                  .map((value) => value.toString())
                  .toList(),
      };
      final relevant = all
          .where((p) =>
              p.features.classificationStatus == 'classified' &&
              p.features.isSwapRelevant &&
              (p.features.swapFamily?.isNotEmpty ?? false))
          .toList()
        ..sort(_qualityThenBarcode);

      final violations = <String>[];
      var runs = 0;
      var nonEmptyRuns = 0;
      var pairs = 0;
      for (final source in relevant) {
        final sourceFamily = source.features.swapFamily!;
        final sourceForm = source.features.productForm;
        if (sourceForm == null || sourceForm.isEmpty) continue;
        final relatedFamilies = related[sourceFamily] ?? const [];
        final pool = relevant
            .where((p) => p.barcode != source.barcode)
            .where((p) => relatedFamilies.isNotEmpty
                ? relatedFamilies.contains(p.features.swapFamily)
                : p.features.productForm == sourceForm &&
                    p.features.swapFamily != sourceFamily)
            .take(40)
            .where((p) =>
                p.features.productForm == null ||
                p.features.productForm == sourceForm)
            .where((p) =>
                p.features.consumptionMode == null ||
                source.features.consumptionMode == null ||
                p.features.consumptionMode == source.features.consumptionMode)
            .where((p) => _hasAnyNutritionImprovement(source, p))
            .toList();

        for (final goal in SwapGoal.values) {
          runs++;
          final ranked = pool
              .map((candidate) => calculator.scoreCrossForm(
                    source: source,
                    candidate: candidate,
                    goal: goal,
                  ))
              .where((result) => !result.isExcluded)
              .toList()
            ..sort((a, b) => b.score.compareTo(a.score));
          if (ranked.isEmpty) continue;
          nonEmptyRuns++;
          for (final result in ranked.take(5)) {
            pairs++;
            final candidate = result.candidate;
            if (candidate.features.swapFamily == sourceFamily) {
              violations
                  .add('${source.barcode}: andere optie bleef in familie');
            }
            final sourceSweet = source.features.isSweet == true;
            final sourceSavory = source.features.isSalty == true &&
                source.features.isSweet != true;
            final candidateSweet = candidate.features.isSweet == true;
            final candidateSavory = candidate.features.isSalty == true &&
                candidate.features.isSweet != true;
            if ((sourceSweet && candidateSavory) ||
                (sourceSavory && candidateSweet)) {
              violations.add('${source.barcode}: zoet/hartigconflict naar '
                  '${candidate.barcode}');
            }
            final (from, to, lower) =
                _axis(source, candidate, goal, result.usesServingData);
            if (from != null && to != null) {
              final wrong = lower ? to > from : to < from;
              if (wrong) {
                violations.add('${source.barcode}: cross ${goal.value} '
                    '$from -> $to (${candidate.barcode})');
              }
              final promises =
                  result.userReason?.startsWith('Past beter') == true;
              final improves = lower ? to < from : to > from;
              if (promises && !improves) {
                violations.add('${source.barcode}: cross onterechte belofte '
                    'naar ${candidate.barcode}');
              }
            }
          }
        }
      }

      // ignore: avoid_print
      print('cross-family matrix: $runs runs, $nonEmptyRuns niet-leeg, '
          '$pairs paren');
      expect(violations, isEmpty,
          reason: 'catalogusbrede cross-family fouten:\n'
              '${violations.take(100).join('\n')}');
    },
    skip: key.isEmpty
        ? 'LIVE_SUPABASE_ANON_KEY ontbreekt; cross-matrix overgeslagen.'
        : false,
    timeout: const Timeout(Duration(minutes: 15)),
  );
}

int _qualityThenBarcode(SwapCandidate a, SwapCandidate b) {
  final quality = (b.features.dataQualityScore ?? -1)
      .compareTo(a.features.dataQualityScore ?? -1);
  return quality != 0 ? quality : a.barcode.compareTo(b.barcode);
}

List<SwapCandidate> _appPool(
  SwapCandidate source,
  List<SwapCandidate> family,
  SwapGoal goal,
) {
  final result =
      family.where((p) => p.barcode != source.barcode).take(40).toList();
  final sourceAxis = _axisValue(source, goal);
  if (goal == SwapGoal.besteOverall || sourceAxis == null) return result;

  final directed = family.where((p) => p.barcode != source.barcode).where((p) {
    final value = _axisValue(p, goal);
    if (value == null) return false;
    return goal == SwapGoal.meerEiwit ? value > sourceAxis : value < sourceAxis;
  }).toList()
    ..sort((a, b) {
      final av = _axisValue(a, goal)!;
      final bv = _axisValue(b, goal)!;
      final axis =
          goal == SwapGoal.meerEiwit ? bv.compareTo(av) : av.compareTo(bv);
      return axis != 0 ? axis : a.barcode.compareTo(b.barcode);
    });
  final seen = result.map((p) => p.barcode).toSet();
  for (final candidate in directed.take(20)) {
    if (seen.add(candidate.barcode)) result.add(candidate);
  }
  return result;
}

String _emptyReason(
  SwapCandidate source,
  List<SwapCandidate> family,
  List<SwapCandidate> pool,
  SwapGoal goal,
) {
  if (family.length < 2) return 'singleton_family';
  if (pool.isEmpty) return 'no_candidate_pool';
  if (goal == SwapGoal.besteOverall) {
    return 'all_candidates_excluded_by_score_gate';
  }
  final sourceAxis = _axisValue(source, goal);
  if (sourceAxis == null) return 'source_axis_missing';
  final hasNonWorse = family.where((p) => p.barcode != source.barcode).any((p) {
    final value = _axisValue(p, goal);
    if (value == null) return true;
    return goal == SwapGoal.meerEiwit
        ? value >= sourceAxis
        : value <= sourceAxis;
  });
  return hasNonWorse
      ? 'all_candidates_excluded_by_score_gate'
      : 'no_nonworse_axis_candidate';
}

double? _axisValue(SwapCandidate product, SwapGoal goal) => switch (goal) {
      SwapGoal.minderKcal => product.kcal100,
      SwapGoal.minderSuiker => product.sugar100,
      SwapGoal.meerEiwit => product.protein100,
      SwapGoal.besteOverall => null,
    };

bool _hasAnyNutritionImprovement(
  SwapCandidate source,
  SwapCandidate candidate,
) {
  if (source.sugar100 != null &&
      candidate.sugar100 != null &&
      candidate.sugar100! < source.sugar100!) {
    return true;
  }
  if (source.kcal100 != null &&
      candidate.kcal100 != null &&
      candidate.kcal100! < source.kcal100!) {
    return true;
  }
  if (source.protein100 != null &&
      candidate.protein100 != null &&
      candidate.protein100! > source.protein100!) {
    return true;
  }
  return false;
}

(double?, double?, bool) _axis(
  SwapCandidate source,
  SwapCandidate candidate,
  SwapGoal goal,
  bool serving,
) =>
    switch (goal) {
      SwapGoal.minderKcal => (
          serving ? source.kcalServing : source.kcal100,
          serving ? candidate.kcalServing : candidate.kcal100,
          true,
        ),
      SwapGoal.minderSuiker => (
          serving ? source.sugarServing : source.sugar100,
          serving ? candidate.sugarServing : candidate.sugar100,
          true,
        ),
      SwapGoal.meerEiwit => (
          serving ? source.proteinServing : source.protein100,
          serving ? candidate.proteinServing : candidate.protein100,
          false,
        ),
      SwapGoal.besteOverall => (null, null, true),
    };
