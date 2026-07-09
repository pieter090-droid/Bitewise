import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bitewise/core/constants/app_constants.dart';
import 'package:bitewise/core/supabase/supabase_service.dart';
import 'package:bitewise/features/snackswap/domain/product_features.dart';
import 'package:bitewise/features/snackswap/domain/snack_product.dart';

// --- Resultaattypes met duidelijke, aparte statussen ---

sealed class LookupOutcome {
  const LookupOutcome();
}

/// Product gevonden.
class LookupFound extends LookupOutcome {
  const LookupFound(this.product);
  final SnackProduct product;
}

/// Backend antwoordde netjes met `found: false`.
class LookupNotFound extends LookupOutcome {
  const LookupNotFound();
}

/// Netwerk-, config- of onverwachte fout (met leesbare melding).
class LookupError extends LookupOutcome {
  const LookupError(this.message);
  final String message;
}

/// Praat UITSLUITEND met de Supabase Edge Functions.
///
/// - Roept nooit Open Food Facts direct aan (dat doet de Edge Function).
/// - Gebruikt alleen de publishable (anon) key; nooit een service_role key.
class SnackSwapService {
  SnackSwapService(this._supabase);

  final SupabaseService _supabase;
  static const _resolvedProductView = 'product_features_resolved';
  static const _resolvedProductColumns = '''
barcode,name,brand,image_url,category,
kcal_100g,sugar_100g,protein_100g,fat_100g,carbs_100g,fiber_100g,salt_100g,saturated_fat_100g,
nova_group,nutriscore_grade,nutriscore_score,additives_n,
completeness,states_tags,serving_quantity,serving_size,kcal_serving,proteins_serving,sugars_serving,
fiber_serving,salt_serving,saturated_fat_serving,allergens,
swap_family,classification_status,is_swap_relevant,category_cluster,snack_type,product_form,consumption_mode,
secondary_consumption_modes,usage_context,taste_profile,texture_profile,use_moment,swap_tags,recommended_swap_directions,
processing_quality_score,data_quality_score,ai_confidence,is_sweet,is_salty,is_drink,is_dairy,is_chocolate,is_crunchy,
is_less_processed,has_sweeteners,has_palm_oil,ingredient_count
''';

  /// Basale barcode-validatie (EAN/UPC): alleen cijfers, 8–14 tekens.
  static bool isValidBarcode(String input) {
    final trimmed = input.trim();
    return RegExp(r'^\d{8,14}$').hasMatch(trimmed);
  }

  Future<LookupOutcome> lookupProduct(String barcode) async {
    final trimmed = barcode.trim();
    if (!_supabase.isAvailable) {
      return const LookupError(
        'Geen backend geconfigureerd. Vul je Supabase-key in assets/env/env.json.',
      );
    }

    try {
      final response = await _supabase.client.functions.invoke(
        AppConstants.fnLookupProduct,
        body: {'barcode': trimmed},
      );

      final data = response.data;
      if (data is! Map) {
        return const LookupError('Onverwacht antwoord van de server.');
      }
      final map = data.cast<String, dynamic>();

      final found = map['found'] == true;
      final product = map['product'];
      if (!found || product == null) {
        return const LookupNotFound();
      }

      return LookupFound(
        SnackProduct.fromJson(
          (product as Map).cast<String, dynamic>(),
          source: map['source'] as String?,
        ),
      );
    } catch (e) {
      return LookupError(_friendly(e));
    }
  }

