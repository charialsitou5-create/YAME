/// Configuration d'environnement de l'app.
class AppConfig {
  AppConfig._();

  // URL de production du panneau admin (yame-admin, déployé sur Vercel) — c'est
  // ce service qui expose /api/rides/dispatch, /api/rides/respond et
  // /api/recharge/initiate (contacte MTN/Airtel pour le compte du chauffeur).
  static const adminApiBaseUrl = 'https://yame-admin.vercel.app';
}
