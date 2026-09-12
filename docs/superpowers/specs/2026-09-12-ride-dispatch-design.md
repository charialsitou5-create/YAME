# Système de dispatch automatique des courses — Yame

**Date** : 2026-09-12
**Statut** : validé en brainstorming, prêt pour le plan d'implémentation

## Problème

Aujourd'hui (`lib/features/driver/driver_home_screen.dart`), toute demande de
course (`ride_requests` avec `status == 'searching'`) est visible et
acceptable par **tous** les chauffeurs connectés du bon type de véhicule.
Le premier qui tape "Accepter" gagne la course via une transaction Firestore
optimiste (`_accept`). Conséquences :

- Aucun filtrage par proximité, ETA, solde ou disponibilité réelle.
- Ne passe pas à l'échelle : avec des centaines de chauffeurs, tout le monde
  reçoit une notification pour chaque course.
- Aucune équité entre chauffeurs (les mieux placés/les plus rapides à taper
  raflent tout).

## Objectif

Remplacer la diffusion générale par un dispatch serveur qui **propose la
course à un chauffeur à la fois**, classé par proximité/ETA estimé, avec un
délai de réponse avant de passer au suivant. Le serveur devient seul
décideur de qui reçoit quelle offre et seul à écrire les champs
d'attribution — le chauffeur ne fait plus que répondre à une offre qui lui
est explicitement adressée.

## Hors scope (v1)

- Offres simultanées à plusieurs chauffeurs (groupe de 2-3) — évoqué comme
  amélioration future, pas nécessaire pour corriger le problème actuel.
- Vrai calcul d'itinéraire (routing OSRM ou équivalent) — v1 utilise une
  estimation par distance à vol d'oiseau, cohérent avec le choix déjà fait
  pour la carte (OpenStreetMap, zéro dépendance payante).
- Score d'équité pondéré (chauffeur qui vient de faire beaucoup de courses
  vs chauffeur qui attend depuis longtemps) — évoqué dans la discussion
  d'origine comme amélioration, pas nécessaire pour la v1 qui se contente du
  classement par ETA.
- Modification du reste du cycle de vie de la course (terminer, annuler,
  noter, payer) — inchangé, hors sujet ici.

## Contraintes vérifiées

- Le projet Firebase est sur le plan **Spark** (gratuit) → Cloud Functions
  indisponibles. Le dispatch vit donc dans **yame-admin** (Next.js/Vercel),
  qui a déjà l'Admin SDK Firebase et tourne sans coût Firebase additionnel.
- `users/{uid}.driverOnline` (bool) est déjà persisté côté serveur
  (corrigé le 2026-09-12, voir mémoire `yame-driver-online-persistence-fix`)
  — pas de heartbeat à construire depuis zéro, seulement à combiner avec la
  fraîcheur de la position GPS pour fiabiliser le signal.
- `driver_profiles/{uid}/location/current.updatedAt` n'est mis à jour que
  tous les 10m de déplacement (`distanceFilter: 10` dans
  `DriverTrackingService`) — un chauffeur à l'arrêt peut avoir une position
  "vieille" sans être hors ligne. Fenêtre de fraîcheur généreuse retenue :
  **3 minutes**.
- Seuil de solde minimum pour recevoir une course : `balance > 0` — c'est
  exactement le seuil déjà utilisé par `driver_home_screen.dart` pour
  autoriser le passage en ligne (`hasBalance = balance > 0`), donc source de
  vérité unique.

## Architecture

