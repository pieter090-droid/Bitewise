/// Afgeleide Bitewise-features voor een product (tabel `product_features`).
///
/// Ontbrekende waarden zijn `null` en betekenen "onbekend" — nooit als
/// `false`/`0` interpreteren (bv. `isLowSugar == null` is geen "nee").
class ProductFeatures {
  const ProductFeatures({
    required this.barcode,
    this.classificationStatus,
    this.categoryCluster,
    this.snackType,
    this.swapFamily,
    this.productForm,
    this.consumptionMode,
    this.secondaryConsumptionModes = const [],
    this.usageContext = const [],
    this.tasteProfile = const [],
    this.textureProfile = const [],
    this.useMoment = const [],
    this.swapTags = const [],
    this.recommendedSwapDirections = const [],
    this.isSweet,
    this.isSalty,
    this.isDrink,
    this.isDairy,
    this.isChocolate,
    this.isCrunchy,
    this.isLowSugar,
    this.isHighProtein,
    this.isLowKcal,
    this.isHighFiber,
    this.isLessProcessed,
    this.hasSweeteners,
    this.hasPalmOil,
    this.ingredientCount,
    this.processingQualityScore,
    this.dataQualityScore,
    this.aiConfidence,
    this.isSwapRelevant = false,
    this.allergens,
  });

  final String barcode;
  final String? classificationStatus;
  final String? categoryCluster;
  final String? snackType;

  /// Primaire kandidaat-groepering (bv. "chocolate_spreads"), fijner dan
  /// `snackType` en betrouwbaarder dan `categoryCluster`. Kan `null` zijn
  /// (nog geen regel/AI-classificatie gevonden) -- dan valt de poort terug
  /// op `snackType`/`categoryCluster`.
  final String? swapFamily;

  /// Fysieke vorm (bv. "spread" vs. "praline") -- voorkomt vorm-mismatches
  /// zoals Nutella (smeersel) vs. een bonbon (los stuk).
  final String? productForm;

  /// Hoe het product normaliter geconsumeerd wordt (bv. "spread_on_bread").
  final String? consumptionMode;

  final List<String> secondaryConsumptionModes;

  /// Extra gebruikssituaties (bv. ontbijt/snack/dessert).
  final List<String> usageContext;

  final List<String> tasteProfile;
  final List<String> textureProfile;
  final List<String> useMoment;
  final List<String> swapTags;
  final List<String> recommendedSwapDirections;

  final bool? isSweet;
  final bool? isSalty;
  final bool? isDrink;
  final bool? isDairy;
  final bool? isChocolate;
  final bool? isCrunchy;
  final bool? isLowSugar;
  final bool? isHighProtein;
  final bool? isLowKcal;
  final bool? isHighFiber;
  final bool? isLessProcessed;
  final bool? hasSweeteners;
  final bool? hasPalmOil;
  final int? ingredientCount;

  final double? processingQualityScore;
  final double? dataQualityScore;
  final double? aiConfidence;
  final bool isSwapRelevant;

  /// Alleen gebruikt voor de "controleer het etiket"-waarschuwing; nooit om
  /// veiligheid te garanderen.
  final String? allergens;

  factory ProductFeatures.fromJson(Map<String, dynamic> json) {
    List<String> list(Object? v) => _stringList(v);
    double? d(Object? v) => v == null ? null : (v as num).toDouble();
    int? i(Object? v) => v == null ? null : (v as num).toInt();

    return ProductFeatures(
      barcode: json['barcode']?.toString() ?? '',
      classificationStatus: json['classification_status'] as String?,
      categoryCluster: json['category_cluster'] as String?,
      snackType: json['snack_type'] as String?,
      swapFamily: json['swap_family'] as String?,
      productForm: json['product_form'] as String?,
      consumptionMode: json['consumption_mode'] as String?,
      secondaryConsumptionModes: list(json['secondary_consumption_modes']),
      usageContext: list(json['usage_context']),
      tasteProfile: list(json['taste_profile']),
      textureProfile: list(json['texture_profile']),
      useMoment: list(json['use_moment']),
      swapTags: list(json['swap_tags']),
      recommendedSwapDirections: list(json['recommended_swap_directions']),
      isSweet: json['is_sweet'] as bool?,
      isSalty: json['is_salty'] as bool?,
      isDrink: json['is_drink'] as bool?,
      isDairy: json['is_dairy'] as bool?,
      isChocolate: json['is_chocolate'] as bool?,
      isCrunchy: json['is_crunchy'] as bool?,
      isLowSugar: json['is_low_sugar'] as bool?,
      isHighProtein: json['is_high_protein'] as bool?,
      isLowKcal: json['is_low_kcal'] as bool?,
      isHighFiber: json['is_high_fiber'] as bool?,
      isLessProcessed: json['is_less_processed'] as bool?,
      hasSweeteners: json['has_sweeteners'] as bool?,
      hasPalmOil: json['has_palm_oil'] as bool?,
      ingredientCount: i(json['ingredient_count']),
      processingQualityScore: d(json['processing_quality_score']),
      dataQualityScore: d(json['data_quality_score']),
      aiConfidence: d(json['ai_confidence']),
      isSwapRelevant: json['is_swap_relevant'] == true,
      allergens: json['allergens'] as String?,
    );
  }
}

