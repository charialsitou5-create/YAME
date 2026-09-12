# Ride Dispatch System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current "broadcast every ride request to every online driver, first to tap Accept wins" model with a server-driven sequential dispatch: yame-admin ranks eligible drivers by approximate ETA and offers the ride to one at a time (12s to respond) via a durable Vercel Workflow.

**Architecture:** A new Vercel Workflow (`yame-admin/lib/dispatch/workflow.ts`) orchestrates the offer loop using `createHook` + `sleep` (`Promise.race`) per candidate. Two new API routes trigger it (`/api/rides/dispatch`) and resolve offers (`/api/rides/respond`). The Flutter driver app now only sees rides explicitly offered to it; the old client-side "accept by writing Firestore directly" path is removed from both the app and `firestore.rules`.

**Tech Stack:** Next.js 15 / TypeScript (yame-admin), `workflow` + `@workflow/next` + `@workflow/vitest` (Vercel Workflow SDK, already installed), Firebase Admin SDK, Flutter/Dart (YAME app), Firestore + Firestore emulator (tests).

**Spec:** `Yame/YAME/docs/superpowers/specs/2026-09-12-ride-dispatch-design.md`

## Global Constraints

- Firebase project is on the **Spark** plan — never use Cloud Functions; all server logic lives in `yame-admin`.
- Offer timeout is **exactly `"12s"`** per candidate (the literal string, passed to `sleep()`).
- Driver location freshness window for eligibility: **3 minutes** (`180000` ms).
- ETA approximation speed constant: **25 km/h**.
- Minimum balance to receive an offer: **`balance > 0`** (matches the existing threshold already used in `driver_home_screen.dart` to allow going online — do not introduce a different threshold).
- `firestore.rules` changes are scoped to the `ride_requests` match block only — no other collection's rules change.
- After this plan, the Flutter app must **never again write** `ride_requests.status`, `.driverUid`, `.driverName`, `.offeredUid`, `.offerExpiresAt` directly — only `yame-admin` (Admin SDK) writes them, via `/api/rides/respond`.
- All new user-facing strings go in `Yame/YAME/lib/core/constants/app_strings.dart`, in French, matching the existing tone (short, direct, no exclamation marks unless the surrounding strings already use them).
- All new yame-admin server files carry `import "server-only";` or live under routes that are already server-only by construction (API routes are inherently server-only; the `lib/dispatch/*.ts` files should still import `server-only` for defense in depth, matching `lib/services/payment-providers/*.ts`).

---

### Task 1: Wire the Vercel Workflow SDK into yame-admin

**Files:**
- Modify: `Yame/yame-admin/next.config.mjs`
- Modify: `Yame/yame-admin/package.json` (already has `workflow`, `@workflow/next`, `@workflow/vitest`, `vitest` installed on disk from spec research — this task commits that and adds scripts)
- Modify: `Yame/yame-admin/tsconfig.json`

**Interfaces:**
- Produces: a dev server that exposes the Workflow SDK's internal routes, verifiable with `npx workflow health`. No other task depends on specific exports from this one — it's infrastructure.

- [ ] **Step 1: Confirm the packages are installed**

Run (from `Yame/yame-admin`):
```bash
npm ls workflow @workflow/next @workflow/vitest vitest
```
Expected: all four listed with no `UNMET DEPENDENCY` errors (they were installed during spec research; if missing, run `npm install workflow @workflow/next` and `npm install --save-dev @workflow/vitest vitest`).

- [ ] **Step 2: Wrap `next.config.mjs` with `withWorkflow`**

Replace the full contents of `Yame/yame-admin/next.config.mjs` with:

```javascript
import { withWorkflow } from "workflow/next";

/** @type {import('next').NextConfig} */
const nextConfig = {
  images: {
    remotePatterns: [
      { protocol: "https", hostname: "firebasestorage.googleapis.com" },
    ],
  },
};

export default withWorkflow(nextConfig);
```

- [ ] **Step 3: Enable TypeScript IntelliSense for the workflow directives (optional but cheap)**

In `Yame/yame-admin/tsconfig.json`, add the `workflow` plugin alongside the existing `next` plugin:

```json
    "plugins": [{ "name": "next" }, { "name": "workflow" }],
```

- [ ] **Step 4: Add test scripts to `package.json`**

In `Yame/yame-admin/package.json`, under `"scripts"`, add two entries (keep the existing `dev`/`build`/`start`/`lint`):

```json
    "test": "vitest run --config vitest.config.ts",
    "test:integration": "node --env-file=.env.local node_modules/.bin/vitest run --config vitest.integration.config.ts"
```

- [ ] **Step 5: Create the unit-test vitest config**

Create `Yame/yame-admin/vitest.config.ts`:

```typescript
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    include: ["lib/**/*.test.ts"],
    exclude: ["lib/**/*.integration.test.ts"],
  },
});
```

- [ ] **Step 6: Create the integration-test vitest config**

Create `Yame/yame-admin/vitest.integration.config.ts`:

```typescript
import { defineConfig } from "vitest/config";
import { workflow } from "@workflow/vitest";

export default defineConfig({
  plugins: [workflow()],
  test: {
    include: ["lib/**/*.integration.test.ts"],
    testTimeout: 60_000,
  },
});
```

- [ ] **Step 7: Verify the dev server exposes the workflow endpoints**

Run:
```bash
cd Yame/yame-admin && npm run dev &
sleep 3
npx workflow health
```
Expected: output confirms the local workflow endpoint is reachable (no connection-refused error). Stop the dev server afterward (`kill %1` or Ctrl+C).

- [ ] **Step 8: Commit**

```bash
cd Yame/yame-admin
git add next.config.mjs tsconfig.json package.json package-lock.json vitest.config.ts vitest.integration.config.ts
git commit -m "chore: wire Vercel Workflow SDK into yame-admin"
```

---

### Task 2: ETA estimation helper

**Files:**
- Create: `Yame/yame-admin/lib/dispatch/eta.ts`
- Test: `Yame/yame-admin/lib/dispatch/eta.test.ts`

**Interfaces:**
- Produces: `haversineDistanceKm(lat1, lng1, lat2, lng2): number`, `estimateEtaMinutes(distanceKm: number): number`, `AVERAGE_SPEED_KMH: number` — consumed by Task 5's `findCandidates` step.

