import { describe, expect, it } from "vitest";
import {
  EVENT_ROOM_IMAGE_MAX_BYTES,
  eventRoomImageStoragePath,
  validateEventRoomImageFile
} from "../event-room-image";

describe("Event Room image helpers", () => {
  it("accepts supported room images within the Storage limit", () => {
    expect(validateEventRoomImageFile({ name: "showcase.png", size: 1024, type: "image/png" })).toBeNull();
    expect(validateEventRoomImageFile({ name: "showcase.jpg", size: EVENT_ROOM_IMAGE_MAX_BYTES, type: "image/jpeg" })).toBeNull();
    expect(validateEventRoomImageFile({ name: "showcase.webp", size: 2048, type: "image/webp" })).toBeNull();
  });

  it("rejects unsupported, empty, and oversized room images", () => {
    expect(validateEventRoomImageFile({ name: "showcase.svg", size: 1024, type: "image/svg+xml" })).toMatch(/PNG, JPG, or WebP/);
    expect(validateEventRoomImageFile({ name: "showcase.png", size: 0, type: "image/png" })).toMatch(/empty/);
    expect(validateEventRoomImageFile({ name: "showcase.png", size: EVENT_ROOM_IMAGE_MAX_BYTES + 1, type: "image/png" })).toMatch(/10 MB/);
  });

  it("builds the existing owner-scoped room image path", () => {
    expect(eventRoomImageStoragePath({
      orgId: "org-1",
      roomId: "room-1",
      userId: "admin-1",
      fileName: "Provincial Showcase (Final).png",
      timestamp: 123
    })).toBe("orgs/org-1/chat/room-1/room-images/admin-1/123_Provincial_Showcase__Final_.png");
  });
});
