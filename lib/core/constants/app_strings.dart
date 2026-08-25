/// Textes de l'application, en français.
class AppStrings {
  AppStrings._();

  static const appName = 'Yame';
  static const slogan = 'Votre trajet, autrement.';

  // Onboarding
  static const onboardingCta = 'Commencer';

  // Sélection de profil
  static const roleSelectionTitle = 'Qui êtes-vous ?';
  static const roleSelectionSubtitle = 'Choisissez votre profil pour continuer.';
  static const roleClient = 'Client';
  static const roleClientDescription = 'Je réserve une course en voiture ou en moto.';
  static const roleDriverCar = 'Chauffeur — Voiture';
  static const roleDriverCarDescription = 'Je conduis une voiture et j\'accepte des courses.';
  static const roleDriverMoto = 'Chauffeur — Moto';
  static const roleDriverMotoDescription = 'Je conduis une moto et j\'accepte des courses.';

  // Inscription
  static const signupTitle = 'Créer un compte';
  static const fieldName = 'Nom complet';
  static const fieldPhone = 'Numéro de téléphone';
  static const fieldEmailOptional = 'Adresse e-mail (optionnel)';
  static const fieldPassword = 'Mot de passe';
  static const signupCta = 'S\'inscrire';
  static const signupHasAccount = 'Déjà un compte ? Se connecter';

  // Connexion
  static const loginTitle = 'Connexion';
  static const loginCta = 'Se connecter';
  static const loginNoAccount = 'Pas encore de compte ? S\'inscrire';

  // Validation
  static const errorRequired = 'Ce champ est obligatoire.';
  static const errorPhoneInvalid = 'Numéro de téléphone invalide.';
  static const errorEmailInvalid = 'Adresse e-mail invalide.';
  static const errorPasswordTooShort = 'Le mot de passe doit contenir au moins 6 caractères.';

  // Accueil
  static const homeWelcome = 'Bienvenue';
  static const homeComingSoon = 'La réservation de course arrive bientôt.';
  static const logout = 'Se déconnecter';
}
