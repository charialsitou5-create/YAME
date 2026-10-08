// Tests des règles Firestore (../firestore.rules) via l'émulateur.
// Lancer : `npm test` (nécessite Java 11+, voir README.md). Projet "demo-*" :
// aucune connexion à un vrai projet Firebase.
import { readFileSync } from 'node:fs';
import { before, after, beforeEach, describe, it } from 'node:test';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc, addDoc, collection } from 'firebase/firestore';

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-yame',
    firestore: { rules: readFileSync('../firestore.rules', 'utf8') },
  });
});
after(async () => env?.cleanup());
beforeEach(async () => env.clearFirestore());

const db = (uid) => env.authenticatedContext(uid).firestore();
// Écrit en contournant les règles (équivalent Admin SDK).
const seed = (fn) => env.withSecurityRulesDisabled(async (ctx) => fn(ctx.firestore()));

const ride = (over = {}) => ({
  clientUid: 'cli',
  clientName: 'Client',
  status: 'searching',
  driverUid: null,
  vehicleType: 'car',
  ...over,
});

describe('wallet chauffeur', () => {
  it('le chauffeur ne peut pas se créditer (update)', async () => {
    await seed((d) => setDoc(doc(d, 'driver_profiles/drv/wallet/current'), { balance: 0 }));
    await assertFails(updateDoc(doc(db('drv'), 'driver_profiles/drv/wallet/current'), { balance: 99999 }));
  });
  it('création uniquement avec balance 0', async () => {
    await assertSucceeds(setDoc(doc(db('drv'), 'driver_profiles/drv/wallet/current'), { balance: 0 }));
    await assertFails(setDoc(doc(db('drv2'), 'driver_profiles/drv2/wallet/current'), { balance: 5000 }));
  });
  it('un client ne peut ni lire ni écrire le wallet d\'un chauffeur', async () => {
    await seed((d) => setDoc(doc(d, 'driver_profiles/drv/wallet/current'), { balance: 100 }));
    await assertFails(getDoc(doc(db('cli'), 'driver_profiles/drv/wallet/current')));
    await assertFails(setDoc(doc(db('cli'), 'driver_profiles/drv/wallet/current'), { balance: 0 }));
  });
  it('le chauffeur lit son propre wallet', async () => {
    await seed((d) => setDoc(doc(d, 'driver_profiles/drv/wallet/current'), { balance: 100 }));
    await assertSucceeds(getDoc(doc(db('drv'), 'driver_profiles/drv/wallet/current')));
  });
});

describe('driver_profiles', () => {
  it('le chauffeur ne peut pas changer son status', async () => {
    await seed((d) => setDoc(doc(d, 'driver_profiles/drv'), { status: 'pending_verification', model: 'A' }));
    await assertFails(updateDoc(doc(db('drv'), 'driver_profiles/drv'), { status: 'approved' }));
    await assertSucceeds(updateDoc(doc(db('drv'), 'driver_profiles/drv'), { model: 'B' }));
  });
  it('création uniquement en pending_verification', async () => {
    await assertFails(setDoc(doc(db('drv'), 'driver_profiles/drv'), { status: 'approved' }));
    await assertSucceeds(setDoc(doc(db('drv'), 'driver_profiles/drv'), { status: 'pending_verification' }));
  });
  it('fiche non approuvée invisible pour autrui, approuvée visible', async () => {
    await seed(async (d) => {
      await setDoc(doc(d, 'driver_profiles/p'), { status: 'pending_verification' });
      await setDoc(doc(d, 'driver_profiles/a'), { status: 'approved' });
    });
    await assertFails(getDoc(doc(db('cli'), 'driver_profiles/p')));
    await assertSucceeds(getDoc(doc(db('cli'), 'driver_profiles/a')));
  });
  it('documents d\'identité jamais lisibles par autrui', async () => {
    await seed((d) => setDoc(doc(d, 'driver_profiles/a/documents/permis'), { url: 'x' }));
    await assertFails(getDoc(doc(db('cli'), 'driver_profiles/a/documents/permis')));
    await assertSucceeds(getDoc(doc(db('a'), 'driver_profiles/a/documents/permis')));
  });
});

