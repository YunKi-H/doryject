//
//  firestore.rules.test.mjs
//  BloodyDay
//
//  Created by Yunki on 7/26/26.
//

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment
} from "@firebase/rules-unit-testing";
import {
  deleteDoc,
  doc,
  getDoc,
  serverTimestamp,
  setDoc,
  updateDoc,
  writeBatch
} from "firebase/firestore";
import { after, afterEach, before, describe, test } from "node:test";
import { readFileSync } from "node:fs";

const projectID = "demo-bloodyday-rules";
const ownerID = "owner";
const viewerID = "viewer";
const outsiderID = "outsider";
const connectionID = `${ownerID}_${viewerID}`;
const eventID = "period-20260726";

let testEnvironment;

before(async () => {
  testEnvironment = await initializeTestEnvironment({
    projectId: projectID,
    firestore: {
      rules: readFileSync("firestore.rules", "utf8")
    }
  });
});

afterEach(async () => {
  await testEnvironment.clearFirestore();
});

after(async () => {
  await testEnvironment.cleanup();
});

function databaseFor(userID) {
  return testEnvironment
    .authenticatedContext(userID)
    .firestore();
}

function unauthenticatedDatabase() {
  return testEnvironment
    .unauthenticatedContext()
    .firestore();
}

function connectionReference(database) {
  return doc(database, "connections", connectionID);
}

function eventReference(database) {
  return doc(
    database,
    "connections",
    connectionID,
    "events",
    eventID
  );
}

function requestReference(database) {
  return doc(database, "connectionRequests", connectionID);
}

function membershipReference(database, userID) {
  return doc(database, "connectionMemberships", userID);
}

async function seedActiveConnection() {
  await testEnvironment.withSecurityRulesDisabled(async context => {
    const database = context.firestore();
    await setDoc(requestReference(database), {
      senderID: ownerID,
      senderDisplayName: "Owner",
      recipientID: viewerID,
      status: "accepted",
      createdAt: new Date("2026-07-26T00:00:00Z")
    });
    await setDoc(connectionReference(database), {
      ownerID,
      ownerDisplayName: "Owner",
      viewerID,
      viewerDisplayName: "Viewer",
      participantIDs: [ownerID, viewerID],
      sharedPeriod: true,
      sharedPill: true,
      sharedLove: true,
      status: "active",
      createdAt: new Date("2026-07-26T00:00:00Z")
    });
    const membership = {
      connectionID,
      participantIDs: [ownerID, viewerID],
      createdAt: new Date("2026-07-26T00:00:00Z")
    };
    await setDoc(membershipReference(database, ownerID), {
      ...membership,
      userID: ownerID
    });
    await setDoc(membershipReference(database, viewerID), {
      ...membership,
      userID: viewerID
    });
    await setDoc(eventReference(database), {
      ownerID,
      eventID,
      dayKey: 20260726,
      typeRaw: "period",
      updatedAt: new Date("2026-07-26T00:00:00Z")
    });
  });
}

async function markTerminating(database, requestedBy) {
  await updateDoc(connectionReference(database), {
    status: "terminating",
    terminationRequestedBy: requestedBy,
    terminationStartedAt: serverTimestamp()
  });
}

describe("calendar connection access", () => {
  test("only participants can read a connection and its events", async () => {
    await seedActiveConnection();

    await assertSucceeds(getDoc(connectionReference(databaseFor(ownerID))));
    await assertSucceeds(getDoc(connectionReference(databaseFor(viewerID))));
    await assertSucceeds(getDoc(eventReference(databaseFor(ownerID))));
    await assertSucceeds(getDoc(eventReference(databaseFor(viewerID))));

    await assertFails(getDoc(connectionReference(databaseFor(outsiderID))));
    await assertFails(getDoc(eventReference(databaseFor(outsiderID))));
    await assertFails(
      getDoc(connectionReference(unauthenticatedDatabase()))
    );
  });

  test("only the owner can edit sharing settings and active events", async () => {
    await seedActiveConnection();
    const ownerDatabase = databaseFor(ownerID);
    const viewerDatabase = databaseFor(viewerID);

    await assertSucceeds(
      updateDoc(connectionReference(ownerDatabase), {
        sharedPill: false,
        sharingUpdatedAt: serverTimestamp(),
        sharingUpdatedBy: ownerID
      })
    );
    await assertFails(
      updateDoc(connectionReference(viewerDatabase), {
        sharedPill: false,
        sharingUpdatedAt: serverTimestamp(),
        sharingUpdatedBy: viewerID
      })
    );

    const secondEventID = "pill-20260727";
    const ownerEventReference = doc(
      ownerDatabase,
      "connections",
      connectionID,
      "events",
      secondEventID
    );
    const viewerEventReference = doc(
      viewerDatabase,
      "connections",
      connectionID,
      "events",
      secondEventID
    );
    const eventData = {
      ownerID,
      eventID: secondEventID,
      dayKey: 20260727,
      typeRaw: "pill",
      updatedAt: serverTimestamp()
    };

    await assertSucceeds(setDoc(ownerEventReference, eventData));
    await assertFails(setDoc(viewerEventReference, eventData));
  });
});

describe("calendar connection termination", () => {
  test("either participant can request termination but an outsider cannot", async () => {
    await seedActiveConnection();

    await assertFails(
      markTerminating(databaseFor(outsiderID), outsiderID)
    );
    await assertSucceeds(
      markTerminating(databaseFor(viewerID), viewerID)
    );
  });

  test("active connection documents cannot be deleted directly", async () => {
    await seedActiveConnection();
    const ownerDatabase = databaseFor(ownerID);

    await assertFails(deleteDoc(connectionReference(ownerDatabase)));
    await assertFails(deleteDoc(requestReference(ownerDatabase)));
    await assertFails(
      deleteDoc(membershipReference(ownerDatabase, viewerID))
    );
  });

  test("participant can clean up all shared data after termination starts", async () => {
    await seedActiveConnection();
    const viewerDatabase = databaseFor(viewerID);
    await assertSucceeds(
      markTerminating(viewerDatabase, viewerID)
    );

    await assertSucceeds(deleteDoc(eventReference(viewerDatabase)));

    const batch = writeBatch(viewerDatabase);
    batch.delete(requestReference(viewerDatabase));
    batch.delete(membershipReference(viewerDatabase, ownerID));
    batch.delete(membershipReference(viewerDatabase, viewerID));
    batch.delete(connectionReference(viewerDatabase));
    await assertSucceeds(batch.commit());
  });

  test("terminating connection rejects new event writes and outsider cleanup", async () => {
    await seedActiveConnection();
    const ownerDatabase = databaseFor(ownerID);
    const outsiderDatabase = databaseFor(outsiderID);
    await assertSucceeds(
      markTerminating(ownerDatabase, ownerID)
    );

    const newEventID = "love-20260727";
    const newEventReference = doc(
      ownerDatabase,
      "connections",
      connectionID,
      "events",
      newEventID
    );
    await assertFails(
      setDoc(newEventReference, {
        ownerID,
        eventID: newEventID,
        dayKey: 20260727,
        typeRaw: "love",
        updatedAt: serverTimestamp()
      })
    );
    await assertFails(deleteDoc(eventReference(outsiderDatabase)));
    await assertFails(deleteDoc(connectionReference(outsiderDatabase)));
  });
});
