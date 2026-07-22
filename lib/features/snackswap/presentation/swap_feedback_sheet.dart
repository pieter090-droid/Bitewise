import 'package:flutter/material.dart';

class SwapFeedbackInput {
  const SwapFeedbackInput({required this.reasons, this.note});
  final List<String> reasons;
  final String? note;
}

const swapFeedbackReasons = <String, String>{
  'not_comparable': 'Producten lijken niet genoeg op elkaar',
  'goal_mismatch': 'Past niet bij mijn gekozen doel',
  'dislike': 'Ik lust deze producten niet',
  'diet_mismatch': 'Past niet bij mijn eetwensen',
  'allergy_intolerance': 'Allergie of intolerantie',
  'unavailable': 'Niet verkrijgbaar of lastig te vinden',
  'too_expensive': 'Te duur',
  'product_data_wrong': 'Productinformatie klopt niet',
  'other': 'Andere reden',
};

Future<SwapFeedbackInput?> showSwapFeedbackSheet(
  BuildContext context, {
  required String title,
}) {
  return showModalBottomSheet<SwapFeedbackInput>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _FeedbackSheet(title: title),
  );
}

class _FeedbackSheet extends StatefulWidget {
  const _FeedbackSheet({required this.title});
  final String title;

  @override
  State<_FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<_FeedbackSheet> {
  final _selected = <String>{};
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              const Text('Je kunt meerdere redenen kiezen.'),
              const SizedBox(height: 14),
              for (final entry in swapFeedbackReasons.entries)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _selected.contains(entry.key),
                  title: Text(entry.value),
                  onChanged: (value) => setState(() {
                    if (value == true) {
                      _selected.add(entry.key);
                    } else {
                      _selected.remove(entry.key);
                    }
                  }),
                ),
              if (_selected.contains('product_data_wrong'))
                const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: Text(
                    'Beschrijf eventueel of de barcode, naam of voedingswaarden niet kloppen.',
                  ),
                ),
              TextField(
                controller: _note,
                maxLength: 300,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Toelichting (optioneel)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _selected.isEmpty
                      ? null
                      : () => Navigator.pop(
                            context,
                            SwapFeedbackInput(
                              reasons: _selected.toList()..sort(),
                              note: _note.text.trim().isEmpty
                                  ? null
                                  : _note.text.trim(),
                            ),
                          ),
                  child: const Text('Feedback versturen'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