describe('ride_requests : création et lecture', () => {
  it('un client crée sa demande en searching', async () => {
    await assertSucceeds(setDoc(doc(db('cli'), 'ride_requests/r1'), ride()));
  });
  it('refuse : créer pour un autre, ou avec un statut avancé', async () => {
    await assertFails(setDoc(doc(db('evil'), 'ride_requests/r1'), ride()));
    await assertFails(setDoc(doc(db('cli'), 'ride_requests/r1'), ride({ status: 'completed' })));
    await assertFails(setDoc(doc(db('cli'), 'ride_requests/r1'), ride({ offeredUid: 'drv' })));
  });
  it('lecture d\'une course d\'autrui interdite', async () => {
    await seed((d) => setDoc(doc(d, 'ride_requests/r1'), ride({ driverUid: 'drv', status: 'accepted' })));
    await assertFails(getDoc(doc(db('other'), 'ride_requests/r1')));
    await assertSucceeds(getDoc(doc(db('cli'), 'ride_requests/r1')));
    await assertSucceeds(getDoc(doc(db('drv'), 'ride_requests/r1')));
  });
  it('un chauffeur sollicité (offeredUid) peut lire l\'offre', async () => {
    await seed((d) => setDoc(doc(d, 'ride_requests/r1'), ride({ offeredUid: 'drv' })));
    await assertSucceeds(getDoc(doc(db('drv'), 'ride_requests/r1')));
  });
});

describe('ride_requests : transitions', () => {
  const setup = (status) =>
    seed((d) => setDoc(doc(d, 'ride_requests/r1'), ride({ driverUid: 'drv', status })));
  const upd = (uid, data) => updateDoc(doc(db(uid), 'ride_requests/r1'), data);

  it('chaîne légitime chauffeur : accepted -> arrived -> inProgress -> completed', async () => {
    await setup('accepted');
    await assertSucceeds(upd('drv', { status: 'arrived' }));
    await assertSucceeds(upd('drv', { status: 'inProgress' }));
    await assertSucceeds(upd('drv', { status: 'completed' }));
  });
  it('saut d\'étape interdit', async () => {
    await setup('accepted');
    await assertFails(upd('drv', { status: 'inProgress' }));
    await assertFails(upd('drv', { status: 'completed' }));
  });
  it('retour en arrière interdit', async () => {
    await setup('inProgress');
    await assertFails(upd('drv', { status: 'arrived' }));
  });
  it('le chauffeur ne peut pas modifier d\'autres champs (prix)', async () => {
    await setup('accepted');
    await assertFails(upd('drv', { status: 'arrived', price: 1 }));
  });
  it('un tiers ne peut pas faire avancer la course', async () => {
    await setup('accepted');
    await assertFails(upd('other', { status: 'arrived' }));
  });
  it('le client ne peut pas faire avancer la course ni se déclarer payé', async () => {
    await setup('accepted');
    await assertFails(upd('cli', { status: 'completed' }));
    await assertFails(upd('cli', { paid: true }));
    await setup('completed');
    await assertFails(upd('cli', { paid: true }));
  });
  it('le client annule tant que la course n\'a pas démarré, pas en cours', async () => {
    await setup('arrived');
    await assertSucceeds(upd('cli', { status: 'cancelled', cancelReason: 'x' }));
    await setup('inProgress');
    await assertFails(upd('cli', { status: 'cancelled' }));
  });
  it('le client note après la fin, pas avant', async () => {
    await setup('completed');
    await assertSucceeds(upd('cli', { rating: 5 }));
    await setup('inProgress');
    await assertFails(upd('cli', { rating: 5 }));
  });
  it('suppression interdite', async () => {
    await setup('searching');
    await assertFails(env.authenticatedContext('cli').firestore().doc('ride_requests/r1').delete());
  });
});

