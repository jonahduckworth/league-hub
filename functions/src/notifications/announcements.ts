import * as admin from "firebase-admin";
import {logger} from "firebase-functions";
import {defineSecret} from "firebase-functions/params";
import {onDocumentCreated as onFirestoreCreated} from "firebase-functions/v2/firestore";
import { db, getUserTokens, sendNotification } from "../helpers";
import {
  canReceiveAnnouncementNotification,
  shouldSendAnnouncementEmail,
  shouldSendAnnouncementPush,
} from "./announcementLogic";
import {
  announcementBatchIdempotencyKey,
  buildAnnouncementEmail,
  classifyAnnouncementDeliveryFailure,
  normalizeAnnouncementRecipient,
} from "./announcementEmailLogic";

const RESEND_API_KEY = defineSecret("RESEND_API_KEY");
const announcementSender = "League Hub <no-reply@leaguehub.ca>";

type EmailRecipient = {
  userId: string;
  email: string;
  displayName: string | null;
};

function stringValue(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function chunksOf<T>(values: T[], size: number): T[][] {
  const chunks: T[][] = [];
  for (let index = 0; index < values.length; index += size) {
    chunks.push(values.slice(index, index + size));
  }
  return chunks;
}

/**
 * Triggers when a new announcement is created.
 * Path: organizations/{orgId}/announcements/{announcementId}
 */
export const onAnnouncementCreated = onFirestoreCreated(
  "organizations/{orgId}/announcements/{announcementId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const data = snapshot.data();
    const orgId = event.params.orgId;
    const title = (data.title as string) || "New Announcement";
    const authorName = (data.authorName as string) || "Someone";
    const scope = (data.scope as string) || "league";
    const isPinned = data.isPinned === true;

    const usersSnap = await db
      .collection("users")
      .where("orgId", "==", orgId)
      .where("isActive", "==", true)
      .get();
    const recipientIds = usersSnap.docs
      .filter((user) =>
        canReceiveAnnouncementNotification(user.data(), data) &&
        shouldSendAnnouncementPush(user.data()),
      )
      .map((user) => user.id);
    const tokens = await getUserTokens(recipientIds);

    await sendNotification(
      tokens,
      {
        title: isPinned ? `📌 ${title}` : title,
        body: `${authorName} posted a new ${scope} announcement`,
      },
      {
        type: "announcement",
        announcementId: event.params.announcementId,
        orgId,
      },
    );
  },
);

/**
 * Delivers announcement email separately from push so retries cannot duplicate
 * device notifications. Each batch is idempotent and records its recipients.
 */
