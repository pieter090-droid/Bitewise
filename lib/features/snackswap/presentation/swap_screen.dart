import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:bitewise/core/router/app_router.dart';
import 'package:bitewise/core/preferences/preferences_service.dart';
import 'package:bitewise/core/theme/app_colors.dart';
import 'package:bitewise/features/snackswap/application/rule_based_swap_provider.dart';
import 'package:bitewise/features/snackswap/data/swap_feedback_repository.dart';
import 'package:bitewise/features/snackswap/data/swap_history_repository.dart';
import 'package:bitewise/features/snackswap/domain/swap_comparison.dart';
import 'package:bitewise/features/snackswap/domain/product_features.dart';
import 'package:bitewise/features/snackswap/domain/swap_score_result.dart';
import 'package:bitewise/features/sync/application/sync_coordinator.dart';
import 'package:bitewise/features/tracker/domain/meal_type.dart';
import 'package:bitewise/features/snackswap/presentation/swap_feedback_sheet.dart';

/// Nederlandse labels voor `snack_type` (zie `feature_vocabulary`), voor het
/// categoriefilter. Onbekende/nieuwe waarden vallen terug op de ruwe waarde.
const Map<String, String> _snackTypeLabels = {
  'zuivel_toetje': 'Zuivel (toetje)',
  'zuiveldrank': 'Zuiveldrank',
  'zoete_snack': 'Zoete snack',
  'chocolade': 'Chocolade',
  'hartige_snack': 'Hartige snack',
  'snoep': 'Snoep',
  'frisdrank': 'Frisdrank',
  'ontbijtgranen': 'Ontbijtgranen',
  'kaas': 'Kaas',
  'sap': 'Sap',
  'noten_zaden': 'Noten & zaden',
  'warme_drank': 'Warme drank',
  'fruit': 'Fruit',
  'reep': 'Reep',
  'ijs': 'IJs',
  'maaltijd_component': 'Maaltijd',
  'groente': 'Groente',
  'water': 'Water',
  'overig': 'Overig',
  'brood_bakkerij': 'Brood & bakkerij',
  'vleeswaren_beleg': 'Vleeswaren & beleg',
  'alcohol': 'Alcohol',
  'supplement': 'Supplement',
};

/// Toont de rule-based SwapScore-aanbevelingen (zie SwapScoreCalculator) als
/// dé aanbeveling. Het oude, craving-gebaseerde `recommend_swaps`-pad leverde
/// aantoonbaar onzinnige cross-categorie "swaps" (bv. snoep -> komkommer) --
/// zie het projectgeheugen voor de root cause -- en wordt hier niet meer
/// aangeroepen.
class SwapScreen extends ConsumerStatefulWidget {
  const SwapScreen({required this.barcode, super.key});

  final String barcode;

  @override
  ConsumerState<SwapScreen> createState() => _SwapScreenState();
}

class _SwapScreenState extends ConsumerState<SwapScreen> {
  SwapGoal? _selectedGoal;
  late bool _useDayContext;

  /// Leeg = nog geen categorie gekozen. Meerdere `snack_type`-waarden
  /// tegelijk aan te vinken (bv. Zuivel + Fruit samen doorzoeken).
  final Set<String> _snackTypeFilters = {};
  final Set<String> _loggingBarcodes = {};

  @override
  void initState() {
    super.initState();
    _useDayContext =
        ref.read(preferencesServiceProvider).snackSwapUseDayContext;
  }

  void _setUseDayContext(bool value) {
    setState(() => _useDayContext = value);
    ref.read(preferencesServiceProvider).setSnackSwapUseDayContext(value);
  }

