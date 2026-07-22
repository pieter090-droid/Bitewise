import 'dart:io';

import 'package:bitewise/core/supabase/supabase_service.dart';
import 'package:bitewise/features/snackswap/data/snackswap_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _url = 'https://ulgfgawoulkyumfzqgrc.supabase.co';
const _importedBarcode = '8718452948758';

void main() {
  final key = Platform.environment['LIVE_SUPABASE_ANON_KEY'] ?? '';

  test(
    'nieuw OFF-product is resolved en direct beschikbaar voor swaps',
    () async {
      final service = SnackSwapService(
        SupabaseService.withClientForTesting(SupabaseClient(_url, key)),
      );

      final lookup = await service.lookupProduct(_importedBarcode);
      expect(lookup, isA<LookupFound>());

      final source = await service.getCandidateByBarcode(_importedBarcode);
      expect(source, isNotNull);
      expect(source!.features.classificationStatus, 'classified');
      expect(source.features.isSwapRelevant, isTrue);
      expect(source.features.swapFamily, 'ice_cream_desserts');

      final candidates = await service.getCandidatesForCluster(
        excludeBarcode: source.barcode,
        swapFamily: source.features.swapFamily,
        snackType: source.features.snackType,
        categoryCluster: source.features.categoryCluster,
        fallbackCategory: source.category,
      );
      expect(candidates, isNotEmpty);
      expect(candidates.every((c) => c.barcode != source.barcode), isTrue);
      expect(
        candidates.every(
          (c) =>
              c.features.classificationStatus == 'classified' &&
              c.features.isSwapRelevant,
        ),
        isTrue,
      );
    },
    skip: key.isEmpty
        ? 'LIVE_SUPABASE_ANON_KEY ontbreekt; nieuwe-scan-test overgeslagen.'
        : false,
  );
}
