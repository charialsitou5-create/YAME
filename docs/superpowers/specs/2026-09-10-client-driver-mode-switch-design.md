# Switch client / chauffeur — design

## Contexte

Aujourd'hui, `users/{uid}.role` (`UserRole`: `client` | `chauffeurVoiture` |
`chauffeurMoto`) est fixé une fois pour toutes à l'inscription. `HomeScreen`
route sur ce champ pour afficher soit `ClientShell`, soit le flow chauffeur
(`DriverIntroScreen` → `VehicleRegistrationWizard` → `DriverStatusScreen` →
`DriverHomeScreen`). `role.vehicleType` sert aussi à porter le type de
véhicule (voiture/moto), et lève une exception si le rôle est `client`.

But : permettre à un compte d'avoir les deux capacités (client et chauffeur)
et de basculer entre les deux à volonté depuis `ProfilScreen`, sans perdre le
verrou existant "un chauffeur doit être approuvé par l'admin avant de
travailler".

## Décisions actées

- **Asymétrique** : chauffeur → client ne demande aucune validation
  supplémentaire (juste écrire le nouveau mode). Client → chauffeur reste
  inchangé : assistant véhicule (`VehicleRegistrationWizard`) + validation
  admin (`driver_profiles.status == 'approved'`).
- **Blocage côté client** : dès qu'une demande est `searching` (pas encore de
  chauffeur), pas seulement une fois `accepted`.
- **Blocage côté chauffeur** : dès qu'une course est `accepted` (même
  condition que `_activeRideId` déjà utilisé par le toggle "en ligne" dans
  `driver_home_screen.dart`) — avant l'acceptation, le chauffeur ne fait que
  parcourir les demandes, il n'est pas engagé.
- Pas de script de migration : seulement 2 comptes de test Firebase Auth
  existent à ce jour, ils seront recréés plutôt que migrés.

## Modèle de données (`users/{uid}`)

Remplace `role` (`UserRole`) par :

- `activeMode: 'client' | 'driver'` — mode actuellement affiché par
  `HomeScreen`. Écrit par le bouton de bascule dans `ProfilScreen`.
- `driverVehicleType: 'car' | 'moto' | null` — posé une fois par
  `VehicleRegistrationWizard` au moment de l'inscription chauffeur, ne
  change plus jamais après (même si l'utilisateur repasse en mode client).
  `null` tant que l'utilisateur n'a jamais démarré l'inscription chauffeur.
- `clientActiveRideId: string | null` — id de la `ride_requests` en cours
  côté client (statut `searching` ou `accepted`), sinon `null`.
- `driverActiveRideId: string | null` — id de la `ride_requests` en cours
  côté chauffeur (statut `accepted`), sinon `null`.

`UserRole` (enum) et `AppUser.role` sont supprimés — plus aucun code n'en a
besoin une fois `activeMode`/`driverVehicleType` en place.

La capacité "peut basculer en mode chauffeur" n'est jamais stockée
séparément : elle se déduit de `driverVehicleType != null` **et**
`driver_profiles/{uid}.status == 'approved'` (lu en live par `ProfilScreen`,
même requête que celle déjà utilisée par `HomeScreen`).

## Écran par écran

### `OnboardingScreen` / `SignupScreen`

Le choix "Client / Chauffeur voiture / Chauffeur moto" à l'écran d'accueil
reste tel quel dans l'esprit, mais ne pousse plus un `UserRole` en argument
de route — il pousse un `VehicleType?` (`null` = client). `SignupScreen` crée
le compte avec `activeMode: vehicleType == null ? AppMode.client :
AppMode.driver` et `driverVehicleType: vehicleType`, pour reproduire
exactement le comportement actuel (un choix "chauffeur" à l'inscription
atterrit directement dans `DriverIntroScreen`, pas dans `ClientShell`) tout
en posant déjà `driverVehicleType` sans attendre la fin de l'assistant.

### `HomeScreen`

Devient l'unique aiguilleur, sur `activeMode` (au lieu de `role`) :

- `activeMode == 'client'` → `ClientShell`.
- `activeMode == 'driver'` → même logique qu'aujourd'hui
  (`vehicleRegistered` puis `driver_profiles.status`), mais en passant
  `driverVehicleType` (un `VehicleType`, pas un `UserRole`) aux écrans en
  aval.

### `DriverIntroScreen`, `VehicleRegistrationWizard`, `DriverHomeScreen`

Ces trois widgets prenaient `required this.role` (`UserRole`) mais ne s'en
servaient que pour `.vehicleType` (et un cas de `.isDriver`). Ils prennent
désormais directement `required this.vehicleType` (`VehicleType`) — ils
n'ont plus besoin de savoir quoi que ce soit sur le mode client/chauffeur de
l'utilisateur, seulement sur son véhicule.

### `ProfilScreen`

Nouvelle zone "Chauffeur" :

- Si `driverVehicleType == null` (jamais inscrit) : bouton "Devenir
  chauffeur" → choix voiture/moto → lance
  `VehicleRegistrationWizard(vehicleType: ...)`, qui à la fin pose
  `driverVehicleType` sur `users/{uid}` (au lieu de `role`) et crée
  `driver_profiles/{uid}` comme aujourd'hui. `activeMode` ne change pas
  automatiquement — le compte reste client pendant la validation.
- Si `driverVehicleType != null` et `driver_profiles.status !=
  'approved'` : message d'attente/refus (réutilise `DriverStatusScreen`
  existant), pas de bouton de bascule.