  /// Logt een gekozen swap direct in het daglog met één consistente
  /// voedingsgrondslag: betrouwbare portiedata, anders exact 100 gram.
  Future<void> _logSwap(
    SwapScoreResult result,
    SwapCandidate source,
    SwapGoal goal,
  ) async {
    final item = result.candidate;
    if (_loggingBarcodes.contains(item.barcode)) return;
    setState(() => _loggingBarcodes.add(item.barcode));
    final meal = MealType.suggestForNow();
    try {
      await ref.read(swapHistoryRepositoryProvider).useSwap(
            source: source,
            result: result,
            goal: goal,
            meal: meal,
          );
      ref.read(syncCoordinatorProvider).onLogsChanged();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${item.name} gebruikt als swap')),
      );
    } finally {
      if (mounted) setState(() => _loggingBarcodes.remove(item.barcode));
    }
  }

  Future<void> _feedback({
    required String sourceBarcode,
    required SwapGoal goal,
    SwapScoreResult? result,
    required bool noGoodSwap,
  }) async {
    final input = await showSwapFeedbackSheet(
      context,
      title: noGoodSwap
          ? 'Waarom zit er geen goede swap bij?'
          : 'Wat is er niet goed aan deze swap?',
    );
    if (input == null) return;
    await ref.read(swapFeedbackRepositoryProvider).save(
          fromBarcode: sourceBarcode,
          toBarcode: result?.candidate.barcode,
          goal: goal,
          reasons: input.reasons,
          note: input.note,
          noGoodSwap: noGoodSwap,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bedankt, je feedback is opgeslagen.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final goal = _selectedGoal;
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        title: const Text('Betere swaps'),
        actions: [
          IconButton(
            tooltip: 'Mijn swapresultaten',
            onPressed: () => context.push(Routes.swapResults),
            icon: const Icon(Icons.insights_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: goal == null
            ? _GoalChooser(
                useDayContext: _useDayContext,
                onUseDayContextChanged: _setUseDayContext,
                onSelected: (value) => setState(() => _selectedGoal = value))
            : ref
                .watch(ruleBasedSwapProvider((
                  barcode: widget.barcode,
                  goal: goal,
                  useDayContext: _useDayContext,
                )))
                .when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, __) => _Info(
                    icon: Icons.cloud_off,
                    title: 'Er ging iets mis',
                    body: 'De aanbevelingen konden niet geladen worden.',
                    action: TextButton.icon(
                      onPressed: () => ref.invalidate(
                        ruleBasedSwapProvider((
                          barcode: widget.barcode,
                          goal: goal,
                          useDayContext: _useDayContext,
                        )),
                      ),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Opnieuw proberen'),
                    ),
                  ),
                  data: (result) => switch (result) {
                    RuleBasedSwapNotFound() => _Info(
                        icon: Icons.inbox_outlined,
                        title: 'Nog geen veilige swap',
                        body: 'We tonen alleen alternatieven die betrouwbaar '
                            'vergelijkbaar zijn en bij je gekozen doel passen. '
                            'Voor dit product is die veilige match er nu niet.',
                        action: TextButton.icon(
                          onPressed: () => _feedback(
                            sourceBarcode: widget.barcode,
                            goal: goal,
                            noGoodSwap: true,
                          ),
                          icon: const Icon(Icons.feedback_outlined),
                          label: const Text('Vertel ons waarom'),
                        ),
                      ),
                    RuleBasedSwapError() => const _Info(
                        icon: Icons.cloud_off,
                        title: 'Er ging iets mis',
                        body: 'De aanbevelingen konden niet geladen worden.',
                      ),
                    RuleBasedSwapFound(
                      :final groups,
                      :final allRanked,
                      :final source,
                      :final configs
                    ) =>
                      _buildFound(groups, allRanked, source, configs),
                  },
                ),
      ),
    );
  }

  Widget _buildFound(
    List<SwapRecommendationGroup> groups,
    List<SwapScoreResult> allRanked,
    SwapCandidate source,
    List<Map<String, dynamic>> configs,
  ) {
    // Beschikbare filter-opties: alleen snack_types die daadwerkelijk
    // voorkomen onder de kandidaten (geen lege keuzes tonen).
    final availableTypes = <String>{};
    for (final r in allRanked) {
      final t = r.candidate.features.snackType;
      if (t != null && t.isNotEmpty) availableTypes.add(t);
    }
    final sortedTypes = availableTypes.toList()
      ..sort((a, b) =>
          (_snackTypeLabels[a] ?? a).compareTo(_snackTypeLabels[b] ?? b));

    // De vaste groepen (Minder kcal, Meer eiwit, Minder suiker, Overall,
    // Andere opties) blijven ALTIJD zichtbaar. De categorie-chips zijn een
    // los, extra zoekmenu eronder -- geen vervanging -- waarmee je zelf nog
    // een alternatief kunt opzoeken, eventueel over meerdere categorieën
    // tegelijk (bv. Zuivel + Fruit). Zelfde 4-subgroepen-logica, herberekend
    // op alleen de gekozen categorieën, met een ruimere limiet (10 i.p.v. 5).
    final extraGroups = _snackTypeFilters.isEmpty
        ? const <SwapRecommendationGroup>[]
        : buildRecommendationGroups(
            configs: configs,
            source: source,
            ranked: allRanked
                .where((r) =>
                    _snackTypeFilters.contains(r.candidate.features.snackType))
                .toList(),
            perGroupLimit: 10,
          );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _selectedGoal = null),
            icon: const Icon(Icons.tune),
            label: const Text('Ander doel kiezen'),
          ),
        ),
        _DayContextToggle(
          value: _useDayContext,
          onChanged: _setUseDayContext,
        ),
        const SizedBox(height: 12),
        for (final group in groups)
          _GroupSection(
            group: group,
            source: source,
            goal: _selectedGoal!,
            loggingBarcodes: _loggingBarcodes,
            onLog: (result) => _logSwap(result, source, _selectedGoal!),
            onFeedback: (result) => _feedback(
              sourceBarcode: source.barcode,
              goal: _selectedGoal!,
              result: result,
              noGoodSwap: false,
            ),
          ),
        if (sortedTypes.length > 1) ...[
          const Divider(height: 24),
          const Text('Extra alternatief zoeken',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: AppColors.navy)),
          const SizedBox(height: 4),
          const Text('Vink één of meer categorieën aan.',
              style: TextStyle(color: AppColors.slate, fontSize: 12)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in sortedTypes)
                FilterChip(
                  label: Text(_snackTypeLabels[t] ?? t),
                  selected: _snackTypeFilters.contains(t),
                  onSelected: (selected) => setState(() {
                    if (selected) {
                      _snackTypeFilters.add(t);
                    } else {
                      _snackTypeFilters.remove(t);
                    }
                  }),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (extraGroups.isEmpty && _snackTypeFilters.isNotEmpty)
            const Text('Niks gevonden in deze categorie(ën).',
                style: TextStyle(color: AppColors.slate)),
          for (final group in extraGroups)
            _GroupSection(
              group: group,
              source: source,
              goal: _selectedGoal!,
              loggingBarcodes: _loggingBarcodes,
              onLog: (result) => _logSwap(result, source, _selectedGoal!),
              onFeedback: (result) => _feedback(
                sourceBarcode: source.barcode,
                goal: _selectedGoal!,
                result: result,
                noGoodSwap: false,
              ),
            ),
        ],
        const Divider(height: 28),
        OutlinedButton.icon(
          onPressed: () => _feedback(
            sourceBarcode: source.barcode,
            goal: _selectedGoal!,
            noGoodSwap: true,
          ),
          icon: const Icon(Icons.feedback_outlined),
          label: const Text('Geen goede swap gevonden'),
        ),
      ],
    );
  }
}

