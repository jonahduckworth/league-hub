export const EVENT_ROOM_IMAGE_MAX_BYTES = 10 * 1024 * 1024;

const supportedEventRoomImageTypes = new Set([
  "image/jpeg",
  "image/png",
  "image/webp"
]);

export function validateEventRoomImageFile(
  file: Pick<File, "name" | "size" | "type">
): string | null {
  if (!supportedEventRoomImageTypes.has(file.type)) {
    return "Choose a PNG, JPG, or WebP image.";
  }
  if (file.size <= 0) return "The selected room image is empty.";
  if (file.size > EVENT_ROOM_IMAGE_MAX_BYTES) {
    return "Room images must be 10 MB or smaller.";
  }
  return null;
}

export function eventRoomImageStoragePath({
  orgId,
  roomId,
  userId,
  fileName,
  timestamp = Date.now()
}: {
  orgId: string;
  roomId: string;
  userId: string;
  fileName: string;
  timestamp?: number;
}): string {
  const safeName = fileName.replace(/[^a-zA-Z0-9._-]/g, "_");
  return `orgs/${orgId}/chat/${roomId}/room-images/${userId}/${timestamp}_${safeName}`;
}
