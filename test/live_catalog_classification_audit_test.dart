import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _url = 'https://ulgfgawoulkyumfzqgrc.supabase.co';

void main() {
  final key = Platform.environment['LIVE_SUPABASE_ANON_KEY'] ?? '';

  test(
    'catalogusaudit is 1-op-1 en bevat geen harde statusinvariantfouten',
    () async {
      final client = SupabaseClient(_url, key);
      final auditRows = await _allRows(
        client,
        'catalog_classification_audit',
        'barcode,audit_bucket',
      );
      final resolvedRows = await _allRows(
        client,
        'product_features_resolved',
        'barcode',
      );

      final auditBarcodes = auditRows.map((row) => row['barcode']).toSet();
      final resolvedBarcodes =
          resolvedRows.map((row) => row['barcode']).toSet();
      final buckets = <String, int>{};
      for (final row in auditRows) {
        final bucket = row['audit_bucket'] as String;
        buckets[bucket] = (buckets[bucket] ?? 0) + 1;
      }

      // ignore: avoid_print
      print('catalogusaudit: ${auditRows.length} rijen, buckets=$buckets');

      expect(auditRows, isNotEmpty);
      expect(auditBarcodes.length, auditRows.length,
          reason: 'auditview bevat dubbele barcodes');
      expect(auditBarcodes, resolvedBarcodes,
          reason: 'auditview en resolved view zijn niet 1-op-1');
      expect(buckets['invalid_classified_without_family'] ?? 0, 0);
      expect(buckets['invalid_unknown_status'] ?? 0, 0);
    },
    skip: key.isEmpty
        ? 'LIVE_SUPABASE_ANON_KEY ontbreekt; catalogusaudit overgeslagen.'
        : false,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

Future<List<Map<String, dynamic>>> _allRows(
  SupabaseClient client,
  String relation,
  String columns,
) async {
  const pageSize = 1000;
  final rows = <Map<String, dynamic>>[];
  for (var start = 0;; start += pageSize) {
    final page = await client
        .from(relation)
        .select(columns)
        .range(start, start + pageSize - 1);
    rows.addAll(List<Map<String, dynamic>>.from(page));
    if (page.length < pageSize) break;
  }
  return rows;
}
