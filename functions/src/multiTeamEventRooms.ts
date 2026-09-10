import * as admin from "firebase-admin";
import {CallableRequest, HttpsError, onCall} from "firebase-functions/v2/https";
import {db} from "./helpers";
import {
  MultiTeamTarget,
  belongsToMultiTeamEventRoomAudience,
  canCreateMultiTeamEventRoom,
  canEditMultiTeamEventRoomAudience,
  existingEventRoomAudience,
  maximumMultiTeamEventRoomTeams,
  multiTeamLegacyScopeSentinel,
  sameMultiTeamAudience,
} from "./multiTeamEventRoomLogic";
import {
  existingAdditionalMemberIds,
  isAdditionalRoomMemberCandidate,
  isRoomEligibleForAdditionalMembers,
  maximumAdditionalRoomMembers,
  sameAdditionalMemberIds,
} from "./roomAdditionalMembersLogic";

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

function parseTargets(value: unknown): MultiTeamTarget[] {
  if (!Array.isArray(value) || value.length === 0 ||
      value.length > maximumMultiTeamEventRoomTeams) {
    throw new HttpsError(
      "invalid-argument",
      `Select between 1 and ${maximumMultiTeamEventRoomTeams} teams.`,
    );
  }
  const targets = value.map((item, index) => {
    if (item == null || typeof item !== "object" || Array.isArray(item)) {
      throw new HttpsError("invalid-argument", `teams[${index}] is invalid.`);
    }
    const record = item as RequestRecord;
    const keys = Object.keys(record).sort();
    if (keys.length !== 2 || keys[0] !== "hubId" || keys[1] !== "teamId") {
      throw new HttpsError(
        "invalid-argument",
        `teams[${index}] must contain only hubId and teamId.`,
      );
    }
    return {
      hubId: requiredString(record.hubId, `teams[${index}].hubId`),
      teamId: requiredString(record.teamId, `teams[${index}].teamId`),
    };
  });
  if (new Set(targets.map((target) => target.teamId)).size !== targets.length) {
    throw new HttpsError("invalid-argument", "Each selected team must be unique.");
  }
  return targets;
}

function parseTeamIds(value: unknown, field: string, allowEmpty = false): string[] {
  if (!Array.isArray(value) || (!allowEmpty && value.length === 0) ||
      value.length > maximumMultiTeamEventRoomTeams) {
    throw new HttpsError(
      "invalid-argument",
      `${field} must contain between ${allowEmpty ? 0 : 1} and ` +
      `${maximumMultiTeamEventRoomTeams} team IDs.`,
    );
  }
  const ids = value.map((item, index) => requiredString(item, `${field}[${index}]`));
  if (new Set(ids).size !== ids.length) {
    throw new HttpsError("invalid-argument", `${field} must contain unique team IDs.`);
  }
  return ids;
}

function parseAdditionalMemberIds(value: unknown, field: string): string[] {
  if (!Array.isArray(value) || value.length > maximumAdditionalRoomMembers) {
    throw new HttpsError(
      "invalid-argument",
      `${field} must contain between 0 and ${maximumAdditionalRoomMembers} user IDs.`,
    );
  }
  const ids = value.map((item, index) => requiredString(item, `${field}[${index}]`));
  if (new Set(ids).size !== ids.length) {
    throw new HttpsError("invalid-argument", `${field} must contain unique user IDs.`);
  }
  return ids;
}