export const onAnnouncementEmailCreated = onFirestoreCreated(
  {
    document: "organizations/{orgId}/announcements/{announcementId}",
    region: "us-central1",
    timeoutSeconds: 120,
    memory: "256MiB",
    secrets: [RESEND_API_KEY],
    retry: true,
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const announcement = snapshot.data();
    const orgId = event.params.orgId;
    const announcementId = event.params.announcementId;
    const usersSnapshot = await db
      .collection("users")
      .where("orgId", "==", orgId)
      .where("isActive", "==", true)
      .get();
    const recipients: EmailRecipient[] = [];
    const invalidRecipientIds: string[] = [];

    for (const userDocument of usersSnapshot.docs) {
      const user = userDocument.data();
      if (!canReceiveAnnouncementNotification(user, announcement) ||
          !shouldSendAnnouncementEmail(user)) {
        continue;
      }
      const email = normalizeAnnouncementRecipient(user.email);
      if (!email) {
        invalidRecipientIds.push(userDocument.id);
        continue;
      }
      recipients.push({
        userId: userDocument.id,
        email,
        displayName: stringValue(user.displayName) || null,
      });
    }
    // Keep batch membership and response-to-recipient mapping deterministic
    // across retries, independent of Firestore query ordering.
    recipients.sort((left, right) => left.userId.localeCompare(right.userId));

    const deliveries = snapshot.ref.collection("emailDeliveries");
    for (const userId of invalidRecipientIds) {
      await deliveries.doc(userId).set({
        status: "failed",
        error: "invalid-email",
        attemptedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
    }

    const organizationDocument = await db.collection("organizations")
      .doc(orgId)
      .get();
    const organizationName = stringValue(organizationDocument.data()?.name) ||
      "League Hub";
    let delivered = 0;

    for (const recipientChunk of chunksOf(recipients, 100)) {
      const deliveryReferences = recipientChunk.map((recipient) =>
        deliveries.doc(recipient.userId),
      );
      const deliverySnapshots = await db.getAll(...deliveryReferences);
      const pendingRecipients = recipientChunk.filter((_, index) =>
        deliverySnapshots[index].data()?.status !== "delivered",
      );
      if (pendingRecipients.length === 0) continue;

      const messages = pendingRecipients.map((recipient) => {
        const message = buildAnnouncementEmail({
          recipientName: recipient.displayName,
          organizationName,
          title: stringValue(announcement.title),
          body: stringValue(announcement.body),
          authorName: stringValue(announcement.authorName),
          scope: stringValue(announcement.scope),
          announcementId,
          isPinned: announcement.isPinned === true,
        });
        return {
          from: announcementSender,
          to: [recipient.email],
          subject: message.subject,
          text: message.text,
          html: message.html,
        };
      });

      let response: Response;
      try {
        response = await fetch("https://api.resend.com/emails/batch", {
          method: "POST",
          headers: {
            "Authorization": `Bearer ${RESEND_API_KEY.value()}`,
            "Content-Type": "application/json",
            "Idempotency-Key": announcementBatchIdempotencyKey(
              orgId,
              announcementId,
              pendingRecipients.map((recipient) => recipient.userId),
            ),
          },
          body: JSON.stringify(messages),
        });
      } catch (error) {
        const writeBatch = db.batch();
        for (const recipient of pendingRecipients) {
          writeBatch.set(deliveries.doc(recipient.userId), {
            status: "retrying",
            error: "network_error",
            attemptedAt: admin.firestore.FieldValue.serverTimestamp(),
          }, {merge: true});
        }
        await writeBatch.commit();
        logger.error("Announcement email batch request failed", {
          error,
          orgId,
          announcementId,
          recipientCount: pendingRecipients.length,
        });
        throw error;
      }

      if (!response.ok) {
        const responseBody = await response.text();
        const failure = classifyAnnouncementDeliveryFailure(
          response.status,
          responseBody,
        );
        const writeBatch = db.batch();
        for (const recipient of pendingRecipients) {
          writeBatch.set(deliveries.doc(recipient.userId), {
            status: failure.deliveryStatus,
            error: failure.code,
            attemptedAt: admin.firestore.FieldValue.serverTimestamp(),
          }, {merge: true});
        }
        await writeBatch.commit();
        logger.error("Announcement email batch delivery failed", {
          status: response.status,
          code: failure.code,
          orgId,
          announcementId,
          recipientCount: pendingRecipients.length,
        });
        if (failure.retryable) {
          throw new Error(
            `Retryable announcement email delivery failure (${failure.code})`,
          );
        }
        continue;
      }

      const result = await response.json() as {
        data?: Array<{id?: unknown}>;
      };
      const providerResults = result.data ?? [];
      const writeBatch = db.batch();
      pendingRecipients.forEach((recipient, index) => {
        writeBatch.set(deliveries.doc(recipient.userId), {
          status: "delivered",
          providerId: typeof providerResults[index]?.id === "string" ?
            providerResults[index].id : null,
          deliveredAt: admin.firestore.FieldValue.serverTimestamp(),
          attemptedAt: admin.firestore.FieldValue.serverTimestamp(),
          error: admin.firestore.FieldValue.delete(),
        }, {merge: true});
      });
      await writeBatch.commit();
      delivered += pendingRecipients.length;
    }

    logger.info("Announcement email delivery completed", {
      orgId,
      announcementId,
      delivered,
      invalidRecipients: invalidRecipientIds.length,
    });
  },
);
