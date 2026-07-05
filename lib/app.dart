import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bitewise/core/constants/app_constants.dart';
import 'package:bitewise/core/preferences/preferences_service.dart';
import 'package:bitewise/core/router/app_router.dart';
import 'package:bitewise/core/theme/app_theme.dart';
import 'package:bitewise/features/sync/application/sync_coordinator.dart';
import 'package:bitewise/features/sync/data/sync_service.dart';

class BitewiseApp extends ConsumerStatefulWidget {
  const BitewiseApp({super.key});

  @override
  ConsumerState<BitewiseApp> createState() => _BitewiseAppState();
}

class _BitewiseAppState extends ConsumerState<BitewiseApp> {
  @override
  void initState() {
    super.initState();
    // Pilot: eenmalig synchroniseren bij het opstarten. Zo krijgt een
    // terugkerende gebruiker z'n logs terug (pull) en worden lokale wijzigingen
    // geback-upt (push). No-op wanneer sync uit staat of er geen backend is.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final enabled = ref.read(syncEnabledProvider);
      final available = ref.read(syncServiceProvider).available;
      if (enabled && available) {
        ref.read(syncCoordinatorProvider).syncNow();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}
