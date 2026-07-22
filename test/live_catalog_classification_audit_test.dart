import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _url = 'https://ulgfgawoulkyumfzqgrc.supabase.co';

void main() {
  final key = Platform.environment['LIVE_SUPABASE_ANON_KEY'] ?? '';

  test(
    'auditcheckpoint plus nieuwe scans bevatten geen statusinvariantfouten',
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
        'barcode,classification_status,swap_family,is_swap_relevant',
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
      // De materialized auditview is bewust een releasecheckpoint. Nieuwe
      // scans komen daarna direct in resolved, maar niet met terugwerkende
      // kracht in dat checkpoint. Controleer daarom én dat het checkpoint
      // nergens van de live catalogus afwijkt én dat iedere nieuwe rij de
      // actuele fail-closed invarianten houdt.
      expect(resolvedBarcodes.containsAll(auditBarcodes), isTrue,
          reason: 'auditcheckpoint bevat een barcode buiten resolved');
      final afterCheckpoint = resolvedRows
          .where((row) => !auditBarcodes.contains(row['barcode']))
          .toList();
      // ignore: avoid_print
      print('na checkpoint: ${afterCheckpoint.length} nieuwe scans');
      for (final row in resolvedRows) {
        final status = row['classification_status'];
        final family = row['swap_family'];
        final relevant = row['is_swap_relevant'] == true;
        expect(status == 'classified' || status == 'review_required', isTrue,
            reason: '${row['barcode']}: ongeldige status $status');
        if (status == 'classified') {
          expect(family is String && family.isNotEmpty, isTrue,
              reason: '${row['barcode']}: classified zonder familie');
        }
        if (relevant) {
          expect(status, 'classified',
              reason: '${row['barcode']}: relevant zonder classified');
        }
      }
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
        .order('barcode')
        .range(start, start + pageSize - 1);
    rows.addAll(List<Map<String, dynamic>>.from(page));
    if (page.length < pageSize) break;
  }
  return rows;
}