```
Client (Flutter)                yame-admin (Vercel)              Chauffeur (Flutter)
     │                                  │                                │
     │ 1. crée ride_requests/{id}       │                                │
     │    (Firestore, comme aujourd'hui)│                                │
     │                                  │                                │
     │ 2. POST /api/rides/dispatch      │                                │
     │    { rideId }          ────────► │                                │
     │                                  │ 3. start(dispatchWorkflow)     │
     │                                  │    (Vercel Workflow, durable)  │
     │                                  │                                │
     │                                  │ 4. lit driver_profiles + users │
     │                                  │    + wallet + location (Admin  │
     │                                  │    SDK, contourne les règles)  │
     │                                  │ 5. filtre + classe par ETA      │
     │                                  │    approché (distance/vitesse)  │
     │                                  │                                │
     │                                  │ 6. pour chaque candidat :       │
     │                                  │    - transaction : réserve le   │
     │                                  │      chauffeur (currentOfferRideId)
     │                                  │    - écrit offeredUid+expiresAt │
     │                                  │      sur ride_requests/{id}     │
     │                                  │    - push FCM au chauffeur ────►│ 7. notif + écran d'offre
     │                                  │    - createHook + race(sleep)   │    avec compte à rebours
     │                                  │                        ◄─────── │ 8. Accepter/Refuser
     │                                  │                                │    → POST /api/rides/respond
     │                                  │                                │      → resumeHook()
     │                                  │ 9. accepté → status=accepted,  │
     │                                  │    driverUid, libère les autres │
     │                                  │    refusé/timeout → libère ce   │
     │                                  │    chauffeur, candidat suivant  │
     │                                  │    liste épuisée/course annulée │
     │                                  │    entre-temps → noDriverFound  │
```

## Modèle de données

### `ride_requests/{id}` — champs ajoutés

| Champ | Type | Description |
|---|---|---|
| `offeredUid` | `string \| null` | Chauffeur actuellement sollicité. `null` hors offre active. |
| `offerExpiresAt` | `Timestamp \| null` | Fin du délai de réponse pour `offeredUid`. |
| `dispatchCandidates` | `string[]` | Liste ordonnée des UID candidats au moment du calcul (traçabilité/debug admin). |
| `rejectedBy` | `string[]` | UID des chauffeurs ayant explicitement refusé (distinct d'un timeout, pour analytics futurs). |

`RideStatus` (`lib/models/ride_request.dart`) : ajout de `noDriverFound` à
l'enum existant (`searching, accepted, completed, cancelled`). Le statut
reste `searching` pendant tout le dispatch (offres successives) — seul un
nouvel état terminal `noDriverFound` est ajouté pour le cas "personne n'a
accepté".

### `driver_profiles/{uid}` — champ ajouté

| Champ | Type | Description |
|---|---|---|
| `currentOfferRideId` | `string \| null` | Empêche qu'un même chauffeur reçoive deux offres simultanées de deux courses différentes. Posé transactionnellement à l'offre, libéré à la résolution (accepté/refusé/timeout). |

### Critères de filtrage d'un candidat (dans cet ordre)

1. `driver_profiles/{uid}.status == 'approved'`
2. `driver_profiles/{uid}.vehicleType` correspond au type demandé
3. `users/{uid}.driverOnline == true`
4. `driver_profiles/{uid}/location/current.updatedAt` < 3 minutes
5. `driver_profiles/{uid}/wallet/current.balance > 0`
6. `driver_profiles/{uid}.currentOfferRideId == null` (pas déjà sollicité ailleurs)

### Classement

ETA approché = distance à vol d'oiseau (formule haversine, `location.lat/lng`
→ `ride.pickup`) ÷ vitesse moyenne estimée (constante, ex. 25 km/h ville).
Tri croissant sur cet ETA.

## Le workflow (`yame-admin/lib/dispatch/dispatchWorkflow.ts`)

```
dispatchWorkflow(rideId):
  "use workflow"
  ride = await loadRide(rideId)                       // step
  candidates = await findCandidates(ride)              // step — filtre + classe, écrit dispatchCandidates
  if candidates.length == 0:
    await markNoDriverFound(rideId)                    // step
    return

  for uid in candidates:
    stillSearching = await checkStillSearching(rideId) // step — le client a pu annuler entre-temps
    if !stillSearching: return

    reserved = await reserveDriver(rideId, uid)        // step — transaction currentOfferRideId + offeredUid/offerExpiresAt + push FCM
    if !reserved: continue                             // course/chauffeur pris entre-temps, candidat suivant

    hook = createHook<{accepted: boolean}>({ token: `ride:${rideId}:driver:${uid}` })
    result = await Promise.race([
      hook,
      sleep("12s").then(() => ({ accepted: false, timedOut: true })),
    ])

    if result.accepted:
      await confirmAssignment(rideId, uid)             // step — status=accepted, driverUid, libère currentOfferRideId
      return
    else:
      await releaseDriver(rideId, uid, reason: result.timedOut ? "timeout" : "rejected") // step
      // boucle continue sur le candidat suivant

  await markNoDriverFound(rideId)                      // step
```

