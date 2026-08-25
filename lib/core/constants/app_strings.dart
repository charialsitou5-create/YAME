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
  static const fieldEmail = 'Adresse e-mail';
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
  static const errorEmailInUse = 'Un compte existe déjà avec cette adresse e-mail.';
  static const errorUserNotFound = 'Aucun compte ne correspond à cette adresse e-mail.';
  static const errorWrongPassword = 'Mot de passe incorrect.';
  static const errorNetwork = 'Problème de connexion, réessayez.';
  static const errorGeneric = 'Une erreur est survenue, réessayez.';

  // Accueil (chauffeur — la course/réservation n'est pas encore construite côté chauffeur)
  static const homeWelcome = 'Bienvenue';
  static const homeComingSoon = 'Les courses à accepter arriveront bientôt ici.';
  static const logout = 'Se déconnecter';

  // Réservation de course (client)
  static const bookingSetPickup = 'Définir le départ';
  static const bookingSetDestination = 'Définir la destination';
  static const bookingPickupLabel = 'Départ';
  static const bookingDestinationLabel = 'Destination';
  static const bookingPickupHint = 'Touchez la carte pour définir le départ';
  static const bookingDestinationHint = 'Touchez la carte pour définir la destination';
  static const bookingVehicleCar = 'Voiture';
  static const bookingVehicleMoto = 'Moto';
  static const bookingCta = 'Rechercher un chauffeur';
  static const bookingComingSoon = 'La mise en relation avec un chauffeur arrive bientôt.';
  static const bookingLocationDenied =
      'Autorisez l\'accès à la position pour centrer la carte sur vous.';
  static const bookingLocatingMe = 'Localisation en cours…';
}