/// Een kandidaat: de feitelijke voedingsdata (`products`) + de afgeleide
/// features (`product_features`), zoals opgehaald in één query.
class SwapCandidate {
  const SwapCandidate({
    required this.barcode,
    required this.name,
    this.brand,
    this.imageUrl,
    this.kcal100,
    this.sugar100,
    this.protein100,
    this.fat100,
    this.carbs100,
    this.fiber100,
    this.salt100,
    this.saturatedFat100,
    this.novaGroup,
    this.nutriscoreGrade,
    this.nutriscoreScore,
    this.ingredientsText,
    this.ingredientsTags = const [],
    this.additivesN,
    this.additivesTags = const [],
    this.completeness,
    this.statesTags = const [],
    this.servingQuantity,
    this.servingSize,
    this.kcalServing,
    this.proteinServing,
    this.sugarServing,
    this.fiberServing,
    this.saltServing,
    this.saturatedFatServing,
    this.allergens,
    this.category,
    required this.features,
  });

  final String barcode;
  final String name;
  final String? brand;
  final String? imageUrl;
  final double? kcal100;
  final double? sugar100;
  final double? protein100;
  final double? fat100;
  final double? carbs100;
  final double? fiber100;
  final double? salt100;
  final double? saturatedFat100;
  final int? novaGroup;
  final String? nutriscoreGrade;
  final double? nutriscoreScore;
  final String? ingredientsText;
  final List<String> ingredientsTags;
  final int? additivesN;
  final List<String> additivesTags;
  final double? completeness;
  final List<String> statesTags;
  final double? servingQuantity;
  final String? servingSize;
  final double? kcalServing;
  final double? proteinServing;
  final double? sugarServing;
  final double? fiberServing;
  final double? saltServing;
  final double? saturatedFatServing;
  final String? allergens;

  /// Kale OFF-categorie (`products.category`) -- alleen gebruikt als
  /// `category_cluster` nog ontbreekt (product nog niet AI-verrijkt).
  final String? category;
  final ProductFeatures features;

  factory SwapCandidate.fromJoinedJson(Map<String, dynamic> row) {
    double? d(Object? v) => v == null ? null : (v as num).toDouble();
    int? i(Object? v) => v == null ? null : (v as num).toInt();
    List<String> list(Object? v) => _stringList(v);
    final product = (row['products'] as Map?)?.cast<String, dynamic>();
    Object? value(String key) => product?[key] ?? row[key];
    return SwapCandidate(
      barcode: row['barcode']?.toString() ?? '',
      name: (value('name') as String?)?.trim().isNotEmpty == true
          ? value('name') as String
          : 'Onbekend product',
      brand: value('brand') as String?,
      imageUrl: value('image_url') as String?,
      kcal100: d(value('kcal_100g')),
      sugar100: d(value('sugar_100g') ?? value('sugars_100g')),
      protein100: d(value('protein_100g') ?? value('proteins_100g')),
      fat100: d(value('fat_100g')),
      carbs100: d(value('carbs_100g')),
      fiber100: d(value('fiber_100g')),
      salt100: d(value('salt_100g')),
      saturatedFat100: d(value('saturated_fat_100g')),
      novaGroup: i(value('nova_group')),
      nutriscoreGrade: value('nutriscore_grade') as String?,
      nutriscoreScore: d(value('nutriscore_score')),
      ingredientsText: value('ingredients_text') as String?,
      ingredientsTags: list(value('ingredients_tags')),
      additivesN: i(value('additives_n')),
      additivesTags: list(value('additives_tags')),
      completeness: d(value('completeness')),
      statesTags: list(value('states_tags')),
      servingQuantity: d(value('serving_quantity')),
      servingSize: value('serving_size')?.toString(),
      kcalServing: d(value('kcal_serving')),
      proteinServing: d(value('proteins_serving')),
      sugarServing: d(value('sugars_serving')),
      fiberServing: d(value('fiber_serving')),
      saltServing: d(value('salt_serving')),
      saturatedFatServing: d(value('saturated_fat_serving')),
      allergens: value('allergens') as String?,
      category: value('category') as String?,
      features: ProductFeatures.fromJson(row),
    );
  }
}

List<String> _stringList(Object? value) {
  if (value == null) return const [];
  if (value is List) {
    return value.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
  }
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return const [];
    final withoutBraces = trimmed.startsWith('{') && trimmed.endsWith('}')
        ? trimmed.substring(1, trimmed.length - 1)
        : trimmed;
    return withoutBraces
        .split(',')
        .map((part) => part.trim().replaceAll('"', ''))
        .where((part) => part.isNotEmpty)
        .toList();
  }
  return const [];
}
