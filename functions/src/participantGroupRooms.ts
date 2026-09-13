import * as admin from "firebase-admin";
import {CallableRequest, HttpsError, onCall} from "firebase-functions/v2/https";
import {db} from "./helpers";
import {
  canManageParticipantGroups,
  isParticipantGroupRoom,
  maximumParticipantGroupMembers,
  minimumParticipantGroupMembers,
  participantGroupScopeSentinel,
  participantRecordsMatchOrganization,
  sameParticipantIds,
} from "./participantGroupRoomLogic";

type RequestRecord = Record<string, unknown>;

const runtime = {
  timeoutSeconds: 60,
  memory: "256MiB" as const,
};

function requiredString(value: unknown, field: string, maximumLength = 200): string {
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", `${field} is required.`);
  }
  const trimmed = value.trim();
  if (trimmed.length === 0 || trimmed.length > maximumLength) {
    throw new HttpsError(
      "invalid-argument",
      `${field} must be between 1 and ${maximumLength} characters.`,
    );
  }
  return trimmed;
}

function requestData(request: CallableRequest): RequestRecord {
  if (request.data == null || typeof request.data !== "object" ||
      Array.isArray(request.data)) {
    throw new HttpsError("invalid-argument", "Group Chat details are required.");
  }
  return request.data as RequestRecord;
}

function assertSupportedFields(data: RequestRecord, supported: string[]): void {
  const allowed = new Set(supported);
  if (Object.keys(data).some((field) => !allowed.has(field))) {
    throw new HttpsError(
      "invalid-argument",
      "Group Chat details include unsupported fields.",
    );
  }
}

function participantIds(
  value: unknown,
  field: string,
  minimum = minimumParticipantGroupMembers,
): string[] {
  if (!Array.isArray(value) ||
      value.length < minimum ||
      value.length > maximumParticipantGroupMembers) {
    throw new HttpsError(
      "invalid-argument",
      `${field} must contain between ${minimum} and ` +
        `${maximumParticipantGroupMembers} people.`,
    );
  }
  const ids = value.map((item, index) =>
    requiredString(item, `${field}[${index}]`),
  );
  if (new Set(ids).size !== ids.length) {
    throw new HttpsError("invalid-argument", `${field} must contain unique user IDs.`);
  }
  return ids;
}

async function loadActor(userId: string, orgId: string) {
  const snapshot = await db.collection("users").doc(userId).get();
  const actor = snapshot.data();
  if (!snapshot.exists || !canManageParticipantGroups(
    {...actor, id: snapshot.id},
    orgId,
  )) {
    throw new HttpsError(
      "permission-denied",
      "Only a Platform Owner or organization Admin can manage Group Chats.",
    );
  }
  return actor ?? {};
}

function assertValidParticipantSnapshots(
  orgId: string,
  ids: string[],
  snapshots: FirebaseFirestore.DocumentSnapshot[],
): void {
  const records = snapshots
    .filter((snapshot) => snapshot.exists)
    .map((snapshot) => ({id: snapshot.id, ...snapshot.data()}));
  if (!participantRecordsMatchOrganization(ids, orgId, records)) {
    throw new HttpsError(
      "invalid-argument",
      "Every Group Chat participant must be an active user in this organization.",
    );
  }
}

