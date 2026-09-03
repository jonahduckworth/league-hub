import * as admin from "firebase-admin";
import {logger} from "firebase-functions";
import {defineSecret} from "firebase-functions/params";
import {onDocumentCreated as onFirestoreCreated} from "firebase-functions/v2/firestore";
import { db, sendNotification } from "../helpers";
import {
  buildInvitationEmail,
  classifyInvitationDeliveryFailure,
  invitationExpiresAt,
  invitationIdempotencyKey,
  invitationProfileTitleForUser,
  normalizeInvitationRecipient,
  normalizeInvitationToken,
} from "../invitationEmailLogic";

const RESEND_API_KEY = defineSecret("RESEND_API_KEY");
const invitationSender = "League Hub <no-reply@leaguehub.ca>";

function stringValue(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function normalizeEmail(value: unknown): string {
  return stringValue(value).toLowerCase();
}

function toIsoString(value: unknown): string {
  if (typeof value === "string") {
    return value;
  }

  const timestamp = value as { toDate?: () => Date } | undefined;
  if (timestamp?.toDate) {
    return timestamp.toDate().toISOString();
  }

  return new Date().toISOString();
}

async function ensureInvitationLookup(
  token: string,
  orgId: string,
  invitationId: string,
  data: FirebaseFirestore.DocumentData,
  expiresAt: admin.firestore.Timestamp,
): Promise<void> {
  const lookupRef = db.collection("invitationLookups").doc(token);
  await db.runTransaction(async (transaction) => {
    const lookupDoc = await transaction.get(lookupRef);
    if (lookupDoc.exists) {
      transaction.set(lookupRef, {expiresAt}, {merge: true});
    } else {
      transaction.set(lookupRef, {
        token,
        orgId,
        invitationId,
        email: data.email || "",
        status: data.status || "pending",
        createdAt: toIsoString(data.createdAt),
        expiresAt,
      });
    }
  });
}

function sameInvitee(
  userData: FirebaseFirestore.DocumentData,
  inviteData: FirebaseFirestore.DocumentData,
  orgId: string,
): boolean {
  const userEmail = normalizeEmail(userData.email);
  const inviteEmail = normalizeEmail(inviteData.email);
  if (!userEmail || userEmail !== inviteEmail) return false;

  const inviteOrgId = stringValue(inviteData.orgId);
  if (inviteOrgId && inviteOrgId !== orgId) return false;

  const inviteRole = stringValue(inviteData.role);
  const userRole = stringValue(userData.role);
  if (inviteRole && userRole && inviteRole !== userRole) return false;

  return true;
}

async function markInvitationAcceptedFromUser(
  orgId: string,
  invitationId: string,
  userRef: FirebaseFirestore.DocumentReference,
  userData: FirebaseFirestore.DocumentData,
): Promise<void> {
  const invitationRef = db
    .collection("organizations")
    .doc(orgId)
    .collection("invitations")
    .doc(invitationId);

  await db.runTransaction(async (transaction) => {
    const invitationDoc = await transaction.get(invitationRef);
    if (!invitationDoc.exists) return;

    const invitationData = invitationDoc.data() ?? {};
    if (invitationData.status !== "pending" && invitationData.status !== "accepted") return;
    if (!sameInvitee(userData, invitationData, orgId)) return;

    if (invitationData.status === "pending") {
      transaction.update(invitationRef, { status: "accepted" });
      const token = stringValue(invitationData.token);
      if (token) {
        transaction.set(
          db.collection("invitationLookups").doc(token),
          { status: "accepted" },
          { merge: true },
        );
      }
    }

    const title = invitationProfileTitleForUser(invitationData.title, userData.title);
    if (title) {
      transaction.update(userRef, { title });
    }
  });
}

/**
 * Triggers when a new invitation is created.
 * Path: organizations/{orgId}/invitations/{invitationId}
 *
 * Sends a notification to the invitee if they already have an account,
 * and notifies org admins about the new invitation.
 */
export const onInvitationCreated = onFirestoreCreated(
  "organizations/{orgId}/invitations/{invitationId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const data = snapshot.data();
    const orgId = event.params.orgId;
    const invitationId = event.params.invitationId;
    const token = (data.token as string) || "";
    const inviteeEmail = (data.email as string) || "";
    const inviteeName = (data.displayName as string) || inviteeEmail;
    const invitedByName = (data.invitedByName as string) || "Someone";
    const expiresAt = admin.firestore.Timestamp.fromDate(
      invitationExpiresAt(snapshot.createTime.toDate()),
    );

    await snapshot.ref.set({expiresAt}, {merge: true});

    if (token) {
      await ensureInvitationLookup(token, orgId, invitationId, data, expiresAt);
    }

    // Notify admins in the org about the new invitation.
    const adminsSnap = await db
      .collection("users")
      .where("orgId", "==", orgId)
      .where("isActive", "==", true)
      .where("role", "in", ["platformOwner", "superAdmin"])
      .get();

    const adminTokens: string[] = [];
    for (const doc of adminsSnap.docs) {
      const userData = doc.data();
      const tokens = userData.fcmTokens as string[] | undefined;
      if (tokens && tokens.length > 0) {
        adminTokens.push(...tokens);
      }
    }

    if (adminTokens.length > 0) {
      await sendNotification(
        adminTokens,
        {
          title: "New Invitation Sent",
          body: `${invitedByName} invited ${inviteeName} to join the organization`,
        },
        {
          type: "invitation",
          orgId,
        },
      );
    }

    // If the invitee already has an account, notify them too.
    const existingUserSnap = await db
      .collection("users")
      .where("email", "==", inviteeEmail)
      .limit(1)
      .get();

    if (!existingUserSnap.empty) {
      const existingUser = existingUserSnap.docs[0].data();
      const userTokens = existingUser.fcmTokens as string[] | undefined;
      if (userTokens && userTokens.length > 0) {
        await sendNotification(
          userTokens,
          {
            title: "You've Been Invited!",
            body: `${invitedByName} has invited you to join their organization`,
          },
          {
            type: "invitation_received",
            orgId,
          },
        );
      }
    }
  },
);

