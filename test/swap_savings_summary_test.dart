import 'package:flutter_test/flutter_test.dart';

import 'package:bitewise/core/database/app_database.dart';
import 'package:bitewise/features/snackswap/domain/swap_savings_summary.dart';

void main() {
  test('telt alleen werkelijk behaalde verbeteringen op', () {
    final summary = SwapSavingsSummary.fromEvents([
      _event(1,
          fromKcal: 200,
          toKcal: 120,
          fromSugar: 15,
          toSugar: 5,
          fromProtein: 3,
          toProtein: 8),
      _event(2,
          fromKcal: 100,
          toKcal: 130,
          fromSugar: 4,
          toSugar: 6,
          fromProtein: 10,
          toProtein: 8),
      _event(3),
    ]);

    expect(summary.count, 3);
    expect(summary.kcalSaved, 80);
    expect(summary.sugarSaved, 10);
    expect(summary.proteinGained, 5);
  });
}

SwapEventRow _event(
  int id, {
  double? fromKcal,
  double? toKcal,
  double? fromSugar,
  double? toSugar,
  double? fromProtein,
  double? toProtein,
}) =>
    SwapEventRow(
      id: id,
      fromBarcode: 'from$id',
      fromName: 'From $id',
      toBarcode: 'to$id',
      toName: 'To $id',
      goal: 'beste_overall',
      basis: 'per100g',
      fromAmount: 100,
      toAmount: 100,
      fromKcal: fromKcal,
      toKcal: toKcal,
      fromSugar: fromSugar,
      toSugar: toSugar,
      fromProtein: fromProtein,
      toProtein: toProtein,
      eventDate: DateTime(2026, 7, 22),
      createdAt: DateTime(2026, 7, 22),
    );
