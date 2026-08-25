# Yame

Application de VTC (véhicule de transport avec chauffeur — voiture et moto) pour la ville de Pointe-Noire, en République du Congo.

## Stack

- **Flutter** (Dart) — une seule base de code pour iOS et Android
- **Firebase** — authentification (e-mail/mot de passe), Firestore
- **Google Maps** — réservation de course avec sélection du départ/destination sur la carte

## Google Maps — clé API à configurer

La carte ne s'affichera pas (fond gris) tant qu'une vraie clé Maps n'est pas renseignée. Nécessite d'activer la facturation sur le projet Google Cloud (obligatoire même pour rester dans le quota gratuit) :

1. Activer la facturation sur `yame-pointe-noire-ab112` (console.cloud.google.com → Facturation).
2. Activer les API "Maps SDK for Android", "Maps SDK for iOS" et "Maps JavaScript API".
3. Créer une clé API (idéalement une par plateforme, restreinte à son usage) et remplacer les valeurs `YOUR_..._MAPS_API_KEY` dans :
   - `android/app/src/main/AndroidManifest.xml`
   - `ios/Runner/AppDelegate.swift`
   - `web/index.html`

## Démarrer

```bash
flutter pub get
flutter run
```

Contexte complet du projet (décisions, état d'avancement, prochaines étapes) : voir le fichier de suivi dans le dossier parent du dépôt.
