import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:bitewise/core/config/env.dart';

/// Beheert de Supabase-verbinding. Wanneer geen env geconfigureerd is,
/// draait de app lokaal en zijn remote calls uitgeschakeld.
class SupabaseService {
  SupabaseService._({SupabaseClient? client}) : _clientOverride = client {
    _initialized = client != null;
  }

  /// Alleen voor read-only integratietests die een expliciete testclient
  /// gebruiken. Productie blijft via [instance] en [init] lopen.
  factory SupabaseService.withClientForTesting(SupabaseClient client) =>
      SupabaseService._(client: client);

  static final SupabaseService instance = SupabaseService._();

  final SupabaseClient? _clientOverride;
  bool _initialized = false;
  bool get isAvailable => _initialized;

  Future<void> init() async {
    if (!Env.instance.hasSupabase) return;
    await Supabase.initialize(
      url: Env.instance.supabaseUrl,
      // De key uit env is een publishable/anon key (nooit service_role).
      publishableKey: Env.instance.supabaseAnonKey,
    );
    _initialized = true;
  }

  SupabaseClient get client {
    if (!_initialized) {
      throw StateError('Supabase is niet geconfigureerd (env ontbreekt).');
    }
    return _clientOverride ?? Supabase.instance.client;
  }
}

final supabaseServiceProvider = Provider<SupabaseService>(
  (ref) => SupabaseService.instance,
);
