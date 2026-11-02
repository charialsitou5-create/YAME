// Validations partagées (téléphone +242, plaques congolaises).
//
// Une seule règle pour tous les formulaires : la même que côté admin
/// (`yame-admin/lib/withdrawals.ts`, `normalizeCongoPhone`).

/// Numéro congolais : indicatif +242, puis 9 chiffres commençant par 04/05/06.
/// Accepte « 06 123 45 67 », « +242 06 123 45 67 », « 00242061234567 ».
/// Retourne le format canonique E.164 (`+242061234567`) ou `null` si invalide.
String? normalizeCongoPhone(String? raw) {
  if (raw == null) return null;
  var s = raw.replaceAll(RegExp(r'[\s.\-()]'), '');
  if (s.startsWith('+242')) {
    s = s.substring(4);
  } else if (s.startsWith('00242')) {
    s = s.substring(5);
  }
  if (!RegExp(r'^0[456]\d{7}$').hasMatch(s)) return null;
  return '+242$s';
}

/// Plaque : majuscules, sans espaces, tirets ni caractères invisibles.
String normalizePlate(String raw) =>
    raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

/// Plaque RC normale : 3 chiffres + 1 à 3 lettres + 1 à 2 chiffres
/// (ex. « 271 KX 4 »). Filtre de plausibilité PROVISOIRE : la vraie
/// vérification reste la carte grise, contrôlée par l'admin.
final _normalPlate = RegExp(r'^\d{3}[A-Z]{1,3}\d{1,2}$');

/// Plaque spéciale (temporaire, diplomatique, administrative) ou étrangère :
/// seule une forme alphanumérique raisonnable est exigée ici.
final _specialPlate = RegExp(r'^[A-Z0-9]{3,12}$');

bool isPlausiblePlate(String raw, {bool special = false}) {
  final p = normalizePlate(raw);
  return (special ? _specialPlate : _normalPlate).hasMatch(p);
}
