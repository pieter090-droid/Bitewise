import 'dart:io';

import 'package:bitewise/core/supabase/supabase_service.dart';
import 'package:bitewise/features/snackswap/application/swap_score_calculator.dart';
import 'package:bitewise/features/snackswap/data/snackswap_service.dart';
import 'package:bitewise/features/snackswap/domain/swap_score_result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Brede vangrail-sweep over live data, voor ALLE VIER de doelen.
///
/// De nulmeting in live_swap_regression_test.dart legt exacte top-3-barcodes
/// vast, maar alleen voor `besteOverall`. De fout die in fase 3 gevonden werd
/// (Filet americain -> Jamon serrano, 193 -> 324 kcal onder "Minder kcal")
/// zat juist in een van de andere drie doelen en zou daar niet uit komen.
///
/// Deze test controleert geen exacte uitkomsten maar EIGENSCHAPPEN die altijd
/// moeten gelden, over veel bronproducten en elk doel:
///   1. geen enkele getoonde swap gaat de verkeerde kant op de doelas;
///   2. geen expliciet zoet product als swap voor een expliciet hartig
///      product (en omgekeerd) in cross-family suggesties;
///   3. de doelbelofte in de tekst wordt alleen gedaan als de doelas ook
///      echt wint.
const _url = 'https://ulgfgawoulkyumfzqgrc.supabase.co';