export const adminCreateParticipantGroupRoom = onCall(
  runtime,
  async (request: CallableRequest) => {
    const userId = request.auth?.uid;
    if (!userId) throw new HttpsError("unauthenticated", "Sign in is required.");
    const data = requestData(request);
    assertSupportedFields(data, ["orgId", "name", "participantIds"]);
    const orgId = requiredString(data.orgId, "orgId");
    const name = requiredString(data.name, "name", 120);
    const ids = participantIds(data.participantIds, "participantIds");
    const actor = await loadActor(userId, orgId);
    if (actor.orgId === orgId && !ids.includes(userId)) {
      throw new HttpsError(
        "invalid-argument",
        "The person creating a Group Chat must be included as a participant.",
      );
    }
    const roomRef = db.collection("organizations").doc(orgId)
      .collection("chatRooms").doc();
    const auditRef = db.collection("organizations").doc(orgId)
      .collection("auditLogs").doc();
    const sortedIds = [...ids].sort();
    const timestamp = admin.firestore.FieldValue.serverTimestamp();
    await db.runTransaction(async (transaction) => {
      const snapshots = await transaction.getAll(
        ...sortedIds.map((id) => db.collection("users").doc(id)),
      );
      assertValidParticipantSnapshots(orgId, sortedIds, snapshots);
      transaction.set(roomRef, {
        orgId,
        name,
        type: "event",
        roomPurpose: "group",
        accessMode: "participants",
        leagueId: null,
        // Sentinels keep released assignment-based clients from accidentally
        // treating this room as organization-wide.
        hubId: participantGroupScopeSentinel,
        teamId: participantGroupScopeSentinel,
        hubIds: [],
        teamIds: [],
        additionalMemberIds: [],
        participants: sortedIds,
        isArchived: false,
        createdAt: timestamp,
        createdBy: userId,
        updatedAt: timestamp,
        updatedBy: userId,
        lastMessage: null,
        lastMessageAt: timestamp,
        lastMessageBy: null,
        roomIconName: "group",
        roomImageUrl: null,
      });
      transaction.set(auditRef, {
        action: "adminCreateParticipantGroupRoom",
        actorId: userId,
        actorName: actor.displayName ?? actor.email ?? userId,
        actorEmail: actor.email ?? null,
        actorRole: actor.role,
        request: {name, participantIds: sortedIds},
        result: {roomId: roomRef.id, participantCount: sortedIds.length},
        createdAt: timestamp,
      });
    });
    return {roomId: roomRef.id, participantIds: sortedIds};
  },
);

export const adminUpdateParticipantGroupRoomMembers = onCall(
  runtime,
  async (request: CallableRequest) => {
    const userId = request.auth?.uid;
    if (!userId) throw new HttpsError("unauthenticated", "Sign in is required.");
    const data = requestData(request);
    assertSupportedFields(data, [
      "orgId", "roomId", "expectedParticipantIds", "participantIds",
    ]);
    const orgId = requiredString(data.orgId, "orgId");
    const roomId = requiredString(data.roomId, "roomId");
    const expectedIds = participantIds(
      data.expectedParticipantIds,
      "expectedParticipantIds",
      0,
    );
    const requestedIds = participantIds(data.participantIds, "participantIds");
    const actor = await loadActor(userId, orgId);
    const roomRef = db.collection("organizations").doc(orgId)
      .collection("chatRooms").doc(roomId);
    const auditRef = db.collection("organizations").doc(orgId)
      .collection("auditLogs").doc();
    const sortedIds = [...requestedIds].sort();
    const addedIds = sortedIds.filter((id) => !expectedIds.includes(id));
    const removedIds = expectedIds.filter((id) => !sortedIds.includes(id));

    await db.runTransaction(async (transaction) => {
      const [roomSnapshot, ...requestedSnapshots] = await transaction.getAll(
        roomRef,
        ...sortedIds.map((id) => db.collection("users").doc(id)),
      );
      assertValidParticipantSnapshots(orgId, sortedIds, requestedSnapshots);
      const room = roomSnapshot.data();
      const currentIds = Array.isArray(room?.participants) ?
        room.participants.filter((id): id is string => typeof id === "string") : [];
      if (!roomSnapshot.exists || room?.orgId !== orgId ||
          !isParticipantGroupRoom(room ?? {})) {
        throw new HttpsError(
          "failed-precondition",
          "Only active participant-only Group Chats can have their members edited.",
        );
      }
      if (!sameParticipantIds(currentIds, expectedIds)) {
        throw new HttpsError(
          "aborted",
          "This Group Chat changed after it was opened. Refresh and try again.",
        );
      }
      transaction.update(roomRef, {
        participants: sortedIds,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedBy: userId,
      });
      transaction.set(auditRef, {
        action: "adminUpdateParticipantGroupRoomMembers",
        actorId: userId,
        actorName: actor.displayName ?? actor.email ?? userId,
        actorEmail: actor.email ?? null,
        actorRole: actor.role,
        request: {roomId, expectedParticipantIds: [...expectedIds].sort()},
        result: {
          roomId,
          participantIds: sortedIds,
          addedParticipantIds: addedIds,
          removedParticipantIds: removedIds,
        },
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    return {
      roomId,
      participantIds: sortedIds,
      addedParticipantIds: addedIds,
      removedParticipantIds: removedIds,
    };
  },
);
