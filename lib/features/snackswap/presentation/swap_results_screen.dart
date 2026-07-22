import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bitewise/core/database/app_database.dart';
import 'package:bitewise/core/theme/app_colors.dart';
import 'package:bitewise/features/snackswap/data/swap_history_repository.dart';
import 'package:bitewise/features/snackswap/domain/swap_savings_summary.dart';
import 'package:bitewise/features/snackswap/domain/swap_score_result.dart';

enum _Period { today, sevenDays, thirtyDays, all }

final _eventsProvider = StreamProvider.family<List<SwapEventRow>, _Period>(
  (ref, period) {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day);
    final start = switch (period) {
      _Period.today => end,
      _Period.sevenDays => end.subtract(const Duration(days: 6)),
      _Period.thirtyDays => end.subtract(const Duration(days: 29)),
      _Period.all => DateTime(2000),
    };
    return ref.watch(swapHistoryRepositoryProvider).watchBetween(start, end);
  },
);

class SwapResultsScreen extends ConsumerStatefulWidget {
  const SwapResultsScreen({super.key});
  @override
  ConsumerState<SwapResultsScreen> createState() => _SwapResultsScreenState();
}

class _SwapResultsScreenState extends ConsumerState<SwapResultsScreen> {
  _Period _period = _Period.sevenDays;

  @override
  Widget build(BuildContext context) {
    final events = ref.watch(_eventsProvider(_period));
    return Scaffold(
      appBar: AppBar(title: const Text('Mijn swapresultaten')),
      backgroundColor: AppColors.cream,
      body: events.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Kon resultaten niet laden: $e')),
        data: (rows) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            SegmentedButton<_Period>(
              segments: const [
                ButtonSegment(value: _Period.today, label: Text('Vandaag')),
                ButtonSegment(value: _Period.sevenDays, label: Text('7 d')),
                ButtonSegment(value: _Period.thirtyDays, label: Text('30 d')),
                ButtonSegment(value: _Period.all, label: Text('Alles')),
              ],
              selected: {_period},
              onSelectionChanged: (value) =>
                  setState(() => _period = value.first),
            ),
            const SizedBox(height: 16),
            if (rows.isEmpty)
              const _Empty()
            else ...[
              _Totals(summary: SwapSavingsSummary.fromEvents(rows)),
              const SizedBox(height: 16),
              const _Heading('Per doel'),
              for (final goal in SwapGoal.values)
                if (rows.any((r) => r.goal == goal.value))
                  _GoalSummary(
                    goal: goal,
                    summary: SwapSavingsSummary.fromEvents(
                        rows.where((r) => r.goal == goal.value)),
                  ),
              const SizedBox(height: 16),
              const _Heading('Uitgevoerde swaps'),
              for (final row in rows) _EventCard(row: row),
            ],
          ],
        ),
      ),
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.summary});
  final SwapSavingsSummary summary;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${summary.count} uitgevoerde swaps',
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 14),
            Row(children: [
              _Metric('${summary.kcalSaved.round()}', 'kcal bespaard'),
              _Metric(_fmt(summary.sugarSaved), 'g suiker minder'),
              _Metric(_fmt(summary.proteinGained), 'g eiwit extra'),
            ]),
          ]),
        ),
      );
}

class _GoalSummary extends StatelessWidget {
  const _GoalSummary({required this.goal, required this.summary});
  final SwapGoal goal;
  final SwapSavingsSummary summary;
  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          title: Text('${goal.label} · ${summary.count}×'),
          subtitle: Text('${summary.kcalSaved.round()} kcal minder · '
              '${_fmt(summary.sugarSaved)} g suiker minder · '
              '${_fmt(summary.proteinGained)} g eiwit extra'),
        ),
      );
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.row});
  final SwapEventRow row;
  @override
  Widget build(BuildContext context) {
    final kcal = _diff(row.fromKcal, row.toKcal);
    final sugar = _diff(row.fromSugar, row.toSugar);
    final protein = _diff(row.toProtein, row.fromProtein);
    return Card(
      child: ListTile(
        title: Text('${row.fromName} → ${row.toName}'),
        subtitle: Text(
          '${_date(row.eventDate)} · ${row.basis == 'serving' ? 'per portie' : 'per 100 g'}\n'
          '${kcal == null ? 'kcal onbekend' : '${kcal.round()} kcal minder'} · '
          '${sugar == null ? 'suiker onbekend' : '${_fmt(sugar)} g suiker minder'} · '
          '${protein == null ? 'eiwit onbekend' : '${_fmt(protein)} g eiwit extra'}',
        ),
        isThreeLine: true,
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.value, this.label);
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value,
              style:
                  const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          Text(label,
              style: const TextStyle(fontSize: 11, color: AppColors.slate)),
        ]),
      );
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.navy)),
      );
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) => const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(children: [
            Icon(Icons.swap_horiz, size: 42, color: AppColors.slate),
            SizedBox(height: 10),
            Text('Nog geen swaps in deze periode',
                style: TextStyle(fontWeight: FontWeight.w700)),
            SizedBox(height: 4),
            Text('Kies bij een suggestie “Gebruik deze swap”.'),
          ]),
        ),
      );
}

double? _diff(double? a, double? b) =>
    a == null || b == null ? null : (a - b).clamp(0, double.infinity);
String _fmt(double value) => value.toStringAsFixed(value < 10 ? 1 : 0);
String _date(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
