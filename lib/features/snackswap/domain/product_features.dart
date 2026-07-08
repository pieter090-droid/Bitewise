/// Afgeleide Bitewise-features voor een product (tabel `product_features`).
///
/// Ontbrekende waarden zijn `null` en betekenen "onbekend" — nooit als
/// `false`/`0` interpreteren (bv. `isLowSugar == null` is geen "nee").
class ProductFeatures {
  const ProductFeatures({
    required this.barcode,
    this.categoryCluster,
    this.snackType,
    this.swapFamily,
    this.productForm,
    this.consumptionMode,
    this.usageContext = const [],
    this.tasteProfile = const [],
    this.textureProfile = const [],
    this.useMoment = const [],
    this.swapTags = const [],
    this.recommendedSwapDirections = const [],
    this.isSweet,
    this.isSalty,
    this.isCrunchy,
    this.isLowSugar,
    this.isHighProtein,
    this.isLowKcal,
    this.isHighFiber,
    this.isLessProcessed,
    this.processingQualityScore,
    this.dataQualityScore,
    this.aiConfidence,
    this.isSwapRelevant = false,
    this.allergens,
  });

  final String barcode;
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

  /// Extra gebruikssituaties (bv. ontbijt/snack/dessert).
  final List<String> usageContext;

  final List<String> tasteProfile;
  final List<String> textureProfile;
  final List<String> useMoment;
  final List<String> swapTags;
  final List<String> recommendedSwapDirections;

  final bool? isSweet;
  final bool? isSalty;
  final bool? isCrunchy;
  final bool? isLowSugar;
  final bool? isHighProtein;
  final bool? isLowKcal;
  final bool? isHighFiber;
  final bool? isLessProcessed;

  final double? processingQualityScore;
  final double? dataQualityScore;
  final double? aiConfidence;
  final bool isSwapRelevant;

  /// Alleen gebruikt voor de "controleer het etiket"-waarschuwing; nooit om
  /// veiligheid te garanderen.
  final String? allergens;

  factory ProductFeatures.fromJson(Map<String, dynamic> json) {
    List<String> list(Object? v) =>
        (v as List?)?.map((e) => e.toString()).toList() ?? const [];
    double? d(Object? v) => v == null ? null : (v as num).toDouble();

    return ProductFeatures(
      barcode: json['barcode']?.toString() ?? '',
      categoryCluster: json['category_cluster'] as String?,
      snackType: json['snack_type'] as String?,
      swapFamily: json['swap_family'] as String?,
      productForm: json['product_form'] as String?,
      consumptionMode: json['consumption_mode'] as String?,
      usageContext: list(json['usage_context']),
      tasteProfile: list(json['taste_profile']),
      textureProfile: list(json['texture_profile']),
      useMoment: list(json['use_moment']),
      swapTags: list(json['swap_tags']),
      recommendedSwapDirections: list(json['recommended_swap_directions']),
      isSweet: json['is_sweet'] as bool?,
      isSalty: json['is_salty'] as bool?,
      isCrunchy: json['is_crunchy'] as bool?,
      isLowSugar: json['is_low_sugar'] as bool?,
      isHighProtein: json['is_high_protein'] as bool?,
      isLowKcal: json['is_low_kcal'] as bool?,
      isHighFiber: json['is_high_fiber'] as bool?,
      isLessProcessed: json['is_less_processed'] as bool?,
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
    final product = (row['products'] as Map?)?.cast<String, dynamic>();
    return SwapCandidate(
      barcode: row['barcode']?.toString() ?? '',
      name: (product?['name'] as String?)?.trim().isNotEmpty == true
          ? product!['name'] as String
          : 'Onbekend product',
      brand: product?['brand'] as String?,
      imageUrl: product?['image_url'] as String?,
      kcal100: d(product?['kcal_100g']),
      sugar100: d(product?['sugar_100g']),
      protein100: d(product?['protein_100g']),
      fat100: d(product?['fat_100g']),
      carbs100: d(product?['carbs_100g']),
      fiber100: d(product?['fiber_100g']),
      salt100: d(product?['salt_100g']),
      saturatedFat100: d(product?['saturated_fat_100g']),
      servingQuantity: d(product?['serving_quantity']),
      servingSize: product?['serving_size']?.toString(),
      kcalServing: d(product?['kcal_serving']),
      proteinServing: d(product?['proteins_serving']),
      sugarServing: d(product?['sugars_serving']),
      fiberServing: d(product?['fiber_serving']),
      saltServing: d(product?['salt_serving']),
      saturatedFatServing: d(product?['saturated_fat_serving']),
      allergens: product?['allergens'] as String?,
      category: product?['category'] as String?,
      features: ProductFeatures.fromJson(row),
    );
  }
}
