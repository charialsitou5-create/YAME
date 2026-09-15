/// Configuration d'environnement de l'app.
class AppConfig {
  AppConfig._();

  // TODO(yame): remplacer par l'URL de production du panneau admin une fois
  // déployé (ex: https://admin.yame.cg) — c'est ce service (yame-admin) qui
  // expose /api/recharge/initiate et contacte MTN/Airtel pour le compte du
  // chauffeur.
  static const adminApiBaseUrl = 'https://YOUR_YAME_ADMIN_DOMAIN';
}
