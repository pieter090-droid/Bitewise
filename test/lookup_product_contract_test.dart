import 'package:flutter_test/flutter_test.dart';

import 'package:bitewise/features/snackswap/data/snackswap_service.dart';

void main() {
  group('lookup_product-contract', () {
    test('actueel found-resultaat wordt een volledig product', () {
      final outcome = SnackSwapService.parseLookupResponse({
        'found': true,
        'source': 'open_food_facts_saved',
        'product': {
          'barcode': '12345678',
          'name': 'Testproduct',
          'kcal_100g': 123,
          'sugar_100g': null,
          'protein_100g': 4.5,
        },
      });

      expect(outcome, isA<LookupFound>());
      final product = (outcome as LookupFound).product;
      expect(product.barcode, '12345678');
      expect(product.source, 'open_food_facts_saved');
      expect(product.kcal100, 123);
      expect(product.sugar100, isNull);
      expect(product.protein100, 4.5);
    });

    test('normale API-miss blijft een niet-gevonden resultaat', () {
      final outcome = SnackSwapService.parseLookupResponse({
        'found': false,
        'error': 'Geen product gevonden.',
      });

      expect(outcome, isA<LookupNotFound>());
    });

    test('ouder antwoord met product blijft tijdelijk compatibel', () {
      final outcome = SnackSwapService.parseLookupResponse({
        'product': {'barcode': '12345678', 'name': 'Oud contract'},
      });

      expect(outcome, isA<LookupFound>());
    });

    test('ongeldig productformaat faalt expliciet', () {
      final outcome = SnackSwapService.parseLookupResponse({
        'found': true,
        'product': 'geen object',
      });

      expect(outcome, isA<LookupError>());
    });
  });
}