export const createMultiTeamEventRoom = onCall(runtime, async (request: CallableRequest) => {
  const userId = request.auth?.uid;
  if (!userId) throw new HttpsError("unauthenticated", "Sign in is required.");
  if (request.data == null || typeof request.data !== "object" || Array.isArray(request.data)) {
    throw new HttpsError("invalid-argument", "Room details are required.");
  }

  const data = request.data as RequestRecord;
  const supportedFields = new Set([
    "orgId", "name", "leagueId", "teams", "roomIconName",
  ]);
  if (Object.keys(data).some((field) => !supportedFields.has(field))) {
    throw new HttpsError("invalid-argument", "Room details include unsupported fields.");
  }
  const orgId = requiredString(data.orgId, "orgId");
  const leagueId = requiredString(data.leagueId, "leagueId");
  const name = requiredString(data.name, "name", 120);
  const roomIconName = requiredString(data.roomIconName, "roomIconName", 40);
  const targets = parseTargets(data.teams);

  const actorSnapshot = await db.collection("users").doc(userId).get();
  const actor = actorSnapshot.data();
  if (!actorSnapshot.exists || actor?.isActive !== true ||
      (actor.role !== "platformOwner" && actor.orgId !== orgId)) {
    throw new HttpsError("permission-denied", "You cannot create a room for this organization.");
  }

  const teamRefs = targets.map((target) => db
    .collection("organizations").doc(orgId)
    .collection("leagues").doc(leagueId)
    .collection("hubs").doc(target.hubId)
    .collection("teams").doc(target.teamId));
  const teamSnapshots = await db.getAll(...teamRefs);
  for (let index = 0; index < teamSnapshots.length; index += 1) {
    const team = teamSnapshots[index].data();
    const target = targets[index];
    if (!teamSnapshots[index].exists || team?.orgId !== orgId ||
        team?.leagueId !== leagueId || team?.hubId !== target.hubId) {
      throw new HttpsError(
        "invalid-argument",
        `Team ${target.teamId} is not in the selected Hub and league.`,
      );
    }
  }
  if (!canCreateMultiTeamEventRoom(actor ?? {}, targets)) {
    throw new HttpsError(
      "permission-denied",
      "Select teams that are all directly assigned to you or all within your assigned Hubs.",
    );
  }

  const usersSnapshot = await db.collection("users")
    .where("orgId", "==", orgId)
    .where("isActive", "==", true)
    .get();
  const participantIds = usersSnapshot.docs
    .filter((snapshot) => belongsToMultiTeamEventRoomAudience(
      {...snapshot.data(), id: snapshot.id},
      orgId,
      targets,
    ))
    .map((snapshot) => snapshot.id);
  if (!participantIds.includes(userId)) participantIds.push(userId);

  const hubIds = [...new Set(targets.map((target) => target.hubId))];
  const teamIds = targets.map((target) => target.teamId);
  const roomRef = db.collection("organizations").doc(orgId)
    .collection("chatRooms").doc();
  await roomRef.set({
    orgId,
    name,
    type: "event",
    roomPurpose: "event",
    leagueId,
    // Released clients query singular scope fields. Sentinels keep this room
    // out of those queries instead of leaking a broader or partial audience.
    hubId: multiTeamLegacyScopeSentinel,
    teamId: multiTeamLegacyScopeSentinel,
    hubIds,
    teamIds,
    participants: participantIds,
    isArchived: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    createdBy: userId,
    lastMessage: null,
    lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
    lastMessageBy: null,
    roomIconName,
    roomImageUrl: null,
  });

  return {roomId: roomRef.id};
});

