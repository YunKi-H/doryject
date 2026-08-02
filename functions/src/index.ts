//
//  index.ts
//  BloodyDay Functions
//
//  Created by Yunki on 8/2/26.
//

import {initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";
import * as logger from "firebase-functions/logger";
import {setGlobalOptions} from "firebase-functions/v2/options";
import {onDocumentWritten} from "firebase-functions/v2/firestore";

initializeApp();

setGlobalOptions({
  maxInstances: 10,
  region: "asia-northeast3",
});

interface ConnectionRequestData {
  senderID?: string;
  senderDisplayName?: string;
  recipientID?: string;
  status?: string;
}

interface DeviceRegistration {
  token: string;
  documentPaths: string[];
}

const invalidTokenErrorCodes = new Set([
  "messaging/invalid-registration-token",
  "messaging/registration-token-not-registered",
]);

export const notifyCalendarConnectionRequest = onDocumentWritten(
  "connectionRequests/{requestID}",
  async (event) => {
    const before = event.data?.before.data() as
      ConnectionRequestData | undefined;
    const after = event.data?.after.data() as
      ConnectionRequestData | undefined;

    if (!shouldNotify(before, after)) {
      return;
    }

    const recipientID = after?.recipientID;
    const senderID = after?.senderID;
    if (!recipientID || !senderID) {
      logger.warn("Connection request is missing participant IDs", {
        requestID: event.params.requestID,
      });
      return;
    }

    const registrations = await loadDeviceRegistrations(recipientID);
    if (registrations.length === 0) {
      logger.info("No registered recipient devices", {
        recipientID,
        requestID: event.params.requestID,
      });
      return;
    }

    const senderName = normalizedSenderName(after?.senderDisplayName);
    const invalidDocumentPaths: string[] = [];
    let successCount = 0;
    let failureCount = 0;

    for (const registrationChunk of chunks(registrations, 500)) {
      const response = await getMessaging().sendEachForMulticast({
        tokens: registrationChunk.map((registration) => registration.token),
        notification: {
          title: "캘린더 연결 요청",
          body: `${senderName}님이 캘린더 연결을 요청했어요.`,
        },
        data: {
          type: "calendarConnectionRequest",
          requestID: event.params.requestID,
          senderID,
          route: "calendarSharing",
        },
        apns: {
          headers: {
            "apns-priority": "10",
          },
          payload: {
            aps: {
              badge: 1,
              sound: "default",
              threadId: "calendar-connection-requests",
            },
          },
        },
      });

      successCount += response.successCount;
      failureCount += response.failureCount;
      response.responses.forEach((sendResponse, index) => {
        if (sendResponse.success ||
            !isInvalidTokenError(sendResponse.error?.code)) {
          return;
        }
        invalidDocumentPaths.push(
          ...registrationChunk[index].documentPaths
        );
      });
    }

    await deleteInvalidRegistrations(invalidDocumentPaths);
    logger.info("Connection request notification completed", {
      recipientID,
      requestID: event.params.requestID,
      successCount,
      failureCount,
      invalidRegistrationCount: invalidDocumentPaths.length,
    });
  }
);

/**
 * Returns whether a request write should produce a notification.
 * @param {ConnectionRequestData|undefined} before Previous request data.
 * @param {ConnectionRequestData|undefined} after Current request data.
 * @return {boolean} Whether the recipient should be notified.
 */
function shouldNotify(
  before: ConnectionRequestData | undefined,
  after: ConnectionRequestData | undefined
): boolean {
  if (!after || after.status !== "pending") {
    return false;
  }
  return before?.status !== "pending";
}

/**
 * Loads and deduplicates a user's registered FCM tokens.
 * @param {string} userID Recipient Firebase Auth user ID.
 * @return {Promise<DeviceRegistration[]>} Device registrations by token.
 */
async function loadDeviceRegistrations(
  userID: string
): Promise<DeviceRegistration[]> {
  const snapshot = await getFirestore()
    .collection("users")
    .doc(userID)
    .collection("devices")
    .get();
  const pathsByToken = new Map<string, string[]>();

  snapshot.docs.forEach((document) => {
    const token = document.get("fcmToken");
    if (typeof token !== "string" || token.length === 0) {
      return;
    }
    const paths = pathsByToken.get(token) ?? [];
    paths.push(document.ref.path);
    pathsByToken.set(token, paths);
  });

  return Array.from(pathsByToken, ([token, documentPaths]) => ({
    token,
    documentPaths,
  }));
}

/**
 * Removes device documents rejected by FCM as permanently invalid.
 * @param {string[]} paths Firestore device document paths.
 * @return {Promise<void>} Completion of all requested deletes.
 */
async function deleteInvalidRegistrations(paths: string[]): Promise<void> {
  const uniquePaths = [...new Set(paths)];
  await Promise.all(
    uniquePaths.map((path) => getFirestore().doc(path).delete())
  );
}

/**
 * Returns whether an FCM error means the token should be removed.
 * @param {string|undefined} code Firebase Messaging error code.
 * @return {boolean} Whether the device registration is permanently invalid.
 */
function isInvalidTokenError(code: string | undefined): boolean {
  return code !== undefined && invalidTokenErrorCodes.has(code);
}

/**
 * Returns a nonempty display name for the notification body.
 * @param {string|undefined} displayName Request sender display name.
 * @return {string} Display name suitable for user-facing text.
 */
function normalizedSenderName(displayName: string | undefined): string {
  const trimmedName = displayName?.trim();
  return trimmedName && trimmedName.length > 0 ? trimmedName : "상대방";
}

/**
 * Splits values into FCM multicast-sized groups.
 * @param {Array<*>} values Values to split.
 * @param {number} size Maximum values per group.
 * @return {Array<Array<*>>} Chunked values.
 */
function chunks<T>(values: T[], size: number): T[][] {
  const result: T[][] = [];
  for (let index = 0; index < values.length; index += size) {
    result.push(values.slice(index, index + size));
  }
  return result;
}