- Si `driver_profiles.status == 'approved'` : bouton "Passer en mode
  chauffeur" / "Passer en mode client" selon `activeMode` actuel.
  - Désactivé (grisé + message "Terminez votre course en cours avant de
    changer de mode.") si le champ actif-ride correspondant au mode qu'on
    quitte n'est pas `null` (`clientActiveRideId` en quittant `client`,
    `driverActiveRideId` en quittant `driver`).
  - Sinon, écrit `activeMode` sur `users/{uid}` ; `HomeScreen` (déjà en
    écoute via `StreamBuilder` sur ce document) réagit automatiquement, pas
    de navigation explicite nécessaire.

## Maintien des champs actif-ride

Point important : `users/{userId}` n'est modifiable que par son propriétaire
(`request.auth.uid == userId`, règle existante inchangée). Un chauffeur qui
termine une course ne peut donc **jamais** écrire directement sur le
`users/{clientUid}` du client — chaque compte ne peut mettre à jour que son
propre champ actif-ride, jamais celui de l'autre partie. D'où deux
mécanismes différents selon qui est à l'origine du changement de statut :

**Écritures groupées (`WriteBatch` avec la mise à jour de `ride_requests`,
sur le compte qui agit) :**

1. Client crée une demande (`clientUid == uid`, statut `searching`) → batch
   set `users/{uid}.clientActiveRideId = requestId`.
2. Client annule sa demande encore `searching` (seul cas où le client peut
   changer le statut lui-même) → batch clear `users/{uid}.clientActiveRideId`.
3. Chauffeur accepte une demande `searching` (`driverUid == uid`, statut →
   `accepted`) → batch set `users/{uid}.driverActiveRideId = requestId`
   (ne touche pas `clientActiveRideId` : la course du client reste active,
   juste assignée).
4. Chauffeur termine/annule la course `accepted` dont il est responsable
   (seul cas où le chauffeur peut changer le statut vers `completed`/
   `cancelled`) → batch clear `users/{uid}.driverActiveRideId`.

**Écriture réactive côté client (pas de batch possible, écriture séparée) :**

