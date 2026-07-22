import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bitewise/core/database/app_database.dart';
import 'package:bitewise/features/snackswap/data/swap_feedback_repository.dart';
import 'package:bitewise/features/snackswap/data/swap_history_repository.dart';
import 'package:bitewise/features/snackswap/domain/product_features.dart';
import 'package:bitewise/features/snackswap/domain/swap_score_result.dart';
import 'package:bitewise/features/tracker/domain/meal_type.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('gebruikte swap schrijft voedingslog en immutable winstsnapshot',
      () async {
    final repo = SwapHistoryRepository(db);
    final source = _candidate('from', 'Bron', 300, 20, 5);
    final candidate = _candidate('to', 'Swap', 180, 8, 12);

    await repo.useSwap(
      source: source,
      result: _result(candidate),
      goal: SwapGoal.minderKcal,
      meal: MealType.lunch,
      at: DateTime(2026, 7, 22, 12),
    );

    final logs = await db.select(db.dayLogs).get();
    final events = await db.select(db.swapEvents).get();
    expect(logs, hasLength(1));
    expect(logs.single.productName, 'Swap');
    expect(logs.single.kcal, 180);
    expect(events, hasLength(1));
    expect(events.single.fromKcal, 300);
    expect(events.single.toKcal, 180);
    expect(events.single.goal, 'minder_kcal');
    expect(events.single.basis, 'per100g');
  });

  test('geen-goede-swapfeedback bewaart meerdere redenen en leeg doelproduct',
      () async {
    await SwapFeedbackRepository(db).save(
      fromBarcode: 'from',
      goal: SwapGoal.minderSuiker,
      reasons: const ['not_comparable', 'unavailable'],
      noGoodSwap: true,
    );

    final rows = await db.select(db.swapFeedbacks).get();
    expect(rows, hasLength(1));
    expect(rows.single.toBarcode, '');
    expect(rows.single.scope, 'no_good_swap');
    expect(rows.single.goal, 'minder_suiker');
    expect(rows.single.reasonsJson, contains('not_comparable'));
    expect(rows.single.reasonsJson, contains('unavailable'));
  });
}

SwapCandidate _candidate(String barcode, String name, double kcal, double sugar,
        double protein) =>
    SwapCandidate(
      barcode: barcode,
      name: name,
      kcal100: kcal,
      sugar100: sugar,
      protein100: protein,
      carbs100: 30,
      fat100: 10,
      features: ProductFeatures(barcode: barcode),
    );

SwapScoreResult _result(SwapCandidate candidate) => SwapScoreResult(
      candidate: candidate,
      score: 80,
      goalMatch: 80,
      nutritionImprovement: 80,
      dayContext: 50,
      similarity: 80,
      processingQuality: 50,
      dataQuality: 80,
    );
