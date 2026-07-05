import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:bitewise/core/router/app_router.dart';
import 'package:bitewise/core/theme/app_colors.dart';
import 'package:bitewise/features/snackswap/data/snackswap_service.dart';

/// Scan-tab: voer een barcode in (werkt overal) of scan met de camera (telefoon).
class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  final _controller = TextEditingController();
  bool _invalid = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search() {
    FocusScope.of(context).unfocus();
    final input = _controller.text.trim();
    if (!SnackSwapService.isValidBarcode(input)) {
      setState(() => _invalid = true);
      return;
    }
    setState(() => _invalid = false);
    context.push(Routes.product(input));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        title: const Text('Zoek of scan'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('Voer een barcode (EAN/UPC) in.',
                style: TextStyle(color: AppColors.slate, fontSize: 15)),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                hintText: 'bv. 3017620422003',
                prefixIcon: Icon(Icons.qr_code),
              ),
              onSubmitted: (_) => _search(),
            ),
            if (_invalid)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Een barcode bestaat uit 8 tot 14 cijfers.',
                    style: TextStyle(color: AppColors.danger)),
              ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _search,
              icon: const Icon(Icons.search),
              label: const Text('Zoek product'),
            ),
            const SizedBox(height: 24),
            if (!kIsWeb) ...[
              const Row(children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('of', style: TextStyle(color: AppColors.slate)),
                ),
                Expanded(child: Divider()),
              ]),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => context.push(Routes.camera),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan met camera'),
              ),
            ] else
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.mist),
                ),
                child: const Row(children: [
                  Icon(Icons.info_outline, color: AppColors.slate),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text('Camera-scan werkt in de telefoon-app.',
                        style: TextStyle(color: AppColors.slate)),
                  ),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}