Une fois une demande `accepted`, seul le chauffeur peut la faire passer à
`completed`/`cancelled` (règle existante) — le client n'a aucun write path
sur ce changement de statut, donc pas de batch possible côté client à ce
moment-là. Le client doit détecter la fin de course lui-même : `BookingScreen`
écoute déjà en direct le document `ride_requests` de sa course active (pour
l'affichage du statut/les messages) ; quand ce listener observe `status`
passer à `completed` ou `cancelled`, l'app du client fait une écriture
séparée sur son propre document pour clear `clientActiveRideId`. Léger
délai possible entre la fin réelle de la course et la levée du blocage côté
client (le temps que son propre listener réagisse) — négligeable, ce
listener est déjà actif pour d'autres besoins de l'écran.

**Piège existant à corriger au passage** : `_activeRequestId` (côté client,
`BookingScreen`) et `_activeRideId` (côté chauffeur, `DriverHomeScreen`) ne
sont aujourd'hui que de l'état local (`State`), jamais reconstruits — un
redémarrage de l'app pendant une course en cours perd cette référence, donc
plus aucun listener n'observe jamais la fin de cette course. Sans correction,
`clientActiveRideId`/`driverActiveRideId` resteraient bloqués indéfiniment
après un redémarrage en pleine course, cassant définitivement le bouton de
bascule pour ce compte. Les deux écrans doivent donc, à l'ouverture,
relire leur propre champ actif-ride sur `users/{uid}` et, s'il est renseigné,
réinitialiser `_activeRequestId`/`_activeRideId` avec cette valeur pour
rétablir l'écoute — ce n'est pas une fonctionnalité à part, c'est ce qui
rend le blocage fiable.

## Règles Firestore

`users/{userId}` reste modifiable librement par son propriétaire pour tous
les champs, **sauf** un changement de `activeMode` qui exige que le champ
actif-ride du mode qu'on quitte soit déjà `null` :

```
allow update: if request.auth != null && request.auth.uid == userId && (
  request.resource.data.get('activeMode', null) == resource.data.get('activeMode', null)
  || (resource.data.get('activeMode', null) == 'client'
      ? resource.data.get('clientActiveRideId', null) == null
      : resource.data.get('driverActiveRideId', null) == null)
);
```

Limite assumée : cette règle empêche les bascules accidentelles / bugs UI,
pas un client qui modifierait `clientActiveRideId`/`driverActiveRideId` à la
main via une requête Firestore brute pour contourner le verrou. Un
blindage complet demanderait une Cloud Function serveur, hors scope ici —
cohérent avec le reste de `firestore.rules`, qui fait déjà confiance à des
invariants basés sur `diff().affectedKeys()` plutôt que sur des Cloud
Functions.

Le reste de `ride_requests` (règles d'acceptation/fin/annulation) ne change
pas : un `WriteBatch` qui touche `ride_requests` et `users/{uid}` dans le
même envoi est toujours évalué document par document par les règles, donc
aucun des `affectedKeys().hasOnly([...])` existants n'a besoin d'être
élargi.

## Nettoyage

- Suppression de `lib/models/user_role.dart` et du champ `role` /
  `UserRole` dans `lib/models/app_user.dart`.
- Les 2 comptes de test Firebase Auth notés dans la mémoire du projet
  (`yame.test.*@example.com`, `yame.driver.*@example.com`) sont supprimés et
  recréés après le déploiement du nouveau schéma plutôt que migrés.

## Test

Suit le pattern déjà établi du projet : `flutter analyze` → déploiement des
règles Firestore → `flutter build apk --debug` → test en direct sur
l'émulateur Android (`Yame_Pixel`, skill `run-yame`) avec de vrais comptes
de test :
1. Un compte encore purement client, jamais inscrit comme chauffeur → pas
   de bouton de bascule visible, juste "Devenir chauffeur".
2. Ce même compte après inscription véhicule + approbation admin (panneau
   `yame-admin`) → le bouton de bascule apparaît, bascule fonctionne dans
   les deux sens.
3. Course en cours côté client (`searching`) → bascule bloquée avec
   message.
4. Course acceptée côté chauffeur → bascule bloquée avec message ; une fois
   la course terminée, la bascule redevient possible.
