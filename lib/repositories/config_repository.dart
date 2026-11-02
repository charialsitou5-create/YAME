import 'package:flutter/foundation.dart';

import 'doc.dart';

/// Accès à la configuration `app_config` (clé → valeur jsonb).
class ConfigRepository {
  ConfigRepository._();

  @protected
  ConfigRepository.forTesting();

  @visibleForTesting
  static ConfigRepository? debugOverride;

  factory ConfigRepository() => debugOverride ?? ConfigRepository._();

  Future<Doc> _get(String key) async {
    final row = await supabase.from('app_config').select('value').eq('key', key).maybeSingle();
    final value = row?['value'];
    return Doc(key, value is Map ? Json.from(value) : null);
  }

  Future<Doc> getPricing() => _get('pricing');

  /// Réglage d'exigence de l'e-mail vérifié (`app_config/auth`).
  Future<Doc> getAuthPolicy() => _get('auth');
}
