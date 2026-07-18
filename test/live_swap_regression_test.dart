import 'dart:io';

import 'package:bitewise/core/supabase/supabase_service.dart';
import 'package:bitewise/features/snackswap/application/swap_score_calculator.dart';
import 'package:bitewise/features/snackswap/data/snackswap_service.dart';
import 'package:bitewise/features/snackswap/domain/swap_score_result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _url = 'https://ulgfgawoulkyumfzqgrc.supabase.co';

void main() {
  final key = Platform.environment['LIVE_SUPABASE_ANON_KEY'] ?? '';
  final capture = Platform.environment['CAPTURE_SWAP_BASELINE'] == '1';

  test(
    'vaste live barcodes houden dezelfde top-3 beste-overall swaps',
    () async {
      final service = SnackSwapService(
        SupabaseService.withClientForTesting(SupabaseClient(_url, key)),
      );
      const calculator = SwapScoreCalculator();
      final actual = <String, List<String>>{};

      for (final fixture in _fixtures) {
        final source = await service.getCandidateByBarcode(fixture.barcode);
        expect(source, isNotNull, reason: '${fixture.name} ontbreekt live');
        expect(source!.features.swapFamily, fixture.family);

        final candidates = await service.getCandidatesForCluster(
          excludeBarcode: source.barcode,
          swapFamily: source.features.swapFamily,
          snackType: source.features.snackType,
          categoryCluster: source.features.categoryCluster,
          fallbackCategory: source.category,
        );
        final top3 = calculator
            .rankCandidates(
              source: source,
              candidates: candidates,
              goal: SwapGoal.besteOverall,
            )
            .take(3)
            .map((result) => result.candidate.barcode)
            .toList();
        expect(top3, isNotEmpty, reason: '${fixture.name} heeft geen swaps');
        actual[fixture.barcode] = top3;

        if (!capture) {
          expect(top3, fixture.expectedTop3, reason: fixture.name);
        }
      }

      if (capture) {
        for (final fixture in _fixtures) {
          // Expliciete capture-modus maakt de nulmeting controleerbaar zonder
          // ooit credentials of database-inhoud naar een bestand te schrijven.
          // ignore: avoid_print
          print("'${fixture.barcode}': ${actual[fixture.barcode]},");
        }
      }
    },
    skip: key.isEmpty
        ? 'LIVE_SUPABASE_ANON_KEY ontbreekt; live regressietest overgeslagen.'
        : false,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

class _Fixture {
  const _Fixture(this.barcode, this.name, this.family, this.expectedTop3);

  final String barcode;
  final String name;
  final String family;
  final List<String> expectedTop3;
}

const _fixtures = <_Fixture>[
  _Fixture('8718907210393', 'Choco spread duo', 'chocolate_spreads',
      ['8710573455078', '8052575090414', '8710573626140']),
  _Fixture('20646073', 'Coconut Ice Cream', 'ice_cream_desserts',
      ['5060346412931', '8017977014987', '8712100889288']),
  _Fixture('4718900725270', 'Roomkaas rode biet geitenkaas', 'savory_spreads',
      ['8717662263415', '8718452731107', '5430001428018']),
  _Fixture('8718907045599', 'wrap falafel tomaat', 'sandwiches_wraps',
      ['8710400335030', '8720254963846', '2228053004952']),
  _Fixture('8710398529886', 'Paprika Max', 'crisps_chips',
      ['8710400660637', '8710398523327', '8710398526014']),
  _Fixture('4718098550654', 'chiazaad', 'nuts_seeds',
      ['8718907466943', '5059605241757', '4056489440116']),
  _Fixture('8717948145053', 'Yoghurt Grieks Naturel', 'yoghurt_skyr_quark',
      ['8718796045984', '4016241040381', '8718452908424']),
  _Fixture('8714719012903', 'geitenmelk', 'dairy_drinks',
      ['8712800035732', '8710400003625', '8712800002925']),
  _Fixture('7394376623691', 'Barista Edition Vanilla Flavour',
      'plant_based_dairy', ['8718452876365', '4061462919121', '4056489695363']),
  _Fixture(
      '8715600243536',
      'Non sparkling apple pear flavour',
      'soft_drinks_regular',
      ['8718907630634', '4260183211082', '8711399010021']),
  _Fixture('8718907384773', 'AH ice tea zero', 'soft_drinks_light_zero',
      ['8711327596696', '8718452538010', '8718452639564']),
  _Fixture('8718452275328', 'Groentensap spinazie avocado appel kokoswater',
      'fruit_juices', ['8718452646685', '20083076', '8718907924085']),
  _Fixture('9004380071507', 'Capuccino Coffee', 'hot_beverages',
      ['8722700089131', '8712100369278', '8003753918198']),
  _Fixture('8718989020064', 'tomaten creme soep', 'soups',
      ['8720182660299', '8719587101513', '8718907820103']),
  _Fixture('4056489182658', 'pasta saus', 'sauces_dips',
      ['3083680008259', '8718906892958', '8718976016353']),
  _Fixture('8718226581846', 'Wortel Tortilla', 'bread_bakery',
      ['8718989949679', '4335619345720', '8718452356591']),
  _Fixture('8718452202157', 'Havermout', 'breakfast_cereals',
      ['8720256082408', '8711521914227', '5000127061828']),
  _Fixture('8711299015485', 'Chewy Chocolate', 'cereal_bars',
      ['8721161523161', '8713500080893', '8713500011989']),
  _Fixture('8718989970789', 'Vriesvers Aardbeien', 'fresh_fruit',
      ['5413330100855', '3228170000072', '3558370200997']),
  _Fixture('4001724039082', 'Ristorante Pizza Hawaii', 'ready_meals',
      ['8718781601607', '8718265138636', '5065008359739']),
];
