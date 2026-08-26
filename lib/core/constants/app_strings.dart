/// Textes de l'application, en français.
class AppStrings {
  AppStrings._();

  static const appName = 'Yame';
  static const slogan = 'Votre trajet, autrement.';

  // Sélection de profil
  static const roleClient = 'Client';
  static const roleClientDescription = 'Réservez vos courses en quelques secondes';
  static const roleDriverCar = 'Chauffeur Voiture';
  static const roleDriverCarDescription = 'Rejoignez la communauté Yame et gagnez de l\'argent';
  static const roleDriverMoto = 'Chauffeur Moto';
  static const roleDriverMotoDescription = 'Rejoignez la communauté Yame et gagnez de l\'argent';

  // Inscription
  static const signupHeadline = 'Créer votre compte';
  static const signupSubtitle = 'Inscrivez-vous pour commencer vos trajets.';
  static const signupSkip = 'Passer';
  static const fieldName = 'Nom complet';
  static const fieldPhone = 'Numéro de téléphone';
  static const fieldEmail = 'Adresse e-mail';
  static const fieldPassword = 'Mot de passe';
  static const signupCta = 'S\'inscrire';
  static const signupHasAccount = 'Déjà un compte ? Se connecter';
  static const orDivider = 'ou';
  static const continueWithGoogle = 'Continuer avec Google';
  static const continueWithFacebook = 'Continuer avec Facebook';
  static const socialAuthComingSoon = 'Bientôt disponible.';

  // Connexion
  static const loginHeadline = 'Content de vous revoir';
  static const loginSubtitle = 'Connectez-vous pour continuer.';
  static const loginCta = 'Se connecter';
  static const loginNoAccount = 'Pas encore de compte ? ';
  static const loginSignupLink = 'S\'inscrire';

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

  // Accueil (client)
  static const homeGreeting = 'Bonjour,';
  static const homeQuestion = 'Où allons-nous aujourd\'hui ?';
  static const homePromoTitle = 'Paiements faciles et sécurisés avec Yame';
  static const homePromoBody =
      'Payez vos courses par mobile money, virement bancaire ou en espèces en toute sécurité.';
  static const homeServiceTitle = 'Choisissez votre type de service';
  static const homeServiceCarTitle = 'Yame Voiture';
  static const homeServiceCarBody = 'Rapide, abordable et confortable.';
  static const homeServiceMotoTitle = 'Yame Moto';
  static const homeServiceMotoBody = 'Agile et rapide, idéal pour éviter les bouchons.';

  // Navigation
  static const navHome = 'Accueil';
  static const navRides = 'Courses';
  static const navMessages = 'Messages';
  static const navProfile = 'Profil';
  static const comingSoonTab = 'Cette section arrive bientôt.';

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
  static const bookingLocationDenied =
      'Autorisez l\'accès à la position pour centrer la carte sur vous.';
  static const bookingLocatingMe = 'Localisation en cours…';
  static const bookingSearching = 'Recherche d\'un chauffeur…';
  static const bookingCancel = 'Annuler';
  static const bookingCancelled = 'Course annulée.';
  static const bookingAccepted = 'Chauffeur trouvé';
  static const bookingDriverOnTheWay = 'arrive pour vous prendre en charge.';
  static const bookingNewRequest = 'Nouvelle réservation';
  static const bookingRequestError = 'Impossible de lancer la recherche, réessayez.';

  // Espace chauffeur
  static const driverOnline = 'En ligne';
  static const driverOffline = 'Hors ligne';
  static const driverGoOnline = 'Passez en ligne pour recevoir des courses.';
  static const driverNoRequests = 'Aucune demande de course pour l\'instant.';
  static const driverAccept = 'Accepter';
  static const driverAcceptedRide = 'Course en cours';
  static const driverClient = 'Client';
  static const driverPickup = 'Départ';
  static const driverDestination = 'Destination';
  static const driverComplete = 'Terminer la course';
  static const driverCancelRide = 'Annuler la course';
  static const driverRequestTaken = 'Cette course vient d\'être prise par un autre chauffeur.';
}