  /// Zoekt producten op naam in de Supabase `products`-tabel (voor suggesties).
  /// Leest alleen (RLS staat select toe); geeft een lege lijst bij een fout.
  Future<List<SnackProduct>> searchProducts(String query) async {
    final q = query.trim();
    if (!_supabase.isAvailable || q.length < 2) return const [];
    try {
      final rows = await _supabase.client
          .from('products')
          .select()
          .ilike('name', '%$q%')
          .limit(20);
      return (rows as List)
          .map((r) => SnackProduct.fromJson((r as Map).cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  // --- Rule-based SwapScore-engine ---
  //
  // Puur lezen; geen AI-aanroep. Zie SwapScoreCalculator voor de berekening
  // en product_features_resolved voor de schone Supabase-inputlaag.

  /// Bron- of kandidaatproduct incl. afgeleide features, in één query.
  Future<SwapCandidate?> getCandidateByBarcode(String barcode) async {
    if (!_supabase.isAvailable) return null;
    try {
      final rows = await _supabase.client
          .from(_resolvedProductView)
          .select(_resolvedProductColumns)
          .eq('barcode', barcode.trim())
          .limit(1);
      final list = rows as List;
      if (list.isEmpty) return null;
      return SwapCandidate.fromJoinedJson(
        (list.first as Map).cast<String, dynamic>(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Kandidaten van hetzelfde product-type, gesorteerd op datakwaliteit.
  ///
  /// Volgorde (fijn -> grof, stopt zodra er genoeg kandidaten zijn):
  ///  1. `swap_family` (bv. "chocolate_spreads" vs. "chocolate_confectionery"
  ///     -- onderscheidt vorm/gebruik, niet alleen smaak; regelgebaseerd
  ///     gevuld, ~34% dekking, dus vaak nog leeg).
  ///  2. `snack_type` (bv. "snoep", "chocolade", "zuivel_toetje" -- ~22
  ///     waarden, de daadwerkelijke productsoort).
  ///  3. `category_cluster` (slechts 7 brede emmers zoals "zoet"/"drank";
  ///     alleen als vangnet, want "zoet" alleen mengt snoep met yoghurt).
  ///  4. [fallbackCategory] (kale OFF-categorie) wanneer het bronproduct nog
  ///     niet AI-verrijkt is.
  static const _minAcceptableCandidates = 3;

  Future<List<SwapCandidate>> getCandidatesForCluster({
    required String excludeBarcode,
    String? swapFamily,
    String? snackType,
    String? categoryCluster,
    String? fallbackCategory,
    int limit = 40,
  }) async {
    if (!_supabase.isAvailable) return const [];
    try {
      if (swapFamily != null && swapFamily.isNotEmpty) {
        final rows = await _supabase.client
            .from(_resolvedProductView)
            .select(_resolvedProductColumns)
            .eq('swap_family', swapFamily)
            .eq('classification_status', 'classified')
            .eq('is_swap_relevant', true)
            .neq('barcode', excludeBarcode)
            .order('data_quality_score', ascending: false)
            .limit(limit);
        final candidates = (rows as List)
            .map((r) => SwapCandidate.fromJoinedJson(
                (r as Map).cast<String, dynamic>()))
            .where(_isEligibleCandidate)
            .toList();
        if (candidates.length >= _minAcceptableCandidates) return candidates;
      }
      if (snackType != null && snackType.isNotEmpty) {
        final rows = await _supabase.client
            .from(_resolvedProductView)
            .select(_resolvedProductColumns)
            .eq('snack_type', snackType)
            .eq('classification_status', 'classified')
            .eq('is_swap_relevant', true)
            .neq('barcode', excludeBarcode)
            .order('data_quality_score', ascending: false)
            .limit(limit);
        final candidates = (rows as List)
            .map((r) => SwapCandidate.fromJoinedJson(
                (r as Map).cast<String, dynamic>()))
            .where(_isEligibleCandidate)
            .toList();
        if (candidates.length >= _minAcceptableCandidates) return candidates;
      }
      if (categoryCluster != null && categoryCluster.isNotEmpty) {
        final rows = await _supabase.client
            .from(_resolvedProductView)
            .select(_resolvedProductColumns)
            .eq('category_cluster', categoryCluster)
            .eq('classification_status', 'classified')
            .eq('is_swap_relevant', true)
            .neq('barcode', excludeBarcode)
            .order('data_quality_score', ascending: false)
            .limit(limit);
        final candidates = (rows as List)
            .map((r) => SwapCandidate.fromJoinedJson(
                (r as Map).cast<String, dynamic>()))
            .where(_isEligibleCandidate)
            .toList();
        if (candidates.isNotEmpty) return candidates;
      }
      if (fallbackCategory != null && fallbackCategory.isNotEmpty) {
        final rows = await _supabase.client
            .from(_resolvedProductView)
            .select(_resolvedProductColumns)
            .eq('classification_status', 'classified')
            .eq('is_swap_relevant', true)
            .neq('barcode', excludeBarcode)
            .ilike('category', '%$fallbackCategory%')
            .order('data_quality_score', ascending: false)
            .limit(limit);
        return (rows as List)
            .map((r) => SwapCandidate.fromJoinedJson(
                (r as Map).cast<String, dynamic>()))
            .where(_isEligibleCandidate)
            .toList();
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }

  /// Haalt de expliciete `related_families` op voor een `swap_family` uit
  /// `swap_family_mapping` -- de bron van waarheid voor "Andere opties"
  /// (bv. chocolate_spreads -> [nut_butters, jams_fruit_spreads, ...]).
  Future<List<String>> getRelatedFamilies(String swapFamily) async {
    if (!_supabase.isAvailable || swapFamily.isEmpty) return const [];
    try {
      final rows = await _supabase.client
          .from('swap_family_mapping')
          .select('related_families')
          .eq('swap_family', swapFamily)
          .limit(1);
      final list = rows as List;
      if (list.isEmpty) return const [];
      final related = (list.first as Map)['related_families'] as List?;
      return related?.map((e) => e.toString()).toList() ?? const [];
    } catch (_) {
      return const [];
    }
  }

  /// Kandidaten voor "Andere opties": primair via de expliciete
  /// `related_families`-lijst (bv. chocolate_spreads -> nut_butters); als die
  /// leeg is (bv. onbekend `swap_family`), valt terug op gelijke
  /// `product_form` met een andere `swap_family` als losser vangnet.
  Future<List<SwapCandidate>> getCandidatesForOtherForm({
    required String excludeBarcode,
    required String productForm,
    List<String> relatedFamilies = const [],
    String? excludeSwapFamily,
    int limit = 40,
  }) async {
    if (!_supabase.isAvailable) return const [];
    try {
      if (relatedFamilies.isNotEmpty) {
        final rows = await _supabase.client
            .from(_resolvedProductView)
            .select(_resolvedProductColumns)
            .inFilter('swap_family', relatedFamilies)
            .eq('classification_status', 'classified')
            .eq('is_swap_relevant', true)
            .neq('barcode', excludeBarcode)
            .order('data_quality_score', ascending: false)
            .limit(limit);
        final candidates = (rows as List)
            .map((r) => SwapCandidate.fromJoinedJson(
                (r as Map).cast<String, dynamic>()))
            .where(_isEligibleCandidate)
            .toList();
        if (candidates.isNotEmpty) return candidates;
      }
      if (productForm.isEmpty) return const [];
      var query = _supabase.client
          .from(_resolvedProductView)
          .select(_resolvedProductColumns)
          .eq('product_form', productForm)
          .eq('classification_status', 'classified')
          .eq('is_swap_relevant', true)
          .neq('barcode', excludeBarcode);
      if (excludeSwapFamily != null && excludeSwapFamily.isNotEmpty) {
        query = query.neq('swap_family', excludeSwapFamily);
      }
      final rows = await query
          .order('data_quality_score', ascending: false)
          .limit(limit);
      return (rows as List)
          .map((r) =>
              SwapCandidate.fromJoinedJson((r as Map).cast<String, dynamic>()))
          .where(_isEligibleCandidate)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  String _friendly(Object e) {
    final s = e.toString().toLowerCase();
    if (s.contains('socket') ||
        s.contains('network') ||
        s.contains('failed host') ||
        s.contains('connection')) {
      return 'Geen internetverbinding. Controleer je netwerk en probeer opnieuw.';
    }
    return 'Er ging iets mis bij de server. Probeer het later opnieuw.';
  }

  static bool _isEligibleCandidate(SwapCandidate candidate) =>
      candidate.features.classificationStatus == 'classified' &&
      candidate.features.isSwapRelevant &&
      candidate.features.swapFamily != null &&
      candidate.features.swapFamily!.isNotEmpty;
}

final snackSwapServiceProvider = Provider<SnackSwapService>(
  (ref) => SnackSwapService(ref.watch(supabaseServiceProvider)),
);