describe('messages de course', () => {
  beforeEach(() =>
    seed((d) => setDoc(doc(d, 'ride_requests/r1'), ride({ driverUid: 'drv', status: 'accepted' }))));

  it('client et chauffeur peuvent écrire/lire', async () => {
    await assertSucceeds(addDoc(collection(db('cli'), 'ride_requests/r1/messages'), { senderUid: 'cli', text: 'hi' }));
    await assertSucceeds(addDoc(collection(db('drv'), 'ride_requests/r1/messages'), { senderUid: 'drv', text: 'ok' }));
  });
  it('un tiers ne peut ni écrire ni lire', async () => {
    await seed((d) => setDoc(doc(d, 'ride_requests/r1/messages/m1'), { senderUid: 'cli', text: 'hi' }));
    await assertFails(addDoc(collection(db('other'), 'ride_requests/r1/messages'), { senderUid: 'other', text: 'x' }));
    await assertFails(getDoc(doc(db('other'), 'ride_requests/r1/messages/m1')));
    await assertSucceeds(getDoc(doc(db('drv'), 'ride_requests/r1/messages/m1')));
  });
  it('usurpation de senderUid interdite, messages immuables', async () => {
    await assertFails(addDoc(collection(db('cli'), 'ride_requests/r1/messages'), { senderUid: 'drv', text: 'x' }));
    await seed((d) => setDoc(doc(d, 'ride_requests/r1/messages/m1'), { senderUid: 'cli', text: 'hi' }));
    await assertFails(updateDoc(doc(db('cli'), 'ride_requests/r1/messages/m1'), { text: 'edit' }));
  });
});

describe('users.activeMode', () => {
  it('bascule bloquée pendant une course active, autorisée sinon', async () => {
    await seed(async (d) => {
      await setDoc(doc(d, 'users/u1'), { activeMode: 'client', clientActiveRideId: 'r1' });
      await setDoc(doc(d, 'users/u2'), { activeMode: 'client', clientActiveRideId: null });
      await setDoc(doc(d, 'users/u3'), { activeMode: 'driver', driverActiveRideId: 'r9' });
    });
    await assertFails(updateDoc(doc(db('u1'), 'users/u1'), { activeMode: 'driver' }));
    await assertSucceeds(updateDoc(doc(db('u2'), 'users/u2'), { activeMode: 'driver' }));
    await assertFails(updateDoc(doc(db('u3'), 'users/u3'), { activeMode: 'client' }));
  });
  it('autres champs modifiables même en course', async () => {
    await seed((d) => setDoc(doc(d, 'users/u1'), { activeMode: 'client', clientActiveRideId: 'r1' }));
    await assertSucceeds(updateDoc(doc(db('u1'), 'users/u1'), { name: 'N' }));
  });
  it('profil d\'autrui illisible', async () => {
    await seed((d) => setDoc(doc(d, 'users/u1'), { activeMode: 'client' }));
    await assertFails(getDoc(doc(db('u2'), 'users/u1')));
  });
});

describe('incidents', () => {
  it('lisibles uniquement par leur auteur', async () => {
    await seed((d) => setDoc(doc(d, 'incidents/i1'), { reporterUid: 'a', status: 'open' }));
    await assertSucceeds(getDoc(doc(db('a'), 'incidents/i1')));
    await assertFails(getDoc(doc(db('b'), 'incidents/i1')));
  });
  it('création en open pour soi seulement, jamais modifiable', async () => {
    await assertSucceeds(setDoc(doc(db('a'), 'incidents/i2'), { reporterUid: 'a', status: 'open' }));
    await assertFails(setDoc(doc(db('a'), 'incidents/i3'), { reporterUid: 'b', status: 'open' }));
    await assertFails(setDoc(doc(db('a'), 'incidents/i4'), { reporterUid: 'a', status: 'resolved' }));
    await assertFails(updateDoc(doc(db('a'), 'incidents/i2'), { status: 'resolved' }));
  });
});

describe('app_config', () => {
  it('lecture connecté, écriture jamais', async () => {
    await seed((d) => setDoc(doc(d, 'app_config/pricing'), { base: 1 }));
    await assertSucceeds(getDoc(doc(db('a'), 'app_config/pricing')));
    await assertFails(setDoc(doc(db('a'), 'app_config/pricing'), { base: 0 }));
    await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'app_config/pricing')));
  });
});
