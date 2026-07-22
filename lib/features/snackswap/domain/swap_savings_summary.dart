import 'package:bitewise/core/database/app_database.dart';

class SwapSavingsSummary {
  const SwapSavingsSummary({
    required this.count,
    required this.kcalSaved,
    required this.sugarSaved,
    required this.proteinGained,
  });

  final int count;
  final double kcalSaved;
  final double sugarSaved;
  final double proteinGained;

  factory SwapSavingsSummary.fromEvents(Iterable<SwapEventRow> events) {
    double positive(double? value) => value != null && value > 0 ? value : 0;
    var count = 0;
    var kcal = 0.0;
    var sugar = 0.0;
    var protein = 0.0;
    for (final event in events) {
      count++;
      if (event.fromKcal != null && event.toKcal != null) {
        kcal += positive(event.fromKcal! - event.toKcal!);
      }
      if (event.fromSugar != null && event.toSugar != null) {
        sugar += positive(event.fromSugar! - event.toSugar!);
      }
      if (event.fromProtein != null && event.toProtein != null) {
        protein += positive(event.toProtein! - event.fromProtein!);
      }
    }
    return SwapSavingsSummary(
      count: count,
      kcalSaved: kcal,
      sugarSaved: sugar,
      proteinGained: protein,
    );
  }
}
