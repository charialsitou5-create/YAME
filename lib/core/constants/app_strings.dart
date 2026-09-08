/// Textes de l'application, en français.
class AppStrings {
  AppStrings._();

  static const appName = 'Yame';
  static const slogan = 'Votre trajet, autrement.';

  // Sélection de profil
  static const roleClient = 'Client';
  static const roleClientDescription =
      'Réservez vos courses en quelques secondes';
  static const roleDriverCar = 'Chauffeur Voiture';
  static const roleDriverCarDescription =
      'Rejoignez la communauté Yame et gagnez de l\'argent';
  static const roleDriverMoto = 'Chauffeur Moto';
  static const roleDriverMotoDescription =
      'Rejoignez la communauté Yame et gagnez de l\'argent';

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
  static const errorPasswordTooShort =
      'Le mot de passe doit contenir au moins 6 caractères.';
  static const errorEmailInUse =
      'Un compte existe déjà avec cette adresse e-mail.';
  static const errorUserNotFound =
      'Aucun compte ne correspond à cette adresse e-mail.';
  static const errorWrongPassword = 'Mot de passe incorrect.';
  static const errorNetwork = 'Problème de connexion, réessayez.';
  static const errorGeneric = 'Une erreur est survenue, réessayez.';

  // Accueil (chauffeur — la course/réservation n'est pas encore construite côté chauffeur)
  static const homeWelcome = 'Bienvenue';
  static const homeComingSoon =
      'Les courses à accepter arriveront bientôt ici.';
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
  static const homeServiceMotoBody =
      'Agile et rapide, idéal pour éviter les bouchons.';

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
  static const bookingDestinationHint =
      'Touchez la carte pour définir la destination';
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
  static const bookingSharePosition = 'Partager ma position';
  static const bookingSharePositionSheetTitle = 'Partager ma position avec un proche';
  static const bookingSharePositionWhatsapp = 'WhatsApp';
  static const bookingSharePositionSms = 'SMS';
  static const bookingSharePositionCopy = 'Copier le lien';
  static const bookingSharePositionCopied = 'Lien copié dans le presse-papiers.';
  static const bookingSharePositionMessage =
      'Voici ma position actuelle en course avec Yame :';
  static const bookingSharePositionError =
      'Impossible de récupérer votre position pour le moment.';
  static const bookingNewRequest = 'Nouvelle réservation';
  static const bookingCompletedTitle = 'Course terminée';
  static const bookingRateDriver = 'Noter le chauffeur';
  static const bookingPayRide = 'Payer la course';

  // Paiement de la course
  static const paymentTitle = 'Paiement';
  static const paymentAmountLabel = 'Montant de la course';
  static const paymentMethodCard = 'Carte bancaire';
  static const paymentMethodMobileMoney = 'Mobile Money';
  static const paymentSecurityNotice =
      'Pour que le chauffeur reçoive le paiement, veuillez saisir son identifiant Yame.';
  static const paymentDriverIdLabel = 'Identifiant Yame du chauffeur';
  static const paymentDriverIdHint = 'Ex : YAME12345';
  static const paymentDriverIdInfo =
      'Vous pouvez obtenir l\'identifiant auprès du chauffeur avant le paiement.';
  static const paymentErrorDriverIdRequired =
      'Veuillez saisir l\'identifiant du chauffeur.';
  static const paymentError = 'Paiement impossible, réessayez.';
  static const paymentSuccess = 'Paiement effectué avec succès !';
  static const bookingRequestError =
      'Impossible de lancer la recherche, réessayez.';

  // Commander pour quelqu'un d'autre
  static const orderForSomeoneCta = 'Commander pour quelqu\'un d\'autre';
  static const orderForSomeoneTitle = 'Commander pour quelqu\'un';
  static const orderForSomeoneSectionTitle = 'Les détails de la personne';
  static const orderForSomeoneInstructions = 'Instructions (optionnel)';
  static const orderForSomeoneInstructionsHint =
      'Point de repère, informations...';
  static const orderForSomeoneContactToggle =
      'Me contacter en tant que chauffeur pour cette course';
  static const orderForSomeoneConfirm = 'Confirmer';
  static const orderForSomeoneClear = 'Retirer';
  static const orderForSomeonePrefix = 'Pour ';

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
  static const driverRequestTaken =
      'Cette course vient d\'être prise par un autre chauffeur.';
  static const driverContactPassenger = 'Contacter le passager';
  static const driverBalanceRequired =
      'Rechargez votre compte pour passer en ligne et recevoir des courses.';
  static const driverBalanceRequiredCta = 'Recharger mon compte';
  static const driverPendingTitle = 'Inscription en cours de vérification';
  static const driverPendingBody =
      'Notre équipe vérifie vos informations et documents. Vous recevrez une notification dès que votre compte sera validé.';
  static const driverRejectedTitle = 'Inscription refusée';
  static const driverRejectedBody =
      'Votre inscription n\'a pas pu être validée. Contactez le support Yame pour en savoir plus.';

