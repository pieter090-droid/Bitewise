/// Eén aanbeveling uit `recommend_swaps`.
///
/// Let op: de voedingswaarden zijn **per portie** (`kcal`, `sugar_g`,
/// `protein_g`, …), niet per 100 g. Alle velden zijn optioneel/defensief.
class SwapSuggestion {
  const SwapSuggestion({
    required this.name,
    required this.score,
    this.explanation,
    this.description,
    this.tag,
    this.kcal,
    this.sugarG,
    this.proteinG,
    this.fatG,
    this.carbsG,
  });

  final String name;
  final double score;
  final String? explanation;
  final String? description;
  final String? tag;

  final double? kcal;
  final double? sugarG;
  final double? proteinG;
  final double? fatG;
  final double? carbsG;

  factory SwapSuggestion.fromJson(Map<String, dynamic> json) {
    double? d(Object? v) => v == null ? null : (v as num).toDouble();
    return SwapSuggestion(
      name: (json['name'] as String?) ?? 'Onbekend product',
      score: d(json['score']) ?? 0,
      explanation: (json['explanation'] ?? json['reason']) as String?,
      description: json['description'] as String?,
      tag: json['tag'] as String?,
      kcal: d(json['kcal']),
      sugarG: d(json['sugar_g']),
      proteinG: d(json['protein_g']),
      fatG: d(json['fat_g']),
      carbsG: d(json['carbs_g']),
    );
  }
}