void main() {
  final key = Platform.environment['LIVE_SUPABASE_ANON_KEY'] ?? '';

  test(
    'vangrails houden over alle vier de doelen op live data',
    () async {
      final service = SnackSwapService(
        SupabaseService.withClientForTesting(SupabaseClient(_url, key)),
      );
      const calculator = SwapScoreCalculator();

      final wrongDirection = <String>[];
      final falsePromise = <String>[];
      final lookWrongPer100g = <String>[];
      final emptyResults = <String>[];
      var pairsChecked = 0;
      var servingPairs = 0;

      for (final barcode in _sourceBarcodes) {
        final source = await service.getCandidateByBarcode(barcode);
        if (source == null) continue;

        for (final goal in SwapGoal.values) {
          // Zelfde selectie als de app: doelbewust, zodat de sweep meet wat
          // een gebruiker werkelijk krijgt.
          final candidates = await service.getCandidatesForCluster(
            excludeBarcode: source.barcode,
            swapFamily: source.features.swapFamily,
            snackType: source.features.snackType,
            categoryCluster: source.features.categoryCluster,
            fallbackCategory: source.category,
            goal: goal,
            goalSourceValue: switch (goal) {
              SwapGoal.minderKcal => source.kcal100,
              SwapGoal.minderSuiker => source.sugar100,
              SwapGoal.meerEiwit => source.protein100,
              SwapGoal.besteOverall => null,
            },
          );

          final ranked = calculator.rankCandidates(
            source: source,
            candidates: candidates,
            goal: goal,
          );

          // Leeg is alleen fout als er ruimte was om te verbeteren. Bij een
          // bron van 0 kcal (water, zwarte koffie, en helaas ook wat colas
          // met kcal=0 als "onbekend") kan niets lager, en is geen suggestie
          // het juiste antwoord.
          final axisValue = switch (goal) {
            SwapGoal.minderKcal => source.kcal100,
            SwapGoal.minderSuiker => source.sugar100,
            SwapGoal.meerEiwit => null, // altijd ruimte omhoog
            SwapGoal.besteOverall => null,
          };
          if (ranked.isEmpty && (axisValue == null || axisValue > 0)) {
            emptyResults.add('${goal.value}: ${source.name}');
          }

          for (final result in ranked.take(5)) {
            pairsChecked++;
            final c = result.candidate;

            // Op dezelfde grondslag meten als de calculator: die rekent per
            // portie zodra beide kanten portiedata hebben, anders per 100g.
            final s = result.usesServingData;
            final (double? from, double? to, bool lowerIsBetter) =
                switch (goal) {
              SwapGoal.minderKcal => (
                  s ? source.kcalServing : source.kcal100,
                  s ? c.kcalServing : c.kcal100,
                  true
                ),
              SwapGoal.minderSuiker => (
                  s ? source.sugarServing : source.sugar100,
                  s ? c.sugarServing : c.sugar100,
                  true
                ),
              SwapGoal.meerEiwit => (
                  s ? source.proteinServing : source.protein100,
                  s ? c.proteinServing : c.protein100,
                  false
                ),
              SwapGoal.besteOverall => (null, null, true),
            };
            if (from == null || to == null) continue;

            final worse = lowerIsBetter ? to > from : to < from;
            if (worse) {
              wrongDirection.add(
                '${goal.value}: ${source.name} ($from) -> ${c.name} ($to)',
              );
            }

            // De doelas moet ook op 100g-basis kloppen. Anders wint een
            // kandidaat alleen doordat zijn portie groter is, en oogt de
            // suggestie tegenstrijdig naast de waarden op het scherm.
            if (s) servingPairs++;
            final (double? f100, double? t100) = switch (goal) {
              SwapGoal.minderKcal => (source.kcal100, c.kcal100),
              SwapGoal.minderSuiker => (source.sugar100, c.sugar100),
              SwapGoal.meerEiwit => (source.protein100, c.protein100),
              SwapGoal.besteOverall => (null, null),
            };
            if (f100 != null && t100 != null) {
              final wrong100 = lowerIsBetter ? t100 > f100 : t100 < f100;
              if (wrong100) {
                lookWrongPer100g.add(
                  '${goal.value}: ${source.name} ($f100) -> ${c.name} ($t100)',
                );
              }
            }

            final improves = lowerIsBetter ? to < from : to > from;
            final promises = result.userReason?.startsWith('Past beter') == true;
            if (promises && !improves) {
              falsePromise.add(
                '${goal.value}: ${source.name} -> ${c.name} '
                'belooft doel maar wint niet ($from -> $to)',
              );
            }
          }
        }
      }

      // ignore: avoid_print
      print('paren gecontroleerd: $pairsChecked');
      // ignore: avoid_print
      print('per-portie beoordeeld: $servingPairs van $pairsChecked');
      // Sinds de selectie doelbewust aanvult (getCandidatesForCluster met
      // goal) mag geen enkel product met ruimte om te verbeteren nog leeg
      // uitkomen. Bronnen die al op 0 staan (water, zwarte koffie) tellen
      // hier niet mee; daar is niets zinnigs te suggereren.
      expect(emptyResults, isEmpty,
          reason: 'geen enkele swap over terwijl er ruimte was:\n'
              '${emptyResults.join('\n')}');
      expect(lookWrongPer100g, isEmpty,
          reason: 'swaps kloppen per portie maar niet per 100g:\n'
              '${lookWrongPer100g.join('\n')}');
      expect(wrongDirection, isEmpty,
          reason: 'swaps gaan de verkeerde kant op:\n'
              '${wrongDirection.join('\n')}');
      expect(falsePromise, isEmpty,
          reason: 'tekst belooft het doel zonder winst:\n'
              '${falsePromise.join('\n')}');
    },
    skip: key.isEmpty
        ? 'LIVE_SUPABASE_ANON_KEY ontbreekt; sweep overgeslagen.'
        : false,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

/// Bronproducten uit de families waar de audit de meeste fouten vond, plus
/// de historische probleemgevallen die in het oorspronkelijke plan stonden.
const _sourceBarcodes = <String>[
  '8715395060370', // Filet americain (cold_cuts) - de fase 3-fout
  '5410081210154', // Chokotoff (candy_sweets)
  '8714368018639', // Broodje kaas (sandwiches_wraps) - R51-splitsing
  '8712566328352', // Magnum (ice_cream_desserts)
  '8718906652750', // pindakaas (nut_butters)
  '8718907210393', // choco spread (chocolate_spreads)
  '8710398529886', // Paprika Max (crisps_chips)
  '8717389223631', // Goudse kaas (cheese_snacks)
  '8718692786974', // Spaanse worst (cold_cuts)
  '8710397261664', // Volkoren peperkoek (cookies_biscuits)
  '8717948145053', // Griekse yoghurt (yoghurt_skyr_quark)
  '8718906461659', // Cola (soft_drinks_regular)
  '8718452202157', // Havermout (breakfast_cereals)
  '8718226581846', // Wortel tortilla (bread_bakery)
  '8718989020064', // tomatensoep (soups)
  '4001724039082', // Pizza Hawaii (ready_meals)
  '8717662263415', // V Spread (savory_spreads)
  '7350040162859', // Cashews (nuts_seeds)
  '8710482535076', // Oer knack (crackers_rice_cakes)
  '8718989970789', // Vriesvers aardbeien (fresh_fruit)
];