  // Contact passager (chauffeur)
  static const contactPassengerTitle = 'Contact passager';
  static const contactPassengerLabel = 'Passager';
  static const contactPassengerCall = 'Appeler';
  static const contactPassengerMessage = 'Message';
  static const contactPassengerNoticeRecipient =
      'Cette course a été commandée pour le passager. Vous pouvez le contacter pour plus d\'informations.';
  static const contactPassengerNoticeRequester =
      'Cette course a été commandée pour quelqu\'un d\'autre. Le client a demandé à être contacté à sa place.';
  static const contactPassengerInstructions = 'Instructions';
  static const contactPassengerCallError = 'Impossible de lancer l\'appel.';
  static const contactPassengerMessageError =
      'Impossible d\'ouvrir la messagerie.';
  static const contactPassengerNoPhone =
      'Aucun numéro de téléphone disponible.';

  // Notation du chauffeur (fin de course)
  static const ratingTitle = 'Noter le chauffeur';
  static const ratingQuestion = 'Comment était votre expérience ?';
  static const ratingCommentLabel = 'Ajouter un commentaire (optionnel)';
  static const ratingCommentHint = 'Écrivez votre commentaire ici...';
  static const ratingPunctuality = 'Ponctualité';
  static const ratingDriving = 'Conduite';
  static const ratingCourtesy = 'Courtoisie';
  static const ratingCleanliness = 'Propreté du véhicule';
  static const ratingSubmit = 'Soumettre la note';
  static const ratingSkip = 'Passer';
  static const ratingErrorRequired =
      'Merci de donner au moins une note globale.';
  static const ratingSubmitError =
      'Impossible d\'envoyer votre note, réessayez.';
  static const ratingThanks = 'Merci pour votre retour !';
  static const driverWallet = 'Portefeuille';

  // Inscription chauffeur — écran d'introduction
  static const driverIntroPrefix = 'Vous êtes';
  static const driverIntroSubtitle =
      'Complétez votre inscription pour commencer à gagner de l\'argent avec Yame.';
  static const driverIntroHowItWorks = 'Comment ça fonctionne ?';
  static const driverIntroStep1 =
      'Rechargez votre compte Yame au guichet, par mobile money ou virement bancaire.';
  static const driverIntroStep2 =
      'Recevez des courses et transportez en toute sécurité.';
  static const driverIntroStep3 =
      'À chaque course, 15 % de commission sont prélevés par Yame.';
  static const driverIntroStep4 =
      'Notification automatique quand votre solde ≤ 1 000 FCFA.';
  static const driverIntroCta = 'Suivant';

  // Inscription chauffeur — assistant véhicule (3 étapes)
  static const wizardStepVehicleInfo = 'Informations\ndu véhicule';
  static const wizardStepMotoInfo = 'Informations\nde la moto';
  static const wizardStepVehicleImages = 'Images\ndu véhicule';
  static const wizardStepMotoImages = 'Images\nde la moto';
  static const wizardStepDocuments = 'Documents';
  static const wizardVehicleInfoTitle = 'Informations du véhicule';
  static const wizardMotoInfoTitle = 'Informations de la moto';
  static const wizardVehicleInfoSubtitle =
      'Veuillez renseigner les informations de votre véhicule';
  static const wizardMotoInfoSubtitle =
      'Veuillez renseigner les informations de votre moto';
  static const wizardFieldModelCar = 'Modèle du véhicule';
  static const wizardFieldModelCarHint = 'Ex : Corolla, Tucson, Sportage...';
  static const wizardFieldModelMoto = 'Modèle de la moto';
  static const wizardFieldModelMotoHint = 'Ex : CB125, NMAX, PCX...';
  static const wizardFieldYear = 'Année de mise en circulation';
  static const wizardFieldYearHint = 'Ex : 2020';
  static const wizardFieldColor = 'Couleur du véhicule';
  static const wizardFieldColorHint = 'Ex : Noir, Blanc, Gris...';
  static const wizardFieldPlateCar = 'Numéro d\'immatriculation';
  static const wizardFieldPlateCarHint = 'Ex : AB-123-CD';
  static const wizardFieldPlateMotoHint = 'Ex : 12345-AB-67';
  static const wizardFieldSeats = 'Nombre de places';
  static const wizardFieldSeatsHint = 'Ex : 4, 5, 7...';
  static const wizardFieldSeatsMotoHint = 'Ex : 1, 2...';
  static const wizardNext = 'Suivant';
  static const wizardSubmit = 'Soumettre';
  static const wizardImagesVehicleTitle = 'Images du véhicule';
  static const wizardImagesMotoTitle = 'Images de la moto';
  static const wizardImagesVehicleSubtitle =
      'Veuillez ajouter des photos claires de votre véhicule';
  static const wizardImagesMotoSubtitle =
      'Veuillez ajouter des photos claires de votre moto';
  static const wizardPhotoFront = 'Face avant';
  static const wizardPhotoBack = 'Face arrière';
  static const wizardPhotoLeft = 'Côté gauche';
  static const wizardPhotoRight = 'Côté droit';
  static const wizardPhotoOverview = 'Vue d\'ensemble';
  static const wizardAddPhoto = 'Ajouter une photo';
  static const wizardDocumentsTitle = 'Documents';
  static const wizardDocumentsSubtitle =
      'Veuillez ajouter les documents suivants';
  static const wizardDocRegistrationCar = 'Carte grise';
  static const wizardDocRegistrationMoto = 'Carte grise (recto)';
  static const wizardDocLicense = 'Permis de conduire';
  static const wizardSubmitSuccess =
      'Inscription envoyée, en attente de validation.';
  static const wizardSubmitError =
      'Impossible d\'enregistrer votre véhicule, réessayez.';
  static const wizardErrorRequired = 'Ce champ est obligatoire.';
  static const wizardErrorYearInvalid = 'Année invalide.';
  static const wizardErrorPhotoMissing =
      'Veuillez ajouter au moins les photos principales.';
  static const wizardImagePickError = 'Impossible d\'ouvrir la galerie.';