Toute la logique métier (lecture/écriture Firestore, envoi FCM) vit dans des
fonctions `"use step"` (accès Node.js complet, retry automatique, résultats
mis en cache/rejoués) ; la fonction `dispatchWorkflow` elle-même ne fait que
l'orchestration (boucle, `sleep`, `createHook`) — c'est la séparation
recommandée par le SDK pour éviter les restrictions du bac à sable.

## Routes API (`yame-admin/app/api/rides/`)

### `POST /api/rides/dispatch`

- Auth : jeton Firebase du client (rider), vérifié comme les routes
  existantes (`/api/recharge/initiate`).
- Body : `{ rideId: string }`.
- Vérifie que `ride_requests/{rideId}.clientUid` correspond au jeton fourni.
- Appelle `start(dispatchWorkflow, [rideId])` (via une fonction `"use step"`
  côté route, `start()` ne s'appelle pas directement dans un contexte
  workflow mais une route API n'est pas un contexte workflow — appel direct
  possible ici).
- Retourne `{ runId }`.

### `POST /api/rides/respond`

- Auth : jeton Firebase du chauffeur.
- Body : `{ rideId: string, accept: boolean }`.
- Vérifie que `ride_requests/{rideId}.offeredUid == decoded.uid` (sinon
  409 — offre déjà expirée/attribuée ailleurs, réponse ignorée proprement).
- Appelle `resumeHook(`ride:${rideId}:driver:${decoded.uid}`, { accepted })`.

## Changements côté app chauffeur (`driver_home_screen.dart`)

- La requête Firestore passe de "toutes les courses en `searching`" à
  "la course qui m'est actuellement offerte" :
  `.where('offeredUid', isEqualTo: uid).where('status', isEqualTo: 'searching')`
  (au plus un résultat à la fois, le dispatch étant strictement séquentiel).
- Nouvel écran/modal plein écran "Offre de course" avec compte à rebours
  visuel basé sur `offerExpiresAt`, boutons Accepter/Refuser qui appellent
  `POST /api/rides/respond` au lieu d'écrire directement dans Firestore.
- Si le compte à rebours atteint 0 côté client, fermeture silencieuse de la
  modal (le serveur gère déjà le timeout de son côté via `sleep`) — aucune
  action réseau nécessaire pour ce cas.
- FCM : `NotificationService` doit réellement afficher une alerte (son/
  vibration/notification) à la réception d'un message — aujourd'hui
  `FirebaseMessaging.onMessage.listen` est un no-op. Contenu simple
  (titre/corps uniquement) : c'est la requête Firestore modifiée ci-dessus
  qui pilote l'affichage réel de l'offre une fois l'app ouverte, pas le
  contenu du push.

## Changements côté app client (`booking_screen.dart`)

- `_requestDriver` crée le `ride_request` comme aujourd'hui, puis appelle
  `POST {AppConfig.adminApiBaseUrl}/api/rides/dispatch` avec le jeton
  Firebase et l'id créé. Échec de cet appel → message d'erreur existant
  (`bookingRequestError`), pas de mécanisme de retry automatique en v1.
- Nouveau statut affiché : `noDriverFound` → message "Aucun chauffeur
  disponible pour le moment, réessayez." + bouton pour relancer une
  recherche (réutilise le flux existant, pas un écran dédié).

## `firestore.rules` — changements sur `ride_requests`

Le trou de sécurité actuel : `allow read: if ... resource.data.status ==
'searching'` permet à **n'importe quel** utilisateur connecté de lire
**toutes** les demandes en recherche, et la branche `update` "un chauffeur
accepte une demande encore ouverte" permet à n'importe quel chauffeur
d'écrire directement `status`/`driverUid` sur n'importe quelle demande —
c'est exactement le mécanisme de course qu'on supprime.

