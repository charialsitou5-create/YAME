# Yame

Application de VTC (véhicule de transport avec chauffeur — voiture et moto) pour la ville de Pointe-Noire, en République du Congo.

Ce dépôt (`YAME`) contient l'**app Flutter** et les règles Firebase. Le back-office et l'API serveur (dispatch, paiement, commission, modération) sont dans un autre dépôt : `yame-admin/` du dépôt principal (voir `Yame.md` à sa racine pour le contexte complet).

## Stack

- **Flutter** (Dart) — une seule base de code (Android, iOS, web)
- **Firebase** — Auth, Firestore, Storage, Cloud Messaging (FCM), Crashlytics (actif en release)
- **OpenStreetMap** (`flutter_map` + `latlong2`) — cartographie gratuite, **aucune clé Google Maps requise**
- **yame-admin** (Next.js sur Vercel) — appelé en HTTPS avec le jeton Firebase de l'utilisateur pour tout ce qui est sensible (`/api/rides/dispatch`, `/respond`, `/pay`, `/commission`, `/api/recharge/initiate`)

## Architecture en bref

- `lib/features/` : écrans par domaine (auth, booking, driver, home, onboarding, support, wallet)
- `lib/services/` : accès Firebase et API (`dispatch_service`, `dispatch_response_service`, `payment_service`, `recharge_service`, suivi GPS, notifications, `error_reporter`…)
- `lib/models/`, `lib/core/` (tarifs, thème, widgets), `lib/routes/`
- Le client crée sa demande de course dans Firestore ; l'**attribution au chauffeur est faite côté serveur** (workflow de dispatch, offres push avec délai de réponse, rayon max 50 km). L'app ne s'attribue jamais une course elle-même.
- **Paiement et commission côté serveur** : le montant est recalculé par le serveur ; l'app ne l'envoie pas. Commission Yame par défaut 15 % (configurable côté admin).
- Solde, position GPS et documents du chauffeur sont dans des sous-collections privées (`wallet/`, `location/`, `documents/`) protégées par `firestore.rules`.
- Un client ou chauffeur suspendu/bloqué par la modération ne peut pas obtenir de course (contrôle serveur).

## Démarrer

```bash
flutter pub get
flutter run
```

Pré-requis : SDK Flutter (la CI utilise 3.47.1, canal stable), fichiers Firebase déjà présents (`lib/firebase_options.dart`, `android/app/google-services.json`).
L'URL de l'API admin utilisée par l'app est définie dans `AppConfig.adminApiBaseUrl`.

## Tests

```bash
flutter analyze --no-fatal-infos   # analyse statique (infos tolérées, comme en CI)
flutter test                       # tests unitaires et widgets

# Règles Firestore (30 tests, émulateur local, projet fictif demo-yame)
cd test-rules && npm install && npm test
```

Prérequis des tests de règles : Node 22 et Java 11+ ; l'émulateur Firestore est téléchargé au premier lancement via `firebase-tools`. Aucun vrai projet Firebase n'est touché.

## Intégration continue (`.github/workflows/`)

- `ci.yml` : `flutter pub get`, `flutter analyze --no-fatal-infos`, `flutter test` (sur chaque push hors `main`, chaque PR, et appelé par le workflow de distribution).
- `distribute-to-testers.yml` : à chaque push sur `main`, si la CI passe, construit l'APK **debug** et l'envoie aux testeurs via Firebase App Distribution. Secret GitHub requis : `FIREBASE_SERVICE_ACCOUNT` ; variable optionnelle `FIREBASE_TESTER_GROUPS`.
- `dependabot.yml` : mises à jour de dépendances.

## Déployer les règles

```bash
firebase deploy --only firestore:rules,firestore:indexes   # depuis ce dépôt, projet yame-pointe-noire-ab112
firebase deploy --only storage                             # storage.rules
```

Toujours lancer `test-rules` avant de déployer. Procédures complètes (admin, incidents, sauvegardes) : `docs/RUNBOOK.md` du dépôt principal.

## Structure des dépôts git

Ce dossier est un dépôt git **imbriqué** (`https://github.com/charialsitou5-create/YAME.git`, branche `main`), distinct du dépôt principal qui contient `Yame.md` et `yame-admin/`. Le dépôt principal ignore `YAME/` : committez toujours dans le bon dépôt.

## Limites connues

- Mobile Money réel non branché en production ; pas de retrait des gains chauffeur ni de remboursement.
- Pas encore de vérification d'e-mail à l'inscription ni de récupération de compte.
- Règles Firestore de modération (blocage de création de course côté règles) non appliquées : le blocage est effectif côté serveur uniquement.
- Plugin Gradle Crashlytics non ajouté (erreurs Dart remontées, pas de symboles natifs).
- APK de test construit en debug (pas de keystore de production).
- Multi-villes (`service_areas`) non branché dans l'app.
