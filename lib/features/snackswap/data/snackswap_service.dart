import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bitewise/core/constants/app_constants.dart';
import 'package:bitewise/core/supabase/supabase_service.dart';
import 'package:bitewise/features/snackswap/domain/goal.dart';
import 'package:bitewise/features/snackswap/domain/product_features.dart';
import 'package:bitewise/features/snackswap/domain/snack_product.dart';
import 'package:bitewise/features/snackswap/domain/swap_score_result.dart';
import 'package:bitewise/features/snackswap/domain/swap_suggestion.dart';

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

sealed class SwapOutcome {
  const SwapOutcome();
}

class SwapFound extends SwapOutcome {
  const SwapFound(this.suggestions);
  final List<SwapSuggestion> suggestions;
}

class SwapNotFound extends SwapOutcome {
  const SwapNotFound();
}

class SwapError extends SwapOutcome {
  const SwapError(this.message);
  final String message;
}

/// Praat UITSLUITEND met de Supabase Edge Functions.
///
/// - Roept nooit Open Food Facts direct aan (dat doet de Edge Function).
/// - Gebruikt alleen de publishable (anon) key; nooit een service_role key.
class SnackSwapService {
  SnackSwapService(this._supabase);

  final SupabaseService _supabase;

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

  Future<SwapOutcome> recommendSwaps({
    required String barcode,
    required SnackGoal goal,
    int limit = 3,
  }) async {
    if (!_supabase.isAvailable) {
      return const SwapError(
        'Geen backend geconfigureerd. Vul je Supabase-key in assets/env/env.json.',
      );
    }

    try {
      final response = await _supabase.client.functions.invoke(
        AppConstants.fnRecommendSwaps,
        body: {
          'barcode': barcode.trim(),
          'user_goal': goal.apiValue,
          'limit': limit,
        },
      );

      final data = response.data;
      if (data is! Map) {
        return const SwapError('Onverwacht antwoord van de server.');
      }
      final map = data.cast<String, dynamic>();

      final list = (map['recommendations'] as List?) ?? const [];
      if (map['found'] != true || list.isEmpty) {
        return const SwapNotFound();
      }

      final suggestions = list
          .map((e) =>
              SwapSuggestion.fromJson((e as Map).cast<String, dynamic>()))
          .toList()
        ..sort((a, b) => b.score.compareTo(a.score));

      return SwapFound(suggestions);
    } catch (e) {
      return SwapError(_friendly(e));
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

  // --- Rule-based SwapScore-engine (nieuw, parallel pad naast recommend_swaps) ---
  //
  // Puur lezen; geen AI-aanroep. Zie SwapScoreCalculator voor de berekening
  // en supabase/migrations/0009_swapscore_model.sql voor de referentiespec.

  /// Bron- of kandidaatproduct incl. afgeleide features, in één query.
  Future<SwapCandidate?> getCandidateByBarcode(String barcode) async {
    if (!_supabase.isAvailable) return null;
    try {
      final rows = await _supabase.client
          .from('product_features')
          .select('*, products(*)')
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
            .from('product_features')
            .select('*, products(*)')
            .eq('swap_family', swapFamily)
            .eq('is_swap_relevant', true)
            .neq('barcode', excludeBarcode)
            .order('data_quality_score', ascending: false)
            .limit(limit);
        final candidates = (rows as List)
            .map((r) => SwapCandidate.fromJoinedJson((r as Map).cast<String, dynamic>()))
            .toList();
        if (candidates.length >= _minAcceptableCandidates) return candidates;
      }
      if (snackType != null && snackType.isNotEmpty) {
        final rows = await _supabase.client
            .from('product_features')
            .select('*, products(*)')
            .eq('snack_type', snackType)
            .eq('is_swap_relevant', true)
            .neq('barcode', excludeBarcode)
            .order('data_quality_score', ascending: false)
            .limit(limit);
        final candidates = (rows as List)
            .map((r) => SwapCandidate.fromJoinedJson((r as Map).cast<String, dynamic>()))
            .toList();
        if (candidates.length >= _minAcceptableCandidates) return candidates;
      }
      if (categoryCluster != null && categoryCluster.isNotEmpty) {
        final rows = await _supabase.client
            .from('product_features')
            .select('*, products(*)')
            .eq('category_cluster', categoryCluster)
            .eq('is_swap_relevant', true)
            .neq('barcode', excludeBarcode)
            .order('data_quality_score', ascending: false)
            .limit(limit);
        final candidates = (rows as List)
            .map((r) => SwapCandidate.fromJoinedJson((r as Map).cast<String, dynamic>()))
            .toList();
        if (candidates.isNotEmpty) return candidates;
      }
      if (fallbackCategory != null && fallbackCategory.isNotEmpty) {
        final rows = await _supabase.client
            .from('product_features')
            .select('*, products!inner(*)')
            .eq('is_swap_relevant', true)
            .neq('barcode', excludeBarcode)
            .ilike('products.category', '%$fallbackCategory%')
            .order('data_quality_score', ascending: false)
            .limit(limit);
        return (rows as List)
            .map((r) => SwapCandidate.fromJoinedJson((r as Map).cast<String, dynamic>()))
            .toList();
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }

  /// De actieve scoregewichten (`swap_score_weights`), met veilige fallback.
  Future<SwapScoreWeights> getActiveWeights() async {
    if (!_supabase.isAvailable) return SwapScoreWeights.fallback;
    try {
      final rows = await _supabase.client
          .from('swap_score_weights')
          .select()
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(1);
      final list = rows as List;
      if (list.isEmpty) return SwapScoreWeights.fallback;
      return SwapScoreWeights.fromJson((list.first as Map).cast<String, dynamic>());
    } catch (_) {
      return SwapScoreWeights.fallback;
    }
  }

  /// De UX-groep-definities (`swap_recommendation_groups`), niet hardcoded.
  Future<List<Map<String, dynamic>>> getRecommendationGroups() async {
    if (!_supabase.isAvailable) return const [];
    try {
      final rows = await _supabase.client
          .from('swap_recommendation_groups')
          .select()
          .eq('is_active', true)
          .order('sort_order');
      return (rows as List).map((r) => (r as Map).cast<String, dynamic>()).toList();
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
}

final snackSwapServiceProvider = Provider<SnackSwapService>(
  (ref) => SnackSwapService(ref.watch(supabaseServiceProvider)),
);