```
// AVANT
allow read: if request.auth != null && (
  resource.data.status == 'searching' ||
  resource.data.clientUid == request.auth.uid ||
  resource.data.driverUid == request.auth.uid
);

// APRÈS — un chauffeur ne lit que ce qui lui est explicitement offert
allow read: if request.auth != null && (
  resource.data.clientUid == request.auth.uid ||
  resource.data.driverUid == request.auth.uid ||
  resource.data.get('offeredUid', null) == request.auth.uid
);
```

```
// Branche "un chauffeur accepte une demande encore ouverte" —
// SUPPRIMÉE de `allow update`. Le chauffeur n'écrit plus jamais
// status/driverUid lui-même ; seul l'Admin SDK (yame-admin, qui
// contourne ces règles) le fait désormais, via /api/rides/respond.
```

Les branches `create` (client crée sa demande), et les deux branches liées
à terminer/annuler/noter/payer une course déjà acceptée, restent
inchangées — hors scope de ce changement. `create` gagne une contrainte
supplémentaire : `request.resource.data.get('offeredUid', null) == null`
(le client ne peut pas s'auto-attribuer une offre à la création).

## Gestion des erreurs et cas limites

| Cas | Comportement |
|---|---|
| Aucun candidat trouvé dès le départ | `noDriverFound` immédiat |
| Client annule pendant le dispatch | Vérifié avant chaque offre (`checkStillSearching`) ; le workflow s'arrête au step suivant, pas d'offre envoyée à un chauffeur pour une course déjà annulée |
| Deux courses ciblent le même chauffeur en même temps | `reserveDriver` est une transaction Firestore sur `currentOfferRideId` — le second workflow trouve le champ déjà occupé et passe au candidat suivant sans offrir |
| Chauffeur répond après l'expiration de son offre (message réseau en retard) | `/api/rides/respond` vérifie `offeredUid == uid` avant d'appeler `resumeHook` ; si ça ne correspond plus, réponse ignorée avec une erreur claire au client ("offre expirée") |
| Redéploiement/crash de yame-admin pendant un workflow en cours | Géré nativement par Vercel Workflow : les steps déjà exécutés ne sont pas rejoués, `sleep`/`createHook` reprennent exactement où ils en étaient — aucune logique de reprise à écrire à la main |
| Chauffeur accepte mais son solde est retombé à 0 entre l'offre et la réponse (rare) | `confirmAssignment` revérifie le solde avant de valider ; si invalide, traité comme un refus et le dispatch continue sur le candidat suivant |

## Observabilité

`dispatchCandidates` et `rejectedBy` stockés sur `ride_requests` permettent
au panneau admin (page `/courses` existante) d'afficher a posteriori qui a
été sollicité et dans quel ordre, sans dépendre de l'outillage `npx workflow
inspect` (utile en dev, pas exposé aux admins Yame).

## Plan de tests

- **Unitaire** : fonction de filtrage + classement des candidats (pure,
  facile à tester avec des données de chauffeurs fixtures).
- **Intégration** (`@workflow/vitest`) : simulate candidat 1 qui timeout,
  candidat 2 qui accepte → assert sur l'état final de `ride_requests`
  (`status=accepted`, `driverUid` correct, `currentOfferRideId` libéré pour
  le candidat 1).
- **Manuel sur émulateur** (`run-yame`) : deux comptes chauffeur de test
  (un proche, un loin) + un compte client de test — vérifier que l'offre
  arrive d'abord au plus proche, refuser/laisser expirer, vérifier qu'elle
  passe au second, accepter, vérifier le statut côté client et chauffeur.
  Comptes de test nettoyés après coup (voir mémoire `yame-pending-features`).

## Suivant

Ce document sert de base au plan d'implémentation détaillé (skill
`writing-plans`), qui découpera le travail ci-dessus en étapes ordonnées et
vérifiables.
