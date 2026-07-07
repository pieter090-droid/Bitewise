import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bitewise/core/theme/app_colors.dart';
import 'package:bitewise/features/snackswap/application/rule_based_swap_provider.dart';
import 'package:bitewise/features/snackswap/domain/product_features.dart';
import 'package:bitewise/features/snackswap/domain/swap_score_result.dart';
import 'package:bitewise/features/sync/application/sync_coordinator.dart';
import 'package:bitewise/features/tracker/data/day_logs_repository.dart';
import 'package:bitewise/features/tracker/domain/meal_type.dart';

/// Toont de rule-based SwapScore-aanbevelingen (zie SwapScoreCalculator) als
/// dé aanbeveling. Het oude, craving-gebaseerde `recommend_swaps`-pad leverde
/// aantoonbaar onzinnige cross-categorie "swaps" (bv. snoep -> komkommer) --
/// zie het projectgeheugen voor de root cause -- en wordt hier niet meer
/// aangeroepen.
class SwapScreen extends ConsumerWidget {
  const SwapScreen({required this.barcode, super.key});

  final String barcode;

  /// Logt een gekozen swap direct in het daglog (per 100g-waarden, zelfde
  /// eenvoudige semantiek als voorheen: 1 regel, geen gramgewicht-schaling).
  Future<void> _logSwap(WidgetRef ref, BuildContext context, SwapCandidate item) async {
    final meal = MealType.suggestForNow();
    await ref.read(dayLogsRepositoryProvider).logEntry(
          productName: item.name,
          mealType: meal,
          grams: 0,
          kcal: item.kcal100 ?? 0,
          protein: item.protein100 ?? 0,
          sugar: item.sugar100 ?? 0,
          carbs: item.carbs100 ?? 0,
          fat: item.fat100 ?? 0,
        );
    ref.read(syncCoordinatorProvider).onLogsChanged();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${item.name} toegevoegd aan ${meal.label}')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outcome = ref.watch(ruleBasedSwapProvider(barcode));
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        title: const Text('Betere swaps'),
      ),
      body: SafeArea(
        child: outcome.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => _Info(
            icon: Icons.cloud_off,
            title: 'Er ging iets mis',
            body: 'De aanbevelingen konden niet geladen worden.',
            action: TextButton.icon(
              onPressed: () => ref.invalidate(ruleBasedSwapProvider(barcode)),
              icon: const Icon(Icons.refresh),
              label: const Text('Opnieuw proberen'),
            ),
          ),
          data: (result) => switch (result) {
            RuleBasedSwapNotFound() => const _Info(
                icon: Icons.inbox_outlined,
                title: 'Geen swaps gevonden',
                body: 'Voor dit product hebben we nog geen alternatief -- '
                    'mogelijk is het nog niet verrijkt of niet swap-relevant.',
              ),
            RuleBasedSwapError() => const _Info(
                icon: Icons.cloud_off,
                title: 'Er ging iets mis',
                body: 'De aanbevelingen konden niet geladen worden.',
              ),
            RuleBasedSwapFound(:final groups) => ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  for (final group in groups) _GroupSection(
                    group: group,
                    onLog: (item) => _logSwap(ref, context, item),
                  ),
                ],
              ),
          },
        ),
      ),
    );
  }
}

class _GroupSection extends StatelessWidget {
  const _GroupSection({required this.group, required this.onLog});
  final SwapRecommendationGroup group;
  final void Function(SwapCandidate item) onLog;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(group.label,
              style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.navy)),
          const SizedBox(height: 10),
          for (final result in group.results)
            _SwapCard(result: result, onLog: () => onLog(result.candidate)),
        ],
      ),
    );
  }
}

class _SwapCard extends StatelessWidget {
  const _SwapCard({required this.result, required this.onLog});

  final SwapScoreResult result;
  final VoidCallback onLog;

  @override
  Widget build(BuildContext context) {
    final item = result.candidate;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.mist),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: AppColors.navy)),
                    if (item.brand != null && item.brand!.isNotEmpty)
                      Text(item.brand!,
                          style: const TextStyle(color: AppColors.slate, fontSize: 13)),
                  ],
                ),
              ),
              _ScoreBadge(score: result.score),
            ],
          ),
          if (result.reasons.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(result.reasons.join(' · '),
                style: const TextStyle(color: AppColors.ink, height: 1.35)),
          ],
          if (_hasNutrition) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (item.kcal100 != null) _pill('${_fmt(item.kcal100!)} kcal /100g'),
                if (item.sugar100 != null) _pill('${_fmt(item.sugar100!)}g suiker /100g'),
                if (item.protein100 != null) _pill('${_fmt(item.protein100!)}g eiwit /100g'),
              ],
            ),
          ],
          if (result.warnings.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final w in result.warnings)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 14, color: AppColors.slate),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(w,
                        style: const TextStyle(fontSize: 11, color: AppColors.slate)),
                  ),
                ],
              ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: onLog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Toevoegen aan log'),
            ),
          ),
        ],
      ),
    );
  }

  bool get _hasNutrition =>
      result.candidate.kcal100 != null ||
      result.candidate.sugar100 != null ||
      result.candidate.protein100 != null;

  Widget _pill(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.mist),
        ),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.navy)),
      );

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.score});
  final double score;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text('score ${score.round()}',
          style: const TextStyle(
              color: AppColors.navy, fontWeight: FontWeight.w800, fontSize: 12)),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.icon, required this.title, required this.body, this.action});
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.slate),
            const SizedBox(height: 12),
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 18, color: AppColors.navy)),
            const SizedBox(height: 6),
            Text(body,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.slate)),
            if (action != null) ...[
              const SizedBox(height: 12),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