class _GoalChooser extends StatelessWidget {
  const _GoalChooser({
    required this.onSelected,
    required this.useDayContext,
    required this.onUseDayContextChanged,
  });
  final ValueChanged<SwapGoal> onSelected;
  final bool useDayContext;
  final ValueChanged<bool> onUseDayContextChanged;

  @override
  Widget build(BuildContext context) {
    const icons = {
      SwapGoal.meerEiwit: Icons.fitness_center,
      SwapGoal.minderKcal: Icons.local_fire_department_outlined,
      SwapGoal.minderSuiker: Icons.cake_outlined,
      SwapGoal.besteOverall: Icons.auto_awesome,
    };
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('Wat voor swap zoek je?',
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.navy)),
        const SizedBox(height: 8),
        const Text('Kies wat je met deze swap wilt verbeteren.',
            style: TextStyle(color: AppColors.slate)),
        const SizedBox(height: 24),
        _DayContextToggle(
          value: useDayContext,
          onChanged: onUseDayContextChanged,
        ),
        const SizedBox(height: 20),
        for (final goal in SwapGoal.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: FilledButton.icon(
              onPressed: () => onSelected(goal),
              icon: Icon(icons[goal]),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 15),
                child: Text(goal.label),
              ),
            ),
          ),
      ],
    );
  }
}

