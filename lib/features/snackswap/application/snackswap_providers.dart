import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bitewise/core/preferences/preferences_service.dart';
import 'package:bitewise/features/onboarding/data/user_goals_repository.dart';
import 'package:bitewise/features/onboarding/domain/goal_type.dart';
import 'package:bitewise/features/snackswap/domain/goal.dart';

/// Het lokaal opgeslagen standaarddoel (Instellingen → standaard swap-doel).
final defaultGoalProvider = StateProvider<SnackGoal>((ref) {
  final stored = ref.watch(preferencesServiceProvider).defaultGoal;
  return SnackGoal.fromApi(stored);
});

/// Het swap-doel dat standaard op het swap-scherm staat.
///
/// Voorkeur: afgeleid van je onboarding-voedingsdoel; anders de opgeslagen
/// keuze uit Instellingen.
final swapDefaultGoalProvider = Provider<SnackGoal>((ref) {
  final userGoal = ref.watch(activeGoalProvider).valueOrNull;
  if (userGoal != null) return snackGoalForGoalType(userGoal.goalType);
  return ref.watch(defaultGoalProvider);
});

/// Vertaalt een onboarding-doel naar het passende swap-doel.
SnackGoal snackGoalForGoalType(GoalType type) => switch (type) {
      GoalType.loseWeight => SnackGoal.lessCalories,
      GoalType.maintain => SnackGoal.balanced,
      GoalType.buildMuscle => SnackGoal.moreProtein,
      GoalType.lessSugar => SnackGoal.lessSugar,
    };
