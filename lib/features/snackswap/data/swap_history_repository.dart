import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bitewise/core/database/app_database.dart';
import 'package:bitewise/features/snackswap/domain/product_features.dart';
import 'package:bitewise/features/snackswap/domain/swap_comparison.dart';
import 'package:bitewise/features/snackswap/domain/swap_score_result.dart';
import 'package:bitewise/features/tracker/domain/meal_type.dart';

class SwapHistoryRepository {
  SwapHistoryRepository(this._db);
  final AppDatabase _db;

  DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> useSwap({
    required SwapCandidate source,
    required SwapScoreResult result,
    required SwapGoal goal,
    required MealType meal,
    DateTime? at,
  }) async {
    final now = at ?? DateTime.now();
    final comparison = SwapComparison.forResult(source: source, result: result);
    final to = comparison.candidate;
    await _db.transaction(() async {
      await _db.into(_db.dayLogs).insert(
            DayLogsCompanion.insert(
              barcode: Value(result.candidate.barcode),
              productName: result.candidate.name,
              mealTypeIndex: meal.index,
              grams: to.amount,
              kcal: to.kcal ?? 0,
              protein: to.protein ?? 0,
              sugar: to.sugar ?? 0,
              carbs: Value(_scaled(result.candidate.carbs100, to.amount)),
              fat: Value(to.fat ?? 0),
              logDate: _day(now),
            ),
          );
      await _db.into(_db.swapEvents).insert(
            SwapEventsCompanion.insert(
              fromBarcode: source.barcode,
              fromName: source.name,
              toBarcode: result.candidate.barcode,
              toName: result.candidate.name,
              goal: goal.value,
              basis: comparison.usesServingData ? 'serving' : 'per100g',
              fromAmount: comparison.source.amount,
              toAmount: comparison.candidate.amount,
              fromKcal: Value(comparison.source.kcal),
              toKcal: Value(comparison.candidate.kcal),
              fromSugar: Value(comparison.source.sugar),
              toSugar: Value(comparison.candidate.sugar),
              fromProtein: Value(comparison.source.protein),
              toProtein: Value(comparison.candidate.protein),
              fromFat: Value(comparison.source.fat),
              toFat: Value(comparison.candidate.fat),
              fromSalt: Value(comparison.source.salt),
              toSalt: Value(comparison.candidate.salt),
              eventDate: _day(now),
            ),
          );
    });
  }

  Stream<List<SwapEventRow>> watchBetween(DateTime start, DateTime end) {
    final query = _db.select(_db.swapEvents)
      ..where((t) => t.eventDate.isBetweenValues(_day(start), _day(end)))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return query.watch();
  }

  double _scaled(double? value, double amount) =>
      value == null ? 0 : value * amount / 100.0;
}

final swapHistoryRepositoryProvider = Provider<SwapHistoryRepository>(
  (ref) => SwapHistoryRepository(ref.watch(appDatabaseProvider)),
);
