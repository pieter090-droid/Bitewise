import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bitewise/core/database/app_database.dart';
import 'package:bitewise/features/snackswap/domain/swap_score_result.dart';

class SwapFeedbackRepository {
  SwapFeedbackRepository(this._db);
  final AppDatabase _db;

  Future<void> save({
    required String fromBarcode,
    String? toBarcode,
    required SwapGoal goal,
    required List<String> reasons,
    String? note,
    bool positive = false,
    bool noGoodSwap = false,
  }) async {
    await _db.into(_db.swapFeedbacks).insert(
          SwapFeedbacksCompanion.insert(
            fromBarcode: fromBarcode,
            toBarcode: toBarcode ?? '',
            positive: positive,
            goal: Value(goal.value),
            scope: Value(noGoodSwap ? 'no_good_swap' : 'suggestion'),
            reasonsJson: Value(jsonEncode(reasons)),
            note: Value(note?.trim().isEmpty == true ? null : note?.trim()),
          ),
        );
  }
}

final swapFeedbackRepositoryProvider = Provider<SwapFeedbackRepository>(
  (ref) => SwapFeedbackRepository(ref.watch(appDatabaseProvider)),
);
