/**
 * Cloud Functions for League Hub – Push Notifications
 *
 * Triggers on Firestore writes and sends FCM notifications to relevant users.
 * Each user stores their FCM tokens in /users/{uid}/fcmTokens.
 */

export { onAnnouncementCreated } from "./notifications/announcements";
export { onMessageCreated } from "./notifications/messages";
export { onDocumentCreated } from "./notifications/documents";
export { onTeamUpdated } from "./notifications/teams";
export { onInvitationCreated } from "./notifications/invitations";
export { onUserRoleChanged } from "./notifications/roleChanges";