- [ ] **Step 1: Write the failing test**

Create `Yame/yame-admin/lib/dispatch/eta.test.ts`:

```typescript
import { describe, it, expect } from "vitest";
import { haversineDistanceKm, estimateEtaMinutes, AVERAGE_SPEED_KMH } from "./eta";

describe("haversineDistanceKm", () => {
  it("returns 0 for identical points", () => {
    expect(haversineDistanceKm(-4.7889, 11.8656, -4.7889, 11.8656)).toBe(0);
  });

  it("returns approximately 1km for two Pointe-Noire points ~0.009° of latitude apart", () => {
    const distance = haversineDistanceKm(-4.7889, 11.8656, -4.7799, 11.8656);
    expect(distance).toBeGreaterThan(0.9);
    expect(distance).toBeLessThan(1.1);
  });
});

describe("estimateEtaMinutes", () => {
  it("computes ETA using the fixed average speed constant", () => {
    const expectedMinutes = (1 / AVERAGE_SPEED_KMH) * 60;
    expect(estimateEtaMinutes(1)).toBeCloseTo(expectedMinutes, 5);
  });

  it("returns 0 for 0 distance", () => {
    expect(estimateEtaMinutes(0)).toBe(0);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd Yame/yame-admin && npm test -- eta.test.ts`
Expected: FAIL — `Cannot find module './eta'`.

- [ ] **Step 3: Write the implementation**

Create `Yame/yame-admin/lib/dispatch/eta.ts`:

```typescript
import "server-only";

const EARTH_RADIUS_KM = 6371;

/** Vitesse moyenne estimée en ville (Pointe-Noire) — pas de vrai routing. */
export const AVERAGE_SPEED_KMH = 25;

function toRadians(degrees: number): number {
  return (degrees * Math.PI) / 180;
}

/** Distance à vol d'oiseau (formule haversine), en kilomètres. */
export function haversineDistanceKm(
  lat1: number,
  lng1: number,
  lat2: number,
  lng2: number
): number {
  const dLat = toRadians(lat2 - lat1);
  const dLng = toRadians(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRadians(lat1)) * Math.cos(toRadians(lat2)) * Math.sin(dLng / 2) ** 2;
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return EARTH_RADIUS_KM * c;
}

/** ETA approché en minutes, à partir d'une distance à vol d'oiseau. */
export function estimateEtaMinutes(distanceKm: number): number {
  return (distanceKm / AVERAGE_SPEED_KMH) * 60;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd Yame/yame-admin && npm test -- eta.test.ts`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
cd Yame/yame-admin
git add lib/dispatch/eta.ts lib/dispatch/eta.test.ts
git commit -m "feat: add distance/ETA estimation helper for ride dispatch"
```

---

### Task 3: Firestore data model and security rules

**Files:**
- Modify: `Yame/YAME/lib/models/ride_request.dart:6-19` (RideStatus enum) and `:22-102` (RideRequest class)
- Modify: `Yame/YAME/firestore.rules` (the `match /ride_requests/{requestId}` block)

**Interfaces:**
- Produces: `RideStatus.noDriverFound` (enum value, `firestoreValue == 'noDriverFound'`); `RideRequest.offeredUid: String?`, `RideRequest.offerExpiresAt: DateTime?` (parsed in `fromDoc`, not written by `toMap`).
- Consumed by: Task 8 (`_RideStatusPanel`), Task 10 (`_RideOfferCard`).

- [ ] **Step 1: Add the `noDriverFound` status to the enum**

In `Yame/YAME/lib/models/ride_request.dart`, change:

```dart
enum RideStatus {
  searching,
  accepted,
  completed,
  cancelled;
```

to:

```dart
enum RideStatus {
  searching,
  accepted,
  completed,
  cancelled,
  noDriverFound;
```

- [ ] **Step 2: Add `offeredUid`/`offerExpiresAt` to `RideRequest`**

In the same file, add two fields to the constructor and class body. Change:

```dart
  const RideRequest({
    this.id,
    required this.clientUid,
    required this.clientName,
    required this.pickup,
    required this.pickupAddress,
    required this.destination,
    required this.destinationAddress,
    required this.vehicleType,
    required this.status,
    this.driverUid,
    this.driverName,
    this.recipientName,
    this.recipientPhone,
    this.recipientInstructions,
    this.contactRequesterInstead = false,
  });
```

to:

```dart
  const RideRequest({
    this.id,
    required this.clientUid,
    required this.clientName,
    required this.pickup,
    required this.pickupAddress,
    required this.destination,
    required this.destinationAddress,
    required this.vehicleType,
    required this.status,
    this.driverUid,
    this.driverName,
    this.recipientName,
    this.recipientPhone,
    this.recipientInstructions,
    this.contactRequesterInstead = false,
    this.offeredUid,
    this.offerExpiresAt,
  });
```

And add the two fields near `driverName` (after the `final String? driverName;` line):

```dart
  /// Chauffeur actuellement sollicité par le dispatch serveur (yame-admin),
  /// `null` hors offre active — voir `docs/superpowers/specs/2026-09-12-ride-dispatch-design.md`.
  final String? offeredUid;