class _DayContextToggle extends StatelessWidget {
  const _DayContextToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.mist),
      ),
      child: SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        value: value,
        onChanged: onChanged,
        title: const Text(
          'Vandaag meewegen',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: AppColors.navy,
          ),
        ),
        subtitle: const Text(
          'We kijken naar wat je vandaag al binnen hebt, zoals kcal, suiker en eiwit.',
          style: TextStyle(color: AppColors.slate, fontSize: 12),
        ),
      ),
    );
  }
}

class _GroupSection extends StatelessWidget {
  const _GroupSection({
    required this.group,
    required this.source,
    required this.goal,
    required this.loggingBarcodes,
    required this.onLog,
    required this.onFeedback,
  });
  final SwapRecommendationGroup group;
  final SwapCandidate source;
  final SwapGoal goal;
  final Set<String> loggingBarcodes;
  final void Function(SwapScoreResult result) onLog;
  final void Function(SwapScoreResult result) onFeedback;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(group.label,
              style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: AppColors.navy)),
          const SizedBox(height: 10),
          for (final result in group.results)
            _SwapCard(
              source: source,
              result: result,
              goal: goal,
              logging: loggingBarcodes.contains(result.candidate.barcode),
              onLog: () => onLog(result),
              onFeedback: () => onFeedback(result),
            ),
        ],
      ),
    );
  }
}

class _SwapCard extends StatelessWidget {
  const _SwapCard({
    required this.source,
    required this.result,
    required this.goal,
    required this.logging,
    required this.onLog,
    required this.onFeedback,
  });

  final SwapCandidate source;
  final SwapScoreResult result;
  final SwapGoal goal;
  final bool logging;
  final VoidCallback onLog;
  final VoidCallback onFeedback;

  @override
  Widget build(BuildContext context) {
    final item = result.candidate;
    final comparison = SwapComparison.forResult(source: source, result: result);
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
                          style: const TextStyle(
                              color: AppColors.slate, fontSize: 13)),
                  ],
                ),
              ),
              _ScoreBadge(score: result.score),
            ],
          ),
          if (result.reasons.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(result.userReason ?? result.reasons.join(' · '),
                style: const TextStyle(color: AppColors.ink, height: 1.35)),
          ],
          const SizedBox(height: 12),
          _ComparisonTable(
            source: source,
            candidate: item,
            comparison: comparison,
            goal: goal,
          ),
          if (_hasNutrition) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (result.usesServingData && item.kcalServing != null)
                  _pill('${_fmt(item.kcalServing!)} kcal /portie'),
                if (result.usesServingData && item.sugarServing != null)
                  _pill('${_fmt(item.sugarServing!)}g suiker /portie'),
                if (result.usesServingData && item.proteinServing != null)
                  _pill('${_fmt(item.proteinServing!)}g eiwit /portie'),
                if (!result.usesServingData && item.kcal100 != null)
                  _pill('${_fmt(item.kcal100!)} kcal /100g'),
                if (!result.usesServingData && item.sugar100 != null)
                  _pill('${_fmt(item.sugar100!)}g suiker /100g'),
                if (!result.usesServingData && item.protein100 != null)
                  _pill('${_fmt(item.protein100!)}g eiwit /100g'),
              ],
            ),
          ],
          if (result.warnings.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final w in result.warnings)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline,
                      size: 14, color: AppColors.slate),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(w,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.slate)),
                  ),
                ],
              ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onFeedback,
              icon: const Icon(Icons.feedback_outlined, size: 18),
              label: const Text('Feedback'),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: logging ? null : onLog,
              icon: logging
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check, size: 18),
              label: const Text('Gebruik deze swap'),
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
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.navy)),
      );

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}