export const adminUpdateEventRoomAudience = onCall(
  runtime,
  async (request: CallableRequest) => {
    const userId = request.auth?.uid;
    if (!userId) throw new HttpsError("unauthenticated", "Sign in is required.");
    if (request.data == null || typeof request.data !== "object" ||
        Array.isArray(request.data)) {
      throw new HttpsError("invalid-argument", "Room details are required.");
    }

    const data = request.data as RequestRecord;
    const supportedFields = new Set([
      "orgId", "roomId", "expectedTeamIds", "expectedAudienceScope", "teams",
    ]);
    if (Object.keys(data).some((field) => !supportedFields.has(field))) {
      throw new HttpsError("invalid-argument", "Room details include unsupported fields.");
    }
    const orgId = requiredString(data.orgId, "orgId");
    const roomId = requiredString(data.roomId, "roomId");
    const expectedTeamIds = parseTeamIds(data.expectedTeamIds, "expectedTeamIds", true);
    const expectedAudienceScope = data.expectedAudienceScope == null ? null :
      requiredString(data.expectedAudienceScope, "expectedAudienceScope", 220);
    const targets = parseTargets(data.teams);

    const actorSnapshot = await db.collection("users").doc(userId).get();
    const actor = actorSnapshot.data();
    if (!actorSnapshot.exists ||
        !canEditMultiTeamEventRoomAudience(actor ?? {}, orgId)) {
      throw new HttpsError(
        "permission-denied",
        "Only a Platform Owner or organization Admin can edit Event Room teams.",
      );
    }

    const roomRef = db.collection("organizations").doc(orgId)
      .collection("chatRooms").doc(roomId);
    const initialRoomSnapshot = await roomRef.get();
    const initialRoom = initialRoomSnapshot.data();
    const leagueId = typeof initialRoom?.leagueId === "string" ?
      initialRoom.leagueId.trim() : "";
    if (!initialRoomSnapshot.exists || initialRoom?.orgId !== orgId ||
        initialRoom?.type !== "event" ||
        (initialRoom?.roomPurpose != null && initialRoom.roomPurpose !== "event") ||
        initialRoom?.isArchived === true || !leagueId) {
      throw new HttpsError(
        "failed-precondition",
        "Only active Event Rooms can have their teams edited.",
      );
    }
    const initialAudience = existingEventRoomAudience(initialRoom);
    if (!initialAudience ||
        (initialAudience.legacy && expectedAudienceScope == null)) {
      throw new HttpsError(
        "failed-precondition",
        "This Event Room has an unsupported legacy audience. Refresh and try again.",
      );
    }
    if (!sameMultiTeamAudience(initialAudience.teamIds, expectedTeamIds) ||
        (expectedAudienceScope != null &&
          initialAudience.scopeKey !== expectedAudienceScope)) {
      throw new HttpsError(
        "aborted",
        "This Event Room changed after it was opened. Refresh and try again.",
      );
    }

    const teamRefs = targets.map((target) => db
      .collection("organizations").doc(orgId)
      .collection("leagues").doc(leagueId)
      .collection("hubs").doc(target.hubId)
      .collection("teams").doc(target.teamId));
    const teamSnapshots = await db.getAll(...teamRefs);
    for (let index = 0; index < teamSnapshots.length; index += 1) {
      const team = teamSnapshots[index].data();
      const target = targets[index];
      if (!teamSnapshots[index].exists || team?.orgId !== orgId ||
          team?.leagueId !== leagueId || team?.hubId !== target.hubId) {
        throw new HttpsError(
          "invalid-argument",
          `Team ${target.teamId} is not in the Event Room league and Hub.`,
        );
      }
    }

    const usersSnapshot = await db.collection("users")
      .where("orgId", "==", orgId)
      .where("isActive", "==", true)
      .get();
    const participantIds = usersSnapshot.docs
      .filter((snapshot) => belongsToMultiTeamEventRoomAudience(
        {...snapshot.data(), id: snapshot.id},
        orgId,
        targets,
      ))
      .map((snapshot) => snapshot.id);
    if (!participantIds.includes(userId)) participantIds.push(userId);

    const hubIds = [...new Set(targets.map((target) => target.hubId))];
    const teamIds = targets.map((target) => target.teamId);
    const added = teamIds.filter((id) => !expectedTeamIds.includes(id));
    const removed = expectedTeamIds.filter((id) => !teamIds.includes(id));
    const auditRef = db.collection("organizations").doc(orgId)
      .collection("auditLogs").doc();

    await db.runTransaction(async (transaction) => {
      const roomSnapshot = await transaction.get(roomRef);
      const room = roomSnapshot.data();
      if (!roomSnapshot.exists || room?.orgId !== orgId ||
          room?.type !== "event" ||
          (room?.roomPurpose != null && room.roomPurpose !== "event") ||
          room?.leagueId !== leagueId || room?.isArchived === true) {
        throw new HttpsError(
          "failed-precondition",
          "Only active Event Rooms can have their teams edited.",
        );
      }
      const currentAudience = existingEventRoomAudience(room);
      if (!currentAudience ||
          !sameMultiTeamAudience(currentAudience.teamIds, expectedTeamIds) ||
          currentAudience.scopeKey !== initialAudience.scopeKey ||
          (expectedAudienceScope != null &&
            currentAudience.scopeKey !== expectedAudienceScope)) {
        throw new HttpsError(
          "aborted",
          "This Event Room changed after it was opened. Refresh and try again.",
        );
      }

      transaction.update(roomRef, {
        roomPurpose: "event",
        // Released clients query singular fields. Sentinels prevent a repaired
        // legacy room from leaking a broader or partial audience.
        hubId: multiTeamLegacyScopeSentinel,
        teamId: multiTeamLegacyScopeSentinel,
        hubIds,
        teamIds,
        participants: participantIds,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedBy: userId,
      });
      transaction.set(auditRef, {
        action: "adminUpdateEventRoomAudience",
        actorId: userId,
        actorName: actor?.displayName ?? actor?.email ?? userId,
        actorEmail: actor?.email ?? null,
        actorRole: actor?.role,
        request: {roomId, expectedTeamIds, expectedAudienceScope, teamIds},
        result: {
          roomId,
          addedTeamIds: added,
          removedTeamIds: removed,
          convertedLegacyAudience: initialAudience.legacy,
          previousAudienceScope: initialAudience.scopeKey,
        },
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    return {
      roomId,
      addedTeamIds: added,
      removedTeamIds: removed,
      participantCount: participantIds.length,
      convertedLegacyAudience: initialAudience.legacy,
    };
  },
);

export const adminUpdateChatRoomAdditionalMembers = onCall(
  runtime,
  async (request: CallableRequest) => {
    const userId = request.auth?.uid;
    if (!userId) throw new HttpsError("unauthenticated", "Sign in is required.");
    if (request.data == null || typeof request.data !== "object" ||
        Array.isArray(request.data)) {
      throw new HttpsError("invalid-argument", "Room member details are required.");
    }

    const data = request.data as RequestRecord;
    const supportedFields = new Set([
      "orgId", "roomId", "expectedAdditionalMemberIds", "additionalMemberIds",
    ]);
    if (Object.keys(data).some((field) => !supportedFields.has(field))) {
      throw new HttpsError(
        "invalid-argument",
        "Room member details include unsupported fields.",
      );
    }
    const orgId = requiredString(data.orgId, "orgId");
    const roomId = requiredString(data.roomId, "roomId");
    const expectedIds = parseAdditionalMemberIds(
      data.expectedAdditionalMemberIds,
      "expectedAdditionalMemberIds",
    );
    const requestedIds = parseAdditionalMemberIds(
      data.additionalMemberIds,
      "additionalMemberIds",
    );

    const actorSnapshot = await db.collection("users").doc(userId).get();
    const actor = actorSnapshot.data();
    if (!actorSnapshot.exists ||
        !canEditMultiTeamEventRoomAudience(actor ?? {}, orgId)) {
      throw new HttpsError(
        "permission-denied",
        "Only a Platform Owner or organization Admin can edit room-specific access.",
      );
    }

    const roomRef = db.collection("organizations").doc(orgId)
      .collection("chatRooms").doc(roomId);
    const auditRef = db.collection("organizations").doc(orgId)
      .collection("auditLogs").doc();
    const addedIds = requestedIds.filter((id) => !expectedIds.includes(id));
    const removedIds = expectedIds.filter((id) => !requestedIds.includes(id));

    await db.runTransaction(async (transaction) => {
      const roomSnapshot = await transaction.get(roomRef);
      const room = roomSnapshot.data();
      const currentIds = existingAdditionalMemberIds(room ?? {});
      if (!roomSnapshot.exists || room?.orgId !== orgId ||
          !isRoomEligibleForAdditionalMembers(room ?? {}) || currentIds == null) {
        throw new HttpsError(
          "failed-precondition",
          "Only active Team Rooms and Event Rooms can have additional members.",
        );
      }
      if (!sameAdditionalMemberIds(currentIds, expectedIds)) {
        throw new HttpsError(
          "aborted",
          "This room changed after it was opened. Refresh and try again.",
        );
      }

      if (addedIds.length > 0) {
        const addedSnapshots = await transaction.getAll(
          ...addedIds.map((id) => db.collection("users").doc(id)),
        );
        const invalidId = addedSnapshots.find((snapshot) =>
          !snapshot.exists ||
          !isAdditionalRoomMemberCandidate(snapshot.data() ?? {}, orgId),
        )?.id;
        if (invalidId) {
          throw new HttpsError(
            "invalid-argument",
            "Additional members must be active, non-admin league staff " +
              "without Team or Hub assignments.",
          );
        }
      }

      transaction.update(roomRef, {
        additionalMemberIds: requestedIds,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedBy: userId,
      });
      transaction.set(auditRef, {
        action: "adminUpdateChatRoomAdditionalMembers",
        actorId: userId,
        actorName: actor?.displayName ?? actor?.email ?? userId,
        actorEmail: actor?.email ?? null,
        actorRole: actor?.role,
        request: {roomId, expectedAdditionalMemberIds: expectedIds},
        result: {
          roomId,
          additionalMemberIds: requestedIds,
          addedMemberIds: addedIds,
          removedMemberIds: removedIds,
        },
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    return {
      roomId,
      additionalMemberIds: requestedIds,
      addedMemberIds: addedIds,
      removedMemberIds: removedIds,
    };
  },
);