/**
 * Delivers a durable transactional email for every new invitation.
 * Kept separate from push delivery so an email retry cannot duplicate pushes.
 */
export const onInvitationEmailCreated = onFirestoreCreated(
  {
    document: "organizations/{orgId}/invitations/{invitationId}",
    region: "us-central1",
    timeoutSeconds: 30,
    memory: "256MiB",
    secrets: [RESEND_API_KEY],
    retry: true,
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const invitationRef = snapshot.ref;
    const expiresAt = admin.firestore.Timestamp.fromDate(
      invitationExpiresAt(snapshot.createTime.toDate()),
    );
    await invitationRef.set({expiresAt}, {merge: true});
    const currentSnapshot = await invitationRef.get();
    const invitation = currentSnapshot.data();
    if (!invitation || invitation.status !== "pending") return;
    if (invitation.emailDeliveryStatus === "delivered") return;

    const recipient = normalizeInvitationRecipient(invitation.email);
    if (!recipient) {
      await invitationRef.set({
        emailDeliveryStatus: "failed",
        emailDeliveryError: "invalid-email",
        emailDeliveryAttemptedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
      logger.error("Invitation email has an invalid recipient", {
        orgId: event.params.orgId,
        invitationId: event.params.invitationId,
      });
      return;
    }

    const token = normalizeInvitationToken(invitation.token);
    if (!token) {
      await invitationRef.set({
        emailDeliveryStatus: "failed",
        emailDeliveryError: "invalid-token",
        emailDeliveryAttemptedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
      logger.error("Invitation email has an invalid token", {
        orgId: event.params.orgId,
        invitationId: event.params.invitationId,
      });
      return;
    }

    await ensureInvitationLookup(
      token,
      event.params.orgId,
      event.params.invitationId,
      invitation,
      expiresAt,
    );

    const organizationSnapshot = await db.collection("organizations")
      .doc(event.params.orgId)
      .get();
    const organizationName = stringValue(organizationSnapshot.data()?.name) ||
      "your organization";
    const message = buildInvitationEmail({
      recipientName: stringValue(invitation.displayName) || null,
      organizationName,
      invitedByName: stringValue(invitation.invitedByName),
      role: stringValue(invitation.role),
      token,
      expiresAt: expiresAt.toDate(),
    });

    let response: Response;
    try {
      response = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${RESEND_API_KEY.value()}`,
          "Content-Type": "application/json",
          "Idempotency-Key": invitationIdempotencyKey(
            event.params.orgId,
            event.params.invitationId,
          ),
        },
        body: JSON.stringify({
          from: invitationSender,
          to: [recipient],
          subject: message.subject,
          text: message.text,
          html: message.html,
        }),
      });
    } catch (error) {
      const failure = classifyInvitationDeliveryFailure(null);
      await invitationRef.set({
        emailDeliveryStatus: failure.deliveryStatus,
        emailDeliveryError: failure.code,
        emailDeliveryAttemptedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
      logger.error("Invitation email request failed", {
        error,
        orgId: event.params.orgId,
        invitationId: event.params.invitationId,
      });
      throw error;
    }

    if (!response.ok) {
      const responseBody = await response.text();
      const failure = classifyInvitationDeliveryFailure(
        response.status,
        responseBody,
      );
      await invitationRef.set({
        emailDeliveryStatus: failure.deliveryStatus,
        emailDeliveryError: failure.code,
        emailDeliveryAttemptedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
      logger.error("Invitation email delivery failed", {
        status: response.status,
        code: failure.code,
        orgId: event.params.orgId,
        invitationId: event.params.invitationId,
      });
      if (failure.retryable) {
        throw new Error(
          `Retryable invitation email delivery failure (${failure.code})`,
        );
      }
      return;
    }

    const result = await response.json() as {id?: unknown};
    await invitationRef.set({
      emailDeliveryStatus: "delivered",
      emailDeliveredAt: admin.firestore.FieldValue.serverTimestamp(),
      emailDeliveryAttemptedAt: admin.firestore.FieldValue.serverTimestamp(),
      emailDeliveryError: admin.firestore.FieldValue.delete(),
      emailProviderId: typeof result.id === "string" ? result.id : null,
    }, {merge: true});
    logger.info("Invitation email delivered", {
      orgId: event.params.orgId,
      invitationId: event.params.invitationId,
    });
  },
);

export const onUserCreatedFromInvitation = onFirestoreCreated(
  "users/{userId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const userData = snapshot.data();
    if (userData.isActive !== true) return;

    const orgId = stringValue(userData.orgId);
    const acceptedInvitationId = stringValue(userData.acceptedInvitationId);
    if (!orgId || !acceptedInvitationId) return;

    await markInvitationAcceptedFromUser(
      orgId,
      acceptedInvitationId,
      snapshot.ref,
      userData,
    );
  },
);