class _ComparisonTable extends StatelessWidget {
  const _ComparisonTable({
    required this.source,
    required this.candidate,
    required this.comparison,
    required this.goal,
  });

  final SwapCandidate source;
  final SwapCandidate candidate;
  final SwapComparison comparison;
  final SwapGoal goal;

  @override
  Widget build(BuildContext context) {
    final basis = comparison.usesServingData ? 'per portie' : 'per 100 g';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.mist),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Vergelijking $basis',
              style: const TextStyle(
                  fontWeight: FontWeight.w800, color: AppColors.navy)),
          const SizedBox(height: 8),
          Row(children: [
            const SizedBox(width: 76),
            Expanded(child: _name(source.name, 'Huidig')),
            const SizedBox(width: 8),
            Expanded(child: _name(candidate.name, 'Swap')),
            const SizedBox(width: 58),
          ]),
          const Divider(),
          _row('kcal', comparison.source.kcal, comparison.candidate.kcal,
              comparison.kcalSaved,
              highlight: goal == SwapGoal.minderKcal),
          _row('Suiker', comparison.source.sugar, comparison.candidate.sugar,
              comparison.sugarSaved,
              unit: ' g', highlight: goal == SwapGoal.minderSuiker),
          _row('Eiwit', comparison.source.protein, comparison.candidate.protein,
              comparison.proteinGained,
              unit: ' g', gain: true, highlight: goal == SwapGoal.meerEiwit),
          _row('Vet', comparison.source.fat, comparison.candidate.fat,
              comparison.fatSaved,
              unit: ' g'),
          _row('Zout', comparison.source.salt, comparison.candidate.salt,
              comparison.saltSaved,
              unit: ' g'),
          if (!comparison.usesServingData)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Portiedata is niet voor beide producten compleet; daarom vergelijken we eerlijk per 100 g.',
                style: TextStyle(fontSize: 10, color: AppColors.slate),
              ),
            ),
        ],
      ),
    );
  }

  Widget _name(String value, String label) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 10, color: AppColors.slate)),
          Text(value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      );

  Widget _row(
    String label,
    double? before,
    double? after,
    double? difference, {
    String unit = '',
    bool gain = false,
    bool highlight = false,
  }) {
    final positive = difference != null && difference > 0;
    final diffLabel = difference == null
        ? '—'
        : difference == 0
            ? '0$unit'
            : gain
                ? '${difference > 0 ? '+' : '−'}${_fmt(difference.abs())}$unit'
                : '${difference > 0 ? '−' : '+'}${_fmt(difference.abs())}$unit';
    return Container(
      color: highlight ? AppColors.gold.withValues(alpha: 0.12) : null,
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        SizedBox(
          width: 76,
          child: Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: highlight ? FontWeight.w800 : FontWeight.w600)),
        ),
        Expanded(child: Text(_value(before, unit))),
        const SizedBox(width: 8),
        Expanded(child: Text(_value(after, unit))),
        SizedBox(
          width: 58,
          child: Text(
            diffLabel,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: positive ? Colors.green.shade700 : AppColors.slate,
            ),
          ),
        ),
      ]),
    );
  }

  String _value(double? value, String unit) =>
      value == null ? 'Onbekend' : '${_fmt(value)}$unit';
  String _fmt(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
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
      child: Text('Match ${score.round()}',
          style: const TextStyle(
              color: AppColors.navy,
              fontWeight: FontWeight.w800,
              fontSize: 12)),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info(
      {required this.icon,
      required this.title,
      required this.body,
      this.action});
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
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: AppColors.navy)),
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