  /// Fin du délai de réponse pour `offeredUid`.
  final DateTime? offerExpiresAt;
```

- [ ] **Step 3: Parse the two new fields in `fromDoc`**

In `RideRequest.fromDoc`, add these two lines to the returned `RideRequest(...)` (after `driverName: data['driverName'] as String?,`):

```dart
      offeredUid: data['offeredUid'] as String?,
      offerExpiresAt: data['offerExpiresAt'] != null
          ? DateTime.tryParse(data['offerExpiresAt'] as String)
          : null,
```

- [ ] **Step 4: Verify the model compiles**

Run: `cd Yame/YAME && flutter analyze lib/models/ride_request.dart`
Expected: no new errors from this file. (A pre-existing non-exhaustive-switch error will appear for `_RideStatusPanel` in `booking_screen.dart` — that's expected and fixed in Task 8. If `flutter analyze` errors on `ride_request.dart` itself, fix before continuing.)

- [ ] **Step 5: Tighten `firestore.rules` on `ride_requests`**

In `Yame/YAME/firestore.rules`, inside `match /ride_requests/{requestId} { ... }`, replace the `allow read` block:

```
      allow read: if request.auth != null && (
        resource.data.status == 'searching' ||
        resource.data.clientUid == request.auth.uid ||
        resource.data.driverUid == request.auth.uid
      );
```

with:

```
      // Un chauffeur ne lit plus jamais "toutes les courses en recherche" —
      // seulement celle qui lui est explicitement offerte par le dispatch
      // serveur (yame-admin, Admin SDK, qui contourne ces règles). Voir
      // docs/superpowers/specs/2026-09-12-ride-dispatch-design.md.
      allow read: if request.auth != null && (
        resource.data.clientUid == request.auth.uid ||
        resource.data.driverUid == request.auth.uid ||
        resource.data.get('offeredUid', null) == request.auth.uid
      );
```

Replace the `allow create` block:

```
      allow create: if request.auth != null
        && request.resource.data.clientUid == request.auth.uid
        && request.resource.data.status == 'searching';
```

with (adds the `offeredUid` guard):

```
      allow create: if request.auth != null
        && request.resource.data.clientUid == request.auth.uid
        && request.resource.data.status == 'searching'
        && request.resource.data.get('offeredUid', null) == null;
```

In `allow update`, delete this entire branch (the driver no longer self-assigns — only `yame-admin`'s Admin SDK does, via `/api/rides/respond`):

```
        ||
        // un chauffeur accepte une demande encore ouverte
        (resource.data.status == 'searching'
          && request.resource.data.status == 'accepted'
          && request.resource.data.driverUid == request.auth.uid
          && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['status', 'driverUid', 'driverName']))
```

Leave every other branch (`client cancels`, `driver completes/cancels an accepted ride`, `rating`, `payment`) untouched.

- [ ] **Step 6: Deploy the updated rules**

Run:
```bash
cd Yame/YAME && firebase deploy --only firestore:rules
```
Expected: `Deploy complete!` with no errors.

- [ ] **Step 7: Commit**

```bash
cd Yame/YAME
git add lib/models/ride_request.dart firestore.rules
git commit -m "feat: add noDriverFound status and offer fields; lock down ride_requests rules for server-driven dispatch"
```

---

### Task 4: `adminMessaging()` helper

**Files:**
- Modify: `Yame/yame-admin/lib/firebaseAdmin.ts`

**Interfaces:**
- Produces: `adminMessaging(): Messaging` — consumed by Task 5's `reserveDriver` step.

- [ ] **Step 1: Add the Messaging import and lazy accessor**

In `Yame/yame-admin/lib/firebaseAdmin.ts`, add to the imports:

```typescript
import { getMessaging, type Messaging } from "firebase-admin/messaging";
```

Add a module-level variable next to the existing ones:

```typescript
let _adminMessaging: Messaging | undefined;
```

Add the exported function next to `adminStorage`:

```typescript
export function adminMessaging(): Messaging {
  return (_adminMessaging ??= getMessaging(getAdminApp()));
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd Yame/yame-admin && npx tsc --noEmit`
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
cd Yame/yame-admin
git add lib/firebaseAdmin.ts
git commit -m "feat: add adminMessaging() helper for server-sent push notifications"
```

---

### Task 5: The dispatch workflow

**Files:**
- Create: `Yame/yame-admin/lib/dispatch/hookToken.ts`
- Create: `Yame/yame-admin/lib/dispatch/workflow.ts`

**Interfaces:**
- Consumes: `haversineDistanceKm`, `estimateEtaMinutes`, `AVERAGE_SPEED_KMH` from Task 2's `lib/dispatch/eta.ts`; `adminDb`, `adminMessaging` from Task 4's `lib/firebaseAdmin.ts`.
- Produces: `dispatchHookToken(rideId: string, driverUid: string): string`; `dispatchRideWorkflow(rideId: string): Promise<void>` (the `"use workflow"` entry point) — consumed by Task 6's `/api/rides/dispatch` route and Task 7's integration test.

- [ ] **Step 1: Write the hook token helper**

Create `Yame/yame-admin/lib/dispatch/hookToken.ts`:

```typescript
import "server-only";

/**
 * Token déterministe d'un hook Vercel Workflow pour une offre
 * (course, chauffeur) donnée — partagé entre `workflow.ts` (qui crée le
 * hook) et la route `/api/rides/respond` (qui le résout), pour qu'un
 * changement d'un côté ne puisse pas dériver silencieusement de l'autre.
 */
export function dispatchHookToken(rideId: string, driverUid: string): string {
  return `ride:${rideId}:driver:${driverUid}`;
}
```

- [ ] **Step 2: Write the workflow file**

Create `Yame/yame-admin/lib/dispatch/workflow.ts`:

```typescript
import "server-only";
import { sleep, createHook, FatalError } from "workflow";
import { FieldValue } from "firebase-admin/firestore";
import { adminDb, adminMessaging } from "@/lib/firebaseAdmin";
import { haversineDistanceKm, estimateEtaMinutes } from "./eta";
import { dispatchHookToken } from "./hookToken";

const OFFER_TIMEOUT = "12s";
const OFFER_TIMEOUT_MS = 12_000;
const LOCATION_FRESHNESS_MS = 3 * 60 * 1000;

interface RideInfo {
  vehicleType: string;
  pickupLat: number;
  pickupLng: number;
  clientUid: string;
}

async function loadRide(rideId: string): Promise<RideInfo | null> {
  "use step";
  const doc = await adminDb().collection("ride_requests").doc(rideId).get();
  if (!doc.exists) return null;
  const data = doc.data()!;
  return {
    vehicleType: data.vehicleType as string,
    pickupLat: data.pickup.lat as number,
    pickupLng: data.pickup.lng as number,
    clientUid: data.clientUid as string,
  };
}

async function findCandidates(rideId: string, ride: RideInfo): Promise<string[]> {
  "use step";
  const db = adminDb();
  const snapshot = await db
    .collection("driver_profiles")
    .where("status", "==", "approved")
    .where("vehicleType", "==", ride.vehicleType)
    .get();

  const now = Date.now();

  const scored = await Promise.all(
    snapshot.docs.map(async (doc) => {
      const uid = doc.id;
      const driverData = doc.data();
      if (driverData.currentOfferRideId) return null;

      const [userDoc, walletDoc, locationDoc] = await Promise.all([
        db.collection("users").doc(uid).get(),
        doc.ref.collection("wallet").doc("current").get(),
        doc.ref.collection("location").doc("current").get(),
      ]);

      if (userDoc.data()?.driverOnline !== true) return null;

      const balance = (walletDoc.data()?.balance as number | undefined) ?? 0;
      if (balance <= 0) return null;

      const locationData = locationDoc.data();
      const updatedAtRaw = locationData?.updatedAt;
      const updatedAtMs =
        typeof updatedAtRaw === "string"
          ? new Date(updatedAtRaw).getTime()
          : (updatedAtRaw?.toMillis?.() as number | undefined);
      if (!updatedAtMs || now - updatedAtMs > LOCATION_FRESHNESS_MS) return null;

      const lat = locationData?.lat as number | undefined;
      const lng = locationData?.lng as number | undefined;
      if (lat == null || lng == null) return null;

      const distanceKm = haversineDistanceKm(ride.pickupLat, ride.pickupLng, lat, lng);
      return { uid, etaMinutes: estimateEtaMinutes(distanceKm) };
    })
  );

  const ranked = scored
    .filter((c): c is { uid: string; etaMinutes: number } => c !== null)
    .sort((a, b) => a.etaMinutes - b.etaMinutes)
    .map((c) => c.uid);

  await db.collection("ride_requests").doc(rideId).update({ dispatchCandidates: ranked });

  return ranked;
}

async function checkStillSearching(rideId: string): Promise<boolean> {
  "use step";
  const doc = await adminDb().collection("ride_requests").doc(rideId).get();
  return doc.exists && doc.data()?.status === "searching";
}

async function reserveDriver(rideId: string, driverUid: string): Promise<boolean> {
  "use step";
  const db = adminDb();
  const driverRef = db.collection("driver_profiles").doc(driverUid);
  const rideRef = db.collection("ride_requests").doc(rideId);
  const offerExpiresAt = new Date(Date.now() + OFFER_TIMEOUT_MS).toISOString();

  const reserved = await db.runTransaction(async (tx) => {
    const driverSnap = await tx.get(driverRef);
    if (driverSnap.data()?.currentOfferRideId) return false;
    tx.update(driverRef, { currentOfferRideId: rideId });
    tx.update(rideRef, { offeredUid: driverUid, offerExpiresAt });
    return true;
  });

  if (!reserved) return false;

  const userDoc = await db.collection("users").doc(driverUid).get();
  const fcmToken = userDoc.data()?.fcmToken as string | undefined;
  if (fcmToken) {
    try {
      await adminMessaging().send({
        token: fcmToken,
        notification: {
          title: "Nouvelle course disponible",
          body: "Une course vous a été proposée, ouvrez l'app pour répondre.",
        },
      });
    } catch {
      // Un token invalide/expiré ne doit jamais bloquer le dispatch — le
      // chauffeur peut quand même voir l'offre s'il a l'app ouverte.
    }
  }

  return true;
}

async function releaseDriver(rideId: string, driverUid: string): Promise<void> {
  "use step";
  const db = adminDb();
  await Promise.all([
    db.collection("driver_profiles").doc(driverUid).update({ currentOfferRideId: null }),
    db.collection("ride_requests").doc(rideId).update({
      offeredUid: null,
      offerExpiresAt: null,
      rejectedBy: FieldValue.arrayUnion(driverUid),
    }),
  ]);
}

async function confirmAssignment(rideId: string, driverUid: string, clientUid: string): Promise<boolean> {
  "use step";
  const db = adminDb();
  const walletDoc = await db
    .collection("driver_profiles")
    .doc(driverUid)
    .collection("wallet")
    .doc("current")
    .get();
  const balance = (walletDoc.data()?.balance as number | undefined) ?? 0;
  if (balance <= 0) return false;

  const userDoc = await db.collection("users").doc(driverUid).get();
  const driverName = (userDoc.data()?.name as string | undefined) ?? "";

  await Promise.all([
    db.collection("ride_requests").doc(rideId).update({
      status: "accepted",
      driverUid,
      driverName,
      offeredUid: null,
      offerExpiresAt: null,
    }),
    db.collection("driver_profiles").doc(driverUid).update({ currentOfferRideId: null }),
    db
      .collection("driver_profiles")
      .doc(driverUid)
      .collection("location")
      .doc("current")
      .set({ activeClientUid: clientUid }, { merge: true }),
    db.collection("users").doc(driverUid).update({ driverActiveRideId: rideId }),
  ]);

  return true;
}

async function markNoDriverFound(rideId: string): Promise<void> {
  "use step";
  await adminDb().collection("ride_requests").doc(rideId).update({
    status: "noDriverFound",
    offeredUid: null,
    offerExpiresAt: null,
  });
}

export async function dispatchRideWorkflow(rideId: string): Promise<void> {
  "use workflow";

  const ride = await loadRide(rideId);
  if (!ride) {
    throw new FatalError(`Course introuvable: ${rideId}`);
  }

  const candidates = await findCandidates(rideId, ride);
  if (candidates.length === 0) {
    await markNoDriverFound(rideId);
    return;
  }

  for (const driverUid of candidates) {
    const stillSearching = await checkStillSearching(rideId);
    if (!stillSearching) return;

    const reserved = await reserveDriver(rideId, driverUid);
    if (!reserved) continue;

    const hook = createHook<{ accepted: boolean }>({
      token: dispatchHookToken(rideId, driverUid),
    });

    const result = await Promise.race([
      hook,
      sleep(OFFER_TIMEOUT).then(() => ({ accepted: false }) as const),
    ]);

    if (result.accepted) {
      const confirmed = await confirmAssignment(rideId, driverUid, ride.clientUid);
      if (confirmed) return;
    }

    await releaseDriver(rideId, driverUid);
  }

  await markNoDriverFound(rideId);
}
```

- [ ] **Step 3: Verify it compiles**

Run: `cd Yame/yame-admin && npx tsc --noEmit`
Expected: no errors.

- [ ] **Step 4: Commit**

```bash
cd Yame/yame-admin
git add lib/dispatch/hookToken.ts lib/dispatch/workflow.ts
git commit -m "feat: implement sequential ride-dispatch workflow"
```

---

### Task 6: API routes

**Files:**
- Create: `Yame/yame-admin/app/api/rides/dispatch/route.ts`
- Create: `Yame/yame-admin/app/api/rides/respond/route.ts`

**Interfaces:**
- Consumes: `dispatchRideWorkflow` and `dispatchHookToken` from Task 5.
- Produces: `POST /api/rides/dispatch` `{ rideId }` → `{ success: true, runId }`; `POST /api/rides/respond` `{ rideId, accept }` → `{ success: true }` — consumed by Task 9 (`DispatchService`) and Task 10 (`DispatchResponseService`).

- [ ] **Step 1: Write `/api/rides/dispatch`**

Create `Yame/yame-admin/app/api/rides/dispatch/route.ts`:

```typescript
import { NextResponse } from "next/server";
import { start } from "workflow/api";
import { adminAuth, adminDb } from "@/lib/firebaseAdmin";
import { dispatchRideWorkflow } from "@/lib/dispatch/workflow";

/**
 * Lance le dispatch serveur d'une course tout juste créée par le client.
 * Voir docs/superpowers/specs/2026-09-12-ride-dispatch-design.md.
 */
export async function POST(request: Request) {
  try {
    const authHeader = request.headers.get("authorization");
    const idToken = authHeader?.startsWith("Bearer ") ? authHeader.slice(7) : null;
    if (!idToken) {
      return NextResponse.json({ error: "Jeton d'authentification manquant." }, { status: 401 });
    }

    let decoded;
    try {
      decoded = await adminAuth().verifyIdToken(idToken);
    } catch {
      return NextResponse.json({ error: "Jeton d'authentification invalide." }, { status: 401 });
    }

    const body = await request.json();
    const rideId = body.rideId as string | undefined;
    if (!rideId) {
      return NextResponse.json({ error: "rideId manquant." }, { status: 400 });
    }

    const rideDoc = await adminDb().collection("ride_requests").doc(rideId).get();
    if (!rideDoc.exists) {
      return NextResponse.json({ error: "Course introuvable." }, { status: 404 });
    }
    if (rideDoc.data()?.clientUid !== decoded.uid) {
      return NextResponse.json(
        { error: "Vous ne pouvez lancer le dispatch que pour votre propre course." },
        { status: 403 }
      );
    }

    const run = await start(dispatchRideWorkflow, [rideId]);
    return NextResponse.json({ success: true, runId: run.runId });
  } catch (error) {
    console.error("Erreur lancement dispatch:", error);
    return NextResponse.json({ error: "Erreur lors du lancement du dispatch." }, { status: 500 });
  }
}
```

- [ ] **Step 2: Write `/api/rides/respond`**

Create `Yame/yame-admin/app/api/rides/respond/route.ts`:

```typescript
import { NextResponse } from "next/server";
import { resumeHook } from "workflow/api";
import { adminAuth, adminDb } from "@/lib/firebaseAdmin";
import { dispatchHookToken } from "@/lib/dispatch/hookToken";

/**
 * Un chauffeur répond (accepte/refuse) à l'offre qui lui a été adressée.
 * Le chauffeur n'écrit plus jamais directement status/driverUid sur
 * ride_requests — voir docs/superpowers/specs/2026-09-12-ride-dispatch-design.md.
 */
export async function POST(request: Request) {
  try {
    const authHeader = request.headers.get("authorization");
    const idToken = authHeader?.startsWith("Bearer ") ? authHeader.slice(7) : null;
    if (!idToken) {
      return NextResponse.json({ error: "Jeton d'authentification manquant." }, { status: 401 });
    }

    let decoded;
    try {
      decoded = await adminAuth().verifyIdToken(idToken);
    } catch {
      return NextResponse.json({ error: "Jeton d'authentification invalide." }, { status: 401 });
    }

    const body = await request.json();
    const rideId = body.rideId as string | undefined;
    const accept = body.accept as boolean | undefined;
    if (!rideId || typeof accept !== "boolean") {
      return NextResponse.json({ error: "rideId ou accept manquant." }, { status: 400 });
    }

    const rideDoc = await adminDb().collection("ride_requests").doc(rideId).get();
    if (rideDoc.data()?.offeredUid !== decoded.uid) {
      return NextResponse.json(
        { error: "Cette offre a expiré ou ne vous est plus destinée." },
        { status: 409 }
      );
    }

    try {
      await resumeHook(dispatchHookToken(rideId, decoded.uid), { accepted: accept });
    } catch {
      return NextResponse.json(
        { error: "Cette offre a expiré ou ne vous est plus destinée." },
        { status: 409 }
      );
    }

    return NextResponse.json({ success: true });
  } catch (error) {
    console.error("Erreur réponse à l'offre:", error);
    return NextResponse.json({ error: "Erreur lors de l'envoi de la réponse." }, { status: 500 });
  }
}
```

- [ ] **Step 3: Verify the routes compile and respond**

Run:
```bash
cd Yame/yame-admin && npx tsc --noEmit
npm run dev &
sleep 3
curl -s -X POST http://localhost:3000/api/rides/dispatch -H "Content-Type: application/json" -d '{}'
curl -s -X POST http://localhost:3000/api/rides/respond -H "Content-Type: application/json" -d '{}'
kill %1
```
Expected: both curl calls return `{"error":"Jeton d'authentification manquant."}` with no server crash in the log.

- [ ] **Step 4: Commit**

```bash
cd Yame/yame-admin
git add app/api/rides
git commit -m "feat: add /api/rides/dispatch and /api/rides/respond routes"
```

---

### Task 7: Integration test for the dispatch workflow (Firestore emulator)

**Files:**
- Modify: `Yame/YAME/firebase.json` (add an `emulators` block)
- Create: `Yame/yame-admin/lib/dispatch/workflow.integration.test.ts`

**Interfaces:**
- Consumes: `dispatchRideWorkflow` and `dispatchHookToken` from Task 5; `adminDb` from `lib/firebaseAdmin.ts`.

- [ ] **Step 1: Add a Firestore emulator config**

In `Yame/YAME/firebase.json`, add an `"emulators"` key at the top level (alongside `"flutter"`, `"firestore"`, `"storage"`):

```json
  "emulators": {
    "firestore": {
      "port": 8080
    }
  }
```

- [ ] **Step 2: Write the integration test**

Create `Yame/yame-admin/lib/dispatch/workflow.integration.test.ts`:

```typescript
import { describe, it, expect, beforeAll } from "vitest";
import { start, getRun, resumeHook } from "workflow/api";
import { waitForHook, waitForSleep } from "@workflow/vitest";
import { dispatchRideWorkflow } from "./workflow";
import { dispatchHookToken } from "./hookToken";
import { adminDb } from "@/lib/firebaseAdmin";

const RIDE_ID = "test-ride-1";
const CLIENT_UID = "test-client-1";
const DRIVER_A = "test-driver-a"; // plus proche — offert en premier, va expirer
const DRIVER_B = "test-driver-b"; // plus loin — offert en second, accepte

async function seedDriver(uid: string, lat: number, lng: number) {
  const db = adminDb();
  await db.collection("driver_profiles").doc(uid).set({
    status: "approved",
    vehicleType: "car",
  });
  await db
    .collection("driver_profiles")
    .doc(uid)
    .collection("wallet")
    .doc("current")
    .set({ balance: 1000 });
  await db
    .collection("driver_profiles")
    .doc(uid)
    .collection("location")
    .doc("current")
    .set({ lat, lng, updatedAt: new Date().toISOString() });
  await db.collection("users").doc(uid).set({ driverOnline: true, name: `Driver ${uid}` });
}

describe("dispatchRideWorkflow", () => {
  beforeAll(async () => {
    const db = adminDb();
    await db.collection("ride_requests").doc(RIDE_ID).set({
      clientUid: CLIENT_UID,
      status: "searching",
      vehicleType: "car",
      pickup: { lat: -4.7889, lng: 11.8656 },
    });
    await seedDriver(DRIVER_A, -4.7899, 11.8656);
    await seedDriver(DRIVER_B, -4.82, 11.8656);
  });

  it("moves to the next candidate when the first offer times out, then confirms on acceptance", async () => {
    const run = await start(dispatchRideWorkflow, [RIDE_ID]);

    await waitForHook(run, { token: dispatchHookToken(RIDE_ID, DRIVER_A) });
    const sleepIdA = await waitForSleep(run);
    await getRun(run.runId).wakeUp({ correlationIds: [sleepIdA] });

    await waitForHook(run, { token: dispatchHookToken(RIDE_ID, DRIVER_B) });
    await resumeHook(dispatchHookToken(RIDE_ID, DRIVER_B), { accepted: true });

    await run.returnValue;

    const rideDoc = await adminDb().collection("ride_requests").doc(RIDE_ID).get();
    expect(rideDoc.data()?.status).toBe("accepted");
    expect(rideDoc.data()?.driverUid).toBe(DRIVER_B);

    const driverADoc = await adminDb().collection("driver_profiles").doc(DRIVER_A).get();
    expect(driverADoc.data()?.currentOfferRideId ?? null).toBeNull();

    const driverBDoc = await adminDb().collection("driver_profiles").doc(DRIVER_B).get();
    expect(driverBDoc.data()?.currentOfferRideId ?? null).toBeNull();
  });
});
```

- [ ] **Step 3: Run the integration test against the Firestore emulator**

Run (from the repository root that contains both `Yame/YAME` and `Yame/yame-admin`):
```bash
cd Yame/YAME && firebase emulators:exec --only firestore \
  "cd ../yame-admin && FIRESTORE_EMULATOR_HOST=localhost:8080 npm run test:integration"
```
Expected: the emulator starts, the test suite reports 1 passed test, the emulator shuts down automatically.

- [ ] **Step 4: Commit**

```bash
cd Yame/YAME && git add firebase.json && git commit -m "test: add Firestore emulator config for dispatch integration test"
cd ../yame-admin && git add lib/dispatch/workflow.integration.test.ts && git commit -m "test: add integration test for sequential ride-dispatch workflow"
```

---

### Task 8: Flutter — `noDriverFound` UI on the client booking screen

**Files:**
- Modify: `Yame/YAME/lib/features/booking/booking_screen.dart:440-459` (clearing condition + `_RideStatusPanel` invocation is unchanged, but the switch it feeds needs a new branch)
- Modify: `Yame/YAME/lib/features/booking/booking_screen.dart:789-797` (the `switch (status)` inside `_RideStatusPanel.build`)
- Modify: `Yame/YAME/lib/core/constants/app_strings.dart`

**Interfaces:**
- Consumes: `RideStatus.noDriverFound` from Task 3.

- [ ] **Step 1: Add the two new strings**

In `Yame/YAME/lib/core/constants/app_strings.dart`, near `bookingCancelled`, add:

```dart
  static const bookingNoDriverFoundTitle = 'Aucun chauffeur disponible';
  static const bookingNoDriverFoundBody =
      'Personne n\'a pu prendre votre course pour le moment. Réessayez dans quelques instants.';
```

- [ ] **Step 2: Include `noDriverFound` in the "ride is over" clearing condition**

In `booking_screen.dart`, change:

```dart
                      if (ride != null &&
                          !_clientActiveRideCleared &&
                          (ride.status == RideStatus.completed ||
                              ride.status == RideStatus.cancelled)) {
```

to:

```dart
                      if (ride != null &&
                          !_clientActiveRideCleared &&
                          (ride.status == RideStatus.completed ||
                              ride.status == RideStatus.cancelled ||
                              ride.status == RideStatus.noDriverFound)) {
```

- [ ] **Step 3: Add the switch branch**

In `_RideStatusPanel.build`, inside the `switch (status) { ... }`, add a new arm right after the `RideStatus.cancelled => [...]` arm (before the closing `}`):

```dart
          RideStatus.noDriverFound => [
              Text(
                AppStrings.bookingNoDriverFoundTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.bookingNoDriverFoundBody,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onNewBooking,
                child: const Text(AppStrings.bookingNewRequest),
              ),
            ],
```

- [ ] **Step 4: Verify it compiles**

Run: `cd Yame/YAME && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
cd Yame/YAME
git add lib/core/constants/app_strings.dart lib/features/booking/booking_screen.dart
git commit -m "feat: show a dedicated screen when the dispatch finds no driver"
```

---

### Task 9: Flutter — trigger the dispatch from the client app

**Files:**
- Create: `Yame/YAME/lib/services/dispatch_service.dart`
- Modify: `Yame/YAME/lib/features/booking/booking_screen.dart` (`_requestDriver`)

**Interfaces:**
- Consumes: `AppConfig.adminApiBaseUrl` (already exists in `lib/core/constants/app_config.dart`).
- Produces: `DispatchService.start({required String rideId})`, `DispatchException`.

- [ ] **Step 1: Write `DispatchService`**

Create `Yame/YAME/lib/services/dispatch_service.dart`:

```dart
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../core/constants/app_config.dart';

class DispatchException implements Exception {
  DispatchException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Déclenche le dispatch serveur d'une course tout juste créée — voir
/// `yame-admin/app/api/rides/dispatch` et
/// `docs/superpowers/specs/2026-09-12-ride-dispatch-design.md`.
class DispatchService {
  DispatchService._();

  static Future<void> start({required String rideId}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw DispatchException('Vous devez être connecté.');
    }
    final idToken = await user.getIdToken();

    final response = await http.post(
      Uri.parse('${AppConfig.adminApiBaseUrl}/api/rides/dispatch'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({'rideId': rideId}),
    );

    Map<String, dynamic>? body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      body = null;
    }

    if (response.statusCode != 200 || body?['success'] != true) {
      throw DispatchException(
        body?['error'] as String? ?? 'Impossible de lancer la recherche.',
      );
    }
  }
}
```

- [ ] **Step 2: Wire it into `_requestDriver`**

In `Yame/YAME/lib/features/booking/booking_screen.dart`, add the import:

```dart
import '../../services/dispatch_service.dart';
```

In `_requestDriver`, immediately after the existing:

```dart
      if (!mounted) return;
      setState(() {
        _activeRequestId = requestRef.id;
        _clientActiveRideCleared = false;
      });
```

add:

```dart

      try {
        await DispatchService.start(rideId: requestRef.id);
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.bookingRequestError)),
        );
      }
```

(This nests inside the existing outer `try { ... } catch (_) { ...bookingRequestError... }` block that already wraps the whole method — leave that outer block exactly as-is.)

- [ ] **Step 3: Verify it compiles**

Run: `cd Yame/YAME && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
cd Yame/YAME
git add lib/services/dispatch_service.dart lib/features/booking/booking_screen.dart
git commit -m "feat: call the server dispatch endpoint after creating a ride request"
```

---

### Task 10: Flutter — driver offer card (replaces the old accept-race list)

**Files:**
- Create: `Yame/YAME/lib/services/dispatch_response_service.dart`
- Modify: `Yame/YAME/lib/features/driver/driver_home_screen.dart`
- Modify: `Yame/YAME/lib/core/constants/app_strings.dart`

**Interfaces:**
- Produces: `DispatchResponseService.respond({required String rideId, required bool accept})`, `DispatchResponseException`.
- Removes: `_DriverHomeScreenState._accept` (Firestore transaction), replaced by `_respondToOffer`.
- Removes: `_PendingRequestsList` (browses *all* searching requests), replaced by `_RideOfferCard` (shows the *one* request offered to this driver, with a countdown).

- [ ] **Step 1: Add the "Refuser" string**

In `Yame/YAME/lib/core/constants/app_strings.dart`, near `driverAccept`, add:

```dart
  static const driverDecline = 'Refuser';
  static const driverOfferExpiresIn = 'Répondez avant';
```

- [ ] **Step 2: Write `DispatchResponseService`**

Create `Yame/YAME/lib/services/dispatch_response_service.dart`:

```dart
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../core/constants/app_config.dart';

class DispatchResponseException implements Exception {
  DispatchResponseException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Répond (accepter/refuser) à une offre de course reçue du dispatch
/// serveur — voir `yame-admin/app/api/rides/respond`. Le chauffeur n'écrit
/// plus jamais lui-même status/driverUid sur ride_requests.
class DispatchResponseService {
  DispatchResponseService._();

  static Future<void> respond({required String rideId, required bool accept}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw DispatchResponseException('Vous devez être connecté.');
    }
    final idToken = await user.getIdToken();

    final response = await http.post(
      Uri.parse('${AppConfig.adminApiBaseUrl}/api/rides/respond'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({'rideId': rideId, 'accept': accept}),
    );

    Map<String, dynamic>? body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      body = null;
    }

    if (response.statusCode != 200 || body?['success'] != true) {
      throw DispatchResponseException(
        body?['error'] as String? ?? 'Réponse impossible, réessayez.',
      );
    }
  }
}
```

- [ ] **Step 3: Replace `_accept` with `_respondToOffer`**

In `Yame/YAME/lib/features/driver/driver_home_screen.dart`, add the import:

```dart
import '../../services/dispatch_response_service.dart';
```

Delete the entire `_accept` method (lines 97-139, from `Future<void> _accept(RideRequest request) async {` through its closing `}`) and replace it with:

```dart
  Future<void> _respondToOffer(RideRequest request, bool accept) async {
    final id = request.id;
    if (id == null) return;
    try {
      await DispatchResponseService.respond(rideId: id, accept: accept);
      if (!mounted || !accept) return;
      setState(() => _activeRideId = id);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.driverRequestTaken)),
      );
    }
  }
```

- [ ] **Step 4: Replace `_PendingRequestsList` with `_RideOfferCard`**

In the same file, change the call site:

```dart
                            : _PendingRequestsList(
                                vehicleType: _vehicleType,
                                onAccept: _accept,
                              ),
```

to:

```dart
                            : _RideOfferCard(
                                onRespond: _respondToOffer,
                              ),
```

Replace the entire `_PendingRequestsList` class (from `class _PendingRequestsList extends StatelessWidget {` through its closing `}`, just before `class _ActiveRide extends StatelessWidget {`) with:

```dart
class _RideOfferCard extends StatelessWidget {
  const _RideOfferCard({required this.onRespond});

  final void Function(RideRequest request, bool accept) onRespond;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: uid == null
          ? null
          : FirebaseFirestore.instance
              .collection('ride_requests')
              .where('offeredUid', isEqualTo: uid)
              .where('status', isEqualTo: RideStatus.searching.firestoreValue)
              .limit(1)
              .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.search_rounded,
                    size: 40,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppStrings.driverNoRequests,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          );
        }

        final request = RideRequest.fromDoc(docs.first);
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.clientName.isNotEmpty ? request.clientName : AppStrings.driverClient,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                _AddressRow(
                  icon: Icons.circle,
                  iconColor: AppColors.success,
                  label: AppStrings.driverPickup,
                  address: request.pickupAddress,
                ),
                const SizedBox(height: 8),
                _AddressRow(
                  icon: Icons.location_on,
                  iconColor: AppColors.accent,
                  label: AppStrings.driverDestination,
                  address: request.destinationAddress,
                ),
                if (request.offerExpiresAt != null) ...[
                  const SizedBox(height: 12),
                  _OfferCountdown(expiresAt: request.offerExpiresAt!),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => onRespond(request, false),
                        child: const Text(AppStrings.driverDecline),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => onRespond(request, true),
                        child: const Text(AppStrings.driverAccept),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OfferCountdown extends StatefulWidget {
  const _OfferCountdown({required this.expiresAt});

  final DateTime expiresAt;

  @override
  State<_OfferCountdown> createState() => _OfferCountdownState();
}

class _OfferCountdownState extends State<_OfferCountdown> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.expiresAt.difference(DateTime.now()).inSeconds;
    final seconds = remaining > 0 ? remaining : 0;
    return Text(
      '${AppStrings.driverOfferExpiresIn} ${seconds}s',
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.accentBright),
    );
  }
}
```

Add the `dart:async` import at the top of the file (needed for `Timer`):

```dart
import 'dart:async';
```

- [ ] **Step 5: Verify it compiles**

Run: `cd Yame/YAME && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
cd Yame/YAME
git add lib/services/dispatch_response_service.dart lib/features/driver/driver_home_screen.dart lib/core/constants/app_strings.dart
git commit -m "feat: replace the driver accept-race list with a single-offer card and countdown"
```

---

### Task 11: Manual end-to-end verification on the emulator

**Files:** none (verification only).

- [ ] **Step 1: Fill in real config for local testing**

In `Yame/YAME/lib/core/constants/app_config.dart`, temporarily set `adminApiBaseUrl` to the machine's LAN IP and port running `yame-admin` (e.g. `http://192.168.x.x:3000` — the Android emulator cannot reach `localhost` of the host machine directly; use the host's actual LAN IP, or `10.0.2.2` for the standard Android emulator loopback-to-host address). Do not commit this temporary value if it differs from the real placeholder.

- [ ] **Step 2: Start yame-admin**

```bash
cd Yame/yame-admin && npm run dev
```

- [ ] **Step 3: Build and install the Flutter app**

Follow `Yame/YAME/.claude/skills/run-yame/driver.sh` (`build`, `boot-emulator`, `install`, `launch`) as documented in that skill.

- [ ] **Step 4: Create three test accounts**

One client account and two driver accounts (both car, both approved — use the admin panel or `yame-admin/scripts/make-admin.mjs`-style throwaway script to approve them and set a positive wallet balance), one driver physically "closer" (seed its `driver_profiles/{uid}/location/current` near the test pickup point) than the other.

- [ ] **Step 5: Run the scenario**

As the client, request a ride from a pickup point near both test drivers. Confirm:
- The closer driver's app shows the offer card with a live countdown.
- The farther driver's app shows "Aucune demande" (no offer) while the first offer is pending.
- Let the closer driver's offer expire (or tap "Refuser") — within ~1-2s after the 12s timeout, confirm the farther driver's app now shows the offer.
- Accept on the farther driver's app — confirm the client's screen flips to "Chauffeur trouvé" with the farther driver's name, and the closer driver's app shows no active offer.

- [ ] **Step 6: Clean up test accounts**

Delete the three test accounts and their Firestore data (Auth + `driver_profiles` recursive delete + the test `ride_requests` doc) via a throwaway Node script using `yame-admin/.env.local` credentials, per the pattern noted in the `yame-driver-online-persistence-fix` memory.

- [ ] **Step 7: Revert the temporary config**

Revert `Yame/YAME/lib/core/constants/app_config.dart` to its placeholder value if Step 1 changed it, unless a real production URL is already known — in which case commit that real value instead.

```bash
cd Yame/YAME && git status lib/core/constants/app_config.dart
# If it still holds a temporary LAN IP, revert it; if it holds the real
# deployed yame-admin URL, commit it.
```

---

## Self-Review Notes

- **Spec coverage:** every section of the spec (data model, workflow mechanics, both API routes, driver app changes, client app changes, firestore.rules changes, error handling table, testing plan) maps to a task above. The spec's "Observabilité" section (`dispatchCandidates`/`rejectedBy` visible in the admin `/courses` page) is satisfied by Task 5 writing those fields — no separate admin-UI task was in the spec, so none was added here (YAGNI: the fields exist and are queryable/visible via Firestore console today; a dedicated admin UI surface for them was never requested).
- **Type consistency checked:** `dispatchHookToken(rideId, driverUid)` has the same signature everywhere it's used (Task 5's workflow, Task 6's respond route, Task 7's test). `RideStatus.noDriverFound` / `'noDriverFound'` string matches between Task 3 (Dart enum), Task 5 (TS status string), and Task 8 (switch branch). `offerExpiresAt` is written as an ISO string in Task 5 and parsed with `DateTime.tryParse` in Task 3/10 — no `Timestamp` mismatch.
- **`confirmAssignment` restores the pre-existing side effects** of the old client-side `_accept` transaction (`driver_profiles/{uid}/location/current.activeClientUid`, `users/{uid}.driverActiveRideId`) that a naive server-side rewrite would have silently dropped — verified against the current `_accept` implementation before writing Task 5.