  // Messages (client)
  static const messagesEmptyTitle = 'Aucune conversation';
  static const messagesEmptyBody =
      'Réservez une course pour discuter avec votre chauffeur.';
  static const messagesDriverSubtitle = 'Chauffeur Yame';
  static const messagesAssignedTitle = 'Chauffeur assigné';
  static const messagesAssignedBody = 'Votre chauffeur est en route.';
  static const messagesViewRideDetails = 'Détails de la course';
  static const messagesCall = 'Appeler';
  static const messagesTrack = 'Suivre';
  static const messagesComposerHint = 'Écrire un message...';
  static const messagesTakePhoto = 'Prendre une photo';
  static const messagesTakePhotoSubtitle = 'Montrer où vous êtes';
  static const messagesSendLocation = 'Envoyer ma position';
  static const messagesSendLocationSubtitle = 'Partager votre emplacement';
  static const messagesLocationLabel = 'Je suis ici';
  static const messagesLocationError =
      'Impossible de récupérer votre position.';
  static const messagesSendError = 'Message non envoyé, réessayez.';

  // Profil (client)
  static const profileMember = 'Membre Yame';
  static const profileActivities = 'Mes activités';
  static const profileStatCourses = 'Courses';
  static const profileStatReservations = 'Réservations';
  static const profileStatFavorites = 'Favoris';
  static const profileStatPayments = 'Paiements';
  static const profilePersonalInfo = 'Informations personnelles';
  static const profilePersonalInfoSubtitle = 'Gérez vos informations';
  static const profilePaymentMethods = 'Moyens de paiement';
  static const profilePaymentMethodsSubtitle = 'Carte ou mobile money';
  static const profileAddresses = 'Adresses enregistrées';
  static const profileAddressesSubtitle = 'Maison, travail, autres...';
  static const profileInviteFriend = 'Inviter un ami';
  static const profileInviteFriendSubtitle = 'Gagnez des bonus';
  static const profileSettings = 'Paramètres';
  static const profileSettingsSubtitle =
      'Notifications, langue, confidentialité';
  static const profileHelp = 'Aide & Support';
  static const profileHelpSubtitle = 'FAQ, contactez-nous';
  static const profileAbout = 'À propos de Yame';
  static const profileAboutVersion = 'Version 1.0.0';
  static const profilePremiumTitle = 'Yame Premium';
  static const profilePremiumBody =
      'Profitez d\'avantages exclusifs et d\'un service prioritaire.';
  static const profilePremiumCta = 'Découvrir';
  static const profileLogout = 'Se déconnecter';

  // Signaler un problème (client + chauffeur)
  static const reportTitle = 'Signaler un problème';
  static const reportKindIncident = 'Incident';
  static const reportKindFeedback = 'Avis / suggestion';
  static const reportCategoryLabel = 'Catégorie';
  static const reportCategorySecurity = 'Sécurité';
  static const reportCategoryPayment = 'Paiement';
  static const reportCategoryBehavior = 'Comportement';
  static const reportCategoryVehicle = 'Véhicule';
  static const reportCategoryOther = 'Autre';
  static const reportMessageLabel = 'Décrivez le problème';
  static const reportMessageHint = 'Expliquez ce qui s\'est passé...';
  static const reportErrorRequired = 'Merci de décrire le problème.';
  static const reportSubmit = 'Envoyer';
  static const reportSuccess = 'Merci, votre signalement a été envoyé.';
  static const reportError =
      'Impossible d\'envoyer votre signalement, réessayez.';

  // Recharge de compte (chauffeurs)
  static const rechargeTitle = 'Recharger mon compte';
  static const rechargeCurrentBalance = 'Solde actuel';
  static const rechargeChooseMethod = 'Choisissez un moyen de recharge';
  static const rechargeCash = 'Espèces (Guichet Yame)';
  static const rechargeMobileMoney = 'Mobile Money';
  static const rechargeBankTransfer = 'Virement bancaire';
  static const rechargeNotice =
      'Notification automatique quand votre solde ≤ 1 000 FCFA.';
}
